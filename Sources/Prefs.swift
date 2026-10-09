import AppKit

/// Kullanıcı ayarları (UserDefaults)
enum Prefs {
    private static let d = UserDefaults.standard
    static var defaultFormat: ArchiveFormat {
        get {
            let fallback: ArchiveFormat = RarTools.available ? .rar5 : .zip
            guard d.object(forKey: "DefaultFormat") != nil, let f = ArchiveFormat(rawValue: d.integer(forKey: "DefaultFormat")),
                  ArchiveFormat.creatable.contains(f) else { return fallback }
            return f
        }
        set { d.set(newValue.rawValue, forKey: "DefaultFormat") }
    }
    static var defaultLevel: Int {
        get { d.object(forKey: "DefaultLevel") == nil ? 3 : max(0, min(5, d.integer(forKey: "DefaultLevel"))) }
        set { d.set(newValue, forKey: "DefaultLevel") }
    }
    static var solid: Bool { get { d.bool(forKey: "DefaultSolid") } set { d.set(newValue, forKey: "DefaultSolid") } }
    static var recoveryRecord: Bool { get { d.bool(forKey: "DefaultRecovery") } set { d.set(newValue, forKey: "DefaultRecovery") } }
    static var revealAfterExtract: Bool {
        get { d.object(forKey: "RevealAfterExtract") == nil ? true : d.bool(forKey: "RevealAfterExtract") }
        set { d.set(newValue, forKey: "RevealAfterExtract") }
    }
    static var revealAfterCompress: Bool {
        get { d.object(forKey: "RevealAfterCompress") == nil ? true : d.bool(forKey: "RevealAfterCompress") }
        set { d.set(newValue, forKey: "RevealAfterCompress") }
    }
    static var checkUpdates: Bool {
        get { d.object(forKey: "CheckUpdates") == nil ? true : d.bool(forKey: "CheckUpdates") }
        set { d.set(newValue, forKey: "CheckUpdates") }
    }
    /// "" = sistem dili, "tr", "en"
    static var language: String { get { d.string(forKey: "Language") ?? "" } set { d.set(newValue, forKey: "Language") } }
}

