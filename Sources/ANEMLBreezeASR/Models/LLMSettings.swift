import Foundation

struct LLMSettings: Codable, Equatable {
    var apiKey: String
    var apiEndpoint: String
    var modelName: String
    var systemPrompt: String

    static let `default` = LLMSettings(
        apiKey: "",
        apiEndpoint: "https://generativelanguage.googleapis.com/v1beta/openai",
        modelName: "gemini-2.5-flash",
        systemPrompt: """
You are a subtitle correction assistant. Your task is to:
1. Fix grammar and spelling errors in the subtitles
2. Improve punctuation and capitalization
3. Maintain the original meaning and timing structure
4. Keep the same number of subtitle segments
5. Return ONLY the corrected subtitles in the exact same SRT format

Do not add explanations or change the timing. Just improve the text quality.
"""
    )

    // Parse endpoint URL components
    var host: String {
        guard let url = URL(string: apiEndpoint) else { return "generativelanguage.googleapis.com" }
        return url.host ?? "generativelanguage.googleapis.com"
    }

    var scheme: String {
        guard let url = URL(string: apiEndpoint) else { return "https" }
        return url.scheme ?? "https"
    }

    var port: Int? {
        guard let url = URL(string: apiEndpoint) else { return nil }
        return url.port
    }

    var basePath: String {
        guard let url = URL(string: apiEndpoint) else { return "/v1" }
        let path = url.path
        return path.isEmpty ? "/v1" : path
    }
}
