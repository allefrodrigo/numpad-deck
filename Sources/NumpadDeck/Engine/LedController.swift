import AppKit
import IOKit.hid

/// Drives the Num Lock LED on USB HID keyboards via a 1-byte output report (bit0 Num, bit1 Caps, bit2 Scroll).
/// Needs the "Monitoramento de Entrada" (Input Monitoring) permission to open keyboards.
/// `steady` is the resting state; `blink` interrupts it briefly and restores it.
@MainActor
final class LedController: ObservableObject {
    static let shared = LedController()

    @Published private(set) var steady = false
    @Published private(set) var deviceNames: [String] = []
    @Published private(set) var lastError: String = ""
    var hasDevices: Bool { !deviceNames.isEmpty }

    private var manager: IOHIDManager?
    private var opened: [IOHIDDevice] = []
    private var blinkTask: Task<Void, Never>?

    private init() {}

    /// Opens every HID keyboard now and whenever one is plugged in.
    func start() {
        guard manager == nil else { return }
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [[String: Any]] = [
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard],
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keypad],
        ]
        IOHIDManagerSetDeviceMatchingMultiple(m, match as CFArray)
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        let hotplug: IOHIDDeviceCallback = { ctx, _, _, _ in
            guard let ctx else { return }
            let led = Unmanaged<LedController>.fromOpaque(ctx).takeUnretainedValue()
            Task { @MainActor in led.refreshDevices(); led.apply() }
        }
        IOHIDManagerRegisterDeviceMatchingCallback(m, hotplug, ctx)
        IOHIDManagerRegisterDeviceRemovalCallback(m, hotplug, ctx)
        IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let r = IOHIDManagerOpen(m, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = m
        if r != kIOReturnSuccess {
            lastError = "Sem acesso aos teclados. Ative NumpadDeck em Ajustes › Privacidade e Segurança › Monitoramento de Entrada."
        }
        refreshDevices()
    }

    func stop() {
        blinkTask?.cancel()
        write(false)
        opened.forEach { IOHIDDeviceClose($0, IOOptionBits(kIOHIDOptionsTypeNone)) }
        opened = []
        deviceNames = []
        if let m = manager { IOHIDManagerClose(m, IOOptionBits(kIOHIDOptionsTypeNone)) }
        manager = nil
    }

    func refreshDevices() {
        guard let m = manager else { return }
        opened.forEach { IOHIDDeviceClose($0, IOOptionBits(kIOHIDOptionsTypeNone)) }
        opened = []
        let set = IOHIDManagerCopyDevices(m) as? Set<IOHIDDevice> ?? []
        var names: [String] = []
        for d in set {
            // Skip Apple's built-in keyboard: it has no Num Lock LED and we don't want to touch it.
            let vendor = IOHIDDeviceGetProperty(d, kIOHIDVendorIDKey as CFString) as? Int ?? 0
            let transport = IOHIDDeviceGetProperty(d, kIOHIDTransportKey as CFString) as? String ?? ""
            if vendor == 0x05ac || transport.lowercased().contains("spi") { continue }
            guard IOHIDDeviceOpen(d, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else { continue }
            opened.append(d)
            names.append(IOHIDDeviceGetProperty(d, kIOHIDProductKey as CFString) as? String ?? "Teclado")
        }
        deviceNames = names
        if names.isEmpty {
            if lastError.isEmpty { lastError = "Nenhum teclado USB encontrado. Sem a permissão de Monitoramento de Entrada o macOS esconde os teclados." }
        } else {
            lastError = ""
        }
    }

    /// Sets the resting state and writes it unless a blink is in flight.
    func setSteady(_ on: Bool) {
        steady = on
        if blinkTask == nil { write(on) }
    }

    /// Re-sends the resting state (after hot-plug, permission grant…).
    func apply() { if blinkTask == nil { write(steady) } }

    /// Inverts the LED `times` times, then restores `steady`.
    func blink(times: Int = 1, onMs: Int = 90, offMs: Int = 90) {
        guard hasDevices else { return }
        blinkTask?.cancel()
        blinkTask = Task { [weak self] in
            guard let self else { return }
            defer { self.blinkTask = nil; self.write(self.steady) }
            for i in 0..<times {
                self.write(!self.steady)
                try? await Task.sleep(for: .milliseconds(onMs))
                if Task.isCancelled { return }
                self.write(self.steady)
                if i < times - 1 { try? await Task.sleep(for: .milliseconds(offMs)) }
                if Task.isCancelled { return }
            }
        }
    }

    private func write(_ on: Bool) {
        var byte: UInt8 = on ? 0b001 : 0
        var failures = 0
        for d in opened where IOHIDDeviceSetReport(d, kIOHIDReportTypeOutput, 0, &byte, 1) != kIOReturnSuccess { failures += 1 }
        if !opened.isEmpty && failures == opened.count {
            lastError = "O teclado não aceitou o comando do LED."
        }
    }

    static func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
