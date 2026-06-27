import Foundation
import AppKit

struct SRTFileResult: Identifiable {
    let id = UUID()
    let sourceURL: URL
    var correctedURL: URL?
    var translatedURL: URL?
    var error: String?
    var fileName: String { sourceURL.lastPathComponent }
    var isCompleted: Bool { correctedURL != nil }
    var isFailed: Bool { error != nil }
}

@MainActor
class CorrectViewModel: ObservableObject {
    @Published var srtFiles: [SRTFileResult] = []
    @Published var currentFileIndex: Int = 0
    @Published var state: ProcessingState = .idle
    @Published var statusMessages: [String] = []
    @Published var languageSettings: LanguageSettings

    private let llmService = LLMService()
    private let subtitleService = SubtitleService()
    private let settingsService = SettingsService()

    var hasFiles: Bool { !srtFiles.isEmpty }

    var batchProgressDescription: String {
        guard hasFiles else { return "" }
        let current = min(currentFileIndex + 1, srtFiles.count)
        return "處理第 \(current)/\(srtFiles.count) 個：\(srtFiles[min(currentFileIndex, srtFiles.count - 1)].fileName)"
    }

    var successCount: Int {
        srtFiles.filter { $0.isCompleted }.count
    }

    var failureCount: Int {
        srtFiles.filter { $0.isFailed }.count
    }

    init() {
        languageSettings = settingsService.loadLanguageSettings()
    }

    func selectSRTs(urls: [URL]) {
        srtFiles = urls.map { SRTFileResult(sourceURL: $0) }
        currentFileIndex = 0
        state = .idle
        statusMessages = []
    }

    private func addStatus(_ message: String) {
        statusMessages.append(message)
    }

    func startCorrection() async {
        guard hasFiles else { return }

        // Reset for a clean run
        statusMessages = []
        currentFileIndex = 0
        // Reset all file results
        for i in srtFiles.indices {
            srtFiles[i].correctedURL = nil
            srtFiles[i].translatedURL = nil
            srtFiles[i].error = nil
        }

        // Reload LLM settings to pick up any changes made in Settings tab
        let latestSettings = settingsService.loadSettings()
        llmService.configure(settings: latestSettings)

        guard llmService.isConfigured else {
            state = .error("LLM 未設定，請先在 Settings 中設定 API")
            addStatus("錯誤：LLM 未設定，請先在 Settings 分頁中設定 API Key 與 Endpoint")
            return
        }

        if srtFiles.count > 1 {
            addStatus("批次處理 \(srtFiles.count) 個檔案")
        }

        for index in srtFiles.indices {
            currentFileIndex = index
            let srtURL = srtFiles[index].sourceURL

            addStatus("--- [\(index + 1)/\(srtFiles.count)] \(srtFiles[index].fileName) ---")

            do {
                // Step 1: Correction
                state = .correctingWithLLM(progress: 0)
                addStatus("開始 LLM 校正...")

                let srtContent = try String(contentsOf: srtURL, encoding: .utf8)
                addStatus("已讀取 SRT 檔案（\(srtContent.count) 字元）")

                let correctedResult = try await llmService.correctSubtitles(
                    srtContent: srtContent,
                    progressHandler: { [weak self] progress in
                        self?.state = .correctingWithLLM(progress: progress)
                    }
                )
                addStatus("LLM 校正完成")
                if correctedResult.mismatches > 0 {
                    addStatus("⚠ \(correctedResult.mismatches)/\(correctedResult.originalCount) 段 LLM 對不上原始切分，已保留原文（時間軸已對齊原始版本）")
                } else {
                    addStatus("時間軸已對齊原始版本（\(correctedResult.originalCount) 段全部對上）")
                }

                // Determine corrected file path based on source language
                let originalName = srtURL.deletingPathExtension().lastPathComponent
                let correctedURL: URL
                if languageSettings.sourceLanguage == .auto {
                    correctedURL = srtURL.deletingLastPathComponent()
                        .appendingPathComponent("\(originalName)_corrected.srt")
                } else {
                    correctedURL = srtURL.deletingLastPathComponent()
                        .appendingPathComponent("\(originalName).\(languageSettings.sourceLanguage.rawValue).srt")
                }

                try correctedResult.content.write(to: correctedURL, atomically: true, encoding: .utf8)
                srtFiles[index].correctedURL = correctedURL

                if subtitleService.validateSRT(content: correctedResult.content) {
                    addStatus("校正後 SRT 驗證通過，已儲存至 \(correctedURL.lastPathComponent)")
                } else {
                    addStatus("⚠ 校正後 SRT 格式可能有誤，已儲存至 \(correctedURL.lastPathComponent)，請確認結果")
                }

                // Step 2: Translation (if enabled)
                if languageSettings.enableTranslation, let targetLang = languageSettings.targetLanguage {
                    state = .translatingWithLLM(progress: 0)
                    addStatus("開始 LLM 翻譯（目標語言：\(targetLang.displayName)）...")

                    let translatedResult = try await llmService.translateSubtitles(
                        srtContent: correctedResult.content,
                        targetLanguage: targetLang,
                        progressHandler: { [weak self] progress in
                            self?.state = .translatingWithLLM(progress: progress)
                        }
                    )
                    addStatus("LLM 翻譯完成")
                    if translatedResult.mismatches > 0 {
                        addStatus("⚠ \(translatedResult.mismatches)/\(translatedResult.originalCount) 段多次重試仍對不上，已留空（時間軸已對齊原始版本，避免混入原文）")
                    } else {
                        addStatus("時間軸已對齊原始版本（\(translatedResult.originalCount) 段全部對上）")
                    }

                    let translatedURL = srtURL.deletingLastPathComponent()
                        .appendingPathComponent("\(originalName).\(targetLang.rawValue).srt")
                    try translatedResult.content.write(to: translatedURL, atomically: true, encoding: .utf8)
                    srtFiles[index].translatedURL = translatedURL

                    if subtitleService.validateSRT(content: translatedResult.content) {
                        addStatus("翻譯後 SRT 驗證通過，已儲存至 \(translatedURL.lastPathComponent)")
                    } else {
                        addStatus("⚠ 翻譯後 SRT 格式可能有誤，已儲存至 \(translatedURL.lastPathComponent)，請確認結果")
                    }
                }

                addStatus("✓ \(srtFiles[index].fileName) 處理完成")

            } catch {
                srtFiles[index].error = error.localizedDescription
                addStatus("✗ \(srtFiles[index].fileName) 失敗：\(error.localizedDescription)")
                continue
            }
        }

        if successCount == 0 {
            state = .error("所有檔案處理失敗")
        } else {
            state = .completed
        }

        if srtFiles.count > 1 {
            addStatus("批次處理完成：\(successCount)/\(srtFiles.count) 個檔案成功")
        } else {
            addStatus("處理完成")
        }
    }

    func reset() {
        srtFiles = []
        currentFileIndex = 0
        state = .idle
        statusMessages = []
    }
}
