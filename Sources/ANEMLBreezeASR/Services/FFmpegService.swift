import Foundation

enum FFmpegError: LocalizedError {
    case notFound
    case executionFailed(String)
    case invalidDuration

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "FFmpeg not found. Please install FFmpeg using: brew install ffmpeg"
        case .executionFailed(let message):
            return "FFmpeg execution failed: \(message)"
        case .invalidDuration:
            return "Could not determine video duration"
        }
    }
}

@MainActor
class FFmpegService {
    private var ffmpegPath: String?

    init() {
        self.ffmpegPath = findFFmpeg()
    }

    private func findFFmpeg() -> String? {
        let possiblePaths = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try using 'which' command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try? process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        }

        return nil
    }

    func checkFFmpegAvailable() throws {
        guard ffmpegPath != nil else {
            throw FFmpegError.notFound
        }
    }

    func getVideoDuration(url: URL) async throws -> TimeInterval {
        guard let ffmpegPath = ffmpegPath else {
            throw FFmpegError.notFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpegPath)
            process.arguments = [
                "-i", url.path,
                "-hide_banner"
            ]

            let errorPipe = Pipe()
            process.standardError = errorPipe
            process.standardOutput = Pipe()

            var errorOutput = ""

            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8) {
                    errorOutput += output
                }
            }

            do {
                try process.run()
                process.waitUntilExit()

                errorPipe.fileHandleForReading.readabilityHandler = nil

                // Parse duration from output: "Duration: 00:01:23.45"
                if let durationMatch = errorOutput.range(of: "Duration: (\\d+):(\\d+):(\\d+\\.\\d+)", options: .regularExpression) {
                    let durationStr = String(errorOutput[durationMatch])
                    let components = durationStr.replacingOccurrences(of: "Duration: ", with: "").split(separator: ":")

                    if components.count == 3,
                       let hours = Double(components[0]),
                       let minutes = Double(components[1]),
                       let seconds = Double(components[2]) {
                        let totalSeconds = hours * 3600 + minutes * 60 + seconds
                        continuation.resume(returning: totalSeconds)
                        return
                    }
                }

                continuation.resume(throwing: FFmpegError.invalidDuration)
            } catch {
                continuation.resume(throwing: FFmpegError.executionFailed(error.localizedDescription))
            }
        }
    }

    func extractAudio(from videoURL: URL, to audioURL: URL, progressHandler: @escaping (Double) -> Void) async throws {
        guard let ffmpegPath = ffmpegPath else {
            throw FFmpegError.notFound
        }

        let duration = try await getVideoDuration(url: videoURL)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpegPath)
            process.arguments = [
                "-i", videoURL.path,
                "-vn",
                "-acodec", "pcm_s16le",
                "-ar", "16000",
                "-ac", "1",
                "-y",
                audioURL.path
            ]

            let errorPipe = Pipe()
            process.standardError = errorPipe
            process.standardOutput = Pipe()

            var hasResumed = false

            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8) {
                    // Parse progress: "time=00:01:23.45"
                    if let timeMatch = output.range(of: "time=(\\d+):(\\d+):(\\d+\\.\\d+)", options: .regularExpression) {
                        let timeStr = String(output[timeMatch])
                        let components = timeStr.replacingOccurrences(of: "time=", with: "").split(separator: ":")

                        if components.count == 3,
                           let hours = Double(components[0]),
                           let minutes = Double(components[1]),
                           let seconds = Double(components[2]) {
                            let currentTime = hours * 3600 + minutes * 60 + seconds
                            let progress = min(currentTime / duration, 1.0)
                            Task { @MainActor in
                                progressHandler(progress)
                            }
                        }
                    }
                }
            }

            do {
                try process.run()
                process.waitUntilExit()

                errorPipe.fileHandleForReading.readabilityHandler = nil

                if process.terminationStatus == 0 {
                    if !hasResumed {
                        hasResumed = true
                        Task { @MainActor in
                            progressHandler(1.0)
                        }
                        continuation.resume()
                    }
                } else {
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(throwing: FFmpegError.executionFailed("Process terminated with status \(process.terminationStatus)"))
                    }
                }
            } catch {
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(throwing: FFmpegError.executionFailed(error.localizedDescription))
                }
            }
        }
    }

    func burnSubtitles(videoURL: URL, srtURL: URL, outputURL: URL, progressHandler: @escaping (Double) -> Void) async throws {
        guard let ffmpegPath = ffmpegPath else {
            throw FFmpegError.notFound
        }

        let duration = try await getVideoDuration(url: videoURL)

        // Escape the subtitle path for Windows-style paths if needed
        let subtitlesFilter = "subtitles='\(srtURL.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: ":", with: "\\\\:"))'"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpegPath)
            process.arguments = [
                "-i", videoURL.path,
                "-vf", subtitlesFilter,
                "-c:a", "copy",
                "-y",
                outputURL.path
            ]

            let errorPipe = Pipe()
            process.standardError = errorPipe
            process.standardOutput = Pipe()

            var hasResumed = false

            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8) {
                    if let timeMatch = output.range(of: "time=(\\d+):(\\d+):(\\d+\\.\\d+)", options: .regularExpression) {
                        let timeStr = String(output[timeMatch])
                        let components = timeStr.replacingOccurrences(of: "time=", with: "").split(separator: ":")

                        if components.count == 3,
                           let hours = Double(components[0]),
                           let minutes = Double(components[1]),
                           let seconds = Double(components[2]) {
                            let currentTime = hours * 3600 + minutes * 60 + seconds
                            let progress = min(currentTime / duration, 1.0)
                            Task { @MainActor in
                                progressHandler(progress)
                            }
                        }
                    }
                }
            }

            do {
                try process.run()
                process.waitUntilExit()

                errorPipe.fileHandleForReading.readabilityHandler = nil

                if process.terminationStatus == 0 {
                    if !hasResumed {
                        hasResumed = true
                        Task { @MainActor in
                            progressHandler(1.0)
                        }
                        continuation.resume()
                    }
                } else {
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(throwing: FFmpegError.executionFailed("Process terminated with status \(process.terminationStatus)"))
                    }
                }
            } catch {
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(throwing: FFmpegError.executionFailed(error.localizedDescription))
                }
            }
        }
    }
}
