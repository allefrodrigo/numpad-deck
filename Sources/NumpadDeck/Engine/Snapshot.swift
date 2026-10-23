import AppKit

/// `NumpadDeck --snapshot <dir> [--select slot] [--demo]` renders the main window (light + dark) to PNGs and quits.
/// Used for design review without screen-recording permission. `--demo` seeds sample bindings in memory only.
enum Snapshot {
    static var dir: String? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "--snapshot"), i + 1 < a.count else { return nil }
        return a[i + 1]
    }
    static var demo: Bool { CommandLine.arguments.contains("--demo") }
    /// `--rotate N` quarter turns, only honored in snapshot mode.
    static var rotation: Int? {
        let a = CommandLine.arguments
        return a.firstIndex(of: "--rotate").flatMap { a.indices.contains($0+1) ? Int(a[$0+1]) : nil }
    }

    @MainActor static func runIfRequested(window: NSWindow?) {
        guard let dir, let window else { return }
        Task { @MainActor in
            for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                NSApp.appearance = NSAppearance(named: appearance)
                try? await Task.sleep(for: .milliseconds(900))
                let id = CGWindowID(window.windowNumber)
                guard let cg = CGWindowListCreateImage(.null, .optionIncludingWindow, id, [.boundsIgnoreFraming, .bestResolution]) else { continue }
                let rep = NSBitmapImageRep(cgImage: cg)
                if let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
                }
            }
            NSApp.terminate(nil)
        }
    }

    static func seed(_ cfg: inout DeckConfig) {
        var p = cfg.profiles[0]
        func set(_ id: String, _ name: String, _ a: KeyAction) { if var b = p.binding(for: id) { b.name = name; b.action = a; p.update(b) } }
        set("k7", "Figma", .openApp(path: "/Applications/Figma.app"))
        set("k8", "Terminal", .openApp(path: "/System/Applications/Utilities/Terminal.app"))
        set("k9", "Notas", .openApp(path: "/System/Applications/Notes.app"))
        set("k4", "Gravar", .shortcut(keyCode: 15, modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue))
        set("k5", "Print", .shortcut(keyCode: 21, modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue))
        set("k6", "Mutar", .shortcut(keyCode: 46, modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue))
        set("k1", "Deploy", .shell(command: "cd ~/proj && npm run deploy"))
        set("k2", "Build", .shell(command: "swift build"))
        set("plus", "E-mail", .text("dev.allef@exemplo.com"))
        set("div", "GitHub", .openURL(url: "github.com"))
        set("k0", "Pausa", .shortcut(keyCode: 49, modifiers: 0))
        set("eq", "Cor", .tool(.colorPicker(format: .hex)))
        set("minus", "Bloquear", .tool(.lockScreen))
        set("dot", "Janelas", .tool(.missionControl))
        cfg.profiles[0] = p
        var figma = Profile(name: "Figma", bundleIDs: ["com.figma.Desktop"])
        figma.keys = p.keys.map { var k = $0; k.name = ""; k.action = .none; return k }
        cfg.profiles.append(figma)
    }
}
