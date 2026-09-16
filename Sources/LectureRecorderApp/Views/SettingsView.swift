import SwiftUI
import UniformTypeIdentifiers
import LectureRecorderCore

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var viewModel = SettingsViewModel()
    @State private var editingSubject: Subject?
    @State private var isChoosingVault = false

    var body: some View {
        Form {
            Section("Obsidian Vault") {
                HStack {
                    Text(settings.settings.vaultPath ?? "Not set")
                        .foregroundStyle(settings.settings.vaultPath == nil ? .secondary : .primary)
                    Spacer()
                    Button("Choose...") { isChoosingVault = true }
                }
            }

            Section("Transcription Model") {
                Picker("Model", selection: $settings.settings.selectedModel) {
                    ForEach(ModelVariant.allCases) { variant in
                        Text(variant.displayName).tag(variant)
                    }
                }

                ForEach(ModelVariant.allCases) { variant in
                    HStack {
                        Text(variant.displayName)
                        Spacer()
                        if let progress = viewModel.downloadProgress[variant], progress < 1 {
                            ProgressView(value: progress).frame(width: 100)
                        } else {
                            Button("Download") { viewModel.download(variant) }
                            Button("Delete", role: .destructive) { viewModel.delete(variant) }
                        }
                    }
                }

                if let error = viewModel.downloadError {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section("Recording Format") {
                Stepper(value: $settings.settings.sampleRateHz, in: 16_000...48_000, step: 8_000) {
                    Text("Sample rate: \(Int(settings.settings.sampleRateHz)) Hz")
                }
                Stepper(value: $settings.settings.recordingChannels, in: 1...2) {
                    Text("Channels: \(settings.settings.recordingChannels)")
                }
            }

            Section("Subjects") {
                ForEach(settings.settings.subjects) { subject in
                    Button {
                        editingSubject = subject
                    } label: {
                        HStack {
                            Text(subject.displayName)
                            Text(subject.code).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    settings.settings.subjects.remove(atOffsets: indexSet)
                }

                Button("Add Subject") {
                    let subject = Subject(code: "", displayName: "New Subject")
                    settings.settings.subjects.append(subject)
                    editingSubject = subject
                }
            }
        }
        .formStyle(.grouped)
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
