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
            Text("Subject").font(.title2)

            TextField("Course code (e.g. PHL200)", text: $subject.code)
            TextField("Display name (e.g. Ethics and Political Philosophy)", text: $subject.displayName)

            Text("Glossary (professor names, jargon, proper nouns — words, not sentences)")
                .font(.headline)
            TextEditor(text: $subject.promptGlossary)
                .frame(minHeight: 120)
                .border(Color.secondary.opacity(0.3))

            if estimatedWordCount > PromptLimits.maxTokens {
                Text("This looks close to or over the \(PromptLimits.maxTokens)-token prefill prompt limit; it may get truncated.")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    onSave(subject)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(subject.code.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
