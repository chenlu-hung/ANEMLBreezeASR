# Module: `Sources/ANEMLBreezeASR/Models`

## Summary
Plain Foundation value types shared across the app: `VideoFile` (input path plus derived `srtPath`/`outputVideoPath`), `ProcessingState` (the pipeline state-machine enum), `LanguageSettings`/`SupportedLanguage` (source/target language config), and `LLMSettings` (API key/endpoint/model, `systemPrompt`, `requestIntervalSeconds` throttle, plus URL-component accessors and a backward-compatible decoder; defaults to a Gemini endpoint). Beyond `LLMSettings`'s URL parsing they carry little behavior. They form the data contract passed between Services, ViewModels, and Views.

<!-- projectmap:auto:start (generated — do not edit by hand) -->
## Files (4)
- `Sources/ANEMLBreezeASR/Models/LLMSettings.swift`
- `Sources/ANEMLBreezeASR/Models/LanguageSettings.swift`
- `Sources/ANEMLBreezeASR/Models/ProcessingState.swift`
- `Sources/ANEMLBreezeASR/Models/VideoFile.swift`

## Public symbols (9)
- `struct LLMSettings` — Sources/ANEMLBreezeASR/Models/LLMSettings.swift:3
- `extension LLMSettings` — Sources/ANEMLBreezeASR/Models/LLMSettings.swift:51
- `enum CodingKeys` — Sources/ANEMLBreezeASR/Models/LLMSettings.swift:52
- `enum SupportedLanguage` — Sources/ANEMLBreezeASR/Models/LanguageSettings.swift:3
- `struct LanguageSettings` — Sources/ANEMLBreezeASR/Models/LanguageSettings.swift:42
- `enum ProcessingState` — Sources/ANEMLBreezeASR/Models/ProcessingState.swift:3
- `struct VideoFile` — Sources/ANEMLBreezeASR/Models/VideoFile.swift:3
- `function srtPath` — Sources/ANEMLBreezeASR/Models/VideoFile.swift:31
- `function outputVideoPath` — Sources/ANEMLBreezeASR/Models/VideoFile.swift:37

## Dependencies (imports)
- `Foundation`
<!-- projectmap:auto:end -->
