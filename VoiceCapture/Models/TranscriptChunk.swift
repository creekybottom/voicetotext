import Foundation

struct TranscriptChunk: Identifiable {
    let id = UUID()
    let index: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    var text: String
    var isTranscribed: Bool = false
    var error: String?
}
