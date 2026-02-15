import Foundation

struct VideoFile: Identifiable {
    let id = UUID()
    let url: URL

    var fileName: String {
        url.lastPathComponent
    }

    var fileExtension: String {
        url.pathExtension
    }

    var audioPath: URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("audio_\(id.uuidString).wav")
    }

    var srtPath: URL {
        url.deletingPathExtension().appendingPathExtension("srt")
    }

    var correctedSrtPath: URL {
        let filename = url.deletingPathExtension().lastPathComponent
        return url.deletingLastPathComponent()
            .appendingPathComponent("\(filename)_corrected")
            .appendingPathExtension("srt")
    }

    func outputVideoPath(withName name: String) -> URL {
        url.deletingLastPathComponent()
            .appendingPathComponent(name)
            .appendingPathExtension(fileExtension)
    }
}
