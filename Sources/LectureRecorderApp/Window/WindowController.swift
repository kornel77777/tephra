import AppKit
import SwiftUI
import LectureRecorderCore

enum UIMode: String {
    case notch, window

    init(settings: AppSettings) {
        self = UIMode(rawValue: settings.uiMode ?? "") ?? .notch
    }
}

private struct WindowRootView: View {
    @EnvironmentObject private var themeStore: ThemeStore

    var body: some View {
        AppContentView(metrics: .none, showsPin: false)
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .id(themeStore.revision)
            .preferredColorScheme(.dark)
    }
}

/// The non-notch way to use the app: the same tabs in an ordinary window.
@MainActor
final class WindowController {
    private let window: NSWindow

    init(env: AppEnvironment) {
        let root = WindowRootView()
            .environmentObject(env.settings)
            .environmentObject(env.library)
            .environmentObject(env.queue)
            .environmentObject(env.recorder)
            .environmentObject(env.processor)
            .environmentObject(env.recordingViewModel)
            .environmentObject(env.notchVM)
            .environmentObject(ThemeStore.shared)
            .environmentObject(env.shortcuts)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Tephra"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentMinSize = NSSize(width: 660, height: 380)
        window.contentView = NSHostingView(rootView: root)
        window.setFrameAutosaveName("TephraMainWindow")
        if !window.setFrameUsingName("TephraMainWindow") { window.center() }
    }

    var isFrontmost: Bool { window.isVisible && NSApp.isActive }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func hide() {
        window.orderOut(nil)
    }

    func toggle() {
        isFrontmost ? hide() : show()
    }
}
