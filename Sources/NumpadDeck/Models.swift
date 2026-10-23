import SwiftUI

// MARK: - Sticker palette (mirrors the physical sticker set)

enum StickerColor: String, Codable, CaseIterable, Identifiable {
    case none, yellow, blue, green, purple, salmon, pink, brown, gray, black
    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Sem adesivo"
        case .yellow: return "Amarelo"
        case .blue: return "Azul"
        case .green: return "Verde"
        case .purple: return "Roxo"
        case .salmon: return "Salmão"
        case .pink: return "Rosa"
        case .brown: return "Marrom"
        case .gray: return "Cinza"
        case .black: return "Preto"
        }
    }

    var color: Color {
        switch self {
        case .none: return Color(nsColor: .init(white: 0.24, alpha: 1))
        case .yellow: return Color(red: 0.93, green: 0.84, blue: 0.19)
        case .blue: return Color(red: 0.16, green: 0.60, blue: 0.86)
        case .green: return Color(red: 0.54, green: 0.60, blue: 0.36)   // #8a9a5b
        case .purple: return Color(red: 0.48, green: 0.37, blue: 0.65)  // #7b5ea7
        case .salmon: return Color(red: 0.96, green: 0.52, blue: 0.42)
        case .pink: return Color(red: 0.86, green: 0.30, blue: 0.58)
        case .brown: return Color(red: 0.68, green: 0.46, blue: 0.36)
        case .gray: return Color(red: 0.42, green: 0.42, blue: 0.44)
        case .black: return Color(red: 0.10, green: 0.10, blue: 0.11)
        }
    }

    /// Text color that keeps ≥4.5:1 on the sticker.
    var foreground: Color {
        switch self {
        case .yellow, .green, .salmon: return Color(white: 0.08)
        case .none, .blue, .purple, .pink, .brown, .gray, .black: return .white
        }
    }
}

// MARK: - Actions

enum KeyAction: Codable, Equatable {
    case none
    case openApp(path: String)
    case openURL(url: String)
    case shortcut(keyCode: UInt16, modifiers: UInt)
    case shell(command: String)
    case text(String)
    case tool(Tool)

    /// Built-in tools. Each one is a native macOS call that runs only when the key is pressed;
    /// nothing stays resident between presses.
    enum Tool: Codable, Equatable {
        case colorPicker(format: ColorFormat)
        /// Tries each host in order (port 22), then opens the Terminal already connected.
        case sshConnect(user: String, hosts: String)
        /// Mutes/unmutes the Mac's output, like the ⌥ mute key.
        case toggleMute
        /// Window controls for the app in front, without having to record the shortcut.
        case minimizeWindow, toggleFullScreen, quitApp
        /// System shortcuts: lock the screen and show every window of the current space.
        case lockScreen, missionControl

        enum ColorFormat: String, Codable, CaseIterable, Identifiable {
            case hex, rgb, hsl, swiftUI
            var id: String { rawValue }
            var label: String {
                switch self {
                case .hex: return "HEX  #3a8fd9"
                case .rgb: return "RGB  rgb(58, 143, 217)"
                case .hsl: return "HSL  hsl(208, 68%, 54%)"
                case .swiftUI: return "SwiftUI  Color(red:green:blue:)"
                }
            }
        }

        var label: String {
            switch self {
            case .colorPicker: return "Conta-gotas de cor"
            case .sshConnect(let u, let h):
                let first = h.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                return first.isEmpty ? "SSH: informe o host" : "SSH \(u)@\(first)"
            case .toggleMute: return "Mudo do Mac"
            case .minimizeWindow: return "Minimizar janela"
            case .toggleFullScreen: return "Tela cheia"
            case .quitApp: return "Fechar programa"
            case .lockScreen: return "Bloquear tela"
            case .missionControl: return "Mission Control"
            }
        }

        static let all: [Tool] = [.colorPicker(format: .hex), .sshConnect(user: "", hosts: ""), .toggleMute, .minimizeWindow, .toggleFullScreen, .quitApp, .lockScreen, .missionControl]

