import Foundation
import Combine

@MainActor
public final class LibraryStore: ObservableObject {
    @Published public var recordings: [LectureRecording] {
        didSet { try? store.save(recordings) }
    }

    private let store: JSONFileStore<[LectureRecording]>

    public init() {
        let store = JSONFileStore<[LectureRecording]>(url: AppPaths.libraryFile, defaultValue: [])
        self.store = store
        self.recordings = store.load()
    }

    public func upsert(_ recording: LectureRecording) {
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index] = recording
        } else {
            recordings.insert(recording, at: 0)
        }
    }

    public func updateStatus(id: UUID, status: TranscriptionStatus, failureReason: String? = nil) {
        guard let index = recordings.firstIndex(where: { $0.id == id }) else { return }
        recordings[index].status = status
        recordings[index].failureReason = failureReason
    }

    /// Only finished entries can be removed — anything queued or mid-transcription is still in use.
    public func isRemovable(_ recording: LectureRecording) -> Bool {
        recording.status == .completed || recording.status == .failed
    }

    public func removableRecordings(olderThan cutoff: Date) -> [LectureRecording] {
        recordings.filter { $0.recordedAt < cutoff && isRemovable($0) }
    }

    /// Drops entries from the library and deletes Tephra's own audio copy of each.
    /// Notes and audio already exported to the Notes Folder are never touched.
    @discardableResult
    public func remove(_ targets: [LectureRecording]) -> Int {
        let doomed = targets.filter(isRemovable)
        let ids = Set(doomed.map(\.id))
        for recording in doomed {
            let name = (recording.audioFileName as NSString).lastPathComponent
            try? FileManager.default.removeItem(at: AppPaths.recordingsDirectory.appendingPathComponent(name))
        }
        recordings.removeAll { ids.contains($0.id) }
        return doomed.count
    }
}
