import SwiftUI
import UniformTypeIdentifiers
import LectureRecorderCore

/// The notch's main tab: timer + controls on the left, subject / input /
/// import on the right.
struct NotchRecordView: View {
    @EnvironmentObject private var recorder: AudioRecorder
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var queue: TranscriptionQueueStore
    @EnvironmentObject private var viewModel: RecordingViewModel
    @EnvironmentObject private var vm: NotchViewModel

    @State private var devices: [InputDevice] = []
    @State private var isDropTargeted = false
    @State private var isChoosingFile = false
    @State private var importError: String?

    private var isRecording: Bool { recorder.state == .recording }
    private var isIdle: Bool { recorder.state == .idle }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            recorderPanel
            sidePanel.frame(width: 250)
        }
        .padding(.top, 4)
        .onAppear { devices = viewModel.availableDevices(recorder: recorder) }
        .onChange(of: vm.isExpanded) { _, expanded in
            if expanded { devices = viewModel.availableDevices(recorder: recorder) }
        }
    }

    // MARK: - Left: timer + controls

    private var recorderPanel: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            Text(TimeFormat.clock(recorder.elapsedSeconds))
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .glow(Theme.accent, radius: 16, active: isRecording)
                .contentTransition(.numericText())
                .animation(.default, value: recorder.elapsedSeconds)

            LevelMeterView(level: recorder.inputLevel)
                .padding(.horizontal, 20)

            controls

            if !recorder.bookmarks.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").font(.caption2).foregroundStyle(Theme.accentAlt)
                    Text("\(recorder.bookmarks.count) bookmarked")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .panel(elevated: true)
    }

    private var controls: some View {
        HStack(spacing: 10) {
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
                Button { recorder.pause() } label: { Image(systemName: "pause.fill") }
                    .buttonStyle(.glow(tint: Theme.textSecondary))
                    .help("Pause")
                Button { recorder.addBookmark() } label: { Image(systemName: "star.fill") }
                    .buttonStyle(.glow(tint: Theme.accentAlt))
                    .help("Bookmark this moment")
                Button {
                    viewModel.stopAndEnqueue(recorder: recorder, library: library, queue: queue, settings: settings)
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.glow(tint: Theme.danger, filled: true))

            case .paused:
                Button { try? recorder.resume() } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .buttonStyle(.glow(tint: Theme.accent, filled: true))
                Button {
                    viewModel.stopAndEnqueue(recorder: recorder, library: library, queue: queue, settings: settings)
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.glow(tint: Theme.danger, filled: true))
            }
        }
    }

    // MARK: - Right: subject, input, import

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("SUBJECT")
            if settings.settings.subjects.isEmpty {
                Text("Add a subject in Settings first.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(settings.settings.subjects) { subject in
                        subjectChip(subject)
                    }
                }
                .disabled(!isIdle)
            }

            sectionLabel("INPUT")
            inputMenu.disabled(!isIdle)

            Spacer(minLength: 0)

            if let error = viewModel.lastError ?? importError {
                Text(error)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Theme.danger)
                    .lineLimit(2)
            }

            importArea
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(Theme.textTertiary)
    }

    private func subjectChip(_ subject: Subject) -> some View {
        let selected = viewModel.selectedSubjectCode == subject.code
        return Button {
            viewModel.selectedSubjectCode = subject.code
        } label: {
            Text(subject.code)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(selected ? Color.black.opacity(0.85) : Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(selected ? Theme.accent : Theme.surfaceElevated))
                .overlay(Capsule().strokeBorder(selected ? .clear : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(subject.displayName)
    }

    private var inputMenu: some View {
        Menu {
            Picker("Input", selection: $viewModel.selectedInputDevice) {
                Text("System Default").tag(InputDevice?.none)
                ForEach(devices) { device in
                    Text(device.name).tag(InputDevice?.some(device))
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "mic.fill").font(.caption)
                Text(viewModel.selectedInputDevice?.name ?? "System Default")
                    .font(.system(.footnote, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .panel()
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }

    private var importArea: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.doc.fill")
                .foregroundStyle(isDropTargeted ? Theme.accent : Theme.textTertiary)
            Text("Drop audio")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
            Button("Choose…") { isChoosingFile = true }
                .buttonStyle(.glow(tint: Theme.accent))
                .controlSize(.small)
                .disabled(viewModel.selectedSubjectCode == nil)
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(isDropTargeted ? Theme.accent.opacity(0.1) : Theme.surface.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? Theme.accent.opacity(0.7) : Theme.border,
                    style: StrokeStyle(lineWidth: 1.2, dash: [6, 5])
                )
        )
        .glow(Theme.accent, radius: 10, active: isDropTargeted)
        .animation(.easeOut(duration: 0.15), value: isDropTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .onChange(of: isChoosingFile) { _, showing in
            if showing { NSApp.activate() }
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

    // MARK: - Import

    private func handleDrop(providers: [NSItemProvider]) {
        guard viewModel.selectedSubjectCode != nil else {
            importError = "Pick a subject before importing audio."
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
            importError = "Pick a subject before importing audio."
            return
        }
        guard AudioImporter.isSupported(url) else {
            importError = "\(url.lastPathComponent) isn't a supported audio format."
            return
        }
        importError = nil
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
                vm.tab = .library
            } catch {
                importError = error.localizedDescription
            }
        }
    }
}
