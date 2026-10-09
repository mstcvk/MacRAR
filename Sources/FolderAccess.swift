import AppKit

/// App Store (sandbox) sürümünde klasör izinleri: kullanıcı bir klasörü bir kez seçer, güvenlik kapsamlı
/// yer imi olarak saklanır. GitHub sürümünde her şey serbesttir, bu tür hiçbir şey sormaz.
enum FolderAccess {
    private static let key = "FolderBookmarks"
    private static var active: [URL] = []

    /// Açılışta kayıtlı izinleri etkinleştir
    static func restore() {
        #if APPSTORE
        let datas = UserDefaults.standard.array(forKey: key) as? [Data] ?? []
        var keep: [Data] = []
        for d in datas {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: d, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) else { continue }
            if url.startAccessingSecurityScopedResource() { active.append(url) }
            if stale, let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                keep.append(fresh)
            } else {
                keep.append(d)
            }
        }
        UserDefaults.standard.set(keep, forKey: key)
        #endif
    }

    static var grantedFolders: [String] { active.map { $0.path } }

    static func existingAncestor(of path: String) -> String {
        var p = path
        while !p.isEmpty, p != "/", !FileManager.default.fileExists(atPath: p) { p = (p as NSString).deletingLastPathComponent }
        return p.isEmpty ? "/" : p
    }

    static func canRead(_ dir: String) -> Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: dir)) != nil
    }

    static func canWrite(_ dir: String) -> Bool {
        let probe = (dir as NSString).appendingPathComponent(".archiver-probe-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: probe, contents: Data()) else { return false }
        try? FileManager.default.removeItem(atPath: probe)
        return true
    }

    /// Gerekiyorsa izin ister. false → kullanıcı vazgeçti.
    @discardableResult
    static func ensure(_ dir: String, write: Bool) -> Bool {
        #if APPSTORE
        if write ? canWrite(dir) : canRead(dir) { return true }
        Dialogs.activate()
        let panel = NSOpenPanel()
        panel.title = L("Klasör izni")
        panel.message = LF("%@, “%@” klasörüne erişmek için izninizi istiyor. Bu klasörü (ya da her seferinde sorulmaması için ana klasörünüzü) seçip “İzin Ver”e basın.", AppInfo.name, (dir as NSString).lastPathComponent)
        panel.prompt = L("İzin Ver")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: dir)
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        remember(url)
        return write ? canWrite(dir) : canRead(dir)
        #else
        return true
        #endif
    }

    /// Ayarlar'dan: ana klasöre bir kez izin ver
    static func grantHome() {
        #if APPSTORE
        let panel = NSOpenPanel()
        panel.title = L("Klasör izni")
        panel.message = L("Ana klasörünüz seçili. “İzin Ver”e basarak altındaki tüm klasörlerde sormadan çalışmasına izin verebilirsiniz.")
        panel.prompt = L("İzin Ver")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = URL(fileURLWithPath: AppInfo.realHome)
        Dialogs.activate()
        if panel.runModal() == .OK, let url = panel.url { remember(url) }
        #endif
    }

    static func resetAll() {
        for u in active { u.stopAccessingSecurityScopedResource() }
        active = []
        UserDefaults.standard.removeObject(forKey: key)
    }

    private static func remember(_ url: URL) {
        guard let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) else { return }
        var list = UserDefaults.standard.array(forKey: key) as? [Data] ?? []
        list.append(data)
        UserDefaults.standard.set(list, forKey: key)
        if url.startAccessingSecurityScopedResource() { active.append(url) }
    }
}
