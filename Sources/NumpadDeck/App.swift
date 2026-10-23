import SwiftUI

@main
struct NumpadDeckApp: App {
    @StateObject private var store = DeckStore()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("NumpadDeck", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 880, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 680)

        MenuBarExtra {
            MenuBarContent(openConfig: {
                NSApp.setActivationPolicy(.regular)
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            })
            .environmentObject(store)
        } label: {
            Image(systemName: store.config.enabled && store.accessibilityGranted ? "square.grid.3x3.fill" : "square.grid.3x3")
                // macOS 27 no longer opens the Window scene at launch for menu-bar apps,
                // so snapshot mode opens it here.
                .onAppear { if Snapshot.dir != nil { openWindow(id: "main") } }
        }
    }
}

struct MenuBarContent: View {
    @EnvironmentObject var store: DeckStore
    var openConfig: () -> Void

    var body: some View {
        Toggle("Deck ativo", isOn: $store.config.enabled)
        Text(store.accessibilityGranted ? "Perfil agora: \(store.activeProfile.name)" : "Sem permissão de Acessibilidade")
        Divider()
        Button("Configurar teclas…", action: openConfig).keyboardShortcut(",")
        Divider()
        Button("Sair do NumpadDeck") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
