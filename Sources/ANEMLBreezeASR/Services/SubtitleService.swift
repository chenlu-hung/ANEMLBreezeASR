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

struct ReattachResult {
    let srtContent: String
    let mismatches: Int
}

enum MismatchFallback {
    /// Mismatched entries fall back to the original text (suitable for same-language correction).
    case keepOriginal
    /// Mismatched entries are left as empty text so the output never contains source-language content
    /// (suitable for translation).
    case empty
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

    /// Rebuild an SRT using the original SRT's cue boundaries and timestamps as the source of truth,
    /// taking only the text from the LLM output. LLM cues are aligned to original cues by position.
    /// Positions where LLM text is unavailable count as a mismatch and use `fallback` for the text.
    func reattachOriginalTimestamps(
        originalSRT: String,
        llmOutput: String,
        fallback: MismatchFallback = .keepOriginal
    ) -> ReattachResult {
        let originalCues: [Subtitles.Cue]
        do {
            originalCues = try Subtitles(content: originalSRT, expectedExtension: "srt").cues
        } catch {
            return ReattachResult(srtContent: originalSRT, mismatches: 0)
        }

        guard !originalCues.isEmpty else {
            return ReattachResult(srtContent: originalSRT, mismatches: 0)
        }

        let cleaned = stripMarkdownFences(llmOutput).trimmingCharacters(in: .whitespacesAndNewlines)
        var llmCues: [Subtitles.Cue] = []
        if !cleaned.isEmpty {
            if let parsed = try? Subtitles(content: cleaned, expectedExtension: "srt") {
                llmCues = parsed.cues
            }
        }

        var rebuiltCues: [Subtitles.Cue] = []
        rebuiltCues.reserveCapacity(originalCues.count)
        var mismatches = 0

        for (i, original) in originalCues.enumerated() {
            let text: String
            if i < llmCues.count {
                let candidate = llmCues[i].text.trimmingCharacters(in: .whitespacesAndNewlines)
                if candidate.isEmpty {
                    text = fallback == .keepOriginal ? original.text : ""
                    mismatches += 1
                } else {
                    text = candidate
                }
            } else {
                text = fallback == .keepOriginal ? original.text : ""
                mismatches += 1
            }

            rebuiltCues.append(
                Subtitles.Cue(
                    position: i + 1,
                    startTime: original.startTime,
                    endTime: original.endTime,
                    text: text
                )
            )
        }

        let rebuilt = Subtitles(rebuiltCues)
        do {
            let encoded = try Subtitles.encode(rebuilt, fileExtension: "srt")
            return ReattachResult(srtContent: encoded, mismatches: mismatches)
        } catch {
            return ReattachResult(srtContent: originalSRT, mismatches: originalCues.count)
        }
    }

    /// Strip leading/trailing markdown code fences (```srt … ```) commonly emitted by LLMs.
    private func stripMarkdownFences(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if s.hasPrefix("```") {
            if let firstNewline = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNewline)...])
            } else {
                s = ""
            }
        }

        if s.hasSuffix("```") {
            s = String(s.dropLast(3))
        }

        return s
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
