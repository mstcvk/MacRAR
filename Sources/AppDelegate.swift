import AppKit
import UniformTypeIdentifiers

enum Command {
    case extractHere([String])
    case extractFolder([String])
    case extractTo([String])
    case test([String])
    case compress([String])
    case compressDialog([String])
    case setDefault
    case installQuickActions
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!

    var windows: [ArchiveWindowController] = []
    var pendingCommand: Command?
    var pendingFiles: [String] = []
    private var launched = false
    var headless: Bool { pendingCommand != nil }

    static func isArchive(_ path: String) -> Bool { Formats.isArchive(path) }

    // MARK: Yaşam döngüsü

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        launched = true
        scheduleDebugSnapshot()
        if let cmd = pendingCommand {
            NSApp.activate(ignoringOtherApps: true)
            runCommand(cmd)
            return
        }
        let files = pendingFiles
        pendingFiles = []
        if files.isEmpty {
            if windows.isEmpty { showEmptyWindow() }
        } else {
            handleOpen(files)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        if let log = ProcessInfo.processInfo.environment["MACRAR_DEBUG_LOG"] {
            let line = "\(Date().timeIntervalSince1970) openFiles(\(filenames.count)): \(filenames.map { ($0 as NSString).lastPathComponent }) launched=\(launched) modal=\(NSApp.modalWindow != nil)\n"
            if let h = FileHandle(forWritingAtPath: log) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); h.closeFile() }
            else { try? line.write(toFile: log, atomically: true, encoding: .utf8) }
        }
        // Finder'a hemen yanıt ver; dosyaları Apple olayı işleyicisinin dışında, modal pencere yokken işle
        sender.reply(toOpenOrPrint: .success)
        if launched {
            scheduleOpen(filenames)
        } else {
            pendingFiles += filenames
        }
    }

    private var queuedFiles: [String] = []
    private func scheduleOpen(_ files: [String]) {
        queuedFiles += files
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.flushQueuedFiles() }
    }
    private func flushQueuedFiles() {
        guard !queuedFiles.isEmpty else { return }
        if NSApp.modalWindow != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.flushQueuedFiles() }
            return
        }
        let files = queuedFiles
        queuedFiles = []
        handleOpen(files)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !headless }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, !headless { showEmptyWindow() }
        return true
    }

    // MARK: Pencereler

    @discardableResult
    func showEmptyWindow() -> ArchiveWindowController {
        let wc = ArchiveWindowController()
        windows.append(wc)
        wc.showWindow(nil)
        return wc
    }

    func windowClosed(_ wc: ArchiveWindowController) {
        windows.removeAll { $0 === wc }
    }

    static func resolved(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }

    func handleOpen(_ rawFiles: [String]) {
        // Aynı dosya hem argüman hem de LaunchServices üzerinden gelebilir → tekilleştir
        var seen = Set<String>()
        let files = rawFiles.map { Self.resolved($0) }.filter { seen.insert($0).inserted }
        let archives = files.filter { Self.isArchive($0) }
        let others = files.filter { !Self.isArchive($0) }
        for a in archives { openArchive(a, reuse: nil) }
        if !others.isEmpty {
            compressWithDialog(items: others, host: nil) { [weak self] path in
                if let path { self?.openArchive(path, reuse: nil) }
                else if self?.windows.isEmpty == true { self?.showEmptyWindow() }
            }
        }
    }

    func openArchive(_ path: String, reuse: ArchiveWindowController?) {
        let path = Self.resolved(path)
        if let existing = windows.first(where: { $0.archivePath.map(Self.resolved) == path }) {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        let wc: ArchiveWindowController
        if let reuse, reuse.info == nil {
            wc = reuse
        } else if let empty = windows.first(where: { $0.info == nil && $0.archivePath == nil }) {
            wc = empty
        } else {
            wc = ArchiveWindowController()
            windows.append(wc)
        }
        wc.showWindow(nil)
        wc.window?.makeKeyAndOrderFront(nil)
        wc.open(path)
        if wc.info == nil, windows.count > 1 { wc.close() }
    }

    /// Seçenek penceresi gösterip sıkıştırır. completion(oluşan arşiv yolu / nil)
    func compressWithDialog(items: [String], host: NSWindow?, completion: @escaping (String?) -> Void) {
        let opts = CompressOptions(archivePath: CompressOptions.defaultArchivePath(for: items))
        guard let chosen = CompressDialog(options: opts, itemCount: items.count).run() else { completion(nil); return }
        Ops.compress(items: items, options: chosen, host: host) { ok, path in
            completion(ok ? path : nil)
        }
    }

    // MARK: Komut satırı / Finder hızlı eylem modu

    private func runCommand(_ cmd: Command) {
        switch cmd {
        case .setDefault:
            setDefaultHandler { _ in NSApp.terminate(nil) }
        case .installQuickActions:
            let n = QuickActions.installAll()
            print("\(n) hızlı eylem kuruldu: \(QuickActions.servicesDir)")
            NSApp.terminate(nil)
        case .extractHere(let a):
            processArchives(Self.dedupeVolumes(a), dest: { ($0 as NSString).deletingLastPathComponent })
        case .extractFolder(let a):
            processArchives(Self.dedupeVolumes(a), dest: { Ops.folderNamedAfterArchive($0) })
        case .extractTo(let a):
            let list = Self.dedupeVolumes(a)
            guard let first = list.first,
                  let d = Dialogs.chooseFolder(title: "Nereye çıkartılsın?", prompt: "Çıkart",
                                               initial: (first as NSString).deletingLastPathComponent) else {
                NSApp.terminate(nil); return
            }
            processArchives(list, dest: { _ in d })
        case .test(let a):
            testArchives(Self.dedupeVolumes(a))
        case .compress(let items):
            let existing = items.filter { FileManager.default.fileExists(atPath: $0) }
            guard !existing.isEmpty else { NSApp.terminate(nil); return }
            var opts = CompressOptions(archivePath: CompressOptions.defaultArchivePath(for: existing))
            // Hata ayıklama: MACRAR_DEBUG_FORMAT=zip|7z|tar.gz… ve MACRAR_DEBUG_PASSWORD ile biçim/şifre seçimi
            if let f = ProcessInfo.processInfo.environment["MACRAR_DEBUG_FORMAT"],
               let fmt = ArchiveFormat.allCases.first(where: { $0.ext == f }) {
                opts.format = fmt
                opts.archivePath = CompressOptions.defaultArchivePath(for: existing, format: fmt)
                opts.password = ProcessInfo.processInfo.environment["MACRAR_DEBUG_PASSWORD"]
                opts.encryptNames = ProcessInfo.processInfo.environment["MACRAR_DEBUG_ENCNAMES"] != nil
            }
            Ops.compress(items: existing, options: opts, host: nil) { _, _ in NSApp.terminate(nil) }
        case .compressDialog(let items):
            let existing = items.filter { FileManager.default.fileExists(atPath: $0) }
            guard !existing.isEmpty else { NSApp.terminate(nil); return }
            compressWithDialog(items: existing, host: nil) { _ in NSApp.terminate(nil) }
        }
    }

    /// Çok parçalı arşivlerde yalnızca ilk parçayı bırakır (ad.part2.rar, ad.7z.002 vb. atlanır)
    static func dedupeVolumes(_ paths: [String]) -> [String] {
        let regex = try! NSRegularExpression(pattern: #"^(.*)\.(?:part(\d+)\.rar|(?:7z|zip|rar|tar|bin)\.(\d{3}))$"#, options: .caseInsensitive)
        var best: [String: (Int, String)] = [:]
        var order: [String] = []
        var result: [String] = []
        for p in paths {
            let ns = p as NSString
            if let m = regex.firstMatch(in: p, range: NSRange(location: 0, length: ns.length)) {
                let base = ns.substring(with: m.range(at: 1))
                let numRange = m.range(at: 2).location != NSNotFound ? m.range(at: 2) : m.range(at: 3)
                let num = Int(ns.substring(with: numRange)) ?? 0
                if let cur = best[base] {
                    if num < cur.0 { best[base] = (num, p) }
                } else {
                    best[base] = (num, p)
                    order.append(base)
                }
            } else {
                result.append(p)
            }
        }
        for b in order { if let v = best[b] { result.append(v.1) } }
        return result
    }

    private func processArchives(_ archives: [String], dest: @escaping (String) -> String, index: Int = 0) {
        guard index < archives.count else { NSApp.terminate(nil); return }
        let a = archives[index]
        var pw: String? = nil
        guard let info = Ops.listInteractive(archive: a, password: &pw) else {
            processArchives(archives, dest: dest, index: index + 1)
            return
        }
        Ops.extract(info: info, names: nil, dest: dest(a), password: pw, host: nil) { [weak self] _, _ in
            self?.processArchives(archives, dest: dest, index: index + 1)
        }
    }

    private func testArchives(_ archives: [String], index: Int = 0) {
        guard index < archives.count else { NSApp.terminate(nil); return }
        let a = archives[index]
        var pw: String? = nil
        guard let info = Ops.listInteractive(archive: a, password: &pw) else {
            testArchives(archives, index: index + 1)
            return
        }
        Ops.test(info: info, password: pw, host: nil) { [weak self] _, _ in
            self?.testArchives(archives, index: index + 1)
        }
    }

    // MARK: Hata ayıklama: MACRAR_SNAPSHOT=/yol/önek → açık pencereleri PNG olarak kaydedip çıkar

    private func scheduleDebugSnapshot() {
        guard let prefix = ProcessInfo.processInfo.environment["MACRAR_SNAPSHOT"] else { return }
        let delay = Double(ProcessInfo.processInfo.environment["MACRAR_SNAPSHOT_DELAY"] ?? "") ?? 2.0
        let timer = Timer(timeInterval: delay, repeats: false) { _ in
            var i = 0
            for w in NSApp.windows where w.isVisible {
                guard let frame = w.contentView?.superview else { continue }
                func dump(_ v: NSView) {
                    if let p = v as? NSProgressIndicator { print("progress bar value:", p.doubleValue, "indeterminate:", p.isIndeterminate) }
                    v.subviews.forEach(dump)
                }
                dump(frame)
                guard let rep = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else { continue }
                frame.cacheDisplay(in: frame.bounds, to: rep)
                if let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: "\(prefix)-\(i).png"))
                    i += 1
                }
            }
            exit(0)
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    // MARK: Varsayılan uygulama

    func setDefaultHandler(extensions: [String] = ["rar"], completion: @escaping (Error?) -> Void) {
        var types: [UTType] = []
        for e in extensions {
            if e == "rar", let t = UTType("com.rarlab.rar-archive") { types.append(t); continue }
            if let t = UTType(filenameExtension: e) { types.append(t) }
        }
        func next(_ i: Int) {
            guard i < types.count else { completion(nil); return }
            NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: types[i]) { err in
                DispatchQueue.main.async {
                    if let err { completion(err) } else { next(i + 1) }
                }
            }
        }
        next(0)
    }

    @objc func makeDefaultForAll(_ sender: Any?) {
        setDefaultHandler(extensions: ["rar", "zip", "7z", "tar", "gz", "tgz", "bz2", "xz", "zst", "cab", "iso", "lzh", "arj"]) { err in
            if let err {
                Dialogs.error("Varsayılan uygulama ayarlanamadı", err.localizedDescription)
            } else {
                Dialogs.info("Tamam", "MacRAR artık yaygın arşiv biçimleri için varsayılan uygulama.")
            }
        }
    }

    @objc func makeDefault(_ sender: Any?) {
        setDefaultHandler { err in
            if let err {
                Dialogs.error("Varsayılan uygulama ayarlanamadı", err.localizedDescription)
            } else {
                Dialogs.info("Tamam", "MacRAR artık .rar dosyaları için varsayılan uygulama.")
            }
        }
    }

    @objc func installQuickActionsAction(_ sender: Any?) {
        let n = QuickActions.installAll()
        Dialogs.info("Finder hızlı eylemleri yüklendi", "\(n) hızlı eylem kuruldu. Finder'da bir dosyaya sağ tıklayıp \"Hızlı Eylemler\" menüsünden kullanabilirsiniz.")
    }

    // MARK: Menü

    private func buildMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem(); main.addItem(appItem)
        let app = NSMenu()
        app.addItem(withTitle: "MacRAR Hakkında", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "RAR Dosyaları İçin Varsayılan Uygulama Yap", action: #selector(makeDefault(_:)), keyEquivalent: "")
        app.addItem(withTitle: "Tüm Arşivler (ZIP, 7z, TAR…) İçin Varsayılan Yap", action: #selector(makeDefaultForAll(_:)), keyEquivalent: "")
        app.addItem(withTitle: "Finder Hızlı Eylemlerini (Yeniden) Yükle", action: #selector(installQuickActionsAction(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "MacRAR'ı Gizle", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = app.addItem(withTitle: "Diğerlerini Gizle", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: "Tümünü Göster", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "MacRAR'dan Çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = app

        let fileItem = NSMenuItem(); main.addItem(fileItem)
        let file = NSMenu(title: "Dosya")
        file.addItem(withTitle: "Arşiv Aç…", action: #selector(ArchiveWindowController.openArchive(_:)), keyEquivalent: "o")
        file.addItem(withTitle: "Yeni Arşiv Oluştur…", action: #selector(ArchiveWindowController.newArchive(_:)), keyEquivalent: "n")
        file.addItem(.separator())
        file.addItem(withTitle: "Buraya Çıkart", action: #selector(ArchiveWindowController.extractHere(_:)), keyEquivalent: "e")
        let ef = file.addItem(withTitle: "Klasöre Çıkart", action: #selector(ArchiveWindowController.extractToFolder(_:)), keyEquivalent: "e")
        ef.keyEquivalentModifierMask = [.command, .option]
        let et = file.addItem(withTitle: "Şuraya Çıkart…", action: #selector(ArchiveWindowController.extractTo(_:)), keyEquivalent: "e")
        et.keyEquivalentModifierMask = [.command, .shift]
        file.addItem(withTitle: "Seçilenleri Buraya Çıkart", action: #selector(ArchiveWindowController.extractSelectedHere(_:)), keyEquivalent: "")
        file.addItem(withTitle: "Seçilenleri Şuraya Çıkart…", action: #selector(ArchiveWindowController.extractSelectedTo(_:)), keyEquivalent: "")
        file.addItem(.separator())
        file.addItem(withTitle: "Arşivi Test Et", action: #selector(ArchiveWindowController.testArchive(_:)), keyEquivalent: "t")
        file.addItem(withTitle: "Arşiv Bilgisi", action: #selector(ArchiveWindowController.showInfo(_:)), keyEquivalent: "i")
        file.addItem(.separator())
        let add = file.addItem(withTitle: "Arşive Dosya Ekle…", action: #selector(ArchiveWindowController.addFiles(_:)), keyEquivalent: "a")
        add.keyEquivalentModifierMask = [.command, .shift]
        file.addItem(withTitle: "Seçilenleri Arşivden Sil", action: #selector(ArchiveWindowController.deleteSelected(_:)), keyEquivalent: "\u{8}")
        file.addItem(.separator())
        file.addItem(withTitle: "Kapat", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = file

        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: "Düzen")
        edit.addItem(withTitle: "Geri Al", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Yinele", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Kes", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Kopyala", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Yapıştır", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Tümünü Seç", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit

        let winItem = NSMenuItem(); main.addItem(winItem)
        let win = NSMenu(title: "Pencere")
        win.addItem(withTitle: "Küçült", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        win.addItem(withTitle: "Büyüt", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        win.addItem(.separator())
        win.addItem(withTitle: "Tümünü Öne Getir", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        winItem.submenu = win
        NSApp.windowsMenu = win

        NSApp.mainMenu = main
    }
}
