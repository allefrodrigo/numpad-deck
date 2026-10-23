import AppKit
import Combine

/// App icons and website favicons for keycaps. Favicons are fetched once and cached on disk.
@MainActor
final class IconProvider: ObservableObject {
    static let shared = IconProvider()
    @Published private(set) var favicons: [String: NSImage] = [:]
    private var inflight = Set<String>()

    private let cacheDir: URL = {
        let d = DeckStore.fileURL.deletingLastPathComponent().appendingPathComponent("favicons", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    func image(for action: KeyAction) -> NSImage? {
        switch action {
        case .openApp(let path):
            guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return nil }
            return NSWorkspace.shared.icon(forFile: path)
        case .openURL(let url):
            guard let host = Self.host(of: url) else { return nil }
            if let img = favicons[host] { return img }
            fetch(host: host)
            return nil
        default:
            return nil
        }
    }

    static func host(of raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        if !s.contains("://") { s = "https://" + s }
        guard let u = URL(string: s), let h = u.host, h.contains(".") else { return nil }
        return h.lowercased()
    }

    private func fetch(host: String) {
        guard !inflight.contains(host) else { return }
        let file = cacheDir.appendingPathComponent(host + ".png")
        if let img = NSImage(contentsOf: file) { favicons[host] = img; return }
        inflight.insert(host)
        // Google's service only knows crawled domains (subdomains often 404), so the site itself
        // comes first. Last resort: the icon of the registrable root domain.
        let root = Self.rootDomain(of: host)
        var candidates = [
            "https://\(host)/apple-touch-icon.png",
            "https://\(host)/favicon.ico",
            "https://www.google.com/s2/favicons?domain=\(host)&sz=128",
        ]
        if root != host { candidates.append("https://www.google.com/s2/favicons?domain=\(root)&sz=128") }
        Task {
            defer { inflight.remove(host) }
            for c in candidates {
                guard let url = URL(string: c),
                      let (data, resp) = try? await URLSession.shared.data(from: url),
                      (resp as? HTTPURLResponse)?.statusCode == 200,
                      let img = NSImage(data: data), img.size.width > 0 else { continue }
                try? data.write(to: file)
                favicons[host] = img
                return
            }
        }
    }

    /// "tickets.foodwise.app.br" -> "foodwise.app.br"; "mail.google.com" -> "google.com".
    static func rootDomain(of host: String) -> String {
        let parts = host.split(separator: ".").map(String.init)
        guard parts.count > 2 else { return host }
        let ccSLD: Set<String> = ["com", "net", "org", "gov", "edu", "app", "co"]
        let keep = (parts.count >= 3 && parts[parts.count - 1].count == 2 && ccSLD.contains(parts[parts.count - 2])) ? 3 : 2
        return parts.suffix(keep).joined(separator: ".")
    }
}
