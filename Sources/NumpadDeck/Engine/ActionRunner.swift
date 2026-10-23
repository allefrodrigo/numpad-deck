import Cocoa
import Carbon.HIToolbox

enum ActionRunner {
    static func run(_ action: KeyAction, report: @escaping (String) -> Void) {
        switch action {
        case .none:
            report("Sem ação")
        case .openApp(let path):
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: .init()) { _, err in
                report(err == nil ? "Abriu \(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)" : "Não abriu o app: \(err!.localizedDescription)")
            }
        case .openURL(let s):
            var str = s.trimmingCharacters(in: .whitespaces)
            if !str.contains("://") { str = "https://" + str }
            if let url = URL(string: str) { NSWorkspace.shared.open(url); report("Abriu \(url.host ?? str)") }
            else { report("Link inválido: \(s)") }
        case .shortcut(let code, let mods):
            post(keyCode: code, modifiers: NSEvent.ModifierFlags(rawValue: mods))
            report("Enviou \(KeyNames.describe(keyCode: code, modifiers: mods))")
        case .shell(let cmd):
            runShell(cmd, report: report)
        case .text(let t):
            type(t)
            report("Digitou \(t.count) caracteres")
        case .tool(let tool):
            runTool(tool, report: report)
        }
    }

    // MARK: Tools

    private static func runTool(_ tool: KeyAction.Tool, report: @escaping (String) -> Void) {
        switch tool {
        case .colorPicker(let format):
            // NSColorSampler is the system loupe. It is created here and released when the
            // user picks or cancels, so nothing lingers between presses.
            NSColorSampler().show { picked in
                guard let c = picked?.usingColorSpace(.sRGB) else { report("Conta-gotas cancelado"); return }
                let text = Self.format(c, as: format)
                let pb = NSPasteboard.general
                pb.clearContents(); pb.setString(text, forType: .string)
                report("Copiou \(text)")
            }
        case .toggleMute:
            let script = """
            set muted to output muted of (get volume settings)
            set volume output muted (not muted)
            return not muted
            """
            var err: NSDictionary?
            let result = NSAppleScript(source: script)?.executeAndReturnError(&err)
            if let err { report("Não deu para mudar o som: \(err[NSAppleScript.errorMessage] ?? "erro")"); return }
            report(result?.booleanValue == true ? "Som desligado" : "Som ligado")
        case .minimizeWindow:
            post(keyCode: UInt16(kVK_ANSI_M), modifiers: .command)
            report("Minimizou a janela")
        case .toggleFullScreen:
            post(keyCode: UInt16(kVK_ANSI_F), modifiers: [.control, .command])
            report("Alternou tela cheia")
        case .quitApp:
            let name = NSWorkspace.shared.frontmostApplication?.localizedName ?? "o app"
            post(keyCode: UInt16(kVK_ANSI_Q), modifiers: .command)
            report("Fechou \(name)")
        case .lockScreen:
            post(keyCode: UInt16(kVK_ANSI_Q), modifiers: [.control, .command])
            report("Tela bloqueada")
        case .missionControl:
            post(keyCode: UInt16(kVK_UpArrow), modifiers: .control)
            report("Mission Control")
        case .sshConnect(let user, let hosts):
            let list = hosts.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard !list.isEmpty else { report("SSH: nenhum host configurado"); return }
            report("Procurando \(list.first!)…")
            DispatchQueue.global().async {
                guard let host = list.first(where: { portOpen($0, 22, timeout: 2) }) else {
                    DispatchQueue.main.async { report("Nenhum host respondeu na porta 22: \(list.joined(separator: ", "))") }
                    return
                }
                let target = user.isEmpty ? host : "\(user)@\(host)"
                let script = """
                tell application "Terminal"
                    activate
                    do script "ssh \(target)"
                end tell
                """
                var err: NSDictionary?
                NSAppleScript(source: script)?.executeAndReturnError(&err)
                DispatchQueue.main.async {
                    report(err == nil ? "Abriu ssh \(target)" : "Terminal não abriu: \(err?[NSAppleScript.errorMessage] ?? "erro")")
                }
            }
        }
    }

    /// Blocking TCP probe, used off the main thread.
    private static func portOpen(_ host: String, _ port: Int, timeout: Int) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
        p.arguments = ["-z", "-G", "\(timeout)", host, "\(port)"]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    static func format(_ c: NSColor, as f: KeyAction.Tool.ColorFormat) -> String {
        let r = c.redComponent, g = c.greenComponent, b = c.blueComponent
        let R = Int((r * 255).rounded()), G = Int((g * 255).rounded()), B = Int((b * 255).rounded())
        switch f {
        case .hex: return String(format: "#%02x%02x%02x", R, G, B)
        case .rgb: return "rgb(\(R), \(G), \(B))"
        case .hsl:
            let h = c.hueComponent * 360, s = c.saturationComponent, v = c.brightnessComponent
            let l = v * (1 - s / 2)
            let sl = (l == 0 || l == 1) ? 0 : (v - l) / min(l, 1 - l)
            return "hsl(\(Int(h.rounded())), \(Int((sl * 100).rounded()))%, \(Int((l * 100).rounded()))%)"
        case .swiftUI: return String(format: "Color(red: %.3f, green: %.3f, blue: %.3f)", r, g, b)
        }
    }

    private static func post(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        var flags = CGEventFlags()
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        down?.flags = flags; up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private static func type(_ text: String) {
        let src = CGEventSource(stateID: .combinedSessionState)
        // A trailing or embedded newline is sent as a real Return key, so "/clear\n" runs the command.
        let lines = text.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            if !line.isEmpty { typeRaw(line, src: src) }
            if i < lines.count - 1 {
                let d = CGEvent(keyboardEventSource: src, virtualKey: 36, keyDown: true)
                let u = CGEvent(keyboardEventSource: src, virtualKey: 36, keyDown: false)
                d?.post(tap: .cghidEventTap); u?.post(tap: .cghidEventTap)
                usleep(30000)
            }
        }
    }

    private static func typeRaw(_ text: String, src: CGEventSource?) {
        for chunk in text.chunked(20) {
            var units = Array(chunk.utf16)
            let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)
            let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
            down?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
            up?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
            down?.post(tap: .cghidEventTap); up?.post(tap: .cghidEventTap)
            usleep(4000)
        }
    }

    private static func runShell(_ cmd: String, report: @escaping (String) -> Void) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-lc", cmd]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        p.terminationHandler = { proc in
            let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let last = out.split(separator: "\n").last.map(String.init) ?? ""
            report(proc.terminationStatus == 0 ? (last.isEmpty ? "Script concluído" : last) : "Script falhou (\(proc.terminationStatus)): \(last)")
        }
        do { try p.run() } catch { report("Não rodou o script: \(error.localizedDescription)") }
    }
}

extension String {
    func chunked(_ n: Int) -> [String] {
        var r: [String] = []; var i = startIndex
        while i < endIndex { let j = index(i, offsetBy: n, limitedBy: endIndex) ?? endIndex; r.append(String(self[i..<j])); i = j }
        return r
    }
}
