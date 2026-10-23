import SwiftUI

/// The numpad, drawn the way it sits on the desk. Click a key to edit it; press the physical key to jump to it.
struct DeckPane: View {
    @EnvironmentObject var store: DeckStore

    var body: some View {
        ZStack {
            Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 0.13, alpha: 1) : NSColor(white: 0.93, alpha: 1) })
            VStack(spacing: 18) {
                if !store.accessibilityGranted { PermissionBanner() }
                Spacer(minLength: 0)
                let size = NumpadLayout.size(quarterTurns: store.config.rotation)
                NumpadView()
                    .frame(maxWidth: size.columns > size.rows ? 560 : 440)
                    .aspectRatio(CGFloat(size.columns) / CGFloat(size.rows) * 1.02, contentMode: .fit)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.config.rotation)
                Text(hint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                Spacer(minLength: 0)
            }
            .padding(28)
        }
    }

    private var hint: String {
        if store.learningSlotID != nil { return "Pressione a tecla física que ocupa essa posição." }
        if store.selectedSlotID == nil { return "Clique numa tecla para configurá-la, ou pressione a tecla no numpad para pular direto." }
        return "Com esta janela em primeiro plano as teclas só selecionam; a ação dispara quando outro app está na frente."
    }
}

struct PermissionBanner: View {
    @EnvironmentObject var store: DeckStore
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill").font(.title2).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("O macOS ainda não deixa o NumpadDeck ler o teclado").fontWeight(.semibold)
                Text("Ative o NumpadDeck em Ajustes › Privacidade e Segurança › Acessibilidade. Sem isso, você pode configurar tudo, mas as teclas não disparam.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Abrir Ajustes") { store.requestAccessibility() }
                .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.orange.opacity(0.35)))
        .frame(maxWidth: 560)
    }
}

struct NumpadView: View {
    @EnvironmentObject var store: DeckStore

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 8
            let pad: CGFloat = 16
            let turns = store.config.rotation
            let size = NumpadLayout.size(quarterTurns: turns)
            let cellW = (geo.size.width - pad * 2 - gap * CGFloat(size.columns - 1)) / CGFloat(size.columns)
            let cellH = (geo.size.height - pad * 2 - gap * CGFloat(size.rows - 1)) / CGFloat(size.rows)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [Color(white: 0.17), Color(white: 0.11)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
                ForEach(NumpadLayout.slots) { slot in
                    let r = NumpadLayout.rect(of: slot, quarterTurns: turns)
                    let w = cellW * CGFloat(r.colSpan) + gap * CGFloat(r.colSpan - 1)
                    let h = cellH * CGFloat(r.rowSpan) + gap * CGFloat(r.rowSpan - 1)
                    KeycapView(slot: slot, binding: store.selectedProfile.binding(for: slot.id))
                        .frame(width: w, height: h)
                        .offset(x: pad + CGFloat(r.col) * (cellW + gap), y: pad + CGFloat(r.row) * (cellH + gap))
                }
            }
        }
    }
}

struct KeycapView: View {
    @EnvironmentObject var store: DeckStore
    let slot: KeySlot
    let binding: KeyBinding?
    @State private var hovering = false
    @ObservedObject private var icons = IconProvider.shared

    private var isSelected: Bool { store.selectedSlotID == slot.id }
    private var isPressed: Bool { store.pressedSlotID == slot.id }
    private var isLearning: Bool { store.learningSlotID == slot.id }
    private var sticker: StickerColor { binding?.sticker ?? .none }
    private var configured: Bool { binding?.action.isConfigured ?? false }

    var body: some View {
        let radius: CGFloat = 9
        ZStack {
            // keycap body
            RoundedRectangle(cornerRadius: radius + 2, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.30), Color(white: 0.20)], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(isPressed ? 0.15 : 0.45), radius: isPressed ? 2 : 5, y: isPressed ? 1 : 4)
            // sticker
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(sticker.color)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.22), .clear, .black.opacity(0.10)], startPoint: .top, endPoint: .bottom))
                )
                .padding(5)
            content.padding(9)
            if isLearning {
                RoundedRectangle(cornerRadius: radius + 2, style: .continuous)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            } else if isSelected {
                RoundedRectangle(cornerRadius: radius + 2, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 2.5)
            } else if hovering {
                RoundedRectangle(cornerRadius: radius + 2, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1.5)
            }
        }
        .scaleEffect(isPressed ? 0.94 : 1)
        .brightness(isPressed ? 0.12 : 0)
        .animation(.spring(response: 0.18, dampingFraction: 0.6), value: isPressed)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .contentShape(Rectangle())
        .onTapGesture { store.selectedSlotID = slot.id }
        .onHover { hovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tecla \(slot.glyph), \(binding?.name ?? "sem nome"), \(binding?.action.summary ?? "")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .help(binding?.action.summary ?? "")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top) {
                Text(slot.glyph)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(sticker.foreground.opacity(0.7))
                    .fixedSize()
                Spacer(minLength: 0)
                if configured, let action = binding?.action {
                    if let img = icons.image(for: action) {
                        Image(nsImage: img)
                            .resizable().interpolation(.high)
                            .frame(width: 22, height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                    } else {
                        Image(systemName: action.symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(sticker.foreground.opacity(0.85))
                    }
                }
            }
            Spacer(minLength: 0)
            if let name = binding?.name, !name.isEmpty {
                Text(name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(sticker.foreground)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .allowsTightening(true)
            }
        }
    }
}
