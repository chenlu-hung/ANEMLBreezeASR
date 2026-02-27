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
            timeoutInterval: 120.0
        )

        self.openAI = OpenAI(configuration: configuration)
        self.currentSettings = settings
    }

    func correctSubtitles(
        srtContent: String,
        languageSettings: LanguageSettings? = nil,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> String {
        guard let client = openAI, let settings = currentSettings else {
            throw LLMError.notConfigured
        }

        guard !settings.apiKey.isEmpty else {
            throw LLMError.invalidSettings
        }

        // Build system prompt with optional translation instruction
        var systemPrompt = settings.systemPrompt
        if let langSettings = languageSettings, langSettings.enableTranslation {
            systemPrompt += "\n\n" + langSettings.translationPrompt
        }

        let chunks = splitSRTIntoChunks(srtContent)
        var correctedChunks: [String] = []

        for (index, chunk) in chunks.enumerated() {
            do {
                let query = ChatQuery(
                    messages: [
                        .init(role: .system, content: systemPrompt)!,
                        .init(role: .user, content: """
Please correct the following SRT subtitles:

\(chunk)
""")!
                    ],
                    model: Model(settings.modelName)
                )

                let result = try await client.chats(query: query)

                guard let content = result.choices.first?.message.content else {
                    throw LLMError.invalidResponse
                }

                correctedChunks.append(content)
            } catch let error as LLMError {
                throw error
            } catch {
                throw LLMError.apiError(error.localizedDescription)
            }

            progressHandler?(Double(index + 1) / Double(chunks.count))
        }

        return correctedChunks.joined(separator: "\n\n")
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
