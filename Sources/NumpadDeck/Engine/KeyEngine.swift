import Cocoa
import CoreGraphics

protocol KeyEngineDelegate: AnyObject {
    func keyEngine(didPress keyCode: UInt16) -> Bool
}

/// Global CGEvent tap. Bound keys are swallowed; everything else passes through.
final class KeyEngine {
    weak var delegate: KeyEngineDelegate?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let thread = DispatchQueue(label: "numpaddeck.tap")

    var isRunning: Bool { tap != nil }

    func start() {
        guard tap == nil, AXIsProcessTrusted() else { return }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, info in
                guard let info else { return Unmanaged.passUnretained(event) }
                let engine = Unmanaged<KeyEngine>.fromOpaque(info).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let t = engine.tap { CGEvent.tapEnable(tap: t, enable: true) }
                    return Unmanaged.passUnretained(event)
                }
                let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                if type == .keyDown {
                    let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
                    if isRepeat {
                        // Only swallow repeats of keys the deck already consumed; everything else keeps repeating normally.
                        return engine.swallowedUp.contains(code) ? nil : Unmanaged.passUnretained(event)
                    }
                    if engine.delegate?.keyEngine(didPress: code) == true { engine.swallowedUp.insert(code); return nil }
                } else if type == .keyUp, engine.swallowedUp.remove(code) != nil {
                    return nil
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: userInfo) else { return }
        self.tap = tap
        let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
        source = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // keyUps for swallowed keys must also be swallowed; tracked per code.
    private var swallowedUp = Set<UInt16>()
    func markSwallowed(_ code: UInt16) { swallowedUp.insert(code) }
}
