import SwiftUI
import LectureRecorderCore

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var queue: TranscriptionQueueStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var processor: TranscriptionQueueProcessor

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if library.recordings.isEmpty {
                    emptyState
                } else {
                    ForEach(library.recordings) { recording in
                        row(recording)
                    }
                }
            }
            .padding(24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.title)
                .foregroundStyle(Theme.textTertiary)
            Text("No recordings yet")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    private func row(_ recording: LectureRecording) -> some View {
        let display = recording.status.display
        let isActive = recording.id == processor.currentJobID
        let isCancellable = recording.status == .queued || recording.status == .processing

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("\(recording.subjectCode) — \(recording.recordedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 8) {
                    Text("\(Int(recording.durationSeconds / 60)) min")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                    if recording.isImported {
                        Text("· Imported")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    StatusBadge(status: display)
                }

                if let reason = recording.failureReason {
                    Text(reason)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.danger)
                }
            }

            Spacer()

            if isActive {
                ProgressView(value: processor.currentProgress)
                    .progressViewStyle(.linear)
                    .tint(Theme.accent)
                    .frame(width: 100)
            }

            if isCancellable {
                Button("Cancel") { cancel(recording) }
                    .buttonStyle(.glow(tint: Theme.danger))
            }

            if recording.status == .failed {
                Button("Retry") { retry(recording) }
                    .buttonStyle(.glow(tint: Theme.accent))
            }
        }
        .padding(16)
        .panel()
    }

    /// Removes a queued job outright, or signals the running one to stop early
    /// — either way the recording's audio is never touched, only the
    /// transcription attempt is abandoned.
    private func cancel(_ recording: LectureRecording) {
        if recording.id == processor.currentJobID {
            processor.cancelCurrent()
            return
        }
        if let job = queue.jobs.first(where: { $0.recordingID == recording.id }) {
            queue.remove(job)
        }
        library.updateStatus(id: recording.id, status: .failed, failureReason: "Cancelled")
    }

    private func retry(_ recording: LectureRecording) {
        var updated = recording
        updated.status = .queued
        updated.failureReason = nil
        library.upsert(updated)

        let audioURL = AppPaths.recordingsDirectory
        let job = TranscriptionJob(
            recordingID: recording.id,
            audioPath: audioURL.appendingPathComponent(recording.audioFileName).path,
            subjectCode: recording.subjectCode,
            modelVariant: settings.settings.selectedModel.rawValue
        )
        queue.enqueue(job)
    }
}
