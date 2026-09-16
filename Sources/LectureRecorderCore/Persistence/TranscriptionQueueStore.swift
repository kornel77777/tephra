import Foundation
import Combine

/// Persisted FIFO queue of pending transcription jobs. The processor pulls one
/// job at a time so a restart doesn't lose track of what's still pending.
@MainActor
public final class TranscriptionQueueStore: ObservableObject {
    @Published public private(set) var jobs: [TranscriptionJob] {
        didSet { try? store.save(jobs) }
    }

    private let store: JSONFileStore<[TranscriptionJob]>

    public init() {
        let store = JSONFileStore<[TranscriptionJob]>(url: AppPaths.queueFile, defaultValue: [])
        self.store = store
        self.jobs = store.load()
    }

    public func enqueue(_ job: TranscriptionJob) {
        jobs.append(job)
    }

    public func peekNext() -> TranscriptionJob? {
        jobs.first
    }

    public func remove(_ job: TranscriptionJob) {
        jobs.removeAll { $0.id == job.id }
    }

    public func requeueWithIncrementedAttempts(_ job: TranscriptionJob) {
        remove(job)
        var updated = job
        updated.attempts += 1
        jobs.append(updated)
    }
}
