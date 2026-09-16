import Foundation

/// A queued unit of work: transcribe one recording's audio file.
/// Persisted to disk so the queue survives an app restart.
public struct TranscriptionJob: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var recordingID: UUID
    public var audioPath: String
    public var subjectCode: String
    public var modelVariant: String
    public var createdAt: Date
    public var attempts: Int

    public init(
        id: UUID = UUID(),
        recordingID: UUID,
        audioPath: String,
        subjectCode: String,
        modelVariant: String,
        createdAt: Date = Date(),
        attempts: Int = 0
    ) {
        self.id = id
        self.recordingID = recordingID
        self.audioPath = audioPath
        self.subjectCode = subjectCode
        self.modelVariant = modelVariant
        self.createdAt = createdAt
        self.attempts = attempts
    }
}
