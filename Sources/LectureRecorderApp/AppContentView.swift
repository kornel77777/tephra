import SwiftUI
import LectureRecorderCore

/// Tab bar + the three tabs. Shared by the notch panel and the regular window.
struct AppContentView: View {
    /// Notch dimensions in this view's own (logical) units; `.none` in window mode.
    let metrics: NotchMetrics
    let showsPin: Bool

    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var processor: TranscriptionQueueProcessor

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .frame(height: max(metrics.notchHeight, 36))

            Group {
                switch vm.tab {
                case .record: NotchRecordView()
                case .library: LibraryView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var topBar: some View {
        HStack(spacing: 6) {
            ForEach(NotchTab.allCases) { tab in
                tabButton(tab)
            }

            Spacer(minLength: metrics.hasNotch ? metrics.notchWidth + 28 : 12)

            if processor.isProcessing {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.accent)
                    Text("\(Int(processor.currentProgress * 100))%")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                }
                .help("Transcribing…")
            }

            if showsPin {
                Button {
                    vm.isPinned.toggle()
                } label: {
                    Image(systemName: vm.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(vm.isPinned ? Theme.accent : Theme.textTertiary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(vm.isPinned ? "Unpin" : "Keep open")
            }
        }
    }

    private func tabButton(_ tab: NotchTab) -> some View {
        let selected = vm.tab == tab
        return Button {
            vm.tab = tab
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 13, weight: .medium))
                if selected {
                    Text(tab.title)
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                }
            }
            .foregroundStyle(selected ? Theme.accent : Theme.textSecondary)
            .padding(.horizontal, selected ? 12 : 9)
            .frame(height: 28)
            .background(Capsule().fill(selected ? Theme.surfaceElevated : .clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(tab.title)
        .animation(.easeOut(duration: 0.15), value: selected)
    }
}