        var kindLabel: String {
            switch self {
            case .colorPicker: return "Conta-gotas de cor"
            case .sshConnect: return "Conectar por SSH"
            case .toggleMute: return "Mudo (som do Mac)"
            case .minimizeWindow: return "Minimizar janela"
            case .toggleFullScreen: return "Tela cheia"
            case .quitApp: return "Fechar programa"
            case .lockScreen: return "Bloquear tela"
            case .missionControl: return "Mission Control (todas as janelas)"
            }
        }
        var kindIndex: Int {
            switch self {
            case .colorPicker: return 0
            case .sshConnect: return 1
            case .toggleMute: return 2
            case .minimizeWindow: return 3
            case .toggleFullScreen: return 4
            case .quitApp: return 5
            case .lockScreen: return 6
            case .missionControl: return 7
            }
        }
        var symbol: String {
            switch self {
            case .colorPicker: return "eyedropper"
            case .sshConnect: return "terminal"
            case .toggleMute: return "speaker.slash"
            case .minimizeWindow: return "arrow.down.right.and.arrow.up.left"
            case .toggleFullScreen: return "arrow.up.left.and.arrow.down.right"
            case .quitApp: return "xmark.app"
            case .lockScreen: return "lock"
            case .missionControl: return "rectangle.3.group"
            }
        }
    }

    enum Kind: String, CaseIterable, Identifiable {
        case none, openApp, openURL, shortcut, shell, text, tool
        var id: String { rawValue }
        var label: String {
            switch self {
            case .none: return "Nenhuma"
            case .openApp: return "Abrir app"
            case .openURL: return "Abrir link"
            case .shortcut: return "Atalho"
            case .shell: return "Script"
            case .text: return "Texto"
            case .tool: return "Ferramenta"
            }
        }
        var symbol: String {
            switch self {
            case .none: return "circle.dashed"
            case .openApp: return "app.badge"
            case .openURL: return "link"
            case .shortcut: return "command"
            case .shell: return "terminal"
            case .text: return "text.cursor"
            case .tool: return "eyedropper"
            }
        }
    }

    var kind: Kind {
        switch self {
        case .none: return .none
        case .openApp: return .openApp
        case .openURL: return .openURL
        case .shortcut: return .shortcut
        case .shell: return .shell
        case .text: return .text
        case .tool: return .tool
        }
    }

    static func blank(_ kind: Kind) -> KeyAction {
        switch kind {
        case .none: return .none
        case .openApp: return .openApp(path: "")
        case .openURL: return .openURL(url: "")
        case .shortcut: return .shortcut(keyCode: UInt16.max, modifiers: 0)
        case .shell: return .shell(command: "")
        case .text: return .text("")
        case .tool: return .tool(.colorPicker(format: .hex))
        }
    }

    var isConfigured: Bool {
        switch self {
        case .none: return false
        case .openApp(let p): return !p.isEmpty
        case .openURL(let u): return !u.isEmpty
        case .shortcut(let k, _): return k != UInt16.max
        case .shell(let c): return !c.trimmingCharacters(in: .whitespaces).isEmpty
        case .text(let t): return !t.isEmpty
        case .tool(.sshConnect(_, let h)): return !h.trimmingCharacters(in: .whitespaces).isEmpty
        case .tool: return true
        }
    }

    /// Keycap icon when the action has no app/favicon image.
    var symbol: String {
        if case .tool(let t) = self { return t.symbol }
        return kind.symbol
    }

    /// One-line human summary shown on the keycap and in lists.
    var summary: String {
        switch self {
        case .none: return "Sem ação"
        case .openApp(let p): return p.isEmpty ? "Escolha um app" : URL(fileURLWithPath: p).deletingPathExtension().lastPathComponent
        case .openURL(let u): return u.isEmpty ? "Cole um link" : u
        case .shortcut(let k, let m): return k == UInt16.max ? "Grave um atalho" : KeyNames.describe(keyCode: k, modifiers: m)
        case .shell(let c): return c.isEmpty ? "Escreva um comando" : c
        case .text(let t): return t.isEmpty ? "Escreva um texto" : t
        case .tool(let tool): return tool.label
        }
    }
}

