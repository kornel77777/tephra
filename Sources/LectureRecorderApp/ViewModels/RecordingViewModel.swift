import Foundation
import SwiftUI
import LectureRecorderCore

@MainActor
final class RecordingViewModel: ObservableObject {
    @Published var selectedSubjectCode: String?
    @Published var selectedInputDevice: InputDevice?
    @Published var lastError: String?

    func availableDevices(recorder: AudioRecorder) -> [InputDevice] {
        recorder.availableInputDevices()
    }

    func start(recorder: AudioRecorder, settings: SettingsStore) {
        guard selectedSubjectCode != nil else {
            lastError = "Choose a subject before recording."
            return
        }
        do {
            try recorder.start(
                sampleRate: settings.settings.sampleRateHz,
                channels: settings.settings.recordingChannels,
                inputDevice: selectedInputDevice
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stopAndEnqueue(
        recorder: AudioRecorder,
        library: LibraryStore,
        queue: TranscriptionQueueStore,
        settings: SettingsStore
    ) {
        // Recording in progress always wins: even if the subject selection was
        // somehow lost, finish() must still run so the audio is never stranded
        // (recorder.finish() is a no-op if nothing is recording).
        let subjectCode = selectedSubjectCode ?? "Unknown"
        Task {
            do {
                let (url, duration, bookmarks) = try await recorder.finish()
                let recording = LectureRecording(
                    subjectCode: subjectCode,
                    recordedAt: Date(),
                    durationSeconds: duration,
                    audioFileName: url.lastPathComponent,
                    status: .queued,
                    bookmarks: bookmarks
                )
                library.upsert(recording)
                queue.enqueue(TranscriptionJob(
                    recordingID: recording.id,
                    audioPath: url.path,
                    subjectCode: subjectCode,
                    modelVariant: settings.settings.selectedModel.rawValue
                ))
            } catch {
                lastError = error.localizedDescription
            }
        }
    }
}
