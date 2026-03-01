import Foundation

enum ProcessingState: Equatable {
    case idle
    case extractingAudio(progress: Double)
    case transcribing(progress: Double)
    case correctingWithLLM(progress: Double)
    case translatingWithLLM(progress: Double)
    case completed
    case error(String)

    var isProcessing: Bool {
        switch self {
        case .idle, .completed, .error:
            return false
        case .extractingAudio, .transcribing, .correctingWithLLM, .translatingWithLLM:
            return true
        }
    }

    var progressValue: Double? {
        switch self {
        case .extractingAudio(let progress), .transcribing(let progress), .correctingWithLLM(let progress), .translatingWithLLM(let progress):
            return progress
        default:
            return nil
        }
    }

    var description: String {
        switch self {
        case .idle:
            return "Ready"
        case .extractingAudio:
            return "Extracting audio..."
        case .transcribing:
            return "Transcribing..."
        case .correctingWithLLM:
            return "Correcting with LLM..."
        case .translatingWithLLM:
            return "Translating with LLM..."
        case .completed:
            return "Completed"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}
