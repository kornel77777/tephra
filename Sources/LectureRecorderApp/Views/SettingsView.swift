import SwiftUI
import UniformTypeIdentifiers
import LectureRecorderCore

private let sampleRateOptions: [(label: String, value: Double)] = [
    (label: "16 kHz — smallest files", value: 16_000),
    (label: "44.1 kHz — CD quality", value: 44_100),
    (label: "48 kHz — standard (default)", value: 48_000)
]

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var viewModel = SettingsViewModel()
    @State private var editingSubject: Subject?
    @State private var isChoosingVault = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                SectionCard(title: "Obsidian Vault") {
                    HStack {
                        Text(settings.settings.vaultPath ?? "Not set")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(settings.settings.vaultPath == nil ? Theme.textTertiary : Theme.textPrimary)
                        Spacer()
                        Button("Choose…") { isChoosingVault = true }
                            .buttonStyle(.glow(tint: Theme.accent))
                    }
                }

                SectionCard(title: "Transcription Model") {
                    VStack(spacing: 12) {
                        Picker("Active model", selection: $settings.settings.selectedModel) {
                            ForEach(ModelVariant.allCases) { variant in
                                Text(variant.displayName).tag(variant)
                            }
                        }
                        .tint(Theme.accent)

                        Divider().overlay(Theme.border)

                        ForEach(ModelVariant.allCases) { variant in
                            HStack {
                                Text(variant.displayName)
                                    .font(.system(.callout, design: .rounded))
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                                if let progress = viewModel.downloadProgress[variant], progress < 1 {
                                    ProgressView(value: progress)
                                        .tint(Theme.accent)
                                        .frame(width: 100)
                                } else {
                                    Button("Download") { viewModel.download(variant) }
                                        .buttonStyle(.glow(tint: Theme.accent))
                                    Button("Delete") { viewModel.delete(variant) }
                                        .buttonStyle(.glow(tint: Theme.danger))
                                }
                            }
                        }

                        if let error = viewModel.downloadError {
                            Text(error).font(.caption).foregroundStyle(Theme.danger)
                        }
                    }
                }

                SectionCard(title: "Recording Format") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sample rate")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                            Picker("", selection: $settings.settings.sampleRateHz) {
                                ForEach(sampleRateOptions, id: \.value) { option in
                                    Text(option.label).tag(option.value)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            Text("This only affects the archived audio file's quality. WhisperKit always resamples to 16 kHz internally, so transcription accuracy is unaffected either way.")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Channels")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                            Picker("", selection: $settings.settings.recordingChannels) {
                                Text("Mono").tag(1)
                                Text("Stereo").tag(2)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            Text("Mono is recommended for a single lecture-hall microphone and uses half the storage of stereo.")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }

                SectionCard(title: "Subjects") {
                    VStack(spacing: 8) {
                        ForEach(settings.settings.subjects) { subject in
                            HStack {
                                Button {
                                    editingSubject = subject
                                } label: {
                                    HStack {
                                        Text(subject.displayName)
                                            .font(.system(.body, design: .rounded))
                                            .foregroundStyle(Theme.textPrimary)
                                        Text(subject.code)
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(Theme.textTertiary)
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    settings.settings.subjects.removeAll { $0.id == subject.id }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(RoundedRectangle(cornerRadius: Theme.smallCornerRadius).fill(Theme.surfaceElevated.opacity(0.6)))
                        }

                        Button("Add Subject") {
                            let subject = Subject(code: "", displayName: "New Subject")
                            settings.settings.subjects.append(subject)
                            editingSubject = subject
                        }
                        .buttonStyle(.glow(tint: Theme.accent, filled: true))
                    }
                }
            }
            .padding(24)
        }
        .fileImporter(isPresented: $isChoosingVault, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                settings.settings.vaultPath = url.path
            }
        }
        .sheet(item: $editingSubject) { subject in
            SubjectEditorView(subject: subject) { updated in
                if let index = settings.settings.subjects.firstIndex(where: { $0.id == updated.id }) {
                    settings.settings.subjects[index] = updated
                }
            }
        }
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(.caption, design: .rounded, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textTertiary)
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }
}
