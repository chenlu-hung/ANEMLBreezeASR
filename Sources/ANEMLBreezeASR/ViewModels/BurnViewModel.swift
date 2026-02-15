import Foundation
import AppKit

@MainActor
class BurnViewModel: ObservableObject {
    @Published var videoFile: VideoFile?
    @Published var srtFileURL: URL?
    @Published var outputFileName: String = ""
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var errorMessage: String?
    @Published var isCompleted = false

    private let ffmpegService = FFmpegService()

    func selectVideo(url: URL) {
        videoFile = VideoFile(url: url)
        isCompleted = false
        errorMessage = nil
    }

    func selectSRT(url: URL) {
        srtFileURL = url
        isCompleted = false
        errorMessage = nil
    }

    func burnSubtitles() async {
        guard let video = videoFile,
              let srt = srtFileURL,
              !outputFileName.isEmpty else {
            errorMessage = "Please select video, SRT file, and provide output filename"
            return
        }

        isProcessing = true
        progress = 0
        errorMessage = nil
        isCompleted = false

        do {
            try ffmpegService.checkFFmpegAvailable()

            let outputURL = video.outputVideoPath(withName: outputFileName)

            try await ffmpegService.burnSubtitles(
                videoURL: video.url,
                srtURL: srt,
                outputURL: outputURL,
                progressHandler: { [weak self] p in
                    self?.progress = p
                }
            )

            isProcessing = false
            isCompleted = true

        } catch {
            errorMessage = error.localizedDescription
            isProcessing = false
        }
    }

    func reset() {
        videoFile = nil
        srtFileURL = nil
        outputFileName = ""
        isProcessing = false
        progress = 0
        errorMessage = nil
        isCompleted = false
    }
}
