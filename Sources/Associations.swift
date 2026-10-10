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
            : L("Seçtiğiniz dosya türlerine çift tıklayınca bu uygulama açılır.")) + "\n\n" + L("macOS her dosya türü için ayrıca onay isteyecek.")
        alert.icon = NSApp.applicationIconImage
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        var boxes: [(NSButton, Group)] = []
        for g in groups {
            let current = currentHandler(for: g.exts)
            let mine = current == AppInfo.name
            let box = NSButton(checkboxWithTitle: g.title, target: nil, action: nil)
            box.state = (g.defaultOn || mine) ? .on : .off
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
            boxes.append((box, g))
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
        alert.addButton(withTitle: L("Varsayılan Yap"))
        alert.addButton(withTitle: L("Şimdi Değil"))
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        // Zaten bu uygulamaya ait türler için yeniden onay isteme
        let chosen = boxes.filter { $0.0.state == .on }.flatMap { types(for: $0.1.exts) }.filter { !isMine($0) }
        if chosen.isEmpty { return true }
        apply(chosen)
        return true
    }

    /// Seçilen türler için varsayılan uygulama yap; sonucu bildir
    static func apply(_ types: [UTType], quiet: Bool = false, completion: ((Int, [String]) -> Void)? = nil) {
        var ok = 0
        var failed: [String] = []
        func next(_ i: Int) {
            guard i < types.count else {
                completion?(ok, failed)
                if !quiet {
                    if failed.isEmpty {
                        Dialogs.info(L("Tamam"), LF("%@ artık %d dosya türü için varsayılan uygulama.", AppInfo.name, ok))
                    } else {
                        Dialogs.error(L("Bazı türler ayarlanamadı"), failed.joined(separator: ", "))
                    }
                }
                return
            }
            let t = types[i]
            NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: t) { err in
                DispatchQueue.main.async {
                    if err == nil { ok += 1 } else { failed.append(t.preferredFilenameExtension ?? t.identifier) }
                    next(i + 1)
                }
            }
        }
        next(0)
    }
}
