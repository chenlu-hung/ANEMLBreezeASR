# Module: `Sources/ANEMLBreezeASR/Views`

## Summary
SwiftUI screens for the four-tab UI hosted by `ContentView`: `GenerateView` (生成字幕), `BurnView` (燒錄字幕), `CorrectView` (校正/翻譯字幕), and `SettingsView` (設定 — edits the LLM API key/endpoint/model, request-interval throttle, and system prompt). Each binds to its ViewModel (or `SettingsService`), handles file selection via NSOpenPanel/UTType, and renders progress and status. All user-facing strings are in Traditional Chinese.

<!-- projectmap:auto:start (generated — do not edit by hand) -->
## Files (5)
- `Sources/ANEMLBreezeASR/Views/BurnView.swift`
- `Sources/ANEMLBreezeASR/Views/ContentView.swift`
- `Sources/ANEMLBreezeASR/Views/CorrectView.swift`
- `Sources/ANEMLBreezeASR/Views/GenerateView.swift`
- `Sources/ANEMLBreezeASR/Views/SettingsView.swift`

## Public symbols (14)
- `struct BurnView` — Sources/ANEMLBreezeASR/Views/BurnView.swift:5
- `function selectVideoFile` — Sources/ANEMLBreezeASR/Views/BurnView.swift:168
- `function selectSRTFile` — Sources/ANEMLBreezeASR/Views/BurnView.swift:186
- `struct ContentView` — Sources/ANEMLBreezeASR/Views/ContentView.swift:3
- `struct CorrectView` — Sources/ANEMLBreezeASR/Views/CorrectView.swift:5
- `function fileStatusIcon` — Sources/ANEMLBreezeASR/Views/CorrectView.swift:272
- `function selectSRTFiles` — Sources/ANEMLBreezeASR/Views/CorrectView.swift:290
- `struct GenerateView` — Sources/ANEMLBreezeASR/Views/GenerateView.swift:4
- `function fileStatusIcon` — Sources/ANEMLBreezeASR/Views/GenerateView.swift:295
- `function selectVideoFiles` — Sources/ANEMLBreezeASR/Views/GenerateView.swift:313
- `extension UTType` — Sources/ANEMLBreezeASR/Views/GenerateView.swift:329
- `struct SettingsView` — Sources/ANEMLBreezeASR/Views/SettingsView.swift:3
- `function loadSettings` — Sources/ANEMLBreezeASR/Views/SettingsView.swift:128
- `function saveSettings` — Sources/ANEMLBreezeASR/Views/SettingsView.swift:132

## Dependencies (imports)
- `AppKit`
- `SwiftUI`
- `UniformTypeIdentifiers`
<!-- projectmap:auto:end -->
