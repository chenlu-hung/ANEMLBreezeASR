import Foundation
import OpenAI

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

@MainActor
class LLMService {
    private var openAI: OpenAI?
    private var currentSettings: LLMSettings?

    func configure(settings: LLMSettings) {
        guard !settings.apiKey.isEmpty else {
            self.openAI = nil
            self.currentSettings = nil
            return
        }

        let configuration = OpenAI.Configuration(
            token: settings.apiKey,
            host: settings.host,
            port: settings.port ?? 443,
            scheme: settings.scheme,
            basePath: settings.basePath,
            timeoutInterval: 600.0
        )

        self.openAI = OpenAI(configuration: configuration)
        self.currentSettings = settings
        NSLog("ANEMLBreezeASR: LLM configured — host=%@, basePath=%@, model=%@", settings.host, settings.basePath, settings.modelName)
    }

    func correctSubtitles(
        srtContent: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> String {
        guard let settings = currentSettings else {
            throw LLMError.notConfigured
        }

        return try await sendChunkedRequest(
            srtContent: srtContent,
            systemPrompt: settings.systemPrompt,
            userPromptPrefix: "Please correct the following SRT subtitles:",
            logLabel: "correct",
            progressHandler: progressHandler
        )
    }

    func translateSubtitles(
        srtContent: String,
        targetLanguage: SupportedLanguage,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> String {
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
            progressHandler: progressHandler
        )
    }

    // MARK: - Shared chunked LLM request

    private func sendChunkedRequest(
        srtContent: String,
        systemPrompt: String,
        userPromptPrefix: String,
        logLabel: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> String {
        guard let client = openAI, let settings = currentSettings else {
            throw LLMError.notConfigured
        }

        guard !settings.apiKey.isEmpty else {
            throw LLMError.invalidSettings
        }

        let chunks = splitSRTIntoChunks(srtContent)
        var resultChunks: [String] = []

        for (index, chunk) in chunks.enumerated() {
            do {
                NSLog("ANEMLBreezeASR: LLM %@ chunk %d/%d — sending request...", logLabel, index + 1, chunks.count)

                let query = ChatQuery(
                    messages: [
                        .init(role: .system, content: systemPrompt)!,
                        .init(role: .user, content: """
\(userPromptPrefix)

\(chunk)
""")!
                    ],
                    model: Model(settings.modelName)
                )

                let result = try await client.chats(query: query)

                guard let content = result.choices.first?.message.content else {
                    NSLog("ANEMLBreezeASR: LLM %@ chunk %d/%d — empty response", logLabel, index + 1, chunks.count)
                    throw LLMError.invalidResponse
                }

                NSLog("ANEMLBreezeASR: LLM %@ chunk %d/%d — success (%d chars)", logLabel, index + 1, chunks.count, content.count)
                resultChunks.append(content)
            } catch let error as LLMError {
                throw error
            } catch {
                NSLog("ANEMLBreezeASR: LLM %@ chunk %d/%d — error: %@", logLabel, index + 1, chunks.count, error.localizedDescription)
                throw LLMError.apiError(error.localizedDescription)
            }

            progressHandler?(Double(index + 1) / Double(chunks.count))
        }

        return resultChunks.joined(separator: "\n\n")
    }

    // MARK: - SRT Chunking

    /// Estimate token count using a conservative heuristic (characters / 3) that handles CJK and Latin text.
    private func estimateTokenCount(_ text: String) -> Int {
        max(1, text.count / 3)
    }

    /// Split SRT content into chunks that each fit within the token limit.
    /// Each chunk contains complete subtitle entries (never splits mid-entry).
    private func splitSRTIntoChunks(_ srtContent: String, maxTokens: Int = 20_000) -> [String] {
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
        openAI != nil && currentSettings != nil && !(currentSettings?.apiKey.isEmpty ?? true)
    }
}
