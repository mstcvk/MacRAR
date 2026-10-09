import AppKit

/// Uygulama kimliği (GitHub sürümü "MacRAR", App Store sürümü "Easy Mac Archiver")
enum AppInfo {
    static let name: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "MacRAR"
    static var isAppStore: Bool {
        #if APPSTORE
        return true
        #else
        return false
        #endif
    }
    static var supportDir: String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.path
        return (base as NSString).appendingPathComponent(name)
    }
}

/// RARLAB "RAR for macOS" aracı. Lisansı gereği uygulamayla dağıtılmaz; kullanıcı kendisi indirir.
/// App Store sürümünde hiç kullanılmaz (Apple kuralı 2.5.2).
enum RarTools {
    static let downloadPage = URL(string: "https://www.rarlab.com/download.htm")!
    static var installDir: String { (AppInfo.supportDir as NSString).appendingPathComponent("rar") }

    static var rarURL: URL? {
        #if APPSTORE
        return nil
        #else
        var candidates: [String] = []
        if let custom = UserDefaults.standard.string(forKey: "RarPath"), !custom.isEmpty { candidates.append(custom) }
        candidates += [(installDir as NSString).appendingPathComponent("rar"), "/usr/local/bin/rar", "/opt/homebrew/bin/rar"]
        for c in candidates where FileManager.default.isExecutableFile(atPath: c) { return URL(fileURLWithPath: c) }
        return nil
        #endif
    }

    static var available: Bool { rarURL != nil }