/// Ayarlar penceresi (⌘,)
final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()
    private let formatPopup = NSPopUpButton()
    private let levelPopup = NSPopUpButton()
    private let solidBox = NSButton(checkboxWithTitle: L("Katı (solid) arşiv"), target: nil, action: nil)
    private let rrBox = NSButton(checkboxWithTitle: L("Kurtarma kaydı ekle (%3)"), target: nil, action: nil)
    private let revealExtractBox = NSButton(checkboxWithTitle: L("Çıkartma bitince öğeleri Finder'da göster"), target: nil, action: nil)
    private let revealCompressBox = NSButton(checkboxWithTitle: L("Sıkıştırma bitince arşivi Finder'da göster"), target: nil, action: nil)
    private let updatesBox = NSButton(checkboxWithTitle: L("Günde bir kez GitHub'dan güncelleme denetle"), target: nil, action: nil)
    private let languagePopup = NSPopUpButton()
    private let languageNote = NSTextField(labelWithString: L("Dil değişikliği uygulama yeniden açılınca geçerli olur."))
    private let toolStatus = NSTextField(labelWithString: "")
    private lazy var toolButton = NSButton(title: "", target: self, action: #selector(toolAction))

    private init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = L("Ayarlar")
        w.isReleasedWhenClosed = false
        super.init(window: w)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        guard let content = window?.contentView else { return }
        func label(_ s: String) -> NSTextField { let l = NSTextField(labelWithString: s); l.alignment = .right; return l }
        formatPopup.addItems(withTitles: ArchiveFormat.creatable.map { $0.title })
        levelPopup.addItems(withTitles: [L("Depola (sıkıştırma yok)"), L("En hızlı"), L("Hızlı"), L("Normal"), L("İyi"), L("En iyi")])
        languagePopup.addItems(withTitles: [L("Sistem dili"), "Türkçe", "English"])
        languageNote.font = .systemFont(ofSize: 10)
        languageNote.textColor = .secondaryLabelColor
        for b in [solidBox, rrBox, revealExtractBox, revealCompressBox, updatesBox] { b.target = self; b.action = #selector(changed) }
        for p in [formatPopup, levelPopup, languagePopup] { p.target = self; p.action = #selector(changed) }

        let header1 = NSTextField(labelWithString: L("Hızlı sıkıştırma varsayılanları")); header1.font = .boldSystemFont(ofSize: 12)
        let header2 = NSTextField(labelWithString: L("Davranış")); header2.font = .boldSystemFont(ofSize: 12)
        let grid = NSGridView(views: [
            [NSGridCell.emptyContentView, header1],
            [label(L("Biçim:")), formatPopup],
            [label(L("Sıkıştırma:")), levelPopup],
            [NSGridCell.emptyContentView, solidBox],
            [NSGridCell.emptyContentView, rrBox],
            [NSGridCell.emptyContentView, header2],
            [NSGridCell.emptyContentView, revealExtractBox],
            [NSGridCell.emptyContentView, revealCompressBox],
            [NSGridCell.emptyContentView, updatesBox],
            [label(L("Dil:")), languagePopup],
            [NSGridCell.emptyContentView, languageNote],
            [label(AppInfo.isAppStore ? L("Klasörler:") : L("RAR aracı:")), toolStatus],
            [NSGridCell.emptyContentView, toolButton],
        ])
        updatesBox.isHidden = AppInfo.isAppStore
        toolStatus.font = .systemFont(ofSize: 11)
        toolStatus.textColor = .secondaryLabelColor
        toolStatus.lineBreakMode = .byTruncatingMiddle
        toolStatus.widthAnchor.constraint(lessThanOrEqualToConstant: 340).isActive = true
        grid.rowSpacing = 8; grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
        ])
    }

    private func refreshTool() {
        if AppInfo.isAppStore {
            let n = FolderAccess.grantedFolders.count
            toolStatus.stringValue = n == 0 ? L("Henüz izin verilmiş klasör yok (Downloads her zaman açık).") : LF("%d klasöre izin verildi.", n)
            toolButton.title = L("Ana Klasöre İzin Ver…")
        } else if let v = RarTools.version {
            toolStatus.stringValue = LF("Kurulu: %@", v)
            toolButton.title = L("RAR Aracını Kaldır")
        } else {
            toolStatus.stringValue = L("Kurulu değil (RAR oluşturmak için gerekir)")
            toolButton.title = L("RAR Aracını Kur…")
        }
    }

    @objc private func toolAction() {
        if AppInfo.isAppStore {
            FolderAccess.grantHome()
        } else {
            #if !APPSTORE
            if RarTools.available { RarTools.uninstall() } else { RarTools.ensureAvailable() }
            #endif
        }
        refreshTool()
        formatPopup.removeAllItems()
        formatPopup.addItems(withTitles: ArchiveFormat.creatable.map { $0.title })
        formatPopup.selectItem(at: ArchiveFormat.creatable.firstIndex(of: Prefs.defaultFormat) ?? 0)
    }

    private func load() {
        refreshTool()
        formatPopup.selectItem(at: ArchiveFormat.creatable.firstIndex(of: Prefs.defaultFormat) ?? 0)
        levelPopup.selectItem(at: Prefs.defaultLevel)
        solidBox.state = Prefs.solid ? .on : .off
        rrBox.state = Prefs.recoveryRecord ? .on : .off
        revealExtractBox.state = Prefs.revealAfterExtract ? .on : .off
        revealCompressBox.state = Prefs.revealAfterCompress ? .on : .off
        updatesBox.state = Prefs.checkUpdates ? .on : .off
        languagePopup.selectItem(at: Prefs.language == "tr" ? 1 : (Prefs.language == "en" ? 2 : 0))
    }

    @objc private func changed() {
        let list = ArchiveFormat.creatable
        let fi = formatPopup.indexOfSelectedItem
        Prefs.defaultFormat = fi >= 0 && fi < list.count ? list[fi] : .zip
        Prefs.defaultLevel = levelPopup.indexOfSelectedItem
        Prefs.solid = solidBox.state == .on
        Prefs.recoveryRecord = rrBox.state == .on
        Prefs.revealAfterExtract = revealExtractBox.state == .on
        Prefs.revealAfterCompress = revealCompressBox.state == .on
        Prefs.checkUpdates = updatesBox.state == .on
        Prefs.language = ["", "tr", "en"][languagePopup.indexOfSelectedItem]
    }

    func show() {
        load()
        guard let w = window else { return }
        if let c = w.contentView { c.layoutSubtreeIfNeeded(); w.setContentSize(NSSize(width: max(c.fittingSize.width, 520), height: c.fittingSize.height)) }
        w.center()
        showWindow(nil)
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
