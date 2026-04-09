import Foundation

enum TextOrganizer {

    static let fillerWords: Set<String> = [
        "um", "uh", "like", "you know", "basically", "actually",
        "literally", "right", "so", "well", "I mean", "kind of",
        "sort of", "you see"
    ]

    struct OrganizedResult {
        let summary: String
        let formattedTranscript: String
        let fullText: String
    }

    static func organize(
        chunks: [TranscriptChunk],
        removeFillers: Bool,
        autoPunctuate: Bool
    ) -> OrganizedResult {
        var paragraphs: [String] = []
        var currentParagraph = ""
        var lastTimestamp: TimeInterval = -1

        for chunk in chunks where chunk.isTranscribed {
            var text = chunk.text

            if removeFillers {
                text = removeFillerWords(from: text)
            }
            if autoPunctuate {
                text = fixPunctuation(text)
            }

            // Add timestamp & start new paragraph every ~60 s
            if chunk.startTime - lastTimestamp >= 60 || lastTimestamp < 0 {
                if !currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    paragraphs.append(currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines))
                    currentParagraph = ""
                }
                let ts = formatTimestamp(chunk.startTime)
                currentParagraph += "[\(ts)] "
                lastTimestamp = chunk.startTime
            }

            currentParagraph += text + " "
        }

        let trailing = currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailing.isEmpty {
            paragraphs.append(trailing)
        }

        let formattedTranscript = paragraphs.joined(separator: "\n\n")
        let summary = generateSummary(from: chunks)
        let fullText = "## Summary\n\(summary)\n\n## Transcript\n\(formattedTranscript)"

        return OrganizedResult(
            summary: summary,
            formattedTranscript: formattedTranscript,
            fullText: fullText
        )
    }

    // MARK: - Filler word removal

    static func removeFillerWords(from text: String) -> String {
        var result = text

        // Multi-word fillers first
        let multiWord = ["you know", "I mean", "kind of", "sort of", "you see"]
        for filler in multiWord {
            result = result.replacingOccurrences(of: " \(filler) ", with: " ", options: .caseInsensitive)
            result = result.replacingOccurrences(of: " \(filler),", with: ",", options: .caseInsensitive)
            result = result.replacingOccurrences(of: " \(filler).", with: ".", options: .caseInsensitive)
        }

        // Single-word fillers
        let single = ["um", "uh", "like", "basically", "actually", "literally", "right", "so", "well"]
        for filler in single {
            result = result.replacingOccurrences(of: " \(filler), ", with: " ", options: .caseInsensitive)
            result = result.replacingOccurrences(of: " \(filler) ", with: " ", options: .caseInsensitive)
        }

        // Collapse multiple spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result
    }

    // MARK: - Punctuation

    static func fixPunctuation(_ text: String) -> String {
        var result = text
        if let first = result.first, first.isLowercase {
            result = first.uppercased() + String(result.dropFirst())
        }
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !trimmed.hasSuffix(".") && !trimmed.hasSuffix("!") && !trimmed.hasSuffix("?") {
            result = trimmed + "."
        }
        return result
    }

    // MARK: - Helpers

    static func formatTimestamp(_ time: TimeInterval) -> String {
        let h = Int(time) / 3600
        let m = (Int(time) % 3600) / 60
        let s = Int(time) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private static func generateSummary(from chunks: [TranscriptChunk]) -> String {
        let allText = chunks.compactMap { $0.isTranscribed ? $0.text : nil }.joined(separator: " ")
        let words = allText.split(separator: " ")
        let wordCount = words.count
        let duration = chunks.last?.endTime ?? 0
        let durationStr = formatTimestamp(duration)

        if wordCount < 10 {
            return "Brief recording (\(durationStr)) with \(wordCount) words."
        }

        let preview = words.prefix(20).joined(separator: " ")
        return "Recording of \(durationStr) duration containing \(wordCount) words. Begins with: \"\(preview)...\""
    }
}
