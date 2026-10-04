import AppKit

// The whole UI lives in the notch panel, so there's no SwiftUI App/scene —
// that would open an empty window.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
