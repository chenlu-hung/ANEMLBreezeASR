# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ANEMLBreezeASR is a macOS (13.0+) SwiftUI application for automatic subtitle generation. It extracts audio from video files using FFmpeg, transcribes speech via WhisperKit with the Breeze-ASR-25 CoreML model (optimized for Taiwanese Mandarin), optionally corrects/translates subtitles through an OpenAI-compatible LLM API, and can burn subtitles back into video. Documentation is written in Traditional Chinese (繁體中文).

## Build & Run Commands

```bash
# Build (release)
swift build -c release

# Build standalone .app bundle (creates build/ANEMLBreezeASR.app)
./build-app.sh

# Run in debug mode
swift run

# Resolve/update dependencies
swift package resolve
swift package update

# Run tests (test target exists but has no test files yet)
swift test
```

## Architecture

MVVM pattern with a service layer:

```
Views (SwiftUI) → ViewModels (@ObservableObject) → Services → External (FFmpeg/WhisperKit/OpenAI API)
```

- **Models/** — Data structures: `VideoFile`, `ProcessingState` (state machine enum), `LanguageSettings`, `LLMSettings`
- **Services/** — Business logic, each wrapping an external dependency:
  - `FFmpegService` — Spawns FFmpeg via `Process()` for audio extraction (16kHz WAV) and subtitle burning
  - `WhisperKitService` — WhisperKit ASR wrapper using Breeze-ASR-25 model; downloads ~3GB model via Hub API on first use to `~/Library/Application Support/ANEMLBreezeASR/HubCache/`. Reuses VibeTyping's cached model if available.
  - `LLMService` — OpenAI-compatible API client (supports Ollama, LM Studio, etc.)
  - `SubtitleService` — SRT file generation and parsing via SwiftSubtitles
  - `SettingsService` — UserDefaults persistence with JSON encoding
- **ViewModels/** — `MainViewModel` orchestrates the subtitle generation pipeline; `BurnViewModel` handles subtitle burning
- **Views/** — `ContentView` hosts a 4-tab TabView: Generate (生成字幕), Burn (燒錄字幕), Correct/Translate (校正/翻譯字幕), Settings (設定)

## Key Processing Pipeline

Video → FFmpeg audio extraction → WhisperKit transcription → (optional) LLM correction/translation → SRT export

State transitions are tracked via `ProcessingState`: idle → extractingAudio → transcribing → correctingWithLLM → completed | error

## Dependencies (SPM)

| Package | Purpose |
|---------|---------|
| [WhisperKit](https://github.com/argmaxinc/WhisperKit) ≥0.9.0 | On-device speech recognition |
| Hub (via [swift-transformers](https://github.com/huggingface/swift-transformers)) | HuggingFace model download API |
| [SwiftSubtitles](https://github.com/dagronf/SwiftSubtitles) ≥2.2.0 | SRT file I/O |
| [OpenAI](https://github.com/MacPaw/OpenAI.git) ≥0.3.0 | LLM API client |

FFmpeg is a required external system dependency (detected from `/opt/homebrew/bin/ffmpeg`, `/usr/local/bin/ffmpeg`, or `which ffmpeg`).

## Concurrency

Uses Swift async/await throughout. FFmpeg process execution bridges to async via `CheckedThrowingContinuation`. ViewModels publish state changes on `@MainActor`.

## Error Types

Each service defines its own error enum: `FFmpegError`, `WhisperKitError`, `LLMError`, `SubtitleError`. Errors surface to users via NSAlert dialogs.

## Project map
A `.projectmap/` index exists — use it before broad exploration:
- Read `.projectmap/ARCHITECTURE.md` for the module map, entry points, and conventions.
- To locate a symbol, grep `.projectmap/tags` (ctags format) instead of scanning the repo.
- Open `.projectmap/modules/<name>.md` only for the module you're working in.
Re-run `/project-map update` after substantial changes. **This map is built at grouping depth 3** (per-layer modules: Models / Services / ViewModels / Views) — always run the script with `PROJECTMAP_DEPTH=3`, since the script defaults to 2 and would otherwise regroup the modules and orphan the per-layer docs.
