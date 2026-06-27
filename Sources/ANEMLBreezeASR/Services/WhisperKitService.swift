import Foundation
import WhisperKit
import Hub

enum WhisperKitError: LocalizedError {
    case notInitialized
    case initializationFailed(String)
    case transcriptionFailed(String)
    case modelDownloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "WhisperKit not initialized"
        case .initializationFailed(let message):
            return "WhisperKit initialization failed: \(message)"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .modelDownloadFailed(let message):
            return "Model download failed: \(message)"
        }
    }
}

@MainActor
class WhisperKitService {
    private var whisperKit: WhisperKit?

    private static let modelRepo = "aoiandroid/Breeze-ASR-25_coreml"

    /// Own Hub cache: ~/Library/Application Support/ANEMLBreezeASR/HubCache/
    private var ownCacheURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("ANEMLBreezeASR/HubCache")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// VibeTyping Hub cache: ~/Library/Application Support/VibeTyping/HubCache/
    private var vibeTypingCacheURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("VibeTyping/HubCache")
    }

    var isInitialized: Bool {
        whisperKit != nil
    }

    func initialize(progressHandler: @escaping (Double) -> Void) async throws {
        do {
            let modelFolder: URL

            // 1. Check own Hub cache
            if let cached = findModelInCache(ownCacheURL) {
                modelFolder = cached
                progressHandler(1.0)
                NSLog("ANEMLBreezeASR: Found model in own cache: \(cached.path)")
            }
            // 2. Check VibeTyping's Hub cache (reuse without copying)
            else if let vibeTypingModel = findModelInCache(vibeTypingCacheURL) {
                modelFolder = vibeTypingModel
                progressHandler(1.0)
                NSLog("ANEMLBreezeASR: Reusing VibeTyping model: \(vibeTypingModel.path)")
            }
            // 3. Download via Hub API
            else {
                NSLog("ANEMLBreezeASR: Downloading model from \(Self.modelRepo)...")
                let hubApi = HubApi(downloadBase: ownCacheURL)
                let repo = Hub.Repo(id: Self.modelRepo, type: .models)

                modelFolder = try await hubApi.snapshot(
                    from: repo,
                    matching: ["*.mlmodelc/*", "*.json", "*.txt"],
                    progressHandler: { progress in
                        progressHandler(progress.fractionCompleted)
                    }
                )
                NSLog("ANEMLBreezeASR: Model downloaded to: \(modelFolder.path)")
            }

            // Load WhisperKit with the resolved model folder
            let config = WhisperKitConfig(
                modelFolder: modelFolder.path,
                computeOptions: ModelComputeOptions(
                    audioEncoderCompute: .cpuAndNeuralEngine,
                    textDecoderCompute: .cpuAndNeuralEngine
                ),
                verbose: false,
                logLevel: .error,
                prewarm: true,
                load: true,
                download: false
            )

            whisperKit = try await WhisperKit(config)
            progressHandler(1.0)
            NSLog("ANEMLBreezeASR: WhisperKit model loaded successfully")
        } catch {
            throw WhisperKitError.initializationFailed(error.localizedDescription)
        }
    }

    func transcribe(audioURL: URL, language: SupportedLanguage = .auto, progressHandler: @escaping (Double) -> Void) async throws -> [TranscriptionSegment] {
        guard let kit = whisperKit else {
            throw WhisperKitError.notInitialized
        }

        do {
            progressHandler(0.0)

            let options = DecodingOptions(
                verbose: true,
                task: .transcribe,
                language: language.whisperCode,
                temperature: 0.0,
                temperatureFallbackCount: 5,
                usePrefillPrompt: true,
                skipSpecialTokens: true,
                withoutTimestamps: false,
                clipTimestamps: [],
                suppressBlank: true,
                compressionRatioThreshold: 2.4,
                logProbThreshold: -1.0,
                noSpeechThreshold: 0.6,
                chunkingStrategy: .vad
            )

            let result = try await kit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: options
            )

            progressHandler(1.0)

            // Flatten segments from all chunks (VAD chunking returns multiple results),
            // sort by start time, dedupe overlaps.
            let allSegments = result
                .flatMap { $0.segments }
                .sorted { $0.start < $1.start }

            return allSegments.enumerated().map { index, segment in
                TranscriptionSegment(
                    id: index,
                    startTime: TimeInterval(segment.start),
                    endTime: TimeInterval(segment.end),
                    text: segment.text
                )
            }
        } catch {
            throw WhisperKitError.transcriptionFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    /// Required CoreML components for the Breeze-ASR-25 model.
    private static let requiredComponents = [
        "AudioEncoder.mlmodelc",
        "TextDecoder.mlmodelc",
        "MelSpectrogram.mlmodelc"
    ]

    /// Minimum byte size for a valid AudioEncoder.mlmodelc (real model is ~1.2 GB; HuggingFace
    /// download stubs under `.cache/huggingface/download/` are only a few KB).
    private static let minAudioEncoderBytes: Int64 = 100 * 1024 * 1024  // 100 MB

    /// Search a Hub cache directory for the model. Returns the model folder if a valid
    /// installation is found, nil otherwise.
    /// Strategy: try the canonical Hub layout first (`models/<repo>/`), then fall back to a
    /// recursive scan. Skips HuggingFace `.cache/huggingface/download/` stub directories.
    private func findModelInCache(_ baseURL: URL) -> URL? {
        guard FileManager.default.fileExists(atPath: baseURL.path) else {
            return nil
        }

        // 1. Canonical Hub layout: <base>/models/<repo>/
        let canonical = baseURL
            .appendingPathComponent("models")
            .appendingPathComponent(Self.modelRepo)
        if isValidModelFolder(canonical) {
            return canonical
        }

        // 2. Fallback: recursive search, skipping the HF download cache.
        guard let enumerator = FileManager.default.enumerator(
            at: baseURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        for case let fileURL as URL in enumerator {
            if fileURL.pathComponents.contains(".cache") {
                continue
            }
            if fileURL.lastPathComponent == "AudioEncoder.mlmodelc" {
                let candidate = fileURL.deletingLastPathComponent()
                if isValidModelFolder(candidate) {
                    return candidate
                }
            }
        }
        return nil
    }

    /// Validate that `folder` contains all required `.mlmodelc` directories and the
    /// AudioEncoder is at least `minAudioEncoderBytes` (rejects HF download stubs).
    private func isValidModelFolder(_ folder: URL) -> Bool {
        let fm = FileManager.default
        for component in Self.requiredComponents {
            let path = folder.appendingPathComponent(component).path
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
                return false
            }
        }
        let audioEncoder = folder.appendingPathComponent("AudioEncoder.mlmodelc")
        return directorySize(at: audioEncoder) >= Self.minAudioEncoderBytes
    }

    /// Recursive byte size of a directory; 0 on any error.
    private func directorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if values?.isRegularFile == true, let size = values?.fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
