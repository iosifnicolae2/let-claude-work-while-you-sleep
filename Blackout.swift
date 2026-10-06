import AppKit
import IOKit.pwr_mgt

/// "Screens off" without the Mac locking: turns the external screens off (no signal, so each monitor goes to its
/// own standby) and keeps one screen on, black and dimmed to zero, to hold the windows and the Dock: the built-in,
/// else the main one. A screen macOS won't turn off is covered the same way. Virtual displays stay on, so apps
/// using them keep working. Keeps the displays awake. Calls `onUserReturn` on the first mouse move or key press.
@MainActor
final class Blackout {
    private static let turnedOffKey = "turnedOffDisplays"
    private let onUserReturn: () -> Void
    private var windows: [(display: CGDirectDisplayID, window: NSWindow)] = []
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
        let physical = Displays.physical()
        let kept = physical.first { CGDisplayIsBuiltin($0) != 0 } ?? physical.first { $0 == CGMainDisplayID() }
        let off = turnOff(physical.filter { $0 != kept })
        let lit = physical.filter { !off.contains($0) }
        windows = lit.map { ($0, blackWindow(on: $0)) }
        NSCursor.setHiddenUntilMouseMoves(true)
        dim(lit)
        shownAt = Date()
        inputWatch = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.fitWindows()
                self?.checkForUserInput()
            }
        }
    }

    func hide() {
        inputWatch?.invalidate()
        inputWatch = nil
        windows.forEach { $0.window.orderOut(nil) }
        windows = []
        restoreBrightness()
        Self.turnBackOn()
        if displayBlock != 0 {
            IOPMAssertionRelease(displayBlock)
            displayBlock = 0
        }
    }

    /// Turns on the screens a previous run left off, if it ended without `hide` (a crash or a forced quit).
    static func turnBackOn() {
        let saved = UserDefaults.standard.array(forKey: turnedOffKey) as? [UInt32] ?? []
        Displays.setEnabled(saved, true)
        UserDefaults.standard.removeObject(forKey: turnedOffKey)
    }

    /// Notes the screens before turning them off, so the next launch can turn them on if this one dies.
    private func turnOff(_ displays: [CGDirectDisplayID]) -> [CGDirectDisplayID] {
        UserDefaults.standard.set(displays, forKey: Self.turnedOffKey)
        let off = Displays.setEnabled(displays, false)
        UserDefaults.standard.set(off, forKey: Self.turnedOffKey)
        return off
    }

    /// Asks how long since the last input, so no Accessibility permission is needed. Only hardware input
    /// counts: events other apps post, and the ones macOS posts when screens turn off, don't.
    private func checkForUserInput() {
        let anyInput = CGEventType(rawValue: ~0)!
        let idle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInput)
        if idle < Date().timeIntervalSince(shownAt) {
            onUserReturn()
        }
    }

    private func blackWindow(on display: CGDirectDisplayID) -> NSWindow {
        let frame = Displays.frame(of: display)
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.backgroundColor = .black
        window.level = NSWindow.Level(Int(CGShieldingWindowLevel()))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.setFrame(frame, display: true)
        window.orderFrontRegardless()
        return window
    }

    /// The screens move as the others turn off, so each black window follows its screen.
    private func fitWindows() {
        for (display, window) in windows where window.frame != Displays.frame(of: display) {
            window.setFrame(Displays.frame(of: display), display: true)
        }
    }

    private func dim(_ displays: [CGDirectDisplayID]) {
        for display in displays {
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
