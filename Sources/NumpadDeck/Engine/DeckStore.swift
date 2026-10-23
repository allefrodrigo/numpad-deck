import SwiftUI
import Combine

@MainActor
final class DeckStore: ObservableObject {
    @Published var config: DeckConfig { didSet { scheduleSave(); syncLed() } }
    let led = LedController.shared
    private var lastActiveProfileID: UUID?
    @Published var selectedProfileID: UUID
    @Published var selectedSlotID: String?
    @Published var testMode = false
    @Published var frontmostBundleID: String = ""
    @Published var frontmostAppName: String = ""
    @Published var lastEvent: String = ""          // status line: last action fired
    @Published var pressedSlotID: String?           // transient press feedback
    @Published var accessibilityGranted = false
    @Published var learningSlotID: String?          // slot waiting for a physical key

    let engine = KeyEngine()
    private var saveTask: Task<Void, Never>?
    private var pollTimer: Timer?

    static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NumpadDeck", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }()

    init() {
        let loaded = (try? Data(contentsOf: Self.fileURL)).flatMap { try? JSONDecoder().decode(DeckConfig.self, from: $0) }
        var cfg = loaded ?? DeckConfig()
        if Snapshot.demo { cfg = DeckConfig(); Snapshot.seed(&cfg) }
        if Snapshot.dir != nil, let r = Snapshot.rotation { cfg.rotation = r }
        config = cfg
        selectedProfileID = cfg.profiles.first?.id ?? UUID()
        engine.delegate = self
        refreshAccessibility()
        engine.start()
        NumpadHID.shared.start()
        observeFrontmost()
        lastActiveProfileID = activeProfile.id
        syncLed()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshAccessibility() }
        }
    }

    // MARK: Profiles

    var profiles: [Profile] { config.profiles }

    var selectedProfile: Profile {
        get { config.profiles.first { $0.id == selectedProfileID } ?? config.profiles[0] }
        set {
            if let i = config.profiles.firstIndex(where: { $0.id == newValue.id }) { config.profiles[i] = newValue }
        }
    }

    /// Profile that should fire right now, given the frontmost app.
    var activeProfile: Profile {
        config.profiles.first { $0.bundleIDs.contains(frontmostBundleID) } ?? config.profiles.first { $0.isDefault } ?? config.profiles[0]
    }

    func addProfile() {
        let p = Profile(name: "Novo perfil", bundleIDs: [])
        config.profiles.append(p)
        selectedProfileID = p.id
    }

    func deleteProfile(_ id: UUID) {
        guard config.profiles.count > 1, let i = config.profiles.firstIndex(where: { $0.id == id }) else { return }
        config.profiles.remove(at: i)
        if selectedProfileID == id { selectedProfileID = config.profiles[0].id }
    }

    // MARK: Bindings

    var selectedBinding: KeyBinding? {
        guard let s = selectedSlotID else { return nil }
        return selectedProfile.binding(for: s)
    }

    func update(_ b: KeyBinding) {
        var p = selectedProfile
        p.update(b)
        selectedProfile = p
    }

    func clear(slot: String) {
        guard var b = selectedProfile.binding(for: slot) else { return }
        b.name = ""; b.action = .none
        update(b)
    }

    func copyStickers(to profile: Profile) {
        var p = profile
        let src = config.profiles.first { $0.isDefault } ?? config.profiles[0]
        for k in src.keys { if var t = p.binding(for: k.id) { t.sticker = k.sticker; p.update(t) } }
        selectedProfile = p
    }

    // MARK: Persistence

    private func scheduleSave() {
        if Snapshot.demo { return }
        saveTask?.cancel()
        saveTask = Task { [config] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let d = try? enc.encode(config) { try? d.write(to: Self.fileURL, options: .atomic) }
        }
    }

    // MARK: System

    func refreshAccessibility() {
        // Demo snapshots show the live state, with or without the permission.
        let granted = Snapshot.demo || AXIsProcessTrusted()
        if granted != accessibilityGranted {
            accessibilityGranted = granted
            if granted { engine.start() }
            syncLed()
        }
    }

    // MARK: LED

    /// Resting LED state: lit only when the deck can actually fire keys.
    private func syncLed() {
        guard !Snapshot.demo else { return }
        if config.ledEnabled {
            led.start()
            led.setSteady(config.enabled && accessibilityGranted)
        } else {
            led.stop()
        }
    }

    /// Double blink when the frontmost app switches the active profile.
    private func noteProfileSwitch() {
        let id = activeProfile.id
        guard id != lastActiveProfileID else { return }
        lastActiveProfileID = id
        if config.ledEnabled && config.enabled { led.blink(times: 2, onMs: 70, offMs: 90) }
    }

    func requestAccessibility() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func observeFrontmost() {
        let update: (NSRunningApplication?) -> Void = { [weak self] app in
            guard let self, let app, app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            self.frontmostBundleID = app.bundleIdentifier ?? ""
            self.frontmostAppName = app.localizedName ?? ""
            self.noteProfileSwitch()
        }
        update(NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { n in
            update(n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
        }
    }

    func flash(slot: String) {
        pressedSlotID = slot
        Task { try? await Task.sleep(for: .milliseconds(180)); if pressedSlotID == slot { pressedSlotID = nil } }
    }

    func run(_ b: KeyBinding) {
        ActionRunner.run(b.action) { [weak self] result in
            Task { @MainActor in self?.lastEvent = result }
        }
    }
}

extension DeckStore: KeyEngineDelegate {
    /// Returns true when the key was consumed.
    nonisolated func keyEngine(didPress keyCode: UInt16) -> Bool {
        // Called on the event-tap thread; hop to main synchronously for the decision.
        if Thread.isMainThread { return MainActor.assumeIsolated { handle(keyCode) } }
        return DispatchQueue.main.sync { MainActor.assumeIsolated { handle(keyCode) } }
    }

    /// Runs on the main actor. Returns true when the key was consumed.
    private func handle(_ keyCode: UInt16) -> Bool {
        var consume = false
        do {
            // Learning mode wins: bind physical key to the waiting slot.
            if let learning = learningSlotID, var b = selectedProfile.binding(for: learning) {
                b.keyCode = keyCode
                // Keypad codes are unique to the numpad; anything else gets tied to the keyboard that sent it.
                b.device = KeyNames.keypadCodes.contains(keyCode) ? nil : NumpadHID.shared.recentDevice(for: keyCode, waitUpTo: 0.05)
                if !KeyNames.keypadCodes.contains(keyCode) {
                    lastEvent = b.device.map { "Amarrada ao \(NumpadHID.shared.name(of: $0) ?? $0)" }
                        ?? "Não identifiquei o teclado. Confira a permissão de Monitoramento de Entrada e aprenda de novo."
                }
                update(b)
                learningSlotID = nil
                selectedSlotID = learning
                flash(slot: learning)
                return true
            }
            let windowActive = NSApp.isActive
            let profile = windowActive ? selectedProfile : activeProfile
            // Keypad codes only exist on the numpad. Any other code must be tied to a device, or it is ignored
            // everywhere: a bare Backspace/"." binding would otherwise hijack the main keyboard.
            let candidates = profile.keys.filter { $0.keyCode == keyCode }
            let shared = !KeyNames.keypadCodes.contains(keyCode)
            let source = shared && !candidates.isEmpty ? NumpadHID.shared.recentDevice(for: keyCode) : nil
            guard let b = candidates.first(where: { shared ? ($0.device != nil && $0.device == source) : true }) else {
                if !candidates.isEmpty {
                    if windowActive, learningSlotID == nil, let c = candidates.first, c.device == nil {
                        lastEvent = "\(KeyNames.name(keyCode)) não está amarrada a um teclado. Use Aprender tecla de novo."
                    }
                    return false // same keycode, but from another keyboard (or unbound): let it through
                }
                if windowActive, KeyNames.keypadCodes.contains(keyCode) || !KeyNames.map.keys.contains(keyCode) || [51, 47, 43].contains(keyCode) {
                    lastEvent = "\(KeyNames.name(keyCode)) (código \(keyCode)) não está na grade. Selecione a tecla e use Aprender tecla."
                }
                return false
            }

            if windowActive {
                // Window in front: keys select and preview, never fire.
                selectedSlotID = b.id
                flash(slot: b.id)
                if testMode == false && b.action.isConfigured { lastEvent = "Selecionado \(KeyNames.name(keyCode))" }
                return true
            }
            guard config.enabled, b.action.isConfigured else { return false }
            flash(slot: b.id)
            if config.ledEnabled { led.blink() }
            if testMode {
                lastEvent = "Teste: \(b.name.isEmpty ? KeyNames.name(keyCode) : b.name) → \(b.action.summary)"
            } else {
                run(b)
            }
            consume = true
        }
        return consume
    }
}
