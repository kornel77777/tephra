import Foundation

public enum TranscriptionStatus: String, Codable, Sendable {
    case recorded
    case queued
    case processing
    case completed
    case failed
}

/// One entry in the library: a captured or imported audio file and its transcription state.
public struct LectureRecording: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var subjectCode: String
    public var recordedAt: Date
    public var durationSeconds: Double
    public var audioFileName: String
    public var transcriptFileName: String?
    public var status: TranscriptionStatus
    public var modelUsed: String?
    public var bookmarks: [Bookmark]
    public var failureReason: String?
    /// Source of the audio: recorded in-app, or dropped in from outside.
    public var isImported: Bool

    public init(
        id: UUID = UUID(),
        subjectCode: String,
        recordedAt: Date = Date(),
        durationSeconds: Double = 0,
        audioFileName: String,
        transcriptFileName: String? = nil,
        status: TranscriptionStatus = .recorded,
        modelUsed: String? = nil,
        bookmarks: [Bookmark] = [],
        failureReason: String? = nil,
        isImported: Bool = false
    ) {
        self.id = id
        self.subjectCode = subjectCode
        self.recordedAt = recordedAt
        self.durationSeconds = durationSeconds
        self.audioFileName = audioFileName
        self.transcriptFileName = transcriptFileName
        self.status = status
        self.modelUsed = modelUsed
        self.bookmarks = bookmarks
        self.failureReason = failureReason
        self.isImported = isImported
    }

    /// `<course code>_<HHmm>` base name, date prefix added by the caller.
    public func baseFileName(dateFormatter: DateFormatter) -> String {
        let day = dateFormatter.string(from: recordedAt)
        let hhmm = String(format: "%02d%02d", Calendar.current.component(.hour, from: recordedAt), Calendar.current.component(.minute, from: recordedAt))
        return "\(day)_\(subjectCode)_\(hhmm)"
    }
}
