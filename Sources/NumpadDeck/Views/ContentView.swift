import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: DeckStore
    @State private var showProfiles = false
    private var snapshotSlot: String? { let a = CommandLine.arguments; return a.firstIndex(of: "--select").flatMap { a.indices.contains($0+1) ? a[$0+1] : nil } }

    var body: some View {
        HStack(spacing: 0) {
            DeckPane()
                .frame(minWidth: 480)
            Divider()
            InspectorPane()
                .frame(width: 360)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ProfilePicker(showProfiles: $showProfiles)
            }
            ToolbarItem(placement: .principal) { StatusPill() }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { store.config.rotation = (store.config.rotation + 1) % 4 }
                } label: {
                    Label("Girar", systemImage: "rotate.right")
                }
                .help("Gira a grade em 90° para acompanhar como o numpad está na mesa (\(store.config.rotation * 90)°)")
                Toggle(isOn: $store.testMode) {
                    Label("Modo teste", systemImage: "flask")
                }
                .toggleStyle(.button)
                .help("Com o modo teste ligado, as teclas acendem na tela mas não executam a ação")
                HStack(spacing: 6) {
                    Text(store.config.enabled ? "Ativo" : "Pausado").font(.callout).foregroundStyle(.secondary)
                    Toggle("Deck ativo", isOn: $store.config.enabled).toggleStyle(.switch).labelsHidden()
                }
                .help("Liga e desliga o deck em todo o sistema")
            }
        }
        .sheet(isPresented: $showProfiles) { ProfilesSheet().environmentObject(store) }
        .onAppear {
            NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { n in
                guard let w = n.object as? NSWindow, w.title == "NumpadDeck" else { return }
                DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }
            }
            if Snapshot.dir != nil {
                if let s = snapshotSlot { store.selectedSlotID = s }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { Snapshot.runIfRequested(window: NSApp.windows.first { $0.isVisible }) }
            }
        }
    }
}

struct ProfilePicker: View {
    @EnvironmentObject var store: DeckStore
    @Binding var showProfiles: Bool

    var body: some View {
        Menu {
            ForEach(store.profiles) { p in
                Button {
                    store.selectedProfileID = p.id
                } label: {
                    if p.id == store.selectedProfileID { Label(p.name, systemImage: "checkmark") } else { Text(p.name) }
                }
            }
            Divider()
            Button("Gerenciar perfis…") { showProfiles = true }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: store.selectedProfile.isDefault ? "rectangle.3.group" : "app.badge.checkmark")
                Text(store.selectedProfile.name).fontWeight(.medium)
            }
        }
        .help("Perfil que você está editando")
    }
}

/// One glance: is the deck live, and for which app?
struct StatusPill: View {
    @EnvironmentObject var store: DeckStore

    private var state: (text: String, color: Color, symbol: String) {
        if !store.accessibilityGranted { return ("Precisa de permissão de Acessibilidade", .orange, "exclamationmark.shield") }
        if !store.config.enabled { return ("Deck pausado", .secondary, "pause.circle") }
        if store.testMode { return ("Modo teste — nada é executado", .purple, "flask") }
        let app = store.frontmostAppName.isEmpty ? "" : " · \(store.frontmostAppName)"
        return ("Ativo: \(store.activeProfile.name)\(app)", .green, "dot.radiowaves.left.and.right")
    }

    var body: some View {
        let s = state
        HStack(spacing: 6) {
            Image(systemName: s.symbol).foregroundStyle(s.color)
            Text(s.text).lineLimit(1)
            if !store.lastEvent.isEmpty {
                Text("·").foregroundStyle(.tertiary)
                Text(store.lastEvent).foregroundStyle(.secondary).lineLimit(1)
                    .transition(.opacity)
                    .id(store.lastEvent)
            }
        }
        .font(.callout)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.quaternary.opacity(0.5), in: Capsule())
        .animation(.easeOut(duration: 0.2), value: store.lastEvent)
        .frame(maxWidth: 520)
    }
}
