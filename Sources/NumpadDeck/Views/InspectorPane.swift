import SwiftUI
import UniformTypeIdentifiers

struct InspectorPane: View {
    @EnvironmentObject var store: DeckStore

    var body: some View {
        Group {
            if let b = store.selectedBinding {
                KeyEditor(binding: b)
                    .id(b.id + store.selectedProfile.id.uuidString)
            } else {
                EmptyInspector()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct EmptyInspector: View {
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
            Image(systemName: "hand.point.up.left")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Nenhuma tecla selecionada").font(.headline)
            Text("Escolha uma tecla no numpad ao lado. A cor na tela segue o adesivo que está na tecla de verdade.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            }
            LedSettings()
        }
        .padding()
    }
}

/// The numpad's Num Lock LED as a status light: lit while the deck is live, blinks when a key fires.
struct LedSettings: View {
    @EnvironmentObject var store: DeckStore
    @ObservedObject private var led = LedController.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $store.config.ledEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LED do numpad").fontWeight(.semibold)
                    Text("Aceso enquanto o deck está ativo. Pisca quando uma tecla dispara e pisca duas vezes quando o perfil muda de app.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            if store.config.ledEnabled {
                if led.hasDevices {
                    Label(led.deviceNames.joined(separator: ", "), systemImage: "keyboard")
                        .font(.caption).foregroundStyle(.secondary)
                } else if !led.lastError.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(led.lastError).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button("Abrir Ajustes") { LedController.openInputMonitoringSettings() }
                            .controlSize(.small)
                    }
                }
                Button("Testar LED") { led.blink(times: 3, onMs: 120, offMs: 120) }
                    .controlSize(.small)
                    .disabled(!led.hasDevices)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: 300)
    }
}

struct KeyEditor: View {
    @EnvironmentObject var store: DeckStore
    @State var binding: KeyBinding
    @FocusState private var nameFocused: Bool

