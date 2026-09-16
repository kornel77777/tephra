import Foundation

/// A cross-actor cancellation flag. `TranscriptionService.transcribe` polls its
/// `shouldContinue` closure from a plain `@Sendable` (non-isolated) context, so
/// it can't read a `@MainActor`-isolated `Bool` directly — this wraps one behind
/// a lock instead.
final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return flag
    }

    func cancel() {
        lock.lock()
        flag = true
        lock.unlock()
    }

    func reset() {
        lock.lock()
        flag = false
        lock.unlock()
    }
}

/// Pulls one job at a time off the persisted queue, runs it through WhisperKit,
/// cleans the output, writes the Obsidian note, and updates the library entry.
/// Runs as a long-lived background task owned by the app.
@MainActor
public final class TranscriptionQueueProcessor: ObservableObject {
    @Published public private(set) var isProcessing = false
    @Published public private(set) var currentProgress: Double = 0
    @Published public private(set) var currentJobID: UUID?

    private let queue: TranscriptionQueueStore
    private let library: LibraryStore
    private let settings: SettingsStore
    private let service: TranscriptionService
    private let cancellationFlag = CancellationFlag()
    private var loopTask: Task<Void, Never>?

    public init(queue: TranscriptionQueueStore, library: LibraryStore, settings: SettingsStore, service: TranscriptionService) {
        self.queue = queue
        self.library = library
        self.settings = settings
        self.service = service
    }

    public func start() {
        guard loopTask == nil else { return }
        loopTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    public func cancelCurrent() {
        cancellationFlag.cancel()
    }

    private func runLoop() async {
        while !Task.isCancelled {
            guard let job = queue.peekNext() else {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                continue
            }
            await process(job: job)
        }
    }

    private func process(job: TranscriptionJob) async {
        cancellationFlag.reset()
        isProcessing = true
        currentJobID = job.recordingID
        currentProgress = 0
        library.updateStatus(id: job.recordingID, status: .processing)

        do {
            guard let variant = ModelVariant(rawValue: job.modelVariant) else {
                throw TranscriptionError.underlying("Unknown model variant \(job.modelVariant)")
            }
            try await service.prepare(variant: variant)

            let subjectPrompt = settings.settings.subjects.first { $0.code == job.subjectCode }?.promptGlossary ?? ""

            let audioURL = URL(fileURLWithPath: job.audioPath)
            let attributes = try? FileManager.default.attributesOfItem(atPath: job.audioPath)
            let sizeBytes = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
            let useIncremental = sizeBytes > 500 * 1024 * 1024 // ~500MB threshold for very long files

            let result = try await service.transcribe(
                audioPath: job.audioPath,
                promptGlossary: subjectPrompt,
                incrementalLoading: useIncremental,
                onProgress: { [weak self] fraction in
                    Task { @MainActor in self?.currentProgress = fraction }
                },
                shouldContinue: { [cancellationFlag] in
                    !cancellationFlag.isCancelled
                }
            )

            let cleanedSegments = PostProcessor.clean(result.segments)
            let transcriptBody = PostProcessor.toTimestampedTranscript(cleanedSegments)

            guard var recording = library.recordings.first(where: { $0.id == job.recordingID }) else {
                throw TranscriptionError.underlying("Recording no longer exists in the library")
            }
            recording.modelUsed = result.modelUsed
            recording.status = .completed

            if let vaultRoot = settings.vaultURL {
                let paths = try ObsidianExporter.export(
                    vaultRoot: vaultRoot,
                    recording: recording,
                    sourceAudioURL: audioURL,
                    transcriptBody: transcriptBody
                )
                recording.transcriptFileName = paths.noteURL.lastPathComponent
            } else {
                AppLogger.error("No vault configured; skipping Obsidian export for \(job.recordingID)")
            }

            library.upsert(recording)
            queue.remove(job)
        } catch TranscriptionError.cancelled {
            library.updateStatus(id: job.recordingID, status: .failed, failureReason: "Cancelled")
            queue.remove(job)
        } catch {
            AppLogger.error("Transcription failed for job \(job.id): \(error.localizedDescription)")
            library.updateStatus(id: job.recordingID, status: .failed, failureReason: error.localizedDescription)
            queue.remove(job)
        }

        isProcessing = false
        currentJobID = nil
        currentProgress = 0
    }
}
