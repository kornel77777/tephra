import SwiftUI
import LectureRecorderCore

struct NotchRootView: View {
    @ObservedObject var vm: NotchViewModel
    @EnvironmentObject private var recorder: AudioRecorder
    @EnvironmentObject private var themeStore: ThemeStore

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
                .frame(width: NotchLayout.logicalSize.width, height: NotchLayout.logicalSize.height)
                .scaleEffect(NotchLayout.scale, anchor: .top)
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
        // Colors are read from `Theme` at draw time, so a new id rebuilds everything with the new palette.
        .id(themeStore.revision)
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

    /// Laid out at logical size and scaled down afterwards, so the hardware notch's
    /// real dimensions have to be converted into the same logical units.
    private func content(metrics realMetrics: NotchMetrics) -> some View {
        let metrics = NotchMetrics(
            hasNotch: realMetrics.hasNotch,
            notchWidth: realMetrics.notchWidth / NotchLayout.scale,
            notchHeight: realMetrics.notchHeight / NotchLayout.scale
        )
        return AppContentView(metrics: metrics, showsPin: true)
            .padding(.horizontal, (NotchLayout.ear + 10) / NotchLayout.scale)
            .padding(.bottom, 14)
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
