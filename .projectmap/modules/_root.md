# Module: `(root)`

## Summary
The SwiftPM package manifest. It declares the `ANEMLBreezeASR` executable target, the `ANEMLBreezeASRTests` test target, the macOS 13+ platform floor, and three external dependencies (WhisperKit, swift-transformers/Hub, SwiftSubtitles); the OpenAI SDK was dropped in favor of `LLMService` calling the API directly via `URLSession`. This is the build-system entry point — no application logic lives here.

<!-- projectmap:auto:start (generated — do not edit by hand) -->
## Files (1)
- `Package.swift`

## Public symbols (0)

## Dependencies (imports)
- `PackageDescription`
<!-- projectmap:auto:end -->
