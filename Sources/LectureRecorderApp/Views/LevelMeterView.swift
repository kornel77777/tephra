import SwiftUI

struct LevelMeterView: View {
    let level: Float // 0...1

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                RoundedRectangle(cornerRadius: 4)
                    .fill(level > 0.85 ? Color.red : Color.green)
                    .frame(width: proxy.size.width * CGFloat(min(1, level)))
                    .animation(.linear(duration: 0.08), value: level)
            }
        }
        .frame(height: 10)
    }
}
