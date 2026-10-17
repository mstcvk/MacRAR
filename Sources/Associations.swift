import AppKit
import UniformTypeIdentifiers

/// "Hangi dosyalar bu uygulamayla açılsın?" penceresi: ilk açılışta bir kez, sonra menüden.
enum Associations {
    struct Group {
        let title: String
        let exts: [String]
        let defaultOn: Bool
        let warning: String?
    }

    static var groups: [Group] {
        [
            // macOS her tür için ayrı onay ister: seçili gelenler en yaygın 4 türle sınırlı
            Group(title: "RAR", exts: ["rar"], defaultOn: true, warning: nil),
            Group(title: "ZIP", exts: ["zip"], defaultOn: true, warning: nil),
            Group(title: "7z", exts: ["7z"], defaultOn: true, warning: nil),
            Group(title: "GZ, TAR.GZ", exts: ["gz"], defaultOn: true, warning: nil),
            Group(title: L("Diğer arşivler: TAR, TGZ, BZ2, XZ, ZST, ZIPX, CAB, LZH, ARJ, CPIO…"),
                  exts: ["tar", "tgz", "bz2", "tbz2", "xz", "txz", "zst", "lz4", "lzma", "zipx", "cab", "lzh", "lha", "arj", "cpio", "z"], defaultOn: false, warning: nil),
            Group(title: L("Disk görüntüleri: ISO, DMG, VHD, VMDK"), exts: ["iso", "dmg", "vhd", "vmdk"], defaultOn: false,
                  warning: L("Önerilmez: çift tıklayınca disk bağlanmaz, arşiv gibi açılır.")),
            Group(title: L("Paketler: PKG, JAR, APK, DEB, RPM, MSI"), exts: ["pkg", "jar", "apk", "deb", "rpm", "msi"], defaultOn: false,
                  warning: L("Önerilmez: çift tıklayınca kurulum/çalıştırma yerine arşiv olarak açılır.")),
        ]
    }

