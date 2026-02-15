import Foundation

enum SupportedLanguage: String, CaseIterable, Codable {
    case auto = "auto"
    case chinese = "zh"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case russian = "ru"
    case arabic = "ar"
    case hindi = "hi"

    var displayName: String {
        switch self {
        case .auto: return "自動偵測"
        case .chinese: return "中文"
        case .english: return "English"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .russian: return "Русский"
        case .arabic: return "العربية"
        case .hindi: return "हिन्दी"
        }
    }

    var whisperCode: String? {
        // Whisper uses nil for auto-detection
        self == .auto ? nil : rawValue
    }
}

struct LanguageSettings: Codable, Equatable {
    var sourceLanguage: SupportedLanguage
    var targetLanguage: SupportedLanguage?
    var enableTranslation: Bool

    static let `default` = LanguageSettings(
        sourceLanguage: .auto,
        targetLanguage: nil,
        enableTranslation: false
    )

    var translationPrompt: String {
        guard enableTranslation, let target = targetLanguage else {
            return ""
        }

        return """
Additionally, translate all subtitles to \(target.displayName).
Maintain the SRT format and timing, but replace the text with the translated version.
"""
    }
}
