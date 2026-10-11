import AppKit
import Combine
import SwiftUI
import LectureRecorderCore

struct ThemePalette: Identifiable, Equatable {
    let id: String
    let name: String
    let accent: Color
    let accentAlt: Color
    let surface: Color
    let surfaceElevated: Color

    static let customID = "custom"

    /// All presets stay dark — the notch itself is always black to blend with the hardware.
    static let presets: [ThemePalette] = [
        ThemePalette(
            id: "tephra", name: "Tephra",
            accent: Color(red: 0.16, green: 0.92, blue: 0.85), accentAlt: Color(red: 0.58, green: 0.48, blue: 1.0),
            surface: Color(red: 0.075, green: 0.085, blue: 0.105), surfaceElevated: Color(red: 0.105, green: 0.12, blue: 0.145)
        ),
        ThemePalette(
            id: "ember", name: "Ember",
            accent: Color(red: 1.0, green: 0.55, blue: 0.25), accentAlt: Color(red: 1.0, green: 0.34, blue: 0.45),
            surface: Color(red: 0.105, green: 0.082, blue: 0.075), surfaceElevated: Color(red: 0.145, green: 0.108, blue: 0.098)
        ),
        ThemePalette(
            id: "aurora", name: "Aurora",
            accent: Color(red: 0.45, green: 0.95, blue: 0.55), accentAlt: Color(red: 0.35, green: 0.75, blue: 1.0),
            surface: Color(red: 0.072, green: 0.095, blue: 0.09), surfaceElevated: Color(red: 0.098, green: 0.13, blue: 0.122)
        ),
        ThemePalette(
            id: "ocean", name: "Ocean",
            accent: Color(red: 0.35, green: 0.65, blue: 1.0), accentAlt: Color(red: 0.3, green: 0.9, blue: 0.9),
            surface: Color(red: 0.07, green: 0.085, blue: 0.12), surfaceElevated: Color(red: 0.095, green: 0.115, blue: 0.165)
        ),
        ThemePalette(
            id: "sakura", name: "Sakura",
            accent: Color(red: 1.0, green: 0.55, blue: 0.75), accentAlt: Color(red: 0.78, green: 0.6, blue: 1.0),
            surface: Color(red: 0.105, green: 0.078, blue: 0.095), surfaceElevated: Color(red: 0.145, green: 0.105, blue: 0.128)
        ),
        ThemePalette(
            id: "amber", name: "Amber",
            accent: Color(red: 0.95, green: 0.8, blue: 0.4), accentAlt: Color(red: 0.85, green: 0.55, blue: 0.35),
            surface: Color(red: 0.1, green: 0.092, blue: 0.075), surfaceElevated: Color(red: 0.138, green: 0.126, blue: 0.1)
        ),
        ThemePalette(
            id: "mono", name: "Mono",
            accent: Color(red: 0.92, green: 0.93, blue: 0.95), accentAlt: Color(red: 0.6, green: 0.62, blue: 0.66),
            surface: Color(red: 0.08, green: 0.08, blue: 0.085), surfaceElevated: Color(red: 0.115, green: 0.115, blue: 0.122)
        )
    ]

    static var fallback: ThemePalette { presets[0] }

    /// A neutral dark surface lightly tinted with the user's chosen accent.
    static func custom(accent: Color, accentAlt: Color) -> ThemePalette {
        let ns = NSColor(accent).usingColorSpace(.sRGB) ?? NSColor.systemTeal
        let r = Double(ns.redComponent), g = Double(ns.greenComponent), b = Double(ns.blueComponent)
        func tint(_ base: Double, _ channel: Double, _ amount: Double) -> Double { min(1, base + channel * amount) }
        return ThemePalette(
            id: customID, name: "Custom",
            accent: accent, accentAlt: accentAlt,
            surface: Color(red: tint(0.07, r, 0.045), green: tint(0.075, g, 0.045), blue: tint(0.09, b, 0.045)),
            surfaceElevated: Color(red: tint(0.1, r, 0.07), green: tint(0.108, g, 0.07), blue: tint(0.128, b, 0.07))
        )
    }
}

/// Read from every view via `Theme`; mutated only on the main thread by `ThemeStore`.
enum ThemeState {
    nonisolated(unsafe) static var palette = ThemePalette.fallback
}

extension Color {
    init?(hex: String?) {
        guard var s = hex?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return String(
            format: "#%02X%02X%02X",
            Int((ns.redComponent * 255).rounded()),
            Int((ns.greenComponent * 255).rounded()),
            Int((ns.blueComponent * 255).rounded())
        )
    }
}

/// Keeps `ThemeState` in sync with the saved settings and tells the UI to redraw.
@MainActor
final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    /// Bumped on every change; the notch rebuilds its content when this changes.
    @Published private(set) var revision = 0
    @Published private(set) var palette = ThemePalette.fallback

    private var cancellable: AnyCancellable?

    func bind(to settings: SettingsStore) {
        apply(settings.settings)
        cancellable = settings.$settings
            .map { ($0.themeID, $0.customAccentHex, $0.customAccentAltHex) }
            .removeDuplicates { $0 == $1 }
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                // `$settings` fires before the stored value updates, so read it next turn.
                DispatchQueue.main.async { self.apply(settings.settings) }
            }
    }

    private func apply(_ settings: AppSettings) {
        let next: ThemePalette
        if settings.themeID == ThemePalette.customID {
            next = .custom(
                accent: Color(hex: settings.customAccentHex) ?? ThemePalette.fallback.accent,
                accentAlt: Color(hex: settings.customAccentAltHex) ?? ThemePalette.fallback.accentAlt
            )
        } else {
            next = ThemePalette.presets.first { $0.id == settings.themeID } ?? .fallback
        }
        guard next != ThemeState.palette else { return }
        ThemeState.palette = next
        palette = next
        revision += 1
    }
}
