import Foundation

/// Writes the lecture note + copies the audio into an Obsidian vault, following the
/// existing note layout (frontmatter, embedded audio, Bookmarks section, Transcript section).
public enum ObsidianExporter {
    public struct Paths {
        public let audioURL: URL
        public let noteURL: URL
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    public static func destinationPaths(vaultRoot: URL, recording: LectureRecording, audioExtension: String) -> Paths {
        let base = recording.baseFileName(dateFormatter: dateFormatter)
        let audioURL = vaultRoot
            .appendingPathComponent("Lectures/audio", isDirectory: true)
            .appendingPathComponent("\(base).\(audioExtension)")
        let noteURL = vaultRoot
            .appendingPathComponent("Lectures/transcripts", isDirectory: true)
            .appendingPathComponent("\(base).md")
        return Paths(audioURL: audioURL, noteURL: noteURL)
    }

    public static func renderNote(
        recording: LectureRecording,
        audioFileName: String,
        transcriptBody: String
    ) -> String {
        let durationMinutes = Int((recording.durationSeconds / 60).rounded())
        let dateString = dateFormatter.string(from: recording.recordedAt)

        var bookmarkLines: [String] = []
        if recording.bookmarks.isEmpty {
            bookmarkLines.append("- ⭐ ")
        } else {
            for bookmark in recording.bookmarks.sorted(by: { $0.offsetSeconds < $1.offsetSeconds }) {
                let suffix = bookmark.note.isEmpty ? "" : " \(bookmark.note)"
                bookmarkLines.append("- ⭐ [\(bookmark.timestampLabel)]\(suffix)")
            }
        }

        return """
        ---
        course: \(recording.subjectCode)
        date: \(dateString)
        type: lecture
        duration: \(durationMinutes)
        model: \(recording.modelUsed ?? "unknown")
        ---

        ![[\(audioFileName)]]

        ## Bookmarks
        \(bookmarkLines.joined(separator: "\n"))

        ## Transcript
        \(transcriptBody)
        """
    }

    /// Copies the audio file and writes the note into the vault, creating the
    /// `Lectures/audio` and `Lectures/transcripts` folders if needed.
    public static func export(
        vaultRoot: URL,
        recording: LectureRecording,
        sourceAudioURL: URL,
        transcriptBody: String
    ) throws -> Paths {
        let extensionName = sourceAudioURL.pathExtension
        let paths = destinationPaths(vaultRoot: vaultRoot, recording: recording, audioExtension: extensionName)

        try FileManager.default.createDirectory(at: paths.audioURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paths.noteURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: paths.audioURL.path) {
            try FileManager.default.removeItem(at: paths.audioURL)
        }
        try FileManager.default.copyItem(at: sourceAudioURL, to: paths.audioURL)

        let note = renderNote(recording: recording, audioFileName: paths.audioURL.lastPathComponent, transcriptBody: transcriptBody)
        try note.write(to: paths.noteURL, atomically: true, encoding: .utf8)

        return paths
    }
}
