import SwiftUI
import LectureRecorderCore

struct SubjectEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subject: Subject
    let onSave: (Subject) -> Void

    init(subject: Subject, onSave: @escaping (Subject) -> Void) {
        _subject = State(initialValue: subject)
        self.onSave = onSave
    }

    private var estimatedWordCount: Int {
        subject.promptGlossary.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\n" }).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Subject")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            field("Course code (e.g. PHL200)", text: $subject.code)
            field("Display name (e.g. Ethics and Political Philosophy)", text: $subject.displayName)

            Text("GLOSSARY — professor names, jargon, proper nouns (words, not sentences)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.textTertiary)
            TextEditor(text: $subject.promptGlossary)
                .scrollContentBackground(.hidden)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .frame(minHeight: 120)
                .padding(8)
                .panel()

            if estimatedWordCount > PromptLimits.maxTokens {
                Text("This looks close to or over the \(PromptLimits.maxTokens)-token prefill prompt limit; it may get truncated.")
                    .foregroundStyle(Theme.warning)
                    .font(.system(.caption, design: .rounded))
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.glow(tint: Theme.textSecondary))
                Button("Save") {
                    onSave(subject)
                    dismiss()
                }
                .buttonStyle(.glow(tint: Theme.accent, filled: true))
                .keyboardShortcut(.defaultAction)
                .disabled(subject.code.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(Theme.background)
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(.body, design: .rounded))
            .foregroundStyle(Theme.textPrimary)
            .padding(10)
            .panel()
    }
}
