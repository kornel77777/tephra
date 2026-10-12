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
    @EnvironmentObject private var recorder: AudioRecorder
    @StateObject private var viewModel = SettingsViewModel()
    @State private var editingSubject: Subject?
    @State private var isChoosingVault = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                SectionCard(title: "Appearance") {
                    AppearancePicker()
                }

                SectionCard(title: "Mode") {
                    ModePicker()
                }

                SectionCard(title: "Shortcuts") {
                    ShortcutsEditor()
                }

                SectionCard(title: "Notes Folder") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(settings.settings.vaultPath ?? "Not set")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(settings.settings.vaultPath == nil ? Theme.textTertiary : Theme.textPrimary)
                            Spacer()
                            Button("Choose…") { isChoosingVault = true }
                                .buttonStyle(.glow(tint: Theme.accent))
                        }
                        Text("Just a folder — transcripts and audio land here as plain markdown + audio files. Point it at an Obsidian vault and the audio embeds automatically; any other folder works too, you'll just get the raw files.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
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

                SectionCard(title: "App") {
                    HStack {
                        Text(recorder.state == .idle ? "Tephra lives in your notch — hover the top-center of the screen to open it." : "Stop the recording before quitting.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                        Spacer()
                        Button("Quit Tephra") { NSApp.terminate(nil) }
                            .buttonStyle(.glow(tint: Theme.danger))
                            .disabled(recorder.state != .idle)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .onChange(of: isChoosingVault) { _, showing in
            if showing { NSApp.activate() }
        }
        .onChange(of: editingSubject) { _, subject in
            if subject != nil { NSApp.activate() }
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

private struct AppearancePicker: View {
    @EnvironmentObject private var settings: SettingsStore

    private static let accentChoices: [Color] = [
        Color(red: 0.16, green: 0.92, blue: 0.85), Color(red: 0.45, green: 0.95, blue: 0.55),
        Color(red: 0.75, green: 0.95, blue: 0.35), Color(red: 0.95, green: 0.8, blue: 0.4),
        Color(red: 1.0, green: 0.55, blue: 0.25), Color(red: 1.0, green: 0.36, blue: 0.42),
        Color(red: 1.0, green: 0.55, blue: 0.75), Color(red: 0.85, green: 0.45, blue: 1.0),
        Color(red: 0.58, green: 0.48, blue: 1.0), Color(red: 0.35, green: 0.65, blue: 1.0),
        Color(red: 0.3, green: 0.9, blue: 0.9), Color(red: 0.92, green: 0.93, blue: 0.95),
        Color(red: 0.6, green: 0.62, blue: 0.66)
    ]

    private var currentID: String { settings.settings.themeID ?? ThemePalette.fallback.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FlowLayout(spacing: 8) {
                ForEach(ThemePalette.presets) { preset in
                    swatch(id: preset.id, name: preset.name, accent: preset.accent, accentAlt: preset.accentAlt, fill: preset.surfaceElevated) {
                        settings.settings.themeID = preset.id
                    }
                }
                swatch(id: ThemePalette.customID, name: "Custom", accent: Theme.accent, accentAlt: Theme.accentAlt, fill: Theme.surfaceElevated) {
                    var s = settings.settings
                    s.customAccentHex = s.customAccentHex ?? Theme.accent.hexString
                    s.customAccentAltHex = s.customAccentAltHex ?? Theme.accentAlt.hexString
                    s.themeID = ThemePalette.customID
                    settings.settings = s
                }
            }

            if currentID == ThemePalette.customID {
                colorRow(title: "Accent", hex: settings.settings.customAccentHex) { settings.settings.customAccentHex = $0 }
                colorRow(title: "Secondary", hex: settings.settings.customAccentAltHex) { settings.settings.customAccentAltHex = $0 }
            }
        }
    }

    private func swatch(id: String, name: String, accent: Color, accentAlt: Color, fill: Color, action: @escaping () -> Void) -> some View {
        let selected = currentID == id
        return Button(action: action) {
            HStack(spacing: 6) {
                Circle().fill(accent).frame(width: 10, height: 10)
                Circle().fill(accentAlt).frame(width: 10, height: 10)
                Text(name)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(selected ? accent : Theme.border, lineWidth: selected ? 1.6 : 1))
        }
        .buttonStyle(.plain)
    }

    private func colorRow(title: String, hex: String?, set: @escaping (String) -> Void) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 70, alignment: .leading)
            FlowLayout(spacing: 7) {
                ForEach(Array(Self.accentChoices.enumerated()), id: \.offset) { _, color in
                    let selected = color.hexString == (hex ?? "").uppercased()
                    Button { set(color.hexString) } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 20, height: 20)
                            .overlay(Circle().strokeBorder(.white.opacity(selected ? 0.95 : 0), lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ModePicker: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: Binding(
                get: { UIMode(settings: settings.settings).rawValue },
                set: { settings.settings.uiMode = $0 }
            )) {
                Text("Notch").tag(UIMode.notch.rawValue)
                Text("Window").tag(UIMode.window.rawValue)
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Text("Notch tucks into the top of the screen with no Dock icon. Window is an ordinary window with a Dock icon. Your recordings and settings are the same either way.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
    }
}

private struct ShortcutsEditor: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var shortcuts: ShortcutController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(ShortcutAction.allCases) { action in
                HStack {
                    Text(action.title)
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Picker("", selection: binding(for: action)) {
                        Text("Off").tag(ShortcutModifier?.none)
                        ForEach(ShortcutModifier.allCases) { modifier in
                            Text("Double-tap \(modifier.symbol) \(modifier.name)").tag(ShortcutModifier?.some(modifier))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
            }

            Text("Tap the key twice quickly, on its own — pressing any other key in between cancels it, so normal typing never triggers anything.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.textTertiary)

            if shortcuts.hasAccess {
                Label("Active", systemImage: "checkmark.circle.fill")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.success)
            } else {
                HStack(spacing: 10) {
                    Text("Needs the Input Monitoring permission to see key taps in other apps.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.warning)
                    Spacer()
                    Button("Grant access…") { shortcuts.requestAccess() }
                        .buttonStyle(.glow(tint: Theme.warning))
                }
            }
        }
    }

    /// Each modifier can drive only one action: picking it here switches it off elsewhere.
    private func binding(for action: ShortcutAction) -> Binding<ShortcutModifier?> {
        Binding(
            get: { settings.settings.modifier(for: action) },
            set: { newValue in
                var updated = settings.settings
                if let newValue {
                    for other in ShortcutAction.allCases where other != action && updated.modifier(for: other) == newValue {
                        updated.setModifier(nil, for: other)
                    }
                }
                updated.setModifier(newValue, for: action)
                settings.settings = updated
            }
        )
    }
}
