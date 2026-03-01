import Foundation
import AppKit

struct VideoFileResult: Identifiable {
    let id = UUID()
    let videoFile: VideoFile
    var srtURL: URL?
    var correctedURL: URL?
    var translatedURL: URL?
    var error: String?
    var fileName: String { videoFile.fileName }
    var isCompleted: Bool { srtURL != nil }
    var isFailed: Bool { error != nil }
}

@MainActor
class MainViewModel: ObservableObject {
    @Published var state: ProcessingState = .idle
    @Published var statusMessages: [String] = []
    @Published var videoFiles: [VideoFileResult] = []
    @Published var currentFileIndex: Int = 0
    @Published var transcriptionSegments: [TranscriptionSegment] = []
    @Published var languageSettings: LanguageSettings

    private let ffmpegService = FFmpegService()
    private let whisperService = WhisperKitService()
    private let llmService = LLMService()
    private let subtitleService = SubtitleService()
    private let settingsService = SettingsService()

    var hasFiles: Bool { !videoFiles.isEmpty }

    var batchProgressDescription: String {
        guard hasFiles else { return "" }
        let current = min(currentFileIndex + 1, videoFiles.count)
        return "處理第 \(current)/\(videoFiles.count) 個：\(videoFiles[min(currentFileIndex, videoFiles.count - 1)].fileName)"
    }

    var successCount: Int {
        videoFiles.filter { $0.isCompleted }.count
    }

    var failureCount: Int {
        videoFiles.filter { $0.isFailed }.count
    }

    init() {
        // Load and configure LLM settings
        let settings = settingsService.loadSettings()
        llmService.configure(settings: settings)

        // Load language settings
        languageSettings = settingsService.loadLanguageSettings()
    }

    func selectVideos(urls: [URL]) {
        videoFiles = urls.map { VideoFileResult(videoFile: VideoFile(url: $0)) }
        currentFileIndex = 0
        state = .idle
        statusMessages = []
        transcriptionSegments = []
    }

    private func addStatus(_ message: String) {
        statusMessages.append(message)
    }

