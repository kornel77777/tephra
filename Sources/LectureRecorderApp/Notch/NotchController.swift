import AppKit
import SwiftUI
import LectureRecorderCore

/// Borderless, non-activating panel that floats above the menu bar. It stays
/// on screen the whole time (transparent + click-through while collapsed) so
/// the SwiftUI content can animate between the two states.
final class NotchPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class NotchController {
    private let env: AppEnvironment
    private let vm = NotchViewModel()
    private let panel = NotchPanel()

    private var screen: NSScreen
    private var monitors: [Any] = []
    private var dwellWork: DispatchWorkItem?
    private var collapseTimer: Timer?
    private var outsideSince: Date?
    private var mouseDownPasteboardCount = 0

    init(env: AppEnvironment) {
        self.env = env
        screen = NSScreen.screens.first(where: \.hasNotch) ?? NSScreen.main ?? NSScreen.screens[0]

        let root = NotchRootView(vm: vm)
            .environmentObject(env.settings)
            .environmentObject(env.library)
            .environmentObject(env.queue)
            .environmentObject(env.recorder)
            .environmentObject(env.processor)
            .environmentObject(env.recordingViewModel)
            .environmentObject(vm)
            .preferredColorScheme(.dark)

        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []
        panel.contentView = hosting
    }

    func start() {
        vm.metrics = screen.notchMetrics
        reposition()
        panel.orderFrontRegardless()
        installMonitors()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenParametersChanged() }
        }

        peek()
    }

    /// Opens the notch for a few seconds so the user can see where it lives
    /// (on launch, and when the app is opened again from Finder/Spotlight).
    func peek() {
        vm.isPinned = true
        expand(on: screen)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.vm.isPinned = false
        }
    }

    // MARK: - Expand / collapse

    private func expand(on target: NSScreen) {
        guard !vm.isExpanded else { return }
        screen = target
        vm.metrics = target.notchMetrics
        reposition()
        panel.ignoresMouseEvents = false
        vm.isExpanded = true
        startCollapseTimer()
    }

    private func collapse() {
        guard vm.isExpanded else { return }
        vm.isExpanded = false
        collapseTimer?.invalidate()
        collapseTimer = nil
        outsideSince = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, !self.vm.isExpanded else { return }
            self.panel.ignoresMouseEvents = true
        }
    }

    private func reposition() {
        let size = NotchLayout.windowSize
        let frame = screen.frame
        panel.setFrame(
            NSRect(
                x: frame.midX - size.width / 2,
                y: frame.maxY - size.height,
                width: size.width,
                height: size.height
            ),
            display: false
        )
    }

    private func screenParametersChanged() {
        let home = NSScreen.screens.first(where: \.hasNotch) ?? NSScreen.main ?? NSScreen.screens[0]
        if !NSScreen.screens.contains(screen) { screen = home }
        vm.metrics = screen.notchMetrics
        reposition()
    }

    // MARK: - Hover detection

    private func installMonitors() {
        let masks: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown]

        if let global = NSEvent.addGlobalMonitorForEvents(matching: masks, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: masks, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
            return event
        }) {
            monitors.append(local)
        }
    }

    private func handle(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            mouseDownPasteboardCount = NSPasteboard(name: .drag).changeCount
        }
        guard !vm.isExpanded else { return }

        let mouse = NSEvent.mouseLocation
        guard let target = NSScreen.screens.first(where: { $0.frame.insetBy(dx: 0, dy: -1).contains(mouse) }) else {
            cancelDwell()
            return
        }

        let buttonDown = NSEvent.pressedMouseButtons != 0
        let draggingFiles = buttonDown && isFileDragInProgress
        let allowed = !buttonDown || draggingFiles

        if allowed, isInHotZone(mouse, on: target) {
            if dwellWork == nil {
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.dwellWork = nil
                    self.expand(on: target)
                }
                dwellWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + (draggingFiles ? 0.05 : 0.12), execute: work)
            }
        } else {
            cancelDwell()
        }
    }

    private func cancelDwell() {
        dwellWork?.cancel()
        dwellWork = nil
    }

    private func isInHotZone(_ point: NSPoint, on screen: NSScreen) -> Bool {
        let metrics = screen.notchMetrics
        let width = max(metrics.notchWidth + 8, 140)
        let frame = screen.frame
        return point.y >= frame.maxY - 3 && abs(point.x - frame.midX) <= width / 2
    }

    /// A file is being dragged if the drag pasteboard changed since the button
    /// went down and now holds file URLs (dragging a window never touches it).
    private var isFileDragInProgress: Bool {
        let pasteboard = NSPasteboard(name: .drag)
        return pasteboard.changeCount != mouseDownPasteboardCount
            && pasteboard.types?.contains(.fileURL) == true
    }

    // MARK: - Auto-collapse

    private func startCollapseTimer() {
        collapseTimer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.collapseTick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        collapseTimer = timer
    }

    private func collapseTick() {
        guard vm.isExpanded, !vm.isPinned else {
            outsideSince = nil
            return
        }

        let mouse = NSEvent.mouseLocation
        let size = NotchLayout.expandedSize
        let frame = screen.frame
        let interactive = NSRect(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height,
            width: size.width,
            height: size.height + 40
        ).insetBy(dx: -18, dy: -18)

        if interactive.contains(mouse) || hasTransientUI || isFileDragInProgress && NSEvent.pressedMouseButtons != 0 {
            outsideSince = nil
            return
        }

        if let since = outsideSince {
            if Date().timeIntervalSince(since) > 0.45 { collapse() }
        } else {
            outsideSince = Date()
        }
    }

    /// Menus, popovers, sheets and open panels all live in their own windows;
    /// while one is up the mouse is allowed to wander off without closing the notch.
    private var hasTransientUI: Bool {
        if panel.attachedSheet != nil { return true }
        return NSApp.windows.contains { $0 !== panel && $0.isVisible }
    }
}
