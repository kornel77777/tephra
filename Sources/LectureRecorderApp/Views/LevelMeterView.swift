import SwiftUI

struct LevelMeterView: View {
    let level: Float // 0...1

    private var gradient: LinearGradient {
        LinearGradient(
            colors: level > 0.85
                ? [Theme.warning, Theme.danger]
                : [Theme.accentAlt, Theme.accent],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surface)
                Capsule()
                    .strokeBorder(Theme.border, lineWidth: 1)
                Capsule()
                    .fill(gradient)
                    .frame(width: max(4, proxy.size.width * CGFloat(min(1, level))))
                    .glow(level > 0.85 ? Theme.danger : Theme.accent, radius: 6, active: level > 0.03)
                    .animation(.linear(duration: 0.08), value: level)
            }
        }
        .frame(height: 8)
    }
}