// MARK: - Keys & layout

struct KeyBinding: Codable, Identifiable, Equatable {
    var id: String            // slot id, stable per layout position
    var keyCode: UInt16       // physical key that triggers it
    var name: String = ""     // user label ("Gravar", "Deploy")
    var sticker: StickerColor = .none
    var action: KeyAction = .none
    /// "vendor:product" of the keyboard this key was learned from. Set when the keycode also exists on a
    /// regular keyboard (Backspace, "."), so pressing it on the main keyboard keeps working normally.
    var device: String? = nil
}

/// A physical slot on the numpad grid. Column/row in a 4×5 grid; some keys span 2.
struct KeySlot: Identifiable {
    let id: String
    let glyph: String       // what is printed on the keycap
    let keyCode: UInt16     // default key code
    let col: Int, row: Int
    var colSpan: Int = 1, rowSpan: Int = 1
}

enum NumpadLayout {
    // Matches the 4×5 numpad in the photo: top row num/÷/×/−, + single, ⌫-ish brown key,
    // Enter tall on the last two rows, 0 wide.
    static let slots: [KeySlot] = [
        KeySlot(id: "clear", glyph: "num", keyCode: 71, col: 0, row: 0),
        KeySlot(id: "div",   glyph: "÷",   keyCode: 75, col: 1, row: 0),
        KeySlot(id: "mul",   glyph: "×",   keyCode: 67, col: 2, row: 0),
        KeySlot(id: "minus", glyph: "−",   keyCode: 78, col: 3, row: 0),
        KeySlot(id: "k7",    glyph: "7",   keyCode: 89, col: 0, row: 1),
        KeySlot(id: "k8",    glyph: "8",   keyCode: 91, col: 1, row: 1),
        KeySlot(id: "k9",    glyph: "9",   keyCode: 92, col: 2, row: 1),
        KeySlot(id: "plus",  glyph: "+",   keyCode: 69, col: 3, row: 1),
        KeySlot(id: "k4",    glyph: "4",   keyCode: 86, col: 0, row: 2),
        KeySlot(id: "k5",    glyph: "5",   keyCode: 87, col: 1, row: 2),
        KeySlot(id: "k6",    glyph: "6",   keyCode: 88, col: 2, row: 2),
        KeySlot(id: "eq",    glyph: "=",   keyCode: 81, col: 3, row: 2),
        KeySlot(id: "k1",    glyph: "1",   keyCode: 83, col: 0, row: 3),
        KeySlot(id: "k2",    glyph: "2",   keyCode: 84, col: 1, row: 3),
        KeySlot(id: "k3",    glyph: "3",   keyCode: 85, col: 2, row: 3),
        KeySlot(id: "enter", glyph: "⏎",   keyCode: 76, col: 3, row: 3, rowSpan: 2),
        KeySlot(id: "k0",    glyph: "0",   keyCode: 82, col: 0, row: 4, colSpan: 2),
        KeySlot(id: "dot",   glyph: ".",   keyCode: 65, col: 2, row: 4),
    ]
    static let columns = 4, rows = 5

    /// Grid size after `quarterTurns` clockwise turns.
    static func size(quarterTurns: Int) -> (columns: Int, rows: Int) {
        quarterTurns % 2 == 0 ? (columns, rows) : (rows, columns)
    }

    /// A slot's cell rect (col, row, colSpan, rowSpan) after rotating the whole grid clockwise.
    static func rect(of slot: KeySlot, quarterTurns: Int) -> (col: Int, row: Int, colSpan: Int, rowSpan: Int) {
        switch ((quarterTurns % 4) + 4) % 4 {
        case 1:  return (rows - slot.row - slot.rowSpan, slot.col, slot.rowSpan, slot.colSpan)
        case 2:  return (columns - slot.col - slot.colSpan, rows - slot.row - slot.rowSpan, slot.colSpan, slot.rowSpan)
        case 3:  return (slot.row, columns - slot.col - slot.colSpan, slot.rowSpan, slot.colSpan)
        default: return (slot.col, slot.row, slot.colSpan, slot.rowSpan)
        }
    }

