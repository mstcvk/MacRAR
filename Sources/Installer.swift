#if !APPSTORE
import AppKit

/// GitHub sürümü: uygulama disk görüntüsünden (DMG), İndirilenler'den ya da Masaüstü'nden çalıştırıldıysa
/// Uygulamalar klasörüne taşımayı önerir. Finder sağ tık komutları ve dosya ilişkilendirmeleri yalnızca
/// /Applications altındaki kopya için kurulur; DMG'deki kopyaya bağlanan hızlı eylemler disk çıkarılınca bozulur.
enum Installer {
    private static let declinedKey = "MoveToApplicationsDeclined"

    static var isInApplications: Bool {
        let p = Bundle.main.bundlePath
        return p.hasPrefix("/Applications/") || p.hasPrefix(AppInfo.realHome + "/Applications/")
    }

    private static var shouldOffer: Bool {
        if isInApplications { return false }
        if ProcessInfo.processInfo.environment["MACRAR_NO_MOVE_PROMPT"] != nil { return false }
        if UserDefaults.standard.bool(forKey: declinedKey) { return false }
        let p = Bundle.main.bundlePath
        let home = AppInfo.realHome
        return p.hasPrefix("/Volumes/") || p.hasPrefix(home + "/Downloads/") || p.hasPrefix(home + "/Desktop/")
    }

    /// true → kopya /Applications'a taşındı ve oradan yeniden başlatılıyor; çağıran yer başka iş yapmadan dönmeli.
    static func offerMoveIfNeeded(openingFiles files: [String]) -> Bool {
        guard shouldOffer else { return false }
        Dialogs.activate()
        let src = Bundle.main.bundlePath
        let onDMG = src.hasPrefix("/Volumes/")
        let alert = NSAlert()
        alert.messageText = LF("%@ Uygulamalar klasörüne taşınsın mı?", AppInfo.name)
        alert.informativeText = onDMG
            ? LF("%@ şu anda disk görüntüsünden çalışıyor. Finder sağ tık menüsü ve dosya ilişkilendirmeleri için uygulamanın Uygulamalar klasöründe olması gerekir. Taşıdıktan sonra disk görüntüsünü çıkarabilirsiniz.", AppInfo.name)
            : LF("%@ şu anda “%@” klasöründe. Finder sağ tık menüsü ve dosya ilişkilendirmeleri için uygulamanın Uygulamalar klasöründe olması gerekir.", AppInfo.name, ((src as NSString).deletingLastPathComponent as NSString).lastPathComponent)
        alert.addButton(withTitle: L("Uygulamalar Klasörüne Taşı"))
        alert.addButton(withTitle: L("Buradan Çalıştır"))
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = L("Bir daha sorma")
        let resp = alert.runModal()
        if alert.suppressionButton?.state == .on { UserDefaults.standard.set(true, forKey: declinedKey) }
        guard resp == .alertFirstButtonReturn else { return false }
        do {
            let dest = try move(from: src)
            relaunch(at: dest, files: files)
            return true
        } catch {
            Dialogs.error(L("Uygulamalar klasörüne taşınamadı"), error.localizedDescription)
            return false
        }
    }

    private static func move(from src: String) throws -> String {
        let fm = FileManager.default
        let dest = "/Applications/" + (src as NSString).lastPathComponent
        if fm.fileExists(atPath: dest) { try fm.removeItem(atPath: dest) }   // eski sürümün üzerine yaz
        try fm.copyItem(atPath: src, toPath: dest)
        // Disk görüntüsü salt okunurdur; İndirilenler/Masaüstü'ndeki kopya çöpe gider (çalışan süreç etkilenmez)
        if !src.hasPrefix("/Volumes/") { try? fm.trashItem(at: URL(fileURLWithPath: src), resultingItemURL: nil) }
        return dest
    }

    private static func relaunch(at dest: String, files: [String]) {
        let url = URL(fileURLWithPath: dest)
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.createsNewApplicationInstance = true
        cfg.activates = true
        let done: (NSRunningApplication?, Error?) -> Void = { _, _ in DispatchQueue.main.async { NSApp.terminate(nil) } }
        if files.isEmpty {
            NSWorkspace.shared.openApplication(at: url, configuration: cfg, completionHandler: done)
        } else {
            NSWorkspace.shared.open(files.map { URL(fileURLWithPath: $0) }, withApplicationAt: url, configuration: cfg, completionHandler: done)
        }
    }
}
#endif
