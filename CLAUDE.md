# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ANEMLBreezeASR is a macOS (13.0+) SwiftUI application for automatic subtitle generation. It extracts audio from video files using FFmpeg, transcribes speech via WhisperKit (Whisper Large v3 with CoreML), optionally corrects/translates subtitles through an OpenAI-compatible LLM API, and can burn subtitles back into video. Documentation is written in Traditional Chinese (繁體中文).

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
  - `WhisperKitService` — WhisperKit ASR wrapper; downloads ~1-2GB model on first use to `~/.cache/whisperkit/`
  - `LLMService` — OpenAI-compatible API client (supports Ollama, LM Studio, etc.)
  - `SubtitleService` — SRT file generation and parsing via SwiftSubtitles
  - `SettingsService` — UserDefaults persistence with JSON encoding
- **ViewModels/** — `MainViewModel` orchestrates the subtitle generation pipeline; `BurnViewModel` handles subtitle burning
- **Views/** — `ContentView` hosts a 3-tab TabView: Generate, Burn, Settings

## Key Processing Pipeline

Video → FFmpeg audio extraction → WhisperKit transcription → (optional) LLM correction/translation → SRT export

State transitions are tracked via `ProcessingState`: idle → extractingAudio → transcribing → correctingWithLLM → completed | error

## Dependencies (SPM)

| Package | Purpose |
|---------|---------|
| [WhisperKit](https://github.com/argmaxinc/WhisperKit) ≥0.9.0 | On-device speech recognition |
| [SwiftSubtitles](https://github.com/dagronf/SwiftSubtitles) ≥2.2.0 | SRT file I/O |
| [OpenAI](https://github.com/MacPaw/OpenAI.git) ≥0.3.0 | LLM API client |

FFmpeg is a required external system dependency (detected from `/opt/homebrew/bin/ffmpeg`, `/usr/local/bin/ffmpeg`, or `which ffmpeg`).

## Concurrency

Uses Swift async/await throughout. FFmpeg process execution bridges to async via `CheckedThrowingContinuation`. ViewModels publish state changes on `@MainActor`.

## Error Types

Each service defines its own error enum: `FFmpegError`, `WhisperKitError`, `LLMError`, `SubtitleError`. Errors surface to users via NSAlert dialogs.
