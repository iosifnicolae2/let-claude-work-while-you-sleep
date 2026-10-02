import AppKit
import IOKit.pwr_mgt

/// "Screens off" without really turning them off, so macOS never locks the Mac:
/// keeps the displays awake, covers them in black and dims them to zero.
/// Calls `onUserReturn` on the first mouse move or key press.
@MainActor
final class Blackout {
    private let onUserReturn: () -> Void
    private var windows: [NSWindow] = []
    private var savedBrightness: [CGDirectDisplayID: Float] = [:]
    private var displayBlock: IOPMAssertionID = 0
    private var inputWatch: Timer?
    private var shownAt = Date()

    init(onUserReturn: @escaping () -> Void) {
        self.onUserReturn = onUserReturn
    }

    func show() {
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Let Claude Work: screens dark but awake, so the Mac doesn't lock" as CFString,
            &displayBlock)
        windows = NSScreen.screens.map(blackWindow)
        NSCursor.setHiddenUntilMouseMoves(true)
        dimAllDisplays()
        shownAt = Date()
        inputWatch = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkForUserInput() }
        }
    }

    func hide() {
        inputWatch?.invalidate()
        inputWatch = nil
        windows.forEach { $0.orderOut(nil) }
        windows = []
        restoreBrightness()
        if displayBlock != 0 {
            IOPMAssertionRelease(displayBlock)
            displayBlock = 0
        }
    }

    /// Asks the system how long since the last input, so no Accessibility permission is needed.
    private func checkForUserInput() {
        let anyInput = CGEventType(rawValue: ~0)!
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        if idle < Date().timeIntervalSince(shownAt) {
            onUserReturn()
        }
    }

    private func blackWindow(on screen: NSScreen) -> NSWindow {
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.backgroundColor = .black
        window.level = NSWindow.Level(Int(CGShieldingWindowLevel()))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
        return window
    }

    private func dimAllDisplays() {
        for display in activeDisplays() {
            guard let brightness = Brightness.get(display) else { continue }
            savedBrightness[display] = brightness
            Brightness.set(display, 0)
        }
    }

    private func restoreBrightness() {
        for (display, brightness) in savedBrightness {
            Brightness.set(display, brightness)
        }
        savedBrightness = [:]
    }

    private func activeDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &displays, &count)
        return displays
    }
}

/// Screen brightness through Apple's private DisplayServices framework (what the brightness keys use).
/// Works for built-in and Apple-compatible displays; others return nil and are skipped.
private enum Brightness {
    private typealias GetFunction = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFunction = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let framework = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
    private static let getFunction = load("DisplayServicesGetBrightness", as: GetFunction.self)
    private static let setFunction = load("DisplayServicesSetBrightness", as: SetFunction.self)

    private static func load<T>(_ name: String, as type: T.Type) -> T? {
        guard let symbol = dlsym(framework, name) else { return nil }
        return unsafeBitCast(symbol, to: type)
    }

    static func get(_ display: CGDirectDisplayID) -> Float? {
        var brightness: Float = 0
        guard getFunction?(display, &brightness) == 0 else { return nil }
        return brightness
    }

    static func set(_ display: CGDirectDisplayID, _ brightness: Float) {
        _ = setFunction?(display, brightness)
    }
}
