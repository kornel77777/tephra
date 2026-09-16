import SwiftUI
import LectureRecorderCore

struct RecordingView: View {
    @EnvironmentObject private var recorder: AudioRecorder
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var queue: TranscriptionQueueStore
    @StateObject private var viewModel = RecordingViewModel()

    @State private var devices: [InputDevice] = []
    @State private var isDropTargeted = false
    @State private var importError: String?

    var body: some View {
        VStack(spacing: 20) {
            subjectAndDevicePicker

            Text(TimeFormat.clock(recorder.elapsedSeconds))
                .font(.system(size: 48, weight: .medium, design: .monospaced))

            LevelMeterView(level: recorder.inputLevel)
                .padding(.horizontal, 40)

            controls

            if !recorder.bookmarks.isEmpty {
                bookmarksList
            }

            if let error = viewModel.lastError ?? importError {
                Text(error).foregroundStyle(.red)
            }

            Divider().padding(.vertical, 8)

            dropZone
        }
        .padding(30)
        .onAppear { devices = viewModel.availableDevices(recorder: recorder) }
    }

    private var subjectAndDevicePicker: some View {
        HStack(spacing: 16) {
            Picker("Subject", selection: $viewModel.selectedSubjectCode) {
                Text("Choose...").tag(String?.none)
                ForEach(settings.settings.subjects) { subject in
                    Text(subject.displayName).tag(String?.some(subject.code))
                }
            }
            .disabled(recorder.state != .idle)

            Picker("Input", selection: $viewModel.selectedInputDevice) {
                Text("System Default").tag(InputDevice?.none)
                ForEach(devices) { device in
                    Text(device.name).tag(InputDevice?.some(device))
                }
            }
            .disabled(recorder.state != .idle)
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            switch recorder.state {
            case .idle:
                Button {
                    viewModel.start(recorder: recorder, settings: settings)
                } label: {
                    Label("Start", systemImage: "record.circle").font(.title2)
                }
                .disabled(viewModel.selectedSubjectCode == nil)

            case .recording:
                Button {
                    recorder.pause()
                } label: {
                    Label("Pause", systemImage: "pause.circle").font(.title2)
                }
                Button {
                    recorder.addBookmark()
                } label: {
                    Label("Bookmark", systemImage: "star.circle").font(.title2)
                }
                Button(role: .destructive) {
                    viewModel.stopAndEnqueue(recorder: recorder, library: library, queue: queue, settings: settings)
                } label: {
                    Label("Stop", systemImage: "stop.circle").font(.title2)
                }

            case .paused:
                Button {
                    try? recorder.resume()
                } label: {
                    Label("Resume", systemImage: "play.circle").font(.title2)
                }
                Button(role: .destructive) {
                    viewModel.stopAndEnqueue(recorder: recorder, library: library, queue: queue, settings: settings)
                } label: {
                    Label("Stop", systemImage: "stop.circle").font(.title2)
                }
            }
        }
    }

    private var bookmarksList: some View {
        VStack(alignment: .leading) {
            Text("Bookmarks").font(.headline)
            ForEach(recorder.bookmarks) { bookmark in
                Text("⭐ \(bookmark.timestampLabel)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dropZone: some View {
        VStack {
            Image(systemName: "arrow.down.doc")
                .font(.largeTitle)
            Text("Drop a voice memo or audio file (.m4a, .mp3, .wav, .flac) here to transcribe it")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(RoundedRectangle(cornerRadius: 12).fill(isDropTargeted ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6])))
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .disabled(viewModel.selectedSubjectCode == nil)
    }

    private func handleDrop(providers: [NSItemProvider]) {
        guard let subjectCode = viewModel.selectedSubjectCode else {
            importError = "Choose a subject before importing audio."
            return
        }
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, AudioImporter.isSupported(url) else { return }
                Task { @MainActor in
                    do {
                        let imported = try await AudioImporter.importFile(at: url)
                        let recording = LectureRecording(
                            subjectCode: subjectCode,
                            recordedAt: Date(),
                            durationSeconds: imported.duration,
                            audioFileName: imported.url.lastPathComponent,
                            status: .queued,
                            isImported: true
                        )
                        library.upsert(recording)
                        queue.enqueue(TranscriptionJob(
                            recordingID: recording.id,
                            audioPath: imported.url.path,
                            subjectCode: subjectCode,
                            modelVariant: settings.settings.selectedModel.rawValue
                        ))
                    } catch {
                        importError = error.localizedDescription
                    }
                }
            }
        }
    }
}
