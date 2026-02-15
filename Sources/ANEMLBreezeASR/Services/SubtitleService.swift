import Foundation
import SwiftSubtitles

enum SubtitleError: LocalizedError {
    case invalidSRT
    case writeFailed(String)
    case readFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidSRT:
            return "Invalid SRT format"
        case .writeFailed(let message):
            return "Failed to write SRT file: \(message)"
        case .readFailed(let message):
            return "Failed to read SRT file: \(message)"
        }
    }
}

struct TranscriptionSegment {
    let id: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

class SubtitleService {
    func generateSRT(from segments: [TranscriptionSegment], outputURL: URL) throws {
        let subtitleCues = segments.enumerated().map { index, segment in
            Subtitles.Cue(
                position: index + 1,
                startTime: timeIntervalToSubtitlesTime(segment.startTime),
                endTime: timeIntervalToSubtitlesTime(segment.endTime),
                text: segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        let subtitles = Subtitles(subtitleCues)

        do {
            let srtContent = try Subtitles.encode(subtitles, fileExtension: "srt")
            try srtContent.write(to: outputURL, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            throw SubtitleError.writeFailed(error.localizedDescription)
        }
    }

    func readSRT(from url: URL) throws -> Subtitles {
        do {
            return try Subtitles(fileURL: url, encoding: String.Encoding.utf8)
        } catch {
            throw SubtitleError.readFailed(error.localizedDescription)
        }
    }

    func validateSRT(content: String) -> Bool {
        do {
            _ = try Subtitles(content: content, expectedExtension: "srt")
            return true
        } catch {
            return false
        }
    }

    private func timeIntervalToSubtitlesTime(_ interval: TimeInterval) -> Subtitles.Time {
        let totalMilliseconds = Int(interval * 1000)
        let hours = UInt(totalMilliseconds / 3_600_000)
        let minutes = UInt((totalMilliseconds % 3_600_000) / 60_000)
        let seconds = UInt((totalMilliseconds % 60_000) / 1_000)
        let milliseconds = UInt(totalMilliseconds % 1_000)

        return Subtitles.Time(
            hour: hours,
            minute: minutes,
            second: seconds,
            millisecond: milliseconds
        )
    }
}
