import Foundation
import LectureRecorderCore

/// Owns the long-lived stores that the notch UI (and the transcription queue) share.
@MainActor
final class AppEnvironment {
    let settings = SettingsStore()
    let library = LibraryStore()
    let queue = TranscriptionQueueStore()
    let recorder = AudioRecorder()
    let recordingViewModel = RecordingViewModel()
    let processor: TranscriptionQueueProcessor

    init() {
        ThemeStore.shared.bind(to: settings)
        processor = TranscriptionQueueProcessor(
            queue: queue,
            library: library,
            settings: settings,
            service: TranscriptionService()
        )
    }
}
