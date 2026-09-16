import SwiftUI
import LectureRecorderCore

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var queue: TranscriptionQueueStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var processor: TranscriptionQueueProcessor

    var body: some View {
        List {
            ForEach(library.recordings) { recording in
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(recording.subjectCode) — \(recording.recordedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.headline)
                        Text("\(Int(recording.durationSeconds / 60)) min · \(recording.status.rawValue.capitalized)\(recording.isImported ? " · Imported" : "")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let reason = recording.failureReason {
                            Text(reason).font(.caption).foregroundStyle(.red)
                        }
                    }

                    Spacer()

                    if recording.id == processor.currentJobID {
                        ProgressView(value: processor.currentProgress)
                            .frame(width: 100)
                    }

                    if recording.status == .failed {
                        Button("Retry") { retry(recording) }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Library")
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
