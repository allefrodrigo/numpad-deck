import SwiftUI
import UniformTypeIdentifiers

struct ProfilesSheet: View {
    @EnvironmentObject var store: DeckStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationSplitView {
            List(selection: $store.selectedProfileID) {
                ForEach(store.profiles) { p in
                    Label(p.name, systemImage: p.isDefault ? "rectangle.3.group" : "app.badge.checkmark").tag(p.id)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar {
                ToolbarItem { Button { store.addProfile() } label: { Label("Novo perfil", systemImage: "plus") } }
            }
        } detail: {
            ProfileEditor(profile: store.selectedProfile).id(store.selectedProfileID)
        }
        .frame(width: 640, height: 420)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Concluir") { dismiss() } }
        }
    }
}

struct ProfileEditor: View {
    @EnvironmentObject var store: DeckStore
    @State var profile: Profile

    var body: some View {
        Form {
            Section {
                TextField("Nome", text: $profile.name)
            }
            Section {
                if profile.bundleIDs.isEmpty {
                    Text(store.profiles.filter(\.isDefault).count > 1
                         ? "Sem apps: este perfil só entra quando você o escolhe na janela. Adicione um app para ele trocar sozinho."
                         : "Sem apps: é o perfil padrão, usado quando nenhum outro combina com o app na frente.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(profile.bundleIDs, id: \.self) { id in
                    HStack {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 18, height: 18)
                            Text(url.deletingPathExtension().lastPathComponent)
                        } else { Text(id) }
                        Spacer()
                        Button { profile.bundleIDs.removeAll { $0 == id } } label: { Image(systemName: "minus.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Button("Adicionar app…") { pickApp() }
                    if !store.frontmostBundleID.isEmpty && !profile.bundleIDs.contains(store.frontmostBundleID) {
                        Button("Usar \(store.frontmostAppName)") { profile.bundleIDs.append(store.frontmostBundleID) }
                    }
                }
            } header: { Text("Ativa sozinho nestes apps") }

            Section {
                Button("Copiar adesivos do perfil padrão") { store.copyStickers(to: profile); profile = store.selectedProfile }
                if store.profiles.count > 1 {
                    Button("Apagar perfil", role: .destructive) { store.deleteProfile(profile.id) }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: profile) { _, p in store.selectedProfile = p }
    }

    private func pickApp() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.application]
        p.directoryURL = URL(fileURLWithPath: "/Applications")
        p.allowsMultipleSelection = true
        p.prompt = "Adicionar"
        if p.runModal() == .OK {
            for u in p.urls { if let id = Bundle(url: u)?.bundleIdentifier, !profile.bundleIDs.contains(id) { profile.bundleIDs.append(id) } }
        }
    }
}
