import AppKit
import IOKit.pwr_mgt
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let toggleItem = NSMenuItem(title: "", action: #selector(toggle), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
    private var sleepBlock: IOPMAssertionID = 0
    private var isRunning: Bool { sleepBlock != 0 }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        toggleItem.target = self
        loginItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate), keyEquivalent: "q"))
        statusItem.menu = menu

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(screensWoke),
            name: NSWorkspace.screensDidWakeNotification, object: nil)

        refreshUI()
    }

    @objc private func toggle() {
        isRunning ? stop() : start()
    }

    private func start() {
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Let Claude Work: screens off, Mac stays awake" as CFString,
            &sleepBlock)
        refreshUI()
        // Short pause so the click that opened the menu doesn't wake the screens right away.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { turnScreensOff() }
    }

    private func stop() {
        IOPMAssertionRelease(sleepBlock)
        sleepBlock = 0
        refreshUI()
    }

    @objc private func toggleStartAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSLog("Start at Login failed: \(error)")
        }
        refreshUI()
    }

    @objc private func screensWoke() {
        if isRunning { stop() }
    }

    private func refreshUI() {
        toggleItem.title = isRunning ? "Stop" : "Start (screens off, stay awake)"
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        let symbol = isRunning ? "moon.zzz.fill" : "moon.zzz"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Let Claude Work")
    }
}

private func turnScreensOff() {
    let pmset = Process()
    pmset.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    pmset.arguments = ["displaysleepnow"]
    try? pmset.run()
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
