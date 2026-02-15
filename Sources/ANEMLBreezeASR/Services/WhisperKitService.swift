import Foundation
import WhisperKit

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

    var isInitialized: Bool {
        whisperKit != nil
    }

    func initialize(progressHandler: @escaping (Double) -> Void) async throws {
        do {
            let config = WhisperKitConfig(
                model: "openai_whisper-large-v3",
                downloadBase: nil,
                verbose: true,
                logLevel: .info
            )

            progressHandler(0.1)

            // Initialize WhisperKit
            whisperKit = try await WhisperKit(config)

            progressHandler(1.0)
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
}
