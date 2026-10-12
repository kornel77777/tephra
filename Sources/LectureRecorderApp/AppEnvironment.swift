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
    let notchVM = NotchViewModel()
    let processor: TranscriptionQueueProcessor
    let shortcuts: ShortcutController

    init() {
        ThemeStore.shared.bind(to: settings)
        processor = TranscriptionQueueProcessor(
            queue: queue,
            library: library,
            settings: settings,
            service: TranscriptionService()
        )
        shortcuts = ShortcutController(settings: settings)

        // Remember the last subject so a keyboard-triggered recording can start right away.
        if let code = settings.settings.lastSubjectCode,
           settings.settings.subjects.contains(where: { $0.code == code }) {
            recordingViewModel.selectedSubjectCode = code
        }
    }
}
