import AppKit

// Native macOS process entry runs on the main thread; keep all AppKit state isolated there.
MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
}
