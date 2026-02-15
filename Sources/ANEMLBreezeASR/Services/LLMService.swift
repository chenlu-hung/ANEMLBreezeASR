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

    func correctSubtitles(srtContent: String, languageSettings: LanguageSettings? = nil) async throws -> String {
        guard let client = openAI, let settings = currentSettings else {
            throw LLMError.notConfigured
        }

        guard !settings.apiKey.isEmpty else {
            throw LLMError.invalidSettings
        }

        do {
            // Build system prompt with optional translation instruction
            var systemPrompt = settings.systemPrompt
            if let langSettings = languageSettings, langSettings.enableTranslation {
                systemPrompt += "\n\n" + langSettings.translationPrompt
            }

            let query = ChatQuery(
                messages: [
                    .init(role: .system, content: systemPrompt)!,
                    .init(role: .user, content: """
Please correct the following SRT subtitles:

\(srtContent)
""")!
                ],
                model: Model(settings.modelName)
            )

            let result = try await client.chats(query: query)

            guard let content = result.choices.first?.message.content else {
                throw LLMError.invalidResponse
            }

            return content
        } catch {
            throw LLMError.apiError(error.localizedDescription)
        }
    }

    var isConfigured: Bool {
        openAI != nil && currentSettings != nil && !(currentSettings?.apiKey.isEmpty ?? true)
    }
}
