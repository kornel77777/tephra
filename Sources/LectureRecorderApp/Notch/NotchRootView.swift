import SwiftUI
import LectureRecorderCore

struct NotchRootView: View {
    @ObservedObject var vm: NotchViewModel
    @EnvironmentObject private var recorder: AudioRecorder
    @EnvironmentObject private var processor: TranscriptionQueueProcessor

    @State private var pulse = false

    private let spring = Animation.spring(response: 0.42, dampingFraction: 0.84)

    var body: some View {
        let metrics = vm.metrics
        let size = NotchLayout.expandedSize
        let shapeWidth = vm.isExpanded ? size.width : max(metrics.notchWidth - 6, 120)
        let shapeHeight = vm.isExpanded ? size.height : max(metrics.notchHeight - 2, 6)

        ZStack(alignment: .top) {
            NotchShape(bottomRadius: vm.isExpanded ? 30 : 8)
                .fill(Color.black)
                .frame(width: shapeWidth, height: shapeHeight)
                .shadow(color: .black.opacity(vm.isExpanded ? 0.6 : 0), radius: 22, y: 10)
                .opacity(vm.isExpanded ? 1 : 0)

            content(metrics: metrics)
                .frame(width: shapeWidth, height: shapeHeight, alignment: .top)
                .clipShape(NotchShape(bottomRadius: vm.isExpanded ? 30 : 8))
                .opacity(vm.isExpanded ? 1 : 0)
                .animation(.easeOut(duration: 0.2).delay(vm.isExpanded ? 0.1 : 0), value: vm.isExpanded)
                .allowsHitTesting(vm.isExpanded)

            if !vm.isExpanded, recorder.state != .idle {
                recordingIndicator(metrics: metrics)
                    .transition(.opacity)
            }
        }
        .frame(
            width: NotchLayout.windowSize.width,
            height: NotchLayout.windowSize.height,
            alignment: .top
        )
        .animation(spring, value: vm.isExpanded)
        .animation(.easeOut(duration: 0.2), value: recorder.state)
        .ignoresSafeArea()
    }

    // MARK: - Expanded content

    private func content(metrics: NotchMetrics) -> some View {
        VStack(spacing: 0) {
            topBar(metrics: metrics)
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
        .padding(.horizontal, NotchLayout.ear + 10)
        .padding(.bottom, 14)
    }

    private func topBar(metrics: NotchMetrics) -> some View {
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

    // MARK: - Collapsed recording indicator

    private func recordingIndicator(metrics: NotchMetrics) -> some View {
        let paused = recorder.state == .paused
        let color = paused ? Theme.warning : Theme.danger

        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .opacity(paused ? 1 : (pulse ? 1 : 0.35))
                .glow(color, radius: 4, active: !paused)
            Text(TimeFormat.clock(recorder.elapsedSeconds))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(width: 76, height: 22)
        .background(Capsule().fill(Color.black))
        // Left of the notch: macOS draws its own orange mic dot on the right side.
        .offset(
            x: metrics.hasNotch ? -(metrics.notchWidth / 2 + 8 + 38) : 0,
            y: metrics.hasNotch ? (metrics.notchHeight - 22) / 2 : 4
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
