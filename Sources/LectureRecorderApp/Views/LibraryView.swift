import SwiftUI
import LectureRecorderCore

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var queue: TranscriptionQueueStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var processor: TranscriptionQueueProcessor

    /// Row whose trash button was pressed once and is waiting for a second click.
    @State private var confirmingDelete: UUID?
    /// Age (in days) of a pending "clear old recordings" request awaiting confirmation.
    @State private var pendingCleanupDays: Int?

    private struct MonthGroup: Identifiable {
        let start: Date
        let items: [LectureRecording]
        var id: Date { start }
        var totalSeconds: Double { items.reduce(0) { $0 + $1.durationSeconds } }
    }

    private var groups: [MonthGroup] {
        let calendar = Calendar.current
        let byMonth = Dictionary(grouping: library.recordings) { recording in
            calendar.date(from: calendar.dateComponents([.year, .month], from: recording.recordedAt)) ?? recording.recordedAt
        }
        return byMonth.keys.sorted(by: >).map { start in
            MonthGroup(start: start, items: byMonth[start]!.sorted { $0.recordedAt > $1.recordedAt })
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if library.recordings.isEmpty {
                    emptyState
                } else {
                    toolbar
                    if let days = pendingCleanupDays {
                        cleanupBanner(days: days)
                    }
                    ForEach(groups) { group in
                        header(for: group)
                        ForEach(group.items) { recording in
                            row(recording)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .animation(.easeOut(duration: 0.15), value: pendingCleanupDays)
        }
    }

    // MARK: - Summary + cleanup

    private var toolbar: some View {
        HStack {
            Text("\(library.recordings.count) recordings")
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            Menu {
                Button("Older than 1 month") { pendingCleanupDays = 30 }
                Button("Older than 3 months") { pendingCleanupDays = 90 }
                Button("Older than 6 months") { pendingCleanupDays = 180 }
            } label: {
                Label("Clear old…", systemImage: "trash")
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 6)
    }

    private func cleanupCandidates(days: Int) -> [LectureRecording] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return library.removableRecordings(olderThan: cutoff)
    }

    private func cleanupBanner(days: Int) -> some View {
        let candidates = cleanupCandidates(days: days)
        return VStack(alignment: .leading, spacing: 8) {
            if candidates.isEmpty {
                Text("Nothing finished is older than \(days == 30 ? "1 month" : "\(days / 30) months").")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Button("OK") { pendingCleanupDays = nil }
                    .buttonStyle(.glow(tint: Theme.textSecondary))
            } else {
                Text("Remove \(candidates.count) recording\(candidates.count == 1 ? "" : "s") older than \(days == 30 ? "1 month" : "\(days / 30) months") from Tephra?")
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text("This deletes Tephra's own copy of the audio. Notes and audio already saved in your Notes Folder are not touched.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                HStack {
                    Button("Remove") {
                        library.remove(candidates)
                        pendingCleanupDays = nil
                    }
                    .buttonStyle(.glow(tint: Theme.danger, filled: true))
                    Button("Keep") { pendingCleanupDays = nil }
                        .buttonStyle(.glow(tint: Theme.textSecondary))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel(elevated: true)
    }

    // MARK: - Month header

    private func header(for group: MonthGroup) -> some View {
        HStack {
            Text(group.start.formatted(.dateTime.month(.wide).year()).uppercased())
                .font(.system(.caption, design: .rounded, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textTertiary)
            Spacer()
            Text("\(group.items.count) recording\(group.items.count == 1 ? "" : "s") · \(Self.durationLabel(group.totalSeconds))")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 6)
        .padding(.top, 8)
    }

    private static func durationLabel(_ seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h)h" : "\(h)h \(m)m"
        }
        return "\(minutes)m"
    }

    // MARK: - Rows

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.title)
                .foregroundStyle(Theme.textTertiary)
            Text("No recordings yet")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    private func row(_ recording: LectureRecording) -> some View {
        let display = recording.status.display
        let isActive = recording.id == processor.currentJobID
        let isCancellable = recording.status == .queued || recording.status == .processing

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("\(recording.subjectCode) — \(recording.recordedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 8) {
                    Text("\(Int(recording.durationSeconds / 60)) min")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                    if recording.isImported {
                        Text("· Imported")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    StatusBadge(status: display)
                }

                if let reason = recording.failureReason {
                    Text(reason)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.danger)
                }
            }

            Spacer()

            if isActive {
                ProgressView(value: processor.currentProgress)
                    .progressViewStyle(.linear)
                    .tint(Theme.accent)
                    .frame(width: 100)
            }

            if isCancellable {
                Button("Cancel") { cancel(recording) }
                    .buttonStyle(.glow(tint: Theme.danger))
            }

            if recording.status == .failed {
                Button("Retry") { retry(recording) }
                    .buttonStyle(.glow(tint: Theme.accent))
            }

            if library.isRemovable(recording) {
                deleteControl(recording)
            }
        }
        .padding(16)
        .panel()
    }

    /// Trash button that needs a second click, so a stray click can't delete a recording.
    @ViewBuilder
    private func deleteControl(_ recording: LectureRecording) -> some View {
        if confirmingDelete == recording.id {
            HStack(spacing: 6) {
                Button("Delete") {
                    library.remove([recording])
                    confirmingDelete = nil
                }
                .buttonStyle(.glow(tint: Theme.danger, filled: true))
                Button("Keep") { confirmingDelete = nil }
                    .buttonStyle(.glow(tint: Theme.textSecondary))
            }
        } else {
            Button {
                confirmingDelete = recording.id
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Remove from Tephra (keeps your saved notes)")
        }
    }

    /// Removes a queued job outright, or signals the running one to stop early
    /// — either way the recording's audio is never touched, only the
    /// transcription attempt is abandoned.
    private func cancel(_ recording: LectureRecording) {
        if recording.id == processor.currentJobID {
            processor.cancelCurrent()
            return
        }
        if let job = queue.jobs.first(where: { $0.recordingID == recording.id }) {
            queue.remove(job)
        }
        library.updateStatus(id: recording.id, status: .failed, failureReason: "Cancelled")
    }

    private func retry(_ recording: LectureRecording) {
        var updated = recording
        updated.status = .queued
        updated.failureReason = nil
        library.upsert(updated)

        let audioURL = AppPaths.recordingsDirectory
        let job = TranscriptionJob(
            recordingID: recording.id,
            audioPath: audioURL.appendingPathComponent(recording.audioFileName).path,
            subjectCode: recording.subjectCode,
            modelVariant: settings.settings.selectedModel.rawValue
        )
        queue.enqueue(job)
    }
}
