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
}
