import Foundation
import IOKit.hid

/// Watches raw HID key presses so the deck can tell which keyboard a keycode came from.
/// The CGEvent tap has no notion of device; this runs on its own thread (one hop shorter
/// than the WindowServer path) and records the last device that pressed each usage.
/// Needs Input Monitoring; without it, device-bound keys simply never match.
final class NumpadHID {
    static let shared = NumpadHID()

    struct Press { let device: String; let time: TimeInterval }

    private var manager: IOHIDManager?
    private var thread: Thread?
    private var lock = os_unfair_lock()
    private var presses: [UInt32: Press] = [:]       // HID usage → last press
    private(set) var devices: [String: String] = [:] // "vendor:product" → product name

    private init() {}

    func start() {
        guard thread == nil else { return }
        let t = Thread { [weak self] in
            guard let self else { return }
            let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
            let match: [[String: Any]] = [
                [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard],
                [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keypad],
            ]
            IOHIDManagerSetDeviceMatchingMultiple(m, match as CFArray)
            let ctx = Unmanaged.passUnretained(self).toOpaque()
            IOHIDManagerRegisterDeviceMatchingCallback(m, { ctx, _, _, dev in
                guard let ctx else { return }
                Unmanaged<NumpadHID>.fromOpaque(ctx).takeUnretainedValue().noteDevice(dev)
            }, ctx)
            IOHIDManagerRegisterInputValueCallback(m, { ctx, _, _, value in
                guard let ctx else { return }
                let el = IOHIDValueGetElement(value)
                guard IOHIDElementGetUsagePage(el) == UInt32(kHIDPage_KeyboardOrKeypad), IOHIDValueGetIntegerValue(value) != 0 else { return }
                let usage = IOHIDElementGetUsage(el)
                guard usage >= 4 else { return } // 0–3: no event / rollover
                let dev = IOHIDElementGetDevice(el)
                Unmanaged<NumpadHID>.fromOpaque(ctx).takeUnretainedValue().notePress(usage: usage, device: NumpadHID.key(of: dev))
            }, ctx)
            IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDManagerOpen(m, IOOptionBits(kIOHIDOptionsTypeNone))
            self.manager = m
            CFRunLoopRun()
        }
        t.name = "NumpadHID"
        t.qualityOfService = .userInteractive
        thread = t
        t.start()
    }

    static func key(of d: IOHIDDevice) -> String {
        let v = IOHIDDeviceGetProperty(d, kIOHIDVendorIDKey as CFString) as? Int ?? 0
        let p = IOHIDDeviceGetProperty(d, kIOHIDProductIDKey as CFString) as? Int ?? 0
        return String(format: "%04x:%04x", v, p)
    }

    private func noteDevice(_ d: IOHIDDevice) {
        let name = IOHIDDeviceGetProperty(d, kIOHIDProductKey as CFString) as? String ?? "Teclado"
        os_unfair_lock_lock(&lock); devices[Self.key(of: d)] = name; os_unfair_lock_unlock(&lock)
    }

    private func notePress(usage: UInt32, device: String) {
        os_unfair_lock_lock(&lock)
        presses[usage] = Press(device: device, time: Date().timeIntervalSinceReferenceDate)
        os_unfair_lock_unlock(&lock)
    }

    func name(of device: String) -> String? {
        os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
        return devices[device]
    }

    /// Device that pressed `keyCode` in the last `window` seconds. Waits up to `waitUpTo` for the
    /// HID report to land, since the CGEvent tap can occasionally beat it.
    func recentDevice(for keyCode: UInt16, window: TimeInterval = 0.08, waitUpTo: TimeInterval = 0.012) -> String? {
        guard thread != nil, let usage = Self.usageByKeyCode[keyCode] else { return nil }
        let deadline = Date().timeIntervalSinceReferenceDate + waitUpTo
        while true {
            os_unfair_lock_lock(&lock)
            let p = presses[usage]
            os_unfair_lock_unlock(&lock)
            let now = Date().timeIntervalSinceReferenceDate
            if let p, now - p.time <= window { return p.device }
            if now >= deadline { return nil }
            usleep(400)
        }
    }

    /// HID keyboard usage → macOS virtual keycode (ANSI).
    static let keyCodeByUsage: [UInt32: UInt16] = [
        0x04:0,0x05:11,0x06:8,0x07:2,0x08:14,0x09:3,0x0A:5,0x0B:4,0x0C:34,0x0D:38,0x0E:40,0x0F:37,0x10:46,0x11:45,0x12:31,
        0x13:35,0x14:12,0x15:15,0x16:1,0x17:17,0x18:32,0x19:9,0x1A:13,0x1B:7,0x1C:16,0x1D:6,
        0x1E:18,0x1F:19,0x20:20,0x21:21,0x22:23,0x23:22,0x24:26,0x25:28,0x26:25,0x27:29,
        0x28:36,0x29:53,0x2A:51,0x2B:48,0x2C:49,0x2D:27,0x2E:24,0x2F:33,0x30:30,0x31:42,0x33:41,0x34:39,0x35:50,0x36:43,0x37:47,0x38:44,0x39:57,
        0x3A:122,0x3B:120,0x3C:99,0x3D:118,0x3E:96,0x3F:97,0x40:98,0x41:100,0x42:101,0x43:109,0x44:103,0x45:111,
        0x4A:115,0x4B:116,0x4C:117,0x4D:119,0x4E:121,0x4F:124,0x50:123,0x51:125,0x52:126,
        0x53:71,0x54:75,0x55:67,0x56:78,0x57:69,0x58:76,0x59:83,0x5A:84,0x5B:85,0x5C:86,0x5D:87,0x5E:88,0x5F:89,0x60:91,0x61:92,0x62:82,0x63:65,0x67:81,
    ]
    static let usageByKeyCode: [UInt16: UInt32] = Dictionary(keyCodeByUsage.map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
}
