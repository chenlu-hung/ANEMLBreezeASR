import Foundation

enum LLMError: LocalizedError {
    case notConfigured
    case invalidSettings
    case apiError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "LLM service not configured"
        case .invalidSettings:
            return "Invalid LLM settings"
        case .apiError(let message):
            return "LLM API error: \(message)"
        case .invalidResponse:
            return "Invalid response from LLM"
        }
    }
}

struct LLMSRTResult {
    let content: String
    let mismatches: Int
    let originalCount: Int
}

@MainActor
class LLMService {
    private var currentSettings: LLMSettings?
    private let subtitleService = SubtitleService()
    private let urlSession = URLSession.shared
    /// Start time of the most recent request, used to pace requests (see `throttleIfNeeded`).
    private var lastRequestStart: Date?

    func configure(settings: LLMSettings) {
        guard !settings.apiKey.isEmpty else {
            self.currentSettings = nil
            return
        }

        self.currentSettings = settings
        NSLog("ANEMLBreezeASR: LLM configured — host=%@, basePath=%@, model=%@", settings.host, settings.basePath, settings.modelName)
    }

    func correctSubtitles(
        srtContent: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> LLMSRTResult {
        guard let settings = currentSettings else {
            throw LLMError.notConfigured
        }

        return try await sendChunkedRequest(
            srtContent: srtContent,
            systemPrompt: settings.systemPrompt,
            userPromptPrefix: "Please correct the following SRT subtitles:",
            logLabel: "correct",
            mode: .correct,
            progressHandler: progressHandler
        )
    }

    func translateSubtitles(
        srtContent: String,
        targetLanguage: SupportedLanguage,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> LLMSRTResult {
        let systemPrompt = """
You are a subtitle translation assistant. Your task is to:
1. Translate all subtitle text to \(targetLanguage.displayName)
2. Maintain the exact same SRT format, numbering, and timing
3. Keep the same number of subtitle segments
4. Return ONLY the translated subtitles in the exact same SRT format

Do not add explanations or change the timing. Just translate the text.
"""

        return try await sendChunkedRequest(
            srtContent: srtContent,
            systemPrompt: systemPrompt,
            userPromptPrefix: "Please translate the following SRT subtitles to \(targetLanguage.displayName):",
            logLabel: "translate",
            mode: .translate,
            progressHandler: progressHandler
        )
    }

    // MARK: - Shared chunked LLM request

    private enum LLMRequestMode {
        case correct
        case translate
    }

    private func sendChunkedRequest(
        srtContent: String,
        systemPrompt: String,
        userPromptPrefix: String,
        logLabel: String,
        mode: LLMRequestMode,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> LLMSRTResult {
        guard let settings = currentSettings else {
            throw LLMError.notConfigured
        }

        guard !settings.apiKey.isEmpty else {
            throw LLMError.invalidSettings
        }

        let chunks = splitSRTIntoChunks(srtContent)
        var resultChunks: [String] = []
        var totalMismatches = 0
        var totalOriginalCount = 0

        for (index, chunk) in chunks.enumerated() {
            let chunkEntryCount = countEntries(in: chunk)
            totalOriginalCount += chunkEntryCount
            let chunkLabel = "\(index + 1)/\(chunks.count)"

            let processed: (content: String, mismatches: Int)
            switch mode {
            case .correct:
                processed = try await processCorrectChunk(
                    chunk: chunk,
                    systemPrompt: systemPrompt,
                    userPromptPrefix: userPromptPrefix,
                    logLabel: logLabel,
                    chunkLabel: chunkLabel
                )
                if processed.mismatches > 0 {
                    NSLog("ANEMLBreezeASR: LLM %@ chunk %@ — %d/%d entries fell back to original text", logLabel, chunkLabel, processed.mismatches, chunkEntryCount)
                }
            case .translate:
                processed = try await processTranslateChunk(
                    chunk: chunk,
                    systemPrompt: systemPrompt,
                    userPromptPrefix: userPromptPrefix,
                    logLabel: logLabel,
                    chunkPath: chunkLabel
                )
                if processed.mismatches > 0 {
                    NSLog("ANEMLBreezeASR: LLM %@ chunk %@ — %d/%d entries left empty after retries", logLabel, chunkLabel, processed.mismatches, chunkEntryCount)
                }
            }

            resultChunks.append(processed.content)
            totalMismatches += processed.mismatches
            progressHandler?(Double(index + 1) / Double(chunks.count))
        }

        return LLMSRTResult(
            content: resultChunks.joined(separator: "\n\n"),
            mismatches: totalMismatches,
            originalCount: totalOriginalCount
        )
    }

    private func processCorrectChunk(
        chunk: String,
        systemPrompt: String,
        userPromptPrefix: String,
        logLabel: String,
        chunkLabel: String
    ) async throws -> (content: String, mismatches: Int) {
        let response = try await sendSingleLLMRequest(
            chunk: chunk,
            systemPrompt: systemPrompt,
            userPromptPrefix: userPromptPrefix,
            logLabel: logLabel,
            chunkLabel: chunkLabel
        )
        let reattached = subtitleService.reattachOriginalTimestamps(
            originalSRT: chunk,
            llmOutput: response,
            fallback: .keepOriginal
        )
        return (reattached.srtContent, reattached.mismatches)
    }

    /// For translation: send the chunk, and if any entries fail to align, recursively split the chunk
    /// in half and retry each half. Single-entry chunks that still fail to align fall back to empty text
    /// so the output never contains source-language content.
    private func processTranslateChunk(
        chunk: String,
        systemPrompt: String,
        userPromptPrefix: String,
        logLabel: String,
        chunkPath: String
    ) async throws -> (content: String, mismatches: Int) {
        let response = try await sendSingleLLMRequest(
            chunk: chunk,
            systemPrompt: systemPrompt,
            userPromptPrefix: userPromptPrefix,
            logLabel: logLabel,
            chunkLabel: chunkPath
        )

        let attempt = subtitleService.reattachOriginalTimestamps(
            originalSRT: chunk,
            llmOutput: response,
            fallback: .empty
        )

        if attempt.mismatches == 0 {
            return (attempt.srtContent, 0)
        }

        let entries = splitEntries(chunk)
        if entries.count <= 1 {
            NSLog("ANEMLBreezeASR: LLM %@ chunk %@ — single-entry retry still mismatched, leaving empty", logLabel, chunkPath)
            return (attempt.srtContent, attempt.mismatches)
        }

        NSLog("ANEMLBreezeASR: LLM %@ chunk %@ — alignment mismatch on %d entries, splitting and retrying", logLabel, chunkPath, entries.count)

        let mid = entries.count / 2
        let firstHalf = entries[..<mid].joined(separator: "\n\n")
        let secondHalf = entries[mid...].joined(separator: "\n\n")

        let first = try await processTranslateChunk(
            chunk: firstHalf,
            systemPrompt: systemPrompt,
            userPromptPrefix: userPromptPrefix,
            logLabel: logLabel,
            chunkPath: "\(chunkPath).a"
        )
        let second = try await processTranslateChunk(
            chunk: secondHalf,
            systemPrompt: systemPrompt,
            userPromptPrefix: userPromptPrefix,
            logLabel: logLabel,
            chunkPath: "\(chunkPath).b"
        )

        return (
            first.content + "\n\n" + second.content,
            first.mismatches + second.mismatches
        )
    }

    private func sendSingleLLMRequest(
        chunk: String,
        systemPrompt: String,
        userPromptPrefix: String,
        logLabel: String,
        chunkLabel: String
    ) async throws -> String {
        guard let settings = currentSettings else {
            throw LLMError.notConfigured
        }

        guard let url = chatCompletionsURL(for: settings) else {
            NSLog("ANEMLBreezeASR: LLM %@ chunk %@ — invalid endpoint: %@", logLabel, chunkLabel, settings.apiEndpoint)
            throw LLMError.invalidSettings
        }

        let body = ChatRequest(
            model: settings.modelName,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: "\(userPromptPrefix)\n\n\(chunk)")
            ]
        )

        var request = URLRequest(url: url, timeoutInterval: 600.0)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        // OpenRouter ranking headers — ignored by other OpenAI-compatible providers.
        request.setValue("https://github.com/ANEMLBreezeASR", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("ANEMLBreezeASR", forHTTPHeaderField: "X-Title")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw LLMError.apiError("Failed to encode request: \(error.localizedDescription)")
        }

        // Proactively pace requests to stay under a provider's rate limit.
        await throttleIfNeeded(interval: settings.requestIntervalSeconds)

        // Retry rate-limit (429) and transient server errors (5xx) with backoff,
        // honoring a `Retry-After` header when the provider sends one. Free/loaded
        // OpenAI-compatible providers (e.g. OpenRouter free models) rate-limit aggressively.
        let maxAttempts = 5
        var attempt = 0

        while true {
            attempt += 1
            do {
                NSLog("ANEMLBreezeASR: LLM %@ chunk %@ — sending request (attempt %d/%d)...", logLabel, chunkLabel, attempt, maxAttempts)

                let (data, response) = try await urlSession.data(for: request)
                let http = response as? HTTPURLResponse
                let statusCode = http?.statusCode ?? 0

                // Parse leniently — every field is optional, so a missing/null `finish_reason`,
                // `index`, etc. (common from free/loaded OpenAI-compatible providers) never throws.
                let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data)

                if (200..<300).contains(statusCode),
                   let content = decoded?.choices?.first?.message?.content {
                    NSLog("ANEMLBreezeASR: LLM %@ chunk %@ — success (%d chars)", logLabel, chunkLabel, content.count)
                    return content
                }

                let bodyText = String(data: data, encoding: .utf8) ?? "<non-text response>"
                let detail = decoded?.error?.message ?? String(bodyText.prefix(500))

                let isRetryable = statusCode == 429 || (500..<600).contains(statusCode)
                if isRetryable && attempt < maxAttempts {
                    let delay = retryDelaySeconds(from: http, attempt: attempt)
                    NSLog("ANEMLBreezeASR: LLM %@ chunk %@ — HTTP %d, retrying in %.0fs (attempt %d/%d): %@", logLabel, chunkLabel, statusCode, delay, attempt, maxAttempts, detail)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                // Surface the real failure instead of a generic decode error.
                NSLog("ANEMLBreezeASR: LLM %@ chunk %@ — HTTP %d: %@", logLabel, chunkLabel, statusCode, detail)
                throw LLMError.apiError("HTTP \(statusCode): \(detail)")
            } catch let error as LLMError {
                throw error
            } catch {
                NSLog("ANEMLBreezeASR: LLM %@ chunk %@ — error: %@", logLabel, chunkLabel, error.localizedDescription)
                throw LLMError.apiError(error.localizedDescription)
            }
        }
    }

    /// Pace requests so consecutive sends are at least `interval` seconds apart
    /// (measured start-to-start). Sleeps only the remaining time, so providers whose
    /// requests already take longer than `interval` incur no extra delay.
    private func throttleIfNeeded(interval: Double) async {
        guard interval > 0 else { return }
        if let last = lastRequestStart {
            let remaining = interval - Date().timeIntervalSince(last)
            if remaining > 0 {
                NSLog("ANEMLBreezeASR: LLM throttle — waiting %.1fs (interval %.1fs)", remaining, interval)
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
        }
        lastRequestStart = Date()
    }

    /// Backoff delay for a retry. Prefers the provider's `Retry-After` header (seconds),
    /// otherwise exponential backoff capped at 60s.
    private func retryDelaySeconds(from response: HTTPURLResponse?, attempt: Int) -> Double {
        if let retryAfter = response?.value(forHTTPHeaderField: "Retry-After"),
           let seconds = Double(retryAfter.trimmingCharacters(in: .whitespaces)) {
            return min(max(seconds, 1), 60)
        }
        return min(pow(2.0, Double(attempt)), 60)
    }

    /// Build the `/chat/completions` URL by appending to the configured endpoint,
    /// preserving multi-segment base paths (e.g. Gemini's `/v1beta/openai`).
    private func chatCompletionsURL(for settings: LLMSettings) -> URL? {
        var base = settings.apiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        return URL(string: base + "/chat/completions")
    }

    private struct ChatRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }
        let model: String
        let messages: [Message]
    }

