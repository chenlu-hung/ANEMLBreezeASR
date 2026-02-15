import Foundation

class SettingsService {
    private let defaults = UserDefaults.standard
    private let llmSettingsKey = "llm_settings"
    private let languageSettingsKey = "language_settings"

    func saveSettings(_ settings: LLMSettings) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        defaults.set(data, forKey: llmSettingsKey)
    }

    func loadSettings() -> LLMSettings {
        guard let data = defaults.data(forKey: llmSettingsKey),
              let settings = try? JSONDecoder().decode(LLMSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func resetSettings() {
        defaults.removeObject(forKey: llmSettingsKey)
    }

    func saveLanguageSettings(_ settings: LanguageSettings) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        defaults.set(data, forKey: languageSettingsKey)
    }

    func loadLanguageSettings() -> LanguageSettings {
        guard let data = defaults.data(forKey: languageSettingsKey),
              let settings = try? JSONDecoder().decode(LanguageSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func resetLanguageSettings() {
        defaults.removeObject(forKey: languageSettingsKey)
    }
}