    /// Sticker colors seen in the photo, used as the starter layout.
    static let photoStickers: [String: StickerColor] = [
        "clear": .black, "div": .green, "mul": .salmon, "minus": .gray,
        "k7": .blue, "k8": .blue, "k9": .blue, "plus": .pink,
        "k4": .yellow, "k5": .yellow, "k6": .yellow, "eq": .brown,
        "k1": .green, "k2": .yellow, "k3": .yellow, "enter": .black,
        "k0": .salmon, "dot": .purple,
    ]

    static func freshBindings() -> [KeyBinding] {
        slots.map { KeyBinding(id: $0.id, keyCode: $0.keyCode, sticker: photoStickers[$0.id] ?? .none) }
    }
}

// MARK: - Profiles

struct Profile: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var bundleIDs: [String] = []          // empty = default/fallback profile
    var keys: [KeyBinding] = NumpadLayout.freshBindings()

    var isDefault: Bool { bundleIDs.isEmpty }

    func binding(for slotID: String) -> KeyBinding? { keys.first { $0.id == slotID } }
    mutating func update(_ b: KeyBinding) {
        if let i = keys.firstIndex(where: { $0.id == b.id }) { keys[i] = b }
    }
}

struct DeckConfig: Codable, Equatable {
    var profiles: [Profile] = [Profile(name: "Padrão")]
    var enabled: Bool = true
    /// How the physical numpad sits on the desk, in clockwise quarter turns (0…3). The on-screen grid follows it.
    var rotation: Int = 0
    /// Num Lock LED on the numpad mirrors the deck: lit while active, a blink when a key fires.
    var ledEnabled: Bool = true

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try c.decodeIfPresent([Profile].self, forKey: .profiles) ?? [Profile(name: "Padrão")]
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        rotation = ((try c.decodeIfPresent(Int.self, forKey: .rotation) ?? 0) % 4 + 4) % 4
        ledEnabled = try c.decodeIfPresent(Bool.self, forKey: .ledEnabled) ?? true
    }
}

// MARK: - Key naming

enum KeyNames {
    static let map: [UInt16: String] = [
        0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",
        18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",24:"=",25:"9",26:"7",27:"-",28:"8",29:"0",30:"]",31:"O",32:"U",33:"[",
        34:"I",35:"P",37:"L",38:"J",39:"'",40:"K",41:";",42:"\\",43:",",44:"/",45:"N",46:"M",47:".",50:"`",
        36:"↩",48:"⇥",49:"Espaço",51:"⌫",53:"⎋",117:"⌦",115:"↖",119:"↘",116:"⇞",121:"⇟",123:"←",124:"→",125:"↓",126:"↑",
        122:"F1",120:"F2",99:"F3",118:"F4",96:"F5",97:"F6",98:"F7",100:"F8",101:"F9",109:"F10",103:"F11",111:"F12",
        65:"Num .",67:"Num ×",69:"Num +",71:"Num Clear",75:"Num ÷",76:"Num ⏎",78:"Num −",81:"Num =",
        82:"Num 0",83:"Num 1",84:"Num 2",85:"Num 3",86:"Num 4",87:"Num 5",88:"Num 6",89:"Num 7",91:"Num 8",92:"Num 9",
    ]
    static let keypadCodes: Set<UInt16> = [65,67,69,71,75,76,78,81,82,83,84,85,86,87,88,89,91,92]

    static func name(_ code: UInt16) -> String { map[code] ?? "Tecla \(code)" }

    static func describe(keyCode: UInt16, modifiers: UInt) -> String {
        let f = NSEvent.ModifierFlags(rawValue: modifiers)
        var s = ""
        if f.contains(.control) { s += "⌃" }
        if f.contains(.option) { s += "⌥" }
        if f.contains(.shift) { s += "⇧" }
        if f.contains(.command) { s += "⌘" }
        return s + name(keyCode)
    }
}