    /// "RAR 7.23" gibi; çalışmazsa nil
    static var version: String? {
        guard let url = rarURL else { return nil }
        let p = Process()
        p.executableURL = url
        p.arguments = []
        let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = pipe; p.standardInput = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        p.waitUntilExit()
        for line in out.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("RAR ") { return t.components(separatedBy: "  ").first }
        }
        return nil
    }

    /// RAR yoksa kullanıcıyı indirme ve seçme adımlarına yönlendirir. true → artık kullanılabilir.
    @discardableResult
    static func ensureAvailable() -> Bool {
        if available { return true }
        #if APPSTORE
        return false
        #else
        Dialogs.activate()
        let alert = NSAlert()
        alert.messageText = L("RAR aracı gerekli")
        alert.informativeText = L("RAR biçiminde arşiv oluşturmak veya RAR arşivini değiştirmek için RARLAB'ın “RAR for macOS” aracı gerekir (ücretli, 40 gün denenebilir). Lisansı gereği uygulamayla birlikte dağıtılamıyor.\n\n1. İndirme sayfasından “RAR for macOS ARM” (Apple Silicon) veya “RAR for macOS x64” (Intel) dosyasını indirin.\n2. “İndirdiğim Dosyayı Seç…” ile o dosyayı gösterin.\n\nRAR açmak, ZIP, 7z ve TAR için bu araç gerekmez.")
        alert.addButton(withTitle: L("İndirdiğim Dosyayı Seç…"))
        alert.addButton(withTitle: L("İndirme Sayfasını Aç"))
        alert.addButton(withTitle: L("İptal"))
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return chooseAndInstall()
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(downloadPage)
            let wait = NSAlert()
            wait.messageText = L("İndirme bitince dosyayı seçin")
            wait.informativeText = L("Tarayıcıda “RAR for macOS” dosyasını indirdikten sonra “Dosyayı Seç…” düğmesine basın.")
            wait.addButton(withTitle: L("Dosyayı Seç…"))
            wait.addButton(withTitle: L("İptal"))
            Dialogs.activate()
            return wait.runModal() == .alertFirstButtonReturn ? chooseAndInstall() : false
        default:
            return false
        }
        #endif
    }

    #if !APPSTORE
    private static func chooseAndInstall() -> Bool {
        let panel = NSOpenPanel()
        panel.title = L("RAR for macOS dosyasını seçin")
        panel.message = L("İndirdiğiniz rarmacos-….tar.gz dosyasını, onu açtığınız “rar” klasörünü ya da içindeki “rar” programını seçin.")
        panel.prompt = L("Kur")
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        Dialogs.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do {
            try install(from: url)
            Dialogs.info(L("RAR aracı kuruldu"), LF("%@ hazır. Artık RAR arşivi oluşturabilirsiniz.", version ?? "RAR"))
            return true
        } catch {
            Dialogs.error(L("RAR aracı kurulamadı"), error.localizedDescription)
            return false
        }
    }

    struct InstallError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func install(from url: URL) throws {
        let fm = FileManager.default
        var sourceDir: String?
        var tmp: String?
        let lower = url.lastPathComponent.lowercased()
        if lower.hasSuffix(".tar.gz") || lower.hasSuffix(".tgz") {
            let t = TempDirs.make("rar-install")
            try fm.createDirectory(atPath: t, withIntermediateDirectories: true)
            tmp = t
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            p.arguments = ["-xzf", url.path, "-C", t]
            p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
            try p.run(); p.waitUntilExit()
            guard p.terminationStatus == 0 else { throw InstallError(message: L("Dosya açılamadı. Bozuk ya da farklı bir dosya olabilir.")) }
            sourceDir = findRarDir(in: t)
        } else if isDirectoryPath(url.path) {
            sourceDir = findRarDir(in: url.path)
        } else if url.lastPathComponent == "rar" {
            sourceDir = url.deletingLastPathComponent().path
        }
        defer { if let tmp { try? fm.removeItem(atPath: tmp) } }
        guard let src = sourceDir else {
            throw InstallError(message: L("Seçilen yerde “rar” programı bulunamadı. RARLAB'dan indirdiğiniz “RAR for macOS” dosyasını seçin."))
        }
        try? fm.removeItem(atPath: installDir)
        try fm.createDirectory(atPath: installDir, withIntermediateDirectories: true)
        for name in ["rar", "default.sfx", "rarfiles.lst", "license.txt", "rar.txt", "whatsnew.txt", "acknow.txt", "order.htm"] {
            let s = (src as NSString).appendingPathComponent(name)
            if fm.fileExists(atPath: s) { try fm.copyItem(atPath: s, toPath: (installDir as NSString).appendingPathComponent(name)) }
        }
        let rar = (installDir as NSString).appendingPathComponent("rar")
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: rar)
        let sfx = (installDir as NSString).appendingPathComponent("default.sfx")
        if fm.fileExists(atPath: sfx) { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: sfx) }
        // Kullanıcının kendi seçtiği araç: indirme karantinasını kaldır
        let x = Process()
        x.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        x.arguments = ["-dr", "com.apple.quarantine", installDir]
        x.standardOutput = FileHandle.nullDevice; x.standardError = FileHandle.nullDevice
        try? x.run(); x.waitUntilExit()
        UserDefaults.standard.removeObject(forKey: "RarPath")
        guard version != nil else {
            try? fm.removeItem(atPath: installDir)
            throw InstallError(message: L("RAR aracı bu Mac'te çalışmadı. Mac'inize uygun sürümü (Apple Silicon için ARM, Intel için x64) indirdiğinizden emin olun."))
        }
    }

    private static func findRarDir(in dir: String) -> String? {
        let fm = FileManager.default
        for candidate in [dir, (dir as NSString).appendingPathComponent("rar")] {
            if fm.isExecutableFile(atPath: (candidate as NSString).appendingPathComponent("rar")),
               !isDirectoryPath((candidate as NSString).appendingPathComponent("rar")) { return candidate }
        }
        if let e = fm.enumerator(atPath: dir) {
            while let rel = e.nextObject() as? String {
                if (rel as NSString).lastPathComponent == "rar" {
                    let full = (dir as NSString).appendingPathComponent(rel)
                    if !isDirectoryPath(full), fm.isExecutableFile(atPath: full) { return (full as NSString).deletingLastPathComponent }
                }
            }
        }
        return nil
    }

    static func uninstall() {
        try? FileManager.default.removeItem(atPath: installDir)
        UserDefaults.standard.removeObject(forKey: "RarPath")
    }
    #endif
}
