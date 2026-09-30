import AppKit
import Carbon.HIToolbox

/// A key combo like ⌃⌥⌘L, saved in UserDefaults.
struct Shortcut: Codable {
    var keyCode: UInt16
    var key: String
    var modifiers: UInt

    static let standard = Shortcut(
        keyCode: UInt16(kVK_ANSI_L), key: "l",
        modifiers: NSEvent.ModifierFlags([.control, .option, .command]).rawValue)

    /// Nil unless the key press includes ⌘, ⌥ or ⌃, so plain typing can't become a shortcut.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        guard !flags.isDisjoint(with: [.control, .option, .command]),
              let key = event.charactersIgnoringModifiers?.lowercased(), !key.isEmpty
        else { return nil }
        self.init(keyCode: event.keyCode, key: key, modifiers: flags.rawValue)
    }

    init(keyCode: UInt16, key: String, modifiers: UInt) {
        self.keyCode = keyCode
        self.key = key
        self.modifiers = modifiers
    }

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    private static let defaultsKey = "shortcut"

    static func load() -> Shortcut {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let saved = try? JSONDecoder().decode(Shortcut.self, from: data)
        else { return .standard }
        return saved
    }

    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }
}

/// Listens for one shortcut system-wide. Carbon hot keys need no Accessibility permission.
@MainActor
final class GlobalHotKey {
    private var ref: EventHotKeyRef?
    private static var onPress: () -> Void = {}

    init(onPress: @escaping () -> Void) {
        Self.onPress = onPress
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { GlobalHotKey.onPress() }
            return noErr
        }, 1, &pressed, nil, nil)
    }

    func register(_ shortcut: Shortcut) {
        unregister()
        let id = EventHotKeyID(signature: OSType(0x4C_43_57_4B), id: 1)  // "LCWK"
        RegisterEventHotKey(UInt32(shortcut.keyCode), shortcut.carbonModifiers, id,
                            GetApplicationEventTarget(), 0, &ref)
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }
}

/// A small floating window that records the next key combo.
/// It takes key presses without pulling the app to the front, which macOS often refuses for menu bar apps.
@MainActor
final class ShortcutRecorder {
    private final class KeyPanel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    private let panel = KeyPanel(
        contentRect: NSRect(x: 0, y: 0, width: 300, height: 90),
        styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
    private var monitor: Any?

    init() {
        let label = NSTextField(labelWithString: "Press the new shortcut\nInclude ⌘, ⌥ or ⌃  ·  Esc to cancel")
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 25, width: 300, height: 40)
        panel.contentView?.addSubview(label)
        panel.title = "Change Shortcut"
        panel.level = .floating
        panel.hidesOnDeactivate = false
    }

    /// Calls `done` with the new shortcut, or nil if Esc was pressed.
    func record(_ done: @escaping (Shortcut?) -> Void) {
        finish()
        panel.center()
        panel.makeKeyAndOrderFront(nil)

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let pressed = Shortcut(event: event)
            if pressed != nil || event.keyCode == UInt16(kVK_Escape) {
                self?.finish()
                done(pressed)
            }
            return nil
        }
    }

    private func finish() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        panel.orderOut(nil)
    }
}