    func startProcessing(skipLLMCorrection: Bool = false) async {
        guard hasFiles else { return }

        // Reset for a clean run
        statusMessages = []
        currentFileIndex = 0
        transcriptionSegments = []
        for i in videoFiles.indices {
            videoFiles[i].srtURL = nil
            videoFiles[i].correctedURL = nil
            videoFiles[i].translatedURL = nil
            videoFiles[i].error = nil
        }

        // Check FFmpeg availability once before starting
        do {
            try ffmpegService.checkFFmpegAvailable()
        } catch {
            state = .error(error.localizedDescription)
            addStatus("錯誤：\(error.localizedDescription)")
            return
        }

        // Initialize WhisperKit once before the batch loop
        if !whisperService.isInitialized {
            addStatus("正在載入 Breeze ASR 模型...")
            do {
                try await whisperService.initialize { progress in }
                addStatus("Breeze ASR 模型載入完成")
            } catch {
                state = .error(error.localizedDescription)
                addStatus("錯誤：模型載入失敗 - \(error.localizedDescription)")
                return
            }
        }

        // Reload LLM settings once
        let latestSettings = settingsService.loadSettings()
        llmService.configure(settings: latestSettings)

        if videoFiles.count > 1 {
            addStatus("批次處理 \(videoFiles.count) 個影片")
        }

        for index in videoFiles.indices {
            currentFileIndex = index
            let video = videoFiles[index].videoFile

            addStatus("--- [\(index + 1)/\(videoFiles.count)] \(video.fileName) ---")

            do {
                // Step 1: Extract audio
                state = .extractingAudio(progress: 0)
                addStatus("開始提取音訊...")
                try await ffmpegService.extractAudio(
                    from: video.url,
                    to: video.audioPath,
                    progressHandler: { [weak self] progress in
                        self?.state = .extractingAudio(progress: progress)
                    }
                )
                addStatus("音訊提取完成")

                // Step 2: Transcribe with language setting
                state = .transcribing(progress: 0)
                addStatus("開始語音辨識...")
                transcriptionSegments = try await whisperService.transcribe(
                    audioURL: video.audioPath,
                    language: languageSettings.sourceLanguage,
                    progressHandler: { [weak self] progress in
                        self?.state = .transcribing(progress: progress)
                    }
                )
                addStatus("語音辨識完成，共 \(transcriptionSegments.count) 個片段")

                // Step 3: Generate initial SRT
                let initialSrtURL = video.srtPath
                try subtitleService.generateSRT(
                    from: transcriptionSegments,
                    outputURL: initialSrtURL
                )
                videoFiles[index].srtURL = initialSrtURL
                addStatus("初始 SRT 檔案已生成")

                // Step 4: LLM Correction + Translation (optional)
                if !skipLLMCorrection && llmService.isConfigured {
                    // Step 4a: Correction
                    state = .correctingWithLLM(progress: 0)
                    addStatus("開始 LLM 校正...")

                    let srtContent = try String(contentsOf: initialSrtURL, encoding: .utf8)
                    let correctedContent = try await llmService.correctSubtitles(
                        srtContent: srtContent,
                        progressHandler: { [weak self] progress in
                            self?.state = .correctingWithLLM(progress: progress)
                        }
                    )
                    addStatus("LLM 校正完成")

                    let correctedURL: URL
                    if languageSettings.sourceLanguage == .auto {
                        correctedURL = video.correctedSrtPath
                    } else {
                        correctedURL = video.srtPath(forLanguage: languageSettings.sourceLanguage)
                    }

                    try correctedContent.write(to: correctedURL, atomically: true, encoding: .utf8)
                    videoFiles[index].correctedURL = correctedURL

                    if subtitleService.validateSRT(content: correctedContent) {
                        addStatus("校正後 SRT 驗證通過，已儲存至 \(correctedURL.lastPathComponent)")
                    } else {
                        addStatus("⚠ 校正後 SRT 格式可能有誤，已儲存至 \(correctedURL.lastPathComponent)，請確認結果")
                    }

                    // Step 4b: Translation (if enabled)
                    if languageSettings.enableTranslation, let targetLang = languageSettings.targetLanguage {
                        state = .translatingWithLLM(progress: 0)
                        addStatus("開始 LLM 翻譯（目標語言：\(targetLang.displayName)）...")

                        let translatedContent = try await llmService.translateSubtitles(
                            srtContent: correctedContent,
                            targetLanguage: targetLang,
                            progressHandler: { [weak self] progress in
                                self?.state = .translatingWithLLM(progress: progress)
                            }
                        )
                        addStatus("LLM 翻譯完成")

                        let translatedURL = video.srtPath(forLanguage: targetLang)
                        try translatedContent.write(to: translatedURL, atomically: true, encoding: .utf8)
                        videoFiles[index].translatedURL = translatedURL

                        if subtitleService.validateSRT(content: translatedContent) {
                            addStatus("翻譯後 SRT 驗證通過，已儲存至 \(translatedURL.lastPathComponent)")
                        } else {
                            addStatus("⚠ 翻譯後 SRT 格式可能有誤，已儲存至 \(translatedURL.lastPathComponent)，請確認結果")
                        }
                    }
                } else {
                    videoFiles[index].correctedURL = initialSrtURL
                    if skipLLMCorrection {
                        addStatus("已跳過 LLM 校正（使用者選擇跳過）")
                    } else {
                        addStatus("已跳過 LLM 校正（LLM 未設定，請在 Settings 中設定 API）")
                    }
                }

                addStatus("✓ \(video.fileName) 處理完成")

            } catch {
                videoFiles[index].error = error.localizedDescription
                addStatus("✗ \(video.fileName) 失敗：\(error.localizedDescription)")
            }

            // Cleanup temp audio file (always, whether success or error)
            try? FileManager.default.removeItem(at: video.audioPath)
        }

        if successCount == 0 {
            state = .error("所有檔案處理失敗")
        } else {
            state = .completed
        }

        if videoFiles.count > 1 {
            addStatus("批次處理完成：\(successCount)/\(videoFiles.count) 個檔案成功")
        } else {
            addStatus("處理完成")
        }
    }

    func reset() {
        state = .idle
        statusMessages = []
        videoFiles = []
        currentFileIndex = 0
        transcriptionSegments = []
    }
}
