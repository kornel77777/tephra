import Foundation

/// A course/subject the user records lectures for.
public struct Subject: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var code: String
    public var displayName: String
    /// Comma or newline separated glossary terms (professor names, jargon, proper nouns)
    /// fed to Whisper as an initial prompt to bias transcription toward correct spellings.
    public var promptGlossary: String

    public init(id: UUID = UUID(), code: String, displayName: String, promptGlossary: String = "") {
        self.id = id
        self.code = code
        self.displayName = displayName
        self.promptGlossary = promptGlossary
    }
}
