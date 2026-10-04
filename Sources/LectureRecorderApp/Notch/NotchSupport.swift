import AppKit
import SwiftUI

enum NotchTab: String, CaseIterable, Identifiable {
    case record, library, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .record: return "Record"
        case .library: return "Library"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .record: return "waveform.circle.fill"
        case .library: return "square.stack.3d.up.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
}

struct NotchMetrics: Equatable {
    var hasNotch: Bool
    var notchWidth: CGFloat
    var notchHeight: CGFloat

    static let none = NotchMetrics(hasNotch: false, notchWidth: 0, notchHeight: 0)
}

enum NotchLayout {
    static let expandedSize = CGSize(width: 680, height: 340)
    /// Transparent margin around the shape so its shadow isn't clipped by the window.
    static let windowPadding: CGFloat = 32
    static let ear: CGFloat = 12

    static var windowSize: CGSize {
        CGSize(
            width: expandedSize.width + windowPadding * 2,
            height: expandedSize.height + windowPadding
        )
    }
}

extension NSScreen {
    var hasNotch: Bool { safeAreaInsets.top > 0 }

    var notchMetrics: NotchMetrics {
        guard hasNotch, let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea else {
            return .none
        }
        return NotchMetrics(
            hasNotch: true,
            notchWidth: frame.width - left.width - right.width,
            notchHeight: safeAreaInsets.top
        )
    }
}

/// Black shape that hangs from the top edge of the screen. The small "ears" at
/// the top flare outward so it melts into the menu bar the way the hardware notch does.
struct NotchShape: Shape {
    var ear: CGFloat = NotchLayout.ear
    var bottomRadius: CGFloat

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let e = min(ear, rect.width / 4)
        let r = max(0, min(bottomRadius, (rect.width - 2 * e) / 2, rect.height - e))

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + e, y: rect.minY + e),
            control: CGPoint(x: rect.minX + e, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + e, y: rect.maxY - r))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + e + r, y: rect.maxY),
            control: CGPoint(x: rect.minX + e, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - e - r, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - e, y: rect.maxY - r),
            control: CGPoint(x: rect.maxX - e, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - e, y: rect.minY + e))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - e, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

/// Left-to-right wrapping layout, used for the subject chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

@MainActor
final class NotchViewModel: ObservableObject {
    @Published var isExpanded = false
    @Published var isPinned = false
    @Published var tab: NotchTab = .record
    @Published var metrics: NotchMetrics = .none
}
