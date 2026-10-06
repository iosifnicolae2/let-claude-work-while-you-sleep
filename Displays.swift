import AppKit
import IOKit

/// Which displays are real screens, and turning a real screen off and on the way macOS does when one is
/// unplugged: no signal, so the monitor goes to its own standby (its buttons keep working).
/// Virtual displays (screen sharing, BetterDisplay, test displays) have no hardware behind them.
enum Displays {
    static func active() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &displays, &count)
        return Array(displays.prefix(Int(count)))
    }

    static func physical() -> [CGDirectDisplayID] {
        let screens = hardwareScreens()
        return active().filter { display in
            CGDisplayIsBuiltin(display) != 0 || screens.contains { screen in
                screen.vendor == CGDisplayVendorNumber(display)
                    && (screen.serial == nil || screen.serial == CGDisplaySerialNumber(display))
            }
        }
    }

    /// Turns each display off or on, one at a time (macOS may refuse one); returns those it changed.
    /// macOS keeps a display off even after this app quits, so every way out must turn it back on.
    @discardableResult
    static func setEnabled(_ displays: [CGDirectDisplayID], _ enabled: Bool) -> [CGDirectDisplayID] {
        guard let configureEnabled else { return [] }
        return displays.filter { display in
            var config: CGDisplayConfigRef?
            guard CGBeginDisplayConfiguration(&config) == .success else { return false }
            guard configureEnabled(config, display, enabled) == .success else {
                CGCancelDisplayConfiguration(config)
                return false
            }
            return CGCompleteDisplayConfiguration(config, .forSession) == .success
        }
    }

    /// A display's frame in AppKit's coordinates, current even while the layout is changing.
    static func frame(of display: CGDirectDisplayID) -> NSRect {
        let bounds = CGDisplayBounds(display)
        let mainHeight = CGDisplayBounds(CGMainDisplayID()).height
        return NSRect(x: bounds.minX, y: mainHeight - bounds.maxY, width: bounds.width, height: bounds.height)
    }

    // SkyLight's private call behind "disconnect display" in BetterDisplay.
    private typealias ConfigureEnabled = @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> CGError
    private static let configureEnabled = dlsym(
        dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY), "SLSConfigureDisplayEnabled"
    ).map { unsafeBitCast($0, to: ConfigureEnabled.self) }

    /// Vendor and serial of every real screen, as the graphics hardware (IOKit) sees them.
    private static func hardwareScreens() -> [(vendor: UInt32, serial: UInt32?)] {
        var screens: [(vendor: UInt32, serial: UInt32?)] = []
        each("IOMobileFramebuffer") { service in  // Apple silicon
            guard let attributes = property(service, "DisplayAttributes") as? [String: Any],
                  let product = attributes["ProductAttributes"] as? [String: Any],
                  let vendor = (product["LegacyManufacturerID"] as? NSNumber)?.uint32Value else { return }
            screens.append((vendor, (product["SerialNumber"] as? NSNumber)?.uint32Value))
        }
        each("IODisplayConnect") { service in  // Intel
            guard let vendor = (property(service, "DisplayVendorID") as? NSNumber)?.uint32Value else { return }
            screens.append((vendor, (property(service, "DisplaySerialNumber") as? NSNumber)?.uint32Value))
        }
        return screens
    }

    private static func each(_ serviceClass: String, _ body: (io_service_t) -> Void) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(serviceClass), &iterator) == KERN_SUCCESS
        else { return }
        while case let service = IOIteratorNext(iterator), service != 0 {
            body(service)
            IOObjectRelease(service)
        }
        IOObjectRelease(iterator)
    }

    private static func property(_ service: io_service_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