    private var slot: KeySlot { NumpadLayout.slots.first { $0.id == binding.id }! }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    KeycapPreview(sticker: binding.sticker, glyph: slot.glyph, action: binding.action)
                    VStack(alignment: .leading, spacing: 3) {
                        TextField("Nome na tecla", text: $binding.name, prompt: Text("Nome na tecla"))
                            .textFieldStyle(.plain)
                            .labelsHidden()
                            .font(.title3.weight(.semibold))
                            .focused($nameFocused)
                        Text("Tecla física: \(KeyNames.name(binding.keyCode))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Adesivo") {
                StickerPicker(selection: $binding.sticker)
            }

            Section("Ação") {
                Picker("Tipo", selection: kindBinding) {
                    ForEach(KeyAction.Kind.allCases) { k in
                        Label(k.label, systemImage: k.symbol).tag(k)
                    }
                }
                .pickerStyle(.menu)
                ActionFields(action: $binding.action)
            }

            Section("Tecla física") {
                LabeledContent("Reatribuir") {
                    Button(store.learningSlotID == binding.id ? "Aguardando tecla…" : "Aprender tecla") {
                        store.learningSlotID = store.learningSlotID == binding.id ? nil : binding.id
                    }
                    .disabled(!store.accessibilityGranted)
                }
                if !KeyNames.keypadCodes.contains(binding.keyCode) {
                    if let dev = binding.device {
                        Label("Só responde quando vem do \(NumpadHID.shared.name(of: dev) ?? dev). No teclado principal a tecla continua normal.", systemImage: "keyboard")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Label("Essa tecla também existe no teclado principal e ainda não está amarrada ao numpad, então ela não dispara. Use Aprender tecla e pressione-a no numpad.", systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                Text("Use isso se seu numpad tiver um layout diferente, ou para testar com outro teclado antes do numpad chegar.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button {
                        store.run(binding)
                    } label: { Label("Executar agora", systemImage: "play.fill") }
                    .disabled(!binding.action.isConfigured)
                    Spacer()
                    Button(role: .destructive) {
                        binding.name = ""; binding.action = .none
                    } label: { Label("Limpar", systemImage: "trash") }
                    .disabled(binding.name.isEmpty && binding.action.kind == .none)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onChange(of: binding) { _, new in store.update(new) }
        .onAppear { if binding.name.isEmpty { nameFocused = true } }
    }

    private var kindBinding: Binding<KeyAction.Kind> {
        Binding(get: { binding.action.kind }, set: { k in if k != binding.action.kind { binding.action = .blank(k) } })
    }
}

struct KeycapPreview: View {
    let sticker: StickerColor; let glyph: String
    var action: KeyAction = .none
    @ObservedObject private var icons = IconProvider.shared
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(white: 0.22))
            RoundedRectangle(cornerRadius: 7, style: .continuous).fill(sticker.color).padding(4)
            if let img = icons.image(for: action) {
                Image(nsImage: img).resizable().interpolation(.high).frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Text(glyph).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(sticker.foreground)
            }
        }
        .frame(width: 48, height: 48)
        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
    }
}

struct StickerPicker: View {
    @Binding var selection: StickerColor
    var body: some View {
        HStack(spacing: 8) {
            ForEach(StickerColor.allCases) { s in
                Button { selection = s } label: {
                    ZStack {
                        Circle().fill(s.color)
                        if s == .none { Image(systemName: "slash.circle").foregroundStyle(.white.opacity(0.7)).font(.system(size: 12)) }
                        Circle().strokeBorder(.primary.opacity(selection == s ? 0.9 : 0.3), lineWidth: selection == s ? 2.5 : 1)
                    }
                    .frame(width: 26, height: 26)
                    .scaleEffect(selection == s ? 1.1 : 1)
                    .animation(.easeOut(duration: 0.15), value: selection)
                }
                .buttonStyle(.plain)
                .help(s.label)
                .accessibilityLabel(s.label)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ActionFields: View {
    @Binding var action: KeyAction

    var body: some View {
        switch action {
        case .none:
            Text("Escolha o que essa tecla faz.").font(.caption).foregroundStyle(.secondary)

        case .openApp(let path):
            LabeledContent("App") {
                HStack {
                    if path.isEmpty {
                        Text("Nenhum").foregroundStyle(.secondary)
                    } else {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 18, height: 18)
                        Text(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)
                    }
                    Button("Escolher…") { pickApp { action = .openApp(path: $0) } }
                }
            }

        case .openURL(let url):
            TextField("Link", text: Binding(get: { url }, set: { action = .openURL(url: $0) }), prompt: Text("figma.com/files ou obsidian://vault"))
                .textFieldStyle(.roundedBorder)

        case .shortcut(let code, let mods):
            LabeledContent("Combinação") {
                ShortcutRecorder(keyCode: code, modifiers: mods) { c, m in action = .shortcut(keyCode: c, modifiers: m) }
            }
            Text("Enviado ao app que estiver na frente, como se você digitasse.")
                .font(.caption).foregroundStyle(.secondary)

        case .shell(let cmd):
            TextEditor(text: Binding(get: { cmd }, set: { action = .shell(command: $0) }))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 72)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
            Text("Roda em zsh com seu perfil de login. A última linha da saída aparece na barra de status.")
                .font(.caption).foregroundStyle(.secondary)

        case .text(let t):
            TextEditor(text: Binding(get: { t }, set: { action = .text($0) }))
                .frame(minHeight: 72)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
            Text("Digitado onde o cursor estiver. Uma quebra de linha no fim envia Enter.").font(.caption).foregroundStyle(.secondary)

        case .tool(let tool):
            Picker("Ferramenta", selection: Binding(get: { tool.kindIndex }, set: { action = .tool(KeyAction.Tool.all[$0]) })) {
                ForEach(Array(KeyAction.Tool.all.enumerated()), id: \.offset) { Text($0.element.kindLabel).tag($0.offset) }
            }
            switch tool {
            case .sshConnect(let user, let hosts):
                TextField("Usuário", text: Binding(get: { user }, set: { action = .tool(.sshConnect(user: $0, hosts: hosts)) }), prompt: Text("pi"))
                TextField("Hosts (em ordem, separados por vírgula)", text: Binding(get: { hosts }, set: { action = .tool(.sshConnect(user: user, hosts: $0)) }), prompt: Text("servidor.local, 100.64.0.10"))
                Text("Testa a porta 22 de cada host na ordem (rede local primeiro, Tailscale depois) e abre o Terminal já conectado no primeiro que responder.")
                    .font(.caption).foregroundStyle(.secondary)
            case .colorPicker(let format):
                Picker("Formato", selection: Binding(get: { format }, set: { action = .tool(.colorPicker(format: $0)) })) {
                    ForEach(KeyAction.Tool.ColorFormat.allCases) { Text($0.label).tag($0) }
                }
                Text("Abre a lupa do macOS. Clique em qualquer ponto da tela e a cor vai para a área de transferência. Esc cancela.")
                    .font(.caption).foregroundStyle(.secondary)
            case .minimizeWindow:
                Text("Minimiza a janela do app em primeiro plano (⌘M).").font(.caption).foregroundStyle(.secondary)
            case .toggleFullScreen:
                Text("Entra ou sai da tela cheia do app em primeiro plano (⌃⌘F).").font(.caption).foregroundStyle(.secondary)
            case .quitApp:
                Text("Encerra o app em primeiro plano (⌘Q). Apps com trabalho não salvo ainda perguntam antes de sair.").font(.caption).foregroundStyle(.secondary)
            case .lockScreen:
                Text("Bloqueia a tela na hora (⌃⌘Q). Pede a senha ou Touch ID para voltar.").font(.caption).foregroundStyle(.secondary)
            case .missionControl:
                Text("Abre o Mission Control (⌃↑) com todas as janelas da mesa atual. Aperte de novo para fechar.").font(.caption).foregroundStyle(.secondary)
            case .toggleMute:
                Text("Alterna o mudo da saída de som do Mac. Aperte de novo para voltar o som no volume de antes.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func pickApp(_ done: @escaping (String) -> Void) {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.application]
        p.directoryURL = URL(fileURLWithPath: "/Applications")
        p.canChooseDirectories = false
        p.prompt = "Escolher"
        if p.runModal() == .OK, let u = p.url { done(u.path) }
    }
}