    static func isMine(_ t: UTType) -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(toOpen: t) else { return false }
        return url.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL
    }

    private static let shownKey = "AssociationPromptShown"
    static var alreadyShown: Bool { UserDefaults.standard.bool(forKey: shownKey) }

    /// Bir türü üstlenirken o anki uygulaması burada saklanır ([UTI: uygulama yolu]); işaret kaldırılınca ona dönülür
    private static let previousKey = "AssociationPreviousHandlers"

    static func types(for exts: [String]) -> [UTType] {
        var seen = Set<String>(); var out: [UTType] = []
        for e in exts {
            let t: UTType? = e == "rar" ? (UTType("com.rarlab.rar-archive") ?? UTType(filenameExtension: e)) : UTType(filenameExtension: e)
            if let t, !t.identifier.hasPrefix("dyn."), seen.insert(t.identifier).inserted { out.append(t) }
        }
        return out
    }

    /// Bu türün şu anki varsayılan uygulamasının adı
    static func currentHandler(for exts: [String]) -> String {
        guard let t = types(for: exts).first, let url = NSWorkspace.shared.urlForApplication(toOpen: t) else { return L("yok") }
        if url.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL { return AppInfo.name }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    /// Bu tür MacRAR'a verilmeden önceki uygulama; kayıt yoksa türü açabilen sistem uygulaması, o da yoksa ilk aday
    static func previousHandler(for t: UTType) -> URL? {
        let saved = UserDefaults.standard.dictionary(forKey: previousKey) as? [String: String]
        if let p = saved?[t.identifier], FileManager.default.fileExists(atPath: p) { return URL(fileURLWithPath: p) }
        let me = Bundle.main.bundleURL.standardizedFileURL
        let others = NSWorkspace.shared.urlsForApplications(toOpen: t).filter { $0.standardizedFileURL != me }
        return others.first { $0.path.hasPrefix("/System/") } ?? others.first
    }

    private static func rememberPrevious(for t: UTType) {
        guard let url = NSWorkspace.shared.urlForApplication(toOpen: t),
              url.standardizedFileURL != Bundle.main.bundleURL.standardizedFileURL else { return }
        var saved = (UserDefaults.standard.dictionary(forKey: previousKey) as? [String: String]) ?? [:]
        saved[t.identifier] = url.path
        UserDefaults.standard.set(saved, forKey: previousKey)
    }

    /// İlk açılışta (bir kez) göster
    static func promptIfFirstLaunch() {
        if alreadyShown { return }
        UserDefaults.standard.set(true, forKey: shownKey)
        show(firstLaunch: true)
    }

    @discardableResult
    static func show(firstLaunch: Bool = false) -> Bool {
        Dialogs.activate()
        let alert = NSAlert()
        alert.messageText = LF("Hangi dosyalar %@ ile açılsın?", AppInfo.name)
        alert.informativeText = (firstLaunch
            ? L("Seçtiğiniz dosya türlerine çift tıklayınca bu uygulama açılır. Daha sonra menüden “Dosya İlişkilendirmeleri…” ile değiştirebilirsiniz.")
            : L("Seçtiğiniz dosya türlerine çift tıklayınca bu uygulama açılır. İşareti kaldırdığınız türler önceki uygulamalarına geri verilir.")) + "\n\n" + L("macOS her dosya türü için ayrıca onay isteyecek.")
        alert.icon = NSApp.applicationIconImage
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        var boxes: [(NSButton, Group, Bool)] = []   // kutu, grup, açılışta bu uygulamaya ait türü var mıydı
        for g in groups {
            let current = currentHandler(for: g.exts)
            let mine = types(for: g.exts).contains { isMine($0) }
            let box = NSButton(checkboxWithTitle: g.title, target: nil, action: nil)
            // Zaten bu uygulamaya ait bir tür varsa işaretli gelir; ilk açılışta yaygın türler de işaretli gelir
            box.state = ((g.defaultOn && firstLaunch) || mine) ? .on : .off
            let detail = NSTextField(labelWithString: LF("Şu an: %@", current) + (g.warning.map { "  •  " + $0 } ?? ""))
            detail.font = .systemFont(ofSize: 10)
            detail.textColor = g.warning == nil ? .secondaryLabelColor : .systemOrange
            detail.lineBreakMode = .byTruncatingTail
            let row = NSStackView(views: [box, detail])
            row.orientation = .vertical
            row.alignment = .leading
            row.spacing = 1
            detail.translatesAutoresizingMaskIntoConstraints = false
            detail.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 20).isActive = true
            stack.addArrangedSubview(row)
            boxes.append((box, g, mine))
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 10))
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            container.widthAnchor.constraint(equalToConstant: 400),
        ])
        container.layoutSubtreeIfNeeded()
        container.setFrameSize(NSSize(width: 400, height: stack.fittingSize.height))
        alert.accessoryView = container
        alert.addButton(withTitle: L("Uygula"))
        alert.addButton(withTitle: L("Şimdi Değil"))
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        // İşaretli: zaten bu uygulamaya ait olmayan türler üstlenilir. İşareti kaldırılmış: bu uygulamaya ait türler geri verilir.
        let chosen = boxes.filter { $0.0.state == .on }.flatMap { types(for: $0.1.exts) }.filter { !isMine($0) }
        let released = boxes.filter { $0.0.state == .off && $0.2 }.flatMap { types(for: $0.1.exts) }.filter { isMine($0) }
        if chosen.isEmpty && released.isEmpty { return true }
        apply(chosen, release: released)
        return true
    }

    /// Seçilen türler için varsayılan uygulama yap; `release` türlerini önceki uygulamalarına geri ver; sonucu bildir
    static func apply(_ types: [UTType], release: [UTType] = [], quiet: Bool = false, completion: ((Int, [String]) -> Void)? = nil) {
        var ok = 0
        var released = 0
        var failed: [String] = []
        let me = Bundle.main.bundleURL
        func label(_ t: UTType) -> String { t.preferredFilenameExtension ?? t.identifier }
        func report() {
            completion?(ok, failed)
            guard !quiet else { return }
            var lines: [String] = []
            if ok > 0 { lines.append(LF("%@ artık %d dosya türü için varsayılan uygulama.", AppInfo.name, ok)) }
            if released > 0 { lines.append(LF("%d dosya türü önceki uygulamasına geri verildi.", released)) }
            if failed.isEmpty {
                Dialogs.info(L("Tamam"), lines.joined(separator: "\n"))
            } else {
                Dialogs.error(L("Bazı türler ayarlanamadı"), (lines + [failed.joined(separator: ", ")]).joined(separator: "\n"))
            }
        }
        func releaseNext(_ i: Int) {
            guard i < release.count else { report(); return }
            let t = release[i]
            guard let target = previousHandler(for: t) else { failed.append(label(t)); releaseNext(i + 1); return }
            NSWorkspace.shared.setDefaultApplication(at: target, toOpen: t) { err in
                DispatchQueue.main.async {
                    if err == nil { released += 1 } else { failed.append(label(t)) }
                    releaseNext(i + 1)
                }
            }
        }
        func next(_ i: Int) {
            guard i < types.count else { releaseNext(0); return }
            let t = types[i]
            rememberPrevious(for: t)
            NSWorkspace.shared.setDefaultApplication(at: me, toOpen: t) { err in
                DispatchQueue.main.async {
                    if err == nil { ok += 1 } else { failed.append(label(t)) }
                    next(i + 1)
                }
            }
        }
        next(0)
    }
}
