import Foundation
import AppKit

@MainActor
class MainViewModel: ObservableObject {
    @Published var state: ProcessingState = .idle
    @Published var videoFile: VideoFile?
    @Published var transcriptionSegments: [TranscriptionSegment] = []
    @Published var srtFileURL: URL?
    @Published var correctedSrtURL: URL?
    @Published var languageSettings: LanguageSettings

    private let ffmpegService = FFmpegService()
    private let whisperService = WhisperKitService()
    private let llmService = LLMService()
    private let subtitleService = SubtitleService()
    private let settingsService = SettingsService()

    init() {
        // Load and configure LLM settings
        let settings = settingsService.loadSettings()
        llmService.configure(settings: settings)

        // Load language settings
        languageSettings = settingsService.loadLanguageSettings()
    }

    func selectVideo(url: URL) {
        videoFile = VideoFile(url: url)
        state = .idle
        transcriptionSegments = []
        srtFileURL = nil
        correctedSrtURL = nil
    }

    func startProcessing(skipLLMCorrection: Bool = false) async {
        guard let video = videoFile else { return }

        do {
            // Check FFmpeg availability
            try ffmpegService.checkFFmpegAvailable()

            // Step 1: Extract audio
            state = .extractingAudio(progress: 0)
            try await ffmpegService.extractAudio(
                from: video.url,
                to: video.audioPath,
                progressHandler: { [weak self] progress in
                    self?.state = .extractingAudio(progress: progress)
                }
            )

            // Step 2: Initialize WhisperKit if needed
            if !whisperService.isInitialized {
                try await whisperService.initialize { progress in
                    // Could add a separate state for model download
                }
            }

            // Step 3: Transcribe with language setting
            state = .transcribing(progress: 0)
            transcriptionSegments = try await whisperService.transcribe(
                audioURL: video.audioPath,
                language: languageSettings.sourceLanguage,
                progressHandler: { [weak self] progress in
                    self?.state = .transcribing(progress: progress)
                }
            )

            // Step 4: Generate initial SRT
            let initialSrtURL = video.srtPath
            try subtitleService.generateSRT(
                from: transcriptionSegments,
                outputURL: initialSrtURL
            )
            srtFileURL = initialSrtURL

            // Step 5: LLM Correction/Translation (optional)
            if !skipLLMCorrection && llmService.isConfigured {
                state = .correctingWithLLM(progress: 0)

                let srtContent = try String(contentsOf: initialSrtURL, encoding: .utf8)
                let correctedContent = try await llmService.correctSubtitles(
                    srtContent: srtContent,
                    languageSettings: languageSettings,
                    progressHandler: { [weak self] progress in
                        self?.state = .correctingWithLLM(progress: progress)
                    }
                )

                // Validate corrected SRT
                if subtitleService.validateSRT(content: correctedContent) {
                    let correctedURL = video.correctedSrtPath
                    try correctedContent.write(to: correctedURL, atomically: true, encoding: .utf8)
                    correctedSrtURL = correctedURL
                } else {
                    // If invalid, use original
                    correctedSrtURL = initialSrtURL
                }
            } else {
                correctedSrtURL = initialSrtURL
            }

            // Cleanup temp audio file
            try? FileManager.default.removeItem(at: video.audioPath)

            state = .completed

        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func exportSRT(to url: URL) throws {
        guard let correctedURL = correctedSrtURL else {
            throw NSError(domain: "ANEMLBreezeASR", code: -1, userInfo: [NSLocalizedDescriptionKey: "No SRT file available"])
        }
        try FileManager.default.copyItem(at: correctedURL, to: url)
    }

    func reset() {
        state = .idle
        videoFile = nil
        transcriptionSegments = []
        srtFileURL = nil
        correctedSrtURL = nil
    }
}
