# Module: `Sources/ANEMLBreezeASR/Services`

## Summary
The business-logic layer, each class wrapping one external dependency: `FFmpegService` (audio extraction + subtitle burning via `Process`), `WhisperKitService` (Breeze-ASR-25 on-device transcription with Hub model-cache discovery), `LLMService` (OpenAI-compatible correction/translation called directly over `URLSession` — no SDK — with SRT chunking, token estimation, request throttling via `throttleIfNeeded`, and retry/backoff), `SubtitleService` (SRT generation/parsing and original-timestamp reattachment via SwiftSubtitles), and `SettingsService` (UserDefaults persistence). Each defines its own error enum and exposes async APIs. This layer isolates all I/O and third-party integration from the UI.

<!-- projectmap:auto:start (generated — do not edit by hand) -->
## Files (5)
- `Sources/ANEMLBreezeASR/Services/FFmpegService.swift`
- `Sources/ANEMLBreezeASR/Services/LLMService.swift`
- `Sources/ANEMLBreezeASR/Services/SettingsService.swift`
- `Sources/ANEMLBreezeASR/Services/SubtitleService.swift`
- `Sources/ANEMLBreezeASR/Services/WhisperKitService.swift`

## Public symbols (56)
- `enum FFmpegError` — Sources/ANEMLBreezeASR/Services/FFmpegService.swift:3
- `class FFmpegService` — Sources/ANEMLBreezeASR/Services/FFmpegService.swift:21
- `function findFFmpeg` — Sources/ANEMLBreezeASR/Services/FFmpegService.swift:28
- `function checkFFmpegAvailable` — Sources/ANEMLBreezeASR/Services/FFmpegService.swift:64
- `function getVideoDuration` — Sources/ANEMLBreezeASR/Services/FFmpegService.swift:70
- `function extractAudio` — Sources/ANEMLBreezeASR/Services/FFmpegService.swift:124
- `function burnSubtitles` — Sources/ANEMLBreezeASR/Services/FFmpegService.swift:201
- `enum LLMError` — Sources/ANEMLBreezeASR/Services/LLMService.swift:3
- `struct LLMSRTResult` — Sources/ANEMLBreezeASR/Services/LLMService.swift:23
- `class LLMService` — Sources/ANEMLBreezeASR/Services/LLMService.swift:30
- `function configure` — Sources/ANEMLBreezeASR/Services/LLMService.swift:37
- `function correctSubtitles` — Sources/ANEMLBreezeASR/Services/LLMService.swift:47
- `function translateSubtitles` — Sources/ANEMLBreezeASR/Services/LLMService.swift:65
- `enum LLMRequestMode` — Sources/ANEMLBreezeASR/Services/LLMService.swift:92
- `function sendChunkedRequest` — Sources/ANEMLBreezeASR/Services/LLMService.swift:97
- `function processCorrectChunk` — Sources/ANEMLBreezeASR/Services/LLMService.swift:161
- `function processTranslateChunk` — Sources/ANEMLBreezeASR/Services/LLMService.swift:186
- `function sendSingleLLMRequest` — Sources/ANEMLBreezeASR/Services/LLMService.swift:244
- `function throttleIfNeeded` — Sources/ANEMLBreezeASR/Services/LLMService.swift:336
- `function retryDelaySeconds` — Sources/ANEMLBreezeASR/Services/LLMService.swift:350
- `function chatCompletionsURL` — Sources/ANEMLBreezeASR/Services/LLMService.swift:360
- `struct ChatRequest` — Sources/ANEMLBreezeASR/Services/LLMService.swift:366
- `struct Message` — Sources/ANEMLBreezeASR/Services/LLMService.swift:367
- `struct ChatResponse` — Sources/ANEMLBreezeASR/Services/LLMService.swift:376
- `struct Choice` — Sources/ANEMLBreezeASR/Services/LLMService.swift:377
- `struct Message` — Sources/ANEMLBreezeASR/Services/LLMService.swift:378
- `struct APIError` — Sources/ANEMLBreezeASR/Services/LLMService.swift:381
- `function splitEntries` — Sources/ANEMLBreezeASR/Services/LLMService.swift:386
- `function countEntries` — Sources/ANEMLBreezeASR/Services/LLMService.swift:392
- `function estimateTokenCount` — Sources/ANEMLBreezeASR/Services/LLMService.swift:401
- `function splitSRTIntoChunks` — Sources/ANEMLBreezeASR/Services/LLMService.swift:407
- `class SettingsService` — Sources/ANEMLBreezeASR/Services/SettingsService.swift:3
- `function saveSettings` — Sources/ANEMLBreezeASR/Services/SettingsService.swift:8
- `function loadSettings` — Sources/ANEMLBreezeASR/Services/SettingsService.swift:14
- `function resetSettings` — Sources/ANEMLBreezeASR/Services/SettingsService.swift:22
- `function saveLanguageSettings` — Sources/ANEMLBreezeASR/Services/SettingsService.swift:26
- `function loadLanguageSettings` — Sources/ANEMLBreezeASR/Services/SettingsService.swift:32
- `function resetLanguageSettings` — Sources/ANEMLBreezeASR/Services/SettingsService.swift:40
- `enum SubtitleError` — Sources/ANEMLBreezeASR/Services/SubtitleService.swift:4
- `struct TranscriptionSegment` — Sources/ANEMLBreezeASR/Services/SubtitleService.swift:21
- `struct ReattachResult` — Sources/ANEMLBreezeASR/Services/SubtitleService.swift:28
- `enum MismatchFallback` — Sources/ANEMLBreezeASR/Services/SubtitleService.swift:33
- `class SubtitleService` — Sources/ANEMLBreezeASR/Services/SubtitleService.swift:41
- `function generateSRT` — Sources/ANEMLBreezeASR/Services/SubtitleService.swift:42
- `function readSRT` — Sources/ANEMLBreezeASR/Services/SubtitleService.swift:62
- `function validateSRT` — Sources/ANEMLBreezeASR/Services/SubtitleService.swift:70
- `function reattachOriginalTimestamps` — Sources/ANEMLBreezeASR/Services/SubtitleService.swift:82
- `function stripMarkdownFences` — Sources/ANEMLBreezeASR/Services/SubtitleService.swift:145
- `function timeIntervalToSubtitlesTime` — Sources/ANEMLBreezeASR/Services/SubtitleService.swift:163
- `enum WhisperKitError` — Sources/ANEMLBreezeASR/Services/WhisperKitService.swift:5
- `class WhisperKitService` — Sources/ANEMLBreezeASR/Services/WhisperKitService.swift:26
- `function initialize` — Sources/ANEMLBreezeASR/Services/WhisperKitService.swift:55
- `function transcribe` — Sources/ANEMLBreezeASR/Services/WhisperKitService.swift:109
- `function findModelInCache` — Sources/ANEMLBreezeASR/Services/WhisperKitService.swift:177
- `function isValidModelFolder` — Sources/ANEMLBreezeASR/Services/WhisperKitService.swift:214
- `function directorySize` — Sources/ANEMLBreezeASR/Services/WhisperKitService.swift:228

## Dependencies (imports)
- `Foundation`
- `Hub`
- `SwiftSubtitles`
- `WhisperKit`
<!-- projectmap:auto:end -->
