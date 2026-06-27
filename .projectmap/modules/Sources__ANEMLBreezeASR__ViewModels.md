# Module: `Sources/ANEMLBreezeASR/ViewModels`

## Summary
`@MainActor @ObservableObject` orchestrators that drive the workflows and publish state to the Views: `MainViewModel` runs the generate pipeline (extract → transcribe → optional LLM correct/translate → SRT export) over a batch of videos, `CorrectViewModel` runs standalone batch SRT correction/translation, and `BurnViewModel` handles subtitle burning. They coordinate Services, track per-file progress/status, and surface results. This is the glue between user actions and the service layer.

<!-- projectmap:auto:start (generated — do not edit by hand) -->
## Files (3)
- `Sources/ANEMLBreezeASR/ViewModels/BurnViewModel.swift`
- `Sources/ANEMLBreezeASR/ViewModels/CorrectViewModel.swift`
- `Sources/ANEMLBreezeASR/ViewModels/MainViewModel.swift`

## Public symbols (17)
- `class BurnViewModel` — Sources/ANEMLBreezeASR/ViewModels/BurnViewModel.swift:5
- `function selectVideo` — Sources/ANEMLBreezeASR/ViewModels/BurnViewModel.swift:16
- `function selectSRT` — Sources/ANEMLBreezeASR/ViewModels/BurnViewModel.swift:22
- `function burnSubtitles` — Sources/ANEMLBreezeASR/ViewModels/BurnViewModel.swift:28
- `function reset` — Sources/ANEMLBreezeASR/ViewModels/BurnViewModel.swift:64
- `struct SRTFileResult` — Sources/ANEMLBreezeASR/ViewModels/CorrectViewModel.swift:4
- `class CorrectViewModel` — Sources/ANEMLBreezeASR/ViewModels/CorrectViewModel.swift:16
- `function selectSRTs` — Sources/ANEMLBreezeASR/ViewModels/CorrectViewModel.swift:47
- `function addStatus` — Sources/ANEMLBreezeASR/ViewModels/CorrectViewModel.swift:54
- `function startCorrection` — Sources/ANEMLBreezeASR/ViewModels/CorrectViewModel.swift:58
- `function reset` — Sources/ANEMLBreezeASR/ViewModels/CorrectViewModel.swift:185
- `struct VideoFileResult` — Sources/ANEMLBreezeASR/ViewModels/MainViewModel.swift:4
- `class MainViewModel` — Sources/ANEMLBreezeASR/ViewModels/MainViewModel.swift:17
- `function selectVideos` — Sources/ANEMLBreezeASR/ViewModels/MainViewModel.swift:56
- `function addStatus` — Sources/ANEMLBreezeASR/ViewModels/MainViewModel.swift:64
- `function startProcessing` — Sources/ANEMLBreezeASR/ViewModels/MainViewModel.swift:68
- `function reset` — Sources/ANEMLBreezeASR/ViewModels/MainViewModel.swift:250

## Dependencies (imports)
- `AppKit`
- `Foundation`
<!-- projectmap:auto:end -->
