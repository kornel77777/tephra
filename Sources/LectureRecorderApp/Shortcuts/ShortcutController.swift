import AppKit
import Combine
import CoreGraphics
import LectureRecorderCore

enum ShortcutAction: String, CaseIterable, Identifiable {
    case open, record, pause

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open: return "Open / close"
        case .record: return "Start / stop recording"
        case .pause: return "Pause / resume"
        }
    }

    var defaultModifier: ShortcutModifier {
        switch self {
        case .open: return .option
        case .record: return .control
        case .pause: return .shift
        }
    }
}

extension AppSettings {
    private func stored(for action: ShortcutAction) -> String? {
        switch action {
        case .open: return shortcutOpen
        case .record: return shortcutRecord
        case .pause: return shortcutPause
        }
    }

    /// nil means the shortcut is switched off.
    func modifier(for action: ShortcutAction) -> ShortcutModifier? {
        guard let value = stored(for: action) else { return action.defaultModifier }
        return ShortcutModifier(rawValue: value)
    }

    mutating func setModifier(_ modifier: ShortcutModifier?, for action: ShortcutAction) {
        let value = modifier?.rawValue ?? "off"
        switch action {
        case .open: shortcutOpen = value
        case .record: shortcutRecord = value
        case .pause: shortcutPause = value
        }
    }
}

/// Watches for double-tapped modifier keys system-wide. macOS only delivers
/// other apps' key events to apps with the Input Monitoring permission, so
/// `hasAccess` drives the status shown in Settings.
@MainActor
final class ShortcutController: ObservableObject {
    @Published private(set) var hasAccess = CGPreflightListenEventAccess()

    var onAction: ((ShortcutAction) -> Void)?

    private let settings: SettingsStore
    private var detector = ModifierTapDetector()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var monitorHasAccess = false
    private var timer: Timer?

    private static let requestedKey = "tephra.requestedInputMonitoring"

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func start() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
            return event
        }

        if !CGPreflightListenEventAccess(), !UserDefaults.standard.bool(forKey: Self.requestedKey) {
            UserDefaults.standard.set(true, forKey: Self.requestedKey)
            CGRequestListenEventAccess()
        }

        refreshAccess()
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAccess() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Shows the system prompt (first time) and opens the right Settings pane.
    func requestAccess() {
        CGRequestListenEventAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    /// A monitor created before the permission was granted never starts receiving
    /// events, so it is rebuilt the moment access appears.
    private func refreshAccess() {
        let access = CGPreflightListenEventAccess()
        if access != hasAccess { hasAccess = access }

        if access, !monitorHasAccess {
            if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
                MainActor.assumeIsolated { self?.handle(event) }
            }
            monitorHasAccess = true
        } else if !access {
            monitorHasAccess = false
        }
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            detector.keyPressed()
        case .flagsChanged:
            guard let modifier = detector.flagsChanged(
                keyCode: event.keyCode,
                flags: event.modifierFlags,
                time: event.timestamp
            ) else { return }
            if let action = ShortcutAction.allCases.first(where: { settings.settings.modifier(for: $0) == modifier }) {
                onAction?(action)
            }
        default:
            break
        }
    }
}
