import Foundation

/// Rule-based cleanup applied after decoding: strips leftover special tokens,
/// drops known silence-hallucination phrases, collapses repeated-sentence loops,
/// and groups segments into timestamped paragraphs for the note.
public enum PostProcessor {
    /// Phrases Whisper tends to hallucinate over silence or background noise.
    /// Matched case-insensitively against a whole cleaned segment.
    public static let hallucinationPhrases: Set<String> = [
        "thank you for watching",
        "thanks for watching",
        "please subscribe",
        "don't forget to like and subscribe",
        "like and subscribe",
        "subtitles by the amara.org community",
        "thanks for watching bye",
        "bye bye",
        "goodbye",
        "www",
        "translated by",
        "transcribed by",
        "thank you",
        "thanks",
        "you",
        "the end",
        "..."
    ]

    public static func stripSpecialTokens(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<\\|[^|]*\\|>") else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    private static let trailingPunctuation = CharacterSet(charactersIn: ".!?, ")

    /// Lowercases, strips special tokens, and trims surrounding punctuation/whitespace
    /// so "Thank you." and "thank you" both match the same hallucination-list entry.
    private static func normalized(_ text: String) -> String {
        stripSpecialTokens(text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: trailingPunctuation)
    }

    /// Removes segments that are near-exact repeats of the immediately preceding
    /// segment, which is how VAD-chunked hallucination loops usually manifest.
    public static func removeRepeatedLoops(_ segments: [TranscriptSegment]) -> [TranscriptSegment] {
        var result: [TranscriptSegment] = []
        var lastNormalized: String?
        var repeatRun = 0

        for segment in segments {
            let clean = normalized(segment.text)
            if clean.isEmpty { continue }

            if clean == lastNormalized {
                repeatRun += 1
                // Allow a genuine short repeated phrase once, drop anything beyond that.
                if repeatRun >= 1 { continue }
            } else {
                repeatRun = 0
            }
            lastNormalized = clean
            result.append(segment)
        }
        return result
    }

    public static func removeHallucinations(_ segments: [TranscriptSegment]) -> [TranscriptSegment] {
        segments.filter { segment in
            let clean = normalized(segment.text)
            if clean.isEmpty { return false }
            return !hallucinationPhrases.contains(clean)
        }
    }

    /// Strips special tokens from each segment's text in place.
    public static func stripTokens(_ segments: [TranscriptSegment]) -> [TranscriptSegment] {
        segments.map {
            TranscriptSegment(
                startSeconds: $0.startSeconds,
                endSeconds: $0.endSeconds,
                text: stripSpecialTokens($0.text).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    public static func clean(_ segments: [TranscriptSegment]) -> [TranscriptSegment] {
        let stripped = stripTokens(segments)
        let deLooped = removeRepeatedLoops(stripped)
        return removeHallucinations(deLooped)
    }

    /// Groups cleaned segments into paragraphs, inserting a `[mm:ss]` marker roughly
    /// every `intervalSeconds` of audio (default ~90s per the spec's 1-2 minute target).
    public static func toTimestampedTranscript(_ segments: [TranscriptSegment], intervalSeconds: Double = 90) -> String {
        guard !segments.isEmpty else { return "" }

        var lines: [String] = []
        var currentParagraph: [String] = []
        var paragraphStart: Double = segments[0].startSeconds
        var lastMarker: Double = -.infinity

        func flush() {
            guard !currentParagraph.isEmpty else { return }
            let stamp = "[\(TimeFormat.clock(paragraphStart))]"
            lines.append("\(stamp) \(currentParagraph.joined(separator: " "))")
            currentParagraph.removeAll()
        }

        for segment in segments {
            if segment.startSeconds - lastMarker >= intervalSeconds, !currentParagraph.isEmpty {
                flush()
                paragraphStart = segment.startSeconds
                lastMarker = segment.startSeconds
            } else if lastMarker == -.infinity {
                lastMarker = segment.startSeconds
                paragraphStart = segment.startSeconds
            }
            currentParagraph.append(segment.text)
        }
        flush()

        return lines.joined(separator: "\n\n")
    }
}
