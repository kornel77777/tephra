import SwiftUI
import UniformTypeIdentifiers
import LectureRecorderCore

struct RecordingView: View {
    @EnvironmentObject private var recorder: AudioRecorder
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var queue: TranscriptionQueueStore
    @EnvironmentObject private var viewModel: RecordingViewModel

    @State private var devices: [InputDevice] = []
    @State private var isDropTargeted = false
    @State private var isChoosingFile = false
    @State private var importError: String?

    private var isRecording: Bool { recorder.state == .recording }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                subjectAndDevicePicker

                VStack(spacing: 18) {
                    Text(TimeFormat.clock(recorder.elapsedSeconds))
                        .font(.system(size: 56, weight: .light, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                        .glow(Theme.accent, radius: 18, active: isRecording)
                        .contentTransition(.numericText())
                        .animation(.default, value: recorder.elapsedSeconds)

                    LevelMeterView(level: recorder.inputLevel)
                        .padding(.horizontal, 50)

                    controls
                }
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity)
                .panel(elevated: true)

                if !recorder.bookmarks.isEmpty {
                    bookmarksList
                }

                if let error = viewModel.lastError ?? importError {
                    Text(error)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.danger)
                }

                dropZone
            }
            .padding(28)
        }
        .onAppear { devices = viewModel.availableDevices(recorder: recorder) }
    }

    private var subjectAndDevicePicker: some View {
        HStack(spacing: 14) {
            fieldPicker(label: "SUBJECT") {
                Picker("", selection: $viewModel.selectedSubjectCode) {
                    Text("Choose…").tag(String?.none)
                    ForEach(settings.settings.subjects) { subject in
                        Text(subject.displayName).tag(String?.some(subject.code))
                    }
                }
                .labelsHidden()
            }
            .disabled(recorder.state != .idle)

            fieldPicker(label: "INPUT") {
                Picker("", selection: $viewModel.selectedInputDevice) {
                    Text("System Default").tag(InputDevice?.none)
                    ForEach(devices) { device in
                        Text(device.name).tag(InputDevice?.some(device))
                    }
                }
                .labelsHidden()
            }
            .disabled(recorder.state != .idle)
        }
    }

    private func fieldPicker(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textTertiary)
            content()
                .tint(Theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .panel()
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        HStack(spacing: 14) {
            switch recorder.state {
            case .idle:
                Button {
                    viewModel.start(recorder: recorder, settings: settings)
                } label: {
                    Label("Start Recording", systemImage: "record.circle.fill")
                }
                .buttonStyle(.glow(tint: Theme.accent, filled: true))
                .disabled(viewModel.selectedSubjectCode == nil)

            case .recording:
                Button {
                    recorder.pause()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .buttonStyle(.glow(tint: Theme.textSecondary))

                Button {
                    recorder.addBookmark()
                } label: {
                    Label("Bookmark", systemImage: "star.fill")
                }
                .buttonStyle(.glow(tint: Theme.accentAlt))

                Button(role: .destructive) {
                    viewModel.stopAndEnqueue(recorder: recorder, library: library, queue: queue, settings: settings)
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.glow(tint: Theme.danger, filled: true))

            case .paused:
                Button {
                    try? recorder.resume()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .buttonStyle(.glow(tint: Theme.accent, filled: true))

                Button(role: .destructive) {
                    viewModel.stopAndEnqueue(recorder: recorder, library: library, queue: queue, settings: settings)
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.glow(tint: Theme.danger, filled: true))
            }
        }
    }

    private var bookmarksList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BOOKMARKS")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textTertiary)
            ForEach(recorder.bookmarks) { bookmark in
                HStack(spacing: 6) {
                    Image(systemName: "star.fill").foregroundStyle(Theme.accentAlt).font(.caption)
                    Text(bookmark.timestampLabel)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }

    private var dropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.title)
                .foregroundStyle(isDropTargeted ? Theme.accent : Theme.textTertiary)
            Text("Drop a voice memo or audio file (.m4a, .mp3, .wav, .flac) to transcribe it")
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
            Button("Choose File…") { isChoosingFile = true }
                .buttonStyle(.glow(tint: Theme.accent))
                .disabled(viewModel.selectedSubjectCode == nil)
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(isDropTargeted ? Theme.accent.opacity(0.08) : Theme.surface.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(isDropTargeted ? Theme.accent.opacity(0.7) : Theme.border, style: StrokeStyle(lineWidth: 1.2, dash: [6, 5]))
        )
        .glow(Theme.accent, radius: 12, active: isDropTargeted)
        .animation(.easeOut(duration: 0.15), value: isDropTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .fileImporter(
            isPresented: $isChoosingFile,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls { importAudio(from: url) }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        guard viewModel.selectedSubjectCode != nil else {
            importError = "Choose a subject before importing audio."
            return
        }
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in importAudio(from: url) }
            }
        }
    }

    private func importAudio(from url: URL) {
        guard let subjectCode = viewModel.selectedSubjectCode else {
            importError = "Choose a subject before importing audio."
            return
        }
        guard AudioImporter.isSupported(url) else {
            importError = "\(url.lastPathComponent) isn't a supported audio format."
            return
        }
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
