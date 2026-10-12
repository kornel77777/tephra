import AppKit
import Combine
import LectureRecorderCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var env: AppEnvironment!
    private var notch: NotchController!
    private var window: WindowController!
    private var mode: UIMode = .notch
    private var settingsObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMainMenu()

        let env = AppEnvironment()
        self.env = env
        notch = NotchController(env: env)
        window = WindowController(env: env)

        notch.start()
        env.processor.start()
        env.shortcuts.onAction = { [weak self] action in self?.perform(action) }
        env.shortcuts.start()

        applyMode(force: true)
        settingsObserver = env.settings.$settings
            .map(\.uiMode)
            .removeDuplicates()
            .sink { [weak self] _ in
                // `$settings` fires before the new value is stored.
                DispatchQueue.main.async { self?.applyMode(force: false) }
            }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        reveal()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Quitting mid-recording would strand the audio, so refuse and show the controls instead.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard env.recorder.state != .idle else { return .terminateNow }
        env.recordingViewModel.lastError = "Stop the recording before quitting."
        reveal()
        return .terminateCancel
    }

    // MARK: - Mode

    private func applyMode(force: Bool) {
        let next = UIMode(settings: env.settings.settings)
        guard force || next != mode else { return }
        mode = next

        switch next {
        case .notch:
            window.hide()
            NSApp.setActivationPolicy(.accessory)
            notch.setActive(true)
            notch.peek()
        case .window:
            notch.setActive(false)
            NSApp.setActivationPolicy(.regular)
            window.show()
        }
    }

    /// Brings the UI into view in whichever mode is active.
    private func reveal() {
        switch mode {
        case .notch: notch.peek()
        case .window: window.show()
        }
    }

    // MARK: - Keyboard shortcuts

    private func perform(_ action: ShortcutAction) {
        switch action {
        case .open:
            switch mode {
            case .notch: notch.toggleOpen()
            case .window: window.toggle()
            }
        case .record:
            toggleRecording()
        case .pause:
            togglePause()
        }
    }

    private func toggleRecording() {
        let recorder = env.recorder
        let model = env.recordingViewModel

        switch recorder.state {
        case .idle:
            guard model.selectedSubjectCode != nil else {
                model.lastError = "Pick a subject first, then start recording."
                reveal()
                return
            }
            model.lastError = nil
            NSSound(named: "Tink")?.play()
            model.start(recorder: recorder, settings: env.settings)
            if recorder.state == .idle { reveal() }
        case .recording, .paused:
            NSSound(named: "Pop")?.play()
            model.stopAndEnqueue(recorder: recorder, library: env.library, queue: env.queue, settings: env.settings)
        }
    }

    private func togglePause() {
        let recorder = env.recorder
        switch recorder.state {
        case .recording:
            recorder.pause()
            NSSound(named: "Morse")?.play()
        case .paused:
            try? recorder.resume()
            NSSound(named: "Morse")?.play()
        case .idle:
            break
        }
    }

    // MARK: - Menu

    /// Without a main menu, ⌘C/⌘V/⌘Q don't work in an app that has no Dock presence.
    private func installMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Tephra", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit

        let windowItem = NSMenuItem()
        main.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = main
    }
}
