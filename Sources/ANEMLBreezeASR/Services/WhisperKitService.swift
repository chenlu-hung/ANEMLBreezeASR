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
                usePrefillPrompt: true,
                skipSpecialTokens: true,
                withoutTimestamps: false,
                clipTimestamps: []
            )

            let result = try await kit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: options
            )

            progressHandler(1.0)

            // Convert to TranscriptionSegment
            guard let first = result.first else {
                return []
            }

            return first.segments.enumerated().map { index, segment in
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

    /// Search a Hub cache directory for an existing model by looking for AudioEncoder.mlmodelc.
    /// Returns the parent directory (model folder) if found, nil otherwise.
    private func findModelInCache(_ baseURL: URL) -> URL? {
        guard FileManager.default.fileExists(atPath: baseURL.path) else {
            return nil
        }
        if let enumerator = FileManager.default.enumerator(
            at: baseURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent == "AudioEncoder.mlmodelc" {
                    return fileURL.deletingLastPathComponent()
                }
            }
        }
        return nil
    }
}
