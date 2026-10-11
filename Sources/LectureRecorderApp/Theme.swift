import SwiftUI
import LectureRecorderCore

/// Always dark regardless of the system appearance, the way most pro audio/creative
/// tools do. Accent and surface colors come from the selected `ThemePalette`.
enum Theme {
    static let background = Color(red: 0.035, green: 0.04, blue: 0.055)
    static let backgroundGradient = LinearGradient(
        colors: [Color(red: 0.05, green: 0.055, blue: 0.075), Color(red: 0.02, green: 0.022, blue: 0.03)],
        startPoint: .top,
        endPoint: .bottom
    )
    static var surface: Color { ThemeState.palette.surface }
    static var surfaceElevated: Color { ThemeState.palette.surfaceElevated }
    static let border = Color.white.opacity(0.09)
    static var borderBright: Color { accent.opacity(0.4) }

    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.5)
    static let textTertiary = Color.white.opacity(0.32)

    static var accent: Color { ThemeState.palette.accent }
    static var accentAlt: Color { ThemeState.palette.accentAlt }
    static let danger = Color(red: 1.0, green: 0.36, blue: 0.42)
    static let warning = Color(red: 1.0, green: 0.72, blue: 0.3)
    static let success = Color(red: 0.3, green: 0.95, blue: 0.75)

    static let cornerRadius: CGFloat = 14
    static let smallCornerRadius: CGFloat = 9
}

/// A translucent, faintly bordered panel — the base building block for every
/// grouped section in this app instead of default Form/List chrome.
struct PanelBackground: ViewModifier {
    var elevated: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(elevated ? Theme.surfaceElevated : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
    }
}

extension View {
    func panel(elevated: Bool = false) -> some View {
        modifier(PanelBackground(elevated: elevated))
    }

    /// A soft colored glow behind the view, used sparingly for active/live state.
    func glow(_ color: Color, radius: CGFloat = 14, active: Bool = true) -> some View {
        shadow(color: active ? color.opacity(0.55) : .clear, radius: radius)
    }
}

/// Pill-shaped control button with an accent-tinted border, used for every
/// primary action (Start/Stop/Pause/Bookmark) in place of the system default.
struct GlowButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var tint: Color = Theme.accent
    var filled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(filled ? tint.opacity(configuration.isPressed ? 0.7 : 0.9) : Theme.surfaceElevated)
            )
            .overlay(
                Capsule().strokeBorder(tint.opacity(filled ? 0 : 0.6), lineWidth: 1.2)
            )
            .foregroundStyle(filled ? Color.black.opacity(0.85) : tint)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.35)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlowButtonStyle {
    static var glow: GlowButtonStyle { GlowButtonStyle() }
    static func glow(tint: Color, filled: Bool = false) -> GlowButtonStyle {
        GlowButtonStyle(tint: tint, filled: filled)
    }
}

/// Small colored status dot + label, used in the Library list.
struct StatusBadge: View {
    let status: TranscriptionStatusDisplay

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 7, height: 7)
                .glow(status.color, radius: 5, active: status.pulsing)
            Text(status.label)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(status.color.opacity(0.12)))
    }
}

struct TranscriptionStatusDisplay {
    let label: String
    let color: Color
    let pulsing: Bool
}

extension TranscriptionStatus {
    var display: TranscriptionStatusDisplay {
        switch self {
        case .recorded: return TranscriptionStatusDisplay(label: "Recorded", color: Theme.textSecondary, pulsing: false)
        case .queued: return TranscriptionStatusDisplay(label: "Queued", color: Theme.warning, pulsing: false)
        case .processing: return TranscriptionStatusDisplay(label: "Processing", color: Theme.accent, pulsing: true)
        case .completed: return TranscriptionStatusDisplay(label: "Completed", color: Theme.success, pulsing: false)
        case .failed: return TranscriptionStatusDisplay(label: "Failed", color: Theme.danger, pulsing: false)
        }
    }
}
