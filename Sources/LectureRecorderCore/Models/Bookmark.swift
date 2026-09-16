import Foundation

/// A "this matters" marker dropped during recording, at an offset from recording start.
public struct Bookmark: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var offsetSeconds: Double
    public var note: String

    public init(id: UUID = UUID(), offsetSeconds: Double, note: String = "") {
        self.id = id
        self.offsetSeconds = offsetSeconds
        self.note = note
    }

    /// Formatted as mm:ss (or h:mm:ss past the one hour mark).
    public var timestampLabel: String {
        TimeFormat.clock(offsetSeconds)
    }
}

public enum TimeFormat {
    public static func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
