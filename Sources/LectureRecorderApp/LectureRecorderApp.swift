import SwiftUI
import LectureRecorderCore

@main
struct LectureRecorderApp: App {
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var libraryStore = LibraryStore()
    @StateObject private var queueStore = TranscriptionQueueStore()
    @StateObject private var recorder = AudioRecorder()
    @StateObject private var processor: TranscriptionQueueProcessor

    init() {
        let settings = SettingsStore()
        let library = LibraryStore()
        let queue = TranscriptionQueueStore()
        let service = TranscriptionService()
        _settingsStore = StateObject(wrappedValue: settings)
        _libraryStore = StateObject(wrappedValue: library)
        _queueStore = StateObject(wrappedValue: queue)
        _processor = StateObject(wrappedValue: TranscriptionQueueProcessor(
            queue: queue, library: library, settings: settings, service: service
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsStore)
                .environmentObject(libraryStore)
                .environmentObject(queueStore)
                .environmentObject(recorder)
                .environmentObject(processor)
                .onAppear { processor.start() }
                .frame(minWidth: 720, minHeight: 520)
        }
        .windowResizability(.contentSize)
    }
}