    /// Tolerant response shape — only what we need, everything optional.
    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message?
        }
        struct APIError: Decodable { let message: String? }
        let choices: [Choice]?
        let error: APIError?
    }

    private func splitEntries(_ chunk: String) -> [String] {
        chunk.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Count SRT entries in a chunk using the same blank-line separator logic as splitSRTIntoChunks.
    private func countEntries(in chunk: String) -> Int {
        chunk.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }

    // MARK: - SRT Chunking

    /// Estimate token count using a conservative heuristic (characters / 3) that handles CJK and Latin text.
    private func estimateTokenCount(_ text: String) -> Int {
        max(1, text.count / 3)
    }

    /// Split SRT content into chunks that each fit within the token limit.
    /// Each chunk contains complete subtitle entries (never splits mid-entry).
    private func splitSRTIntoChunks(_ srtContent: String, maxTokens: Int = 10_000) -> [String] {
        let entries = srtContent.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard !entries.isEmpty else { return [srtContent] }

        var chunks: [String] = []
        var currentChunkEntries: [String] = []
        var currentTokenCount = 0

        for entry in entries {
            let entryTokens = estimateTokenCount(entry)

            if !currentChunkEntries.isEmpty && currentTokenCount + entryTokens > maxTokens {
                chunks.append(currentChunkEntries.joined(separator: "\n\n"))
                currentChunkEntries = []
                currentTokenCount = 0
            }

            currentChunkEntries.append(entry)
            currentTokenCount += entryTokens
        }

        if !currentChunkEntries.isEmpty {
            chunks.append(currentChunkEntries.joined(separator: "\n\n"))
        }

        return chunks.isEmpty ? [srtContent] : chunks
    }

    var isConfigured: Bool {
        currentSettings != nil && !(currentSettings?.apiKey.isEmpty ?? true)
    }
}
