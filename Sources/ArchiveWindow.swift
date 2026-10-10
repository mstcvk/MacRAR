import AppKit
import Quartz
import UniformTypeIdentifiers

// MARK: - Klavye destekli ağaç görünümü

final class ArchiveOutlineView: NSOutlineView {
    var onReturn: (() -> Void)?
    var onSpace: (() -> Void)?
    override func keyDown(with event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.numericPad)
        if mods.isEmpty, let ch = event.charactersIgnoringModifiers?.unicodeScalars.first {
            if ch == "\r" || ch == "\u{3}" { onReturn?(); return }
            if ch == " " { onSpace?(); return }
        }
        super.keyDown(with: event)
    }
}

/// Boş pencere: etiket + düğmeler; üzerine dosya bırakılabilir
final class EmptyStateView: NSView {
    var onDrop: (([URL]) -> Void)?
    override init(frame: NSRect) { super.init(frame: frame); registerForDraggedTypes([.fileURL]) }
    required init?(coder: NSCoder) { fatalError() }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty else { return false }
        onDrop?(urls)
        return true
    }
}

// MARK: - Ağaç düğümü

final class Node: NSObject {
    let name: String
    let path: String        // 7zz'ye verilen ham yol; seçim, çıkartma ve silme bunu kullanır
    var key = ""            // normalize yol ("./" yok); filtre ve görüntüleme için
    let isDir: Bool
    var entry: ArchiveEntry?
    var children: [Node] = []

    init(name: String, path: String, isDir: Bool) {
        self.name = name; self.path = path; self.isDir = isDir
    }

    var totalSize: Int64 {
        if !isDir { return entry?.size ?? 0 }
        return children.reduce(0) { $0 + $1.totalSize }
    }
    var totalPacked: Int64 {
        if !isDir { return entry?.packedSize ?? 0 }
        return children.reduce(0) { $0 + $1.totalPacked }
    }
    var containsEncrypted: Bool {
        if !isDir { return entry?.encrypted ?? false }
        return children.contains { $0.containsEncrypted }
    }

    func sortRecursively(key: String = "name", ascending: Bool = true) {
        children.sort { Node.compare($0, $1, key: key, ascending: ascending) }
        children.forEach { $0.sortRecursively(key: key, ascending: ascending) }
    }

    /// Klasörler her zaman önce; sonra seçilen sütuna göre
    static func compare(_ a: Node, _ b: Node, key: String, ascending: Bool) -> Bool {
        if a.isDir != b.isDir { return a.isDir }
        var r: ComparisonResult
        func cmp<T: Comparable>(_ x: T, _ y: T) -> ComparisonResult { x < y ? .orderedAscending : (x == y ? .orderedSame : .orderedDescending) }
        switch key {
        case "size": r = cmp(a.totalSize, b.totalSize)
        case "packed": r = cmp(a.totalPacked, b.totalPacked)
        case "date": r = (a.entry?.mtime ?? "").compare(b.entry?.mtime ?? "")
        case "ratio":
            let ra = a.totalSize > 0 ? Double(a.totalPacked) / Double(a.totalSize) : 0
            let rb = b.totalSize > 0 ? Double(b.totalPacked) / Double(b.totalSize) : 0
            r = cmp(ra, rb)
        default: r = a.name.localizedStandardCompare(b.name)
        }
        if r == .orderedSame { return a.name.localizedStandardCompare(b.name) == .orderedAscending }
        return ascending ? r == .orderedAscending : r == .orderedDescending
    }

    static func buildTree(_ entries: [ArchiveEntry]) -> Node {
        let root = Node(name: "", path: "", isDir: true)
        var map: [String: Node] = [:]
        for e in entries {
            // ".." ve mutlak yollu girdiler ağaca alınmaz; bunları içeren arşiv zaten çıkartılmaz
            guard let levels = ArchivePath.levels(e.name), !levels.isEmpty else { continue }
            var parent = root
            for (i, lv) in levels.enumerated() {
                let node: Node
                if let existing = map[lv.key] {
                    node = existing
                } else {
                    let isLast = i == levels.count - 1
                    node = Node(name: lv.name, path: lv.path, isDir: !isLast || e.isDirectory)
                    node.key = lv.key
                    parent.children.append(node)
                    map[lv.key] = node
                }
                if i == levels.count - 1 { node.entry = e }
                parent = node
            }
        }
        root.sortRecursively()
        return root
    }

    func flatten(into out: inout [Node]) {
        for c in children {
            out.append(c)
            c.flatten(into: &out)
        }
    }
}

// MARK: - Pencere

final class ArchiveWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation {
    private(set) var archivePath: String?
    private(set) var info: ArchiveInfo?
    private var password: String?
    private var root = Node(name: "", path: "", isDir: true)
    private var filtered: [Node]? = nil
    private var filterText = ""

    private let outline = ArchiveOutlineView()
    private let scroll = NSScrollView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let emptyLabel = NSTextField(wrappingLabelWithString: L("Bir arşiv açmak için ⌘O kullanın\nveya bir arşiv dosyasını (RAR, ZIP, 7z…) bu pencereye sürükleyin."))
    private let emptyView = EmptyStateView()
    private var sortKey = "name"
    private var sortAscending = true
    private var previewURLs: [URL] = []
    private let promiseQueue: OperationQueue = {
        let q = OperationQueue(); q.maxConcurrentOperationCount = 1; return q
    }()
    // Finder'a sürükleme oturumu (soru bir kez sorulur, öğeler tek seferde çıkartılır)
    private var dragNodes: [Node] = []
    private var dragDecision: Bool? = nil
    private var dragTempDir: String? = nil
    private var dragExtracted = false
    private var dragExtractOK = false
    private var dragPending = 0

    static let nameCol = NSUserInterfaceItemIdentifier("name")
    static let sizeCol = NSUserInterfaceItemIdentifier("size")
    static let packedCol = NSUserInterfaceItemIdentifier("packed")
    static let ratioCol = NSUserInterfaceItemIdentifier("ratio")
    static let dateCol = NSUserInterfaceItemIdentifier("date")
    static let crcCol = NSUserInterfaceItemIdentifier("crc")
    static let lockCol = NSUserInterfaceItemIdentifier("lock")

    init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = AppInfo.name
        w.minSize = NSSize(width: 560, height: 300)
        w.isReleasedWhenClosed = false
        w.setFrameAutosaveName("ArchiveWindow")
        super.init(window: w)
        w.delegate = self
        buildUI()
        buildToolbar()
        w.center()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: UI

    private func buildUI() {
        guard let w = window, let content = w.contentView else { return }

        func col(_ id: NSUserInterfaceItemIdentifier, _ title: String, width: CGFloat, min: CGFloat = 40, align: NSTextAlignment = .left) -> NSTableColumn {
            let c = NSTableColumn(identifier: id)
            c.title = title
            c.width = width
            c.minWidth = min
            c.headerCell.alignment = align
            return c
        }
        outline.addTableColumn(col(Self.nameCol, L("Ad"), width: 320, min: 160))
        outline.addTableColumn(col(Self.lockCol, "🔒", width: 28, min: 28, align: .center))
        outline.addTableColumn(col(Self.sizeCol, L("Boyut"), width: 90, align: .right))
        outline.addTableColumn(col(Self.packedCol, L("Paketli"), width: 90, align: .right))
        outline.addTableColumn(col(Self.ratioCol, L("Oran"), width: 55, align: .right))
        outline.addTableColumn(col(Self.dateCol, L("Değiştirilme"), width: 140))
        outline.addTableColumn(col(Self.crcCol, "CRC32", width: 80))
        for c in outline.tableColumns where c.identifier != Self.lockCol && c.identifier != Self.crcCol {
            c.sortDescriptorPrototype = NSSortDescriptor(key: c.identifier.rawValue, ascending: true)
        }
        outline.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        outline.autosaveName = "ArchiveOutline"
        outline.autosaveTableColumns = true
        outline.onReturn = { [weak self] in self?.openSelected(nil) }
        outline.onSpace = { [weak self] in self?.quickLook(nil) }
        outline.outlineTableColumn = outline.tableColumns[0]
        outline.dataSource = self
        outline.delegate = self
        outline.allowsMultipleSelection = true
        outline.usesAlternatingRowBackgroundColors = true
        outline.rowSizeStyle = .default
        outline.autoresizesOutlineColumn = true
        outline.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        outline.target = self
        outline.doubleAction = #selector(doubleClicked)
        outline.registerForDraggedTypes([.fileURL])
        outline.setDraggingSourceOperationMask(.copy, forLocal: false)
        outline.menu = buildContextMenu()

        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.alignment = .center
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.font = .systemFont(ofSize: 15)
        let openBtn = NSButton(title: L("Arşiv Aç…"), target: self, action: #selector(openArchive(_:)))
        let newBtn = NSButton(title: L("Yeni Arşiv…"), target: self, action: #selector(newArchive(_:)))
        openBtn.bezelStyle = .rounded; newBtn.bezelStyle = .rounded
        let btnRow = NSStackView(views: [openBtn, newBtn]); btnRow.spacing = 12
        let emptyStack = NSStackView(views: [emptyLabel, btnRow])
        emptyStack.orientation = .vertical; emptyStack.alignment = .centerX; emptyStack.spacing = 18
        emptyStack.translatesAutoresizingMaskIntoConstraints = false
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(emptyStack)
        emptyView.onDrop = { [weak self] urls in self?.handleDrop(urls) }
        NSLayoutConstraint.activate([
            emptyStack.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor),
            emptyStack.centerYAnchor.constraint(equalTo: emptyView.centerYAnchor),
            emptyLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
        ])

        let statusBar = NSVisualEffectView()
        statusBar.material = .titlebar
        statusBar.blendingMode = .withinWindow
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        statusBar.addSubview(statusLabel)

        content.addSubview(scroll)
        content.addSubview(statusBar)
        content.addSubview(emptyView)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            statusBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 24),
            statusLabel.leadingAnchor.constraint(equalTo: statusBar.leadingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: statusBar.trailingAnchor, constant: -10),
            statusLabel.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),
            emptyView.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            emptyView.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            emptyView.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 28),
            emptyView.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
        ])
        updateStatus()
    }

    private func buildContextMenu() -> NSMenu {
        let m = NSMenu()
        m.addItem(withTitle: L("Aç"), action: #selector(openSelected), keyEquivalent: "")
        m.addItem(withTitle: L("Göz At"), action: #selector(quickLook(_:)), keyEquivalent: "")
        m.addItem(.separator())
        m.addItem(withTitle: L("Seçilenleri Buraya Çıkart"), action: #selector(extractSelectedHere), keyEquivalent: "")
        m.addItem(withTitle: L("Seçilenleri Şuraya Çıkart…"), action: #selector(extractSelectedTo), keyEquivalent: "")
        m.addItem(.separator())
        m.addItem(withTitle: L("Arşivden Sil"), action: #selector(deleteSelected), keyEquivalent: "")
        return m
    }

    // MARK: Toolbar

    private enum TB {
        static let open = NSToolbarItem.Identifier("open")
        static let newArchive = NSToolbarItem.Identifier("new")
        static let extractTo = NSToolbarItem.Identifier("extractTo")
        static let extractHere = NSToolbarItem.Identifier("extractHere")
        static let extractFolder = NSToolbarItem.Identifier("extractFolder")
        static let test = NSToolbarItem.Identifier("test")
        static let add = NSToolbarItem.Identifier("add")
        static let delete = NSToolbarItem.Identifier("delete")
        static let info = NSToolbarItem.Identifier("info")
        static let search = NSToolbarItem.Identifier("search")
    }

    private func buildToolbar() {
        let tb = NSToolbar(identifier: "MainToolbar")
        tb.delegate = self
        tb.displayMode = .iconAndLabel
        tb.allowsUserCustomization = true
        tb.autosavesConfiguration = true
        window?.toolbar = tb
        window?.toolbarStyle = .expanded
    }

    // MARK: Arşiv yükleme

    func open(_ path: String) {
        archivePath = path
        password = nil
        reload()
    }

    private func reload() {
        guard let path = archivePath else { return }
        guard let info = Ops.listInteractive(archive: path, password: &password) else {
            // açılamadı: pencereyi boş bırak
            if self.info == nil { archivePath = nil }
            updateStatus()
            return
        }
        self.info = info
        root = Node.buildTree(info.entries)
        // buildTree zaten ada sırasına göre artan sıralar; varsayılan sıralamada tekrar sıralamaya gerek yok
        if sortKey != "name" || !sortAscending { root.sortRecursively(key: sortKey, ascending: sortAscending) }
        applyFilter()
        window?.title = (path as NSString).lastPathComponent
        window?.subtitle = AppInfo.abbreviate((path as NSString).deletingLastPathComponent)
        window?.representedURL = URL(fileURLWithPath: path)
        outline.reloadData()
        if root.children.count == 1, let only = root.children.first, only.isDir {
            outline.expandItem(only)
        }
        if ProcessInfo.processInfo.environment["MACRAR_DEBUG_EXPAND"] != nil {
            outline.expandItem(nil, expandChildren: true)
        }
        if let sort = ProcessInfo.processInfo.environment["MACRAR_DEBUG_SORT"] {   // örn. size:desc
            let parts = sort.split(separator: ":")
            outline.sortDescriptors = [NSSortDescriptor(key: String(parts[0]), ascending: parts.count < 2 || parts[1] != "desc")]
        }
        if let size = ProcessInfo.processInfo.environment["MACRAR_DEBUG_WINDOW"] {
            let parts = size.split(separator: "x").compactMap { Double($0) }
            if parts.count == 2 { window?.setContentSize(NSSize(width: parts[0], height: parts[1])) }
        }
        updateStatus()
        NSDocumentController.shared.noteNewRecentDocumentURL(URL(fileURLWithPath: path))
        if let dest = ProcessInfo.processInfo.environment["MACRAR_DEBUG_DRAG"] { simulateDrag(to: dest) }
    }

    /// Hata ayıklama: ilk üst düzey öğeleri Finder'a sürüklenmiş gibi hedefe yazar
    private func simulateDrag(to dest: String) {
        let nodes = Array(root.children.prefix(2))
        guard !nodes.isEmpty else { return }
        outlineView(outline, draggingSession: NSDraggingSession(), willBeginAt: .zero, forItems: nodes)
        for n in nodes {
            let p = NSFilePromiseProvider(fileType: "public.data", delegate: self)
            p.userInfo = n
            let url = URL(fileURLWithPath: (dest as NSString).appendingPathComponent(n.name))
            promiseQueue.addOperation { [self] in
                let done = DispatchSemaphore(value: 0)
                filePromiseProvider(p, writePromiseTo: url) { err in
                    print("drag-sim:", n.name, err.map { "HATA \($0)" } ?? "OK")
                    done.signal()
                }
                done.wait()
            }
        }
    }

    private func applyFilter() {
        if filterText.isEmpty {
            filtered = nil
        } else {
            var all: [Node] = []
            root.flatten(into: &all)
            filtered = all.filter { $0.key.localizedCaseInsensitiveContains(filterText) }
                .sorted { Node.compare($0, $1, key: sortKey, ascending: sortAscending) }
        }
        outline.reloadData()
        updateStatus()
    }

    private func updateStatus() {
        emptyView.isHidden = info != nil
        guard let info else {
            statusLabel.stringValue = L("Arşiv açık değil")
            return
        }
        var parts: [String] = []
        let sel = selectedNodes()
        if !sel.isEmpty {
            let size = sel.reduce(0) { $0 + $1.totalSize }
            parts.append(LF("Seçili: %d öğe, %@", sel.count, Fmt.size(size)))
        } else if let f = filtered {
            parts.append(LF("%d eşleşme", f.count))
        } else {
            parts.append(LF("%d dosya, %@ (paketli %@)", info.fileCount, Fmt.size(info.totalSize), Fmt.size(info.totalPacked)))
        }
        var det = info.details
        if info.headersEncrypted, !det.contains("encrypted headers") { det += ", encrypted headers" }
        det = det.replacingOccurrences(of: "encrypted headers", with: L("şifreli başlıklar"))
            .replacingOccurrences(of: "solid", with: L("katı"))
            .replacingOccurrences(of: "recovery record", with: L("kurtarma kaydı"))
            .replacingOccurrences(of: "volume", with: L("parça"))
            .replacingOccurrences(of: "lock", with: L("kilitli"))
        if info.hasEncryptedFiles && !info.headersEncrypted { det += L(", şifreli dosyalar") }
        parts.append(det)
        statusLabel.stringValue = parts.joined(separator: "   •   ")
    }

    // MARK: Seçim yardımcıları

    private func selectedNodes() -> [Node] {
        outline.selectedRowIndexes.compactMap { outline.item(atRow: $0) as? Node }
    }

    /// Seçili düğümlerin arşiv yolları (alt öğeleri zaten kapsayan klasörler sadeleştirilir)
    private func selectedPaths() -> [String] { Self.paths(for: selectedNodes()) }

    private static func paths(for nodes: [Node]) -> [String] {
        let dirs = Set(nodes.filter { $0.isDir }.map { $0.path })
        return nodes.filter { !ArchivePath.isInsideDir($0.path, of: dirs) }.map { $0.path }
    }

    // MARK: Eylemler

    @objc func openArchive(_ sender: Any?) {
        let files = Dialogs.chooseFiles(title: L("Arşiv Aç"), prompt: L("Aç"), archivesOnly: true)
        for f in files { AppDelegate.shared.openArchive(f, reuse: self.info == nil ? self : nil) }
    }

    @objc func newArchive(_ sender: Any?) {
        let items = Dialogs.chooseFiles(title: L("Sıkıştırılacak dosya ve klasörleri seçin"), prompt: L("Seç"), archivesOnly: false)
        guard !items.isEmpty else { return }
        AppDelegate.shared.compressWithDialog(items: items, host: window) { [weak self] path in
            guard let self, let path else { return }
            AppDelegate.shared.openArchive(path, reuse: self.info == nil ? self : nil)
        }
    }

    @objc func extractHere(_ sender: Any?) {
        guard let info else { return }
        let dest = (info.path as NSString).deletingLastPathComponent
        doExtract(names: nil, dest: dest)
    }

    @objc func extractToFolder(_ sender: Any?) {
        guard let info else { return }
        doExtract(names: nil, dest: Ops.folderNamedAfterArchive(info.path))
    }

    @objc func extractTo(_ sender: Any?) {
        guard let info else { return }
        guard let dest = Dialogs.chooseFolder(title: L("Nereye çıkartılsın?"), prompt: L("Çıkart"),
                                              initial: (info.path as NSString).deletingLastPathComponent) else { return }
        doExtract(names: nil, dest: dest)
    }

    @objc func extractSelectedHere(_ sender: Any?) {
        guard let info else { return }
        let names = selectedPaths()
        guard !names.isEmpty else { return }
        doExtract(names: names, dest: (info.path as NSString).deletingLastPathComponent)
    }

    @objc func extractSelectedTo(_ sender: Any?) {
        guard let info else { return }
        let names = selectedPaths()
        guard !names.isEmpty else { return }
        guard let dest = Dialogs.chooseFolder(title: L("Seçilenler nereye çıkartılsın?"), prompt: L("Çıkart"),
                                              initial: (info.path as NSString).deletingLastPathComponent) else { return }
        doExtract(names: names, dest: dest)
    }

    private func doExtract(names: [String]?, dest: String) {
        guard let info else { return }
        Ops.extract(info: info, names: names, dest: dest, password: password, host: window) { [weak self] ok, pw in
            self?.password = pw ?? self?.password
            if ok { Ops.revealExtracted(info: info, names: names, dest: dest) }
        }
    }

    @objc func testArchive(_ sender: Any?) {
        guard let info else { return }
        Ops.test(info: info, password: password, host: window) { [weak self] _, pw in
            self?.password = pw ?? self?.password
        }
    }

    @objc func addFiles(_ sender: Any?) {
        guard info != nil else { newArchive(sender); return }
        let items = Dialogs.chooseFiles(title: L("Arşive eklenecek dosya ve klasörleri seçin"), prompt: L("Ekle"), archivesOnly: false)
        guard !items.isEmpty else { return }
        addItems(items)
    }

    private func addItems(_ items: [String]) {
        guard let info else { return }
        Ops.add(info: info, items: items, password: password, host: window) { [weak self] ok, pw in
            guard let self else { return }
            self.password = pw ?? self.password
            if ok { self.reload() }
        }
    }

    @objc func deleteSelected(_ sender: Any?) {
        guard let info else { return }
        let names = selectedPaths()
        guard !names.isEmpty else { return }
        let list = names.prefix(5).map { ($0 as NSString).lastPathComponent }.joined(separator: ", ") + (names.count > 5 ? " …" : "")
        guard Dialogs.confirm(LF("%d öğe arşivden silinsin mi?", names.count), list + L("\n\nBu işlem geri alınamaz."), okTitle: L("Sil"), destructive: true) else { return }
        Ops.delete(info: info, names: names, password: password, host: window) { [weak self] ok, pw in
            guard let self else { return }
            self.password = pw ?? self.password
            if ok { self.reload() }
        }
    }

    @objc func showInfo(_ sender: Any?) {
        guard let info else { return }
        let attrs = (try? FileManager.default.attributesOfItem(atPath: info.path)) ?? [:]
        let fileSize = (attrs[.size] as? Int64) ?? 0
        let text = LF("Dosya: %@\nArşiv boyutu: %@\nBiçim: %@\nDosya sayısı: %d\nKlasör sayısı: %d\nToplam boyut: %@\nPaketli boyut: %@\nŞifreli: %@",
                      info.path, Fmt.size(fileSize), info.details, info.fileCount, info.entries.count - info.fileCount,
                      Fmt.size(info.totalSize), Fmt.size(info.totalPacked), info.hasEncryptedFiles ? L("Evet") : L("Hayır"))
        Dialogs.info((info.path as NSString).lastPathComponent, text)
    }

    @objc func openSelected(_ sender: Any?) {
        for n in selectedNodes() { openNode(n) }
    }

    @objc private func doubleClicked() {
        let row = outline.clickedRow
        guard row >= 0, let n = outline.item(atRow: row) as? Node else { return }
        if n.isDir {
            if outline.isItemExpanded(n) { outline.collapseItem(n) } else { outline.expandItem(n) }
        } else {
            openNode(n)
        }
    }

    private func openNode(_ n: Node) {
        guard let info else { return }
        let tmp = TempDirs.make("open")
        Ops.extract(info: info, names: [n.path], dest: tmp, password: password, host: window, quiet: true) { [weak self] ok, pw in
            self?.password = pw ?? self?.password
            guard ok else { return }
            let target = (tmp as NSString).appendingPathComponent(n.path)
            NSWorkspace.shared.open(URL(fileURLWithPath: target))
        }
    }

    // MARK: Görünüm eylemleri

    @objc func expandAll(_ sender: Any?) { outline.expandItem(nil, expandChildren: true) }
    @objc func collapseAll(_ sender: Any?) { outline.collapseItem(nil, collapseChildren: true) }
    @objc func refresh(_ sender: Any?) { reload() }
    @objc func revealArchive(_ sender: Any?) { if let p = archivePath { Ops.revealInFinder(p) } }

    // MARK: Hızlı Bakış

    @objc func quickLook(_ sender: Any?) {
        if let panel = QLPreviewPanel.shared(), panel.isVisible { panel.orderOut(nil); return }
        prepareQuickLook { QLPreviewPanel.shared()?.makeKeyAndOrderFront(nil) }
    }

    private func prepareQuickLook(completion: @escaping () -> Void) {
        guard let info else { return }
        let files = selectedNodes().filter { !$0.isDir }
        guard !files.isEmpty else { return }
        let tmp = TempDirs.make("ql")
        Ops.extract(info: info, names: files.map { $0.path }, dest: tmp, password: password, host: window, quiet: true) { [weak self] ok, pw in
            guard let self else { return }
            self.password = pw ?? self.password
            guard ok else { return }
            self.previewURLs = files.map { URL(fileURLWithPath: (tmp as NSString).appendingPathComponent($0.path)) }
            completion()
        }
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) { panel.dataSource = self; panel.delegate = self }
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) { panel.dataSource = nil; panel.delegate = nil }

    @objc func searchChanged(_ sender: NSSearchField) {
        filterText = sender.stringValue.trimmingCharacters(in: .whitespaces)
        applyFilter()
    }

    // MARK: Doğrulama

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        validate(item.action)
    }

    private func validate(_ action: Selector?) -> Bool {
        guard let action else { return false }
        switch action {
        case #selector(openArchive), #selector(newArchive):
            return true
        case #selector(extractHere), #selector(extractToFolder), #selector(extractTo), #selector(testArchive), #selector(showInfo):
            return info != nil
        case #selector(addFiles):
            return info == nil || info?.supportsModification == true
        case #selector(deleteSelected):
            return info?.supportsModification == true && !outline.selectedRowIndexes.isEmpty
        case #selector(extractSelectedHere), #selector(extractSelectedTo), #selector(openSelected):
            return info != nil && !outline.selectedRowIndexes.isEmpty
        case #selector(quickLook(_:)):
            return info != nil && selectedNodes().contains { !$0.isDir }
        case #selector(expandAll(_:)), #selector(collapseAll(_:)), #selector(refresh(_:)), #selector(revealArchive(_:)):
            return info != nil
        default:
            return true
        }
    }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        AppDelegate.shared.windowClosed(self)
    }
}

// MARK: - Toolbar delegate

extension ArchiveWindowController: NSToolbarDelegate, NSToolbarItemValidation {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [TB.open, TB.newArchive, .space, TB.extractTo, TB.extractHere, TB.extractFolder, .space, TB.test, TB.add, TB.delete, TB.info, .flexibleSpace, TB.search]
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar) + [.flexibleSpace, .space]
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if id == TB.search {
            let s = NSSearchToolbarItem(itemIdentifier: id)
            s.label = L("Ara")
            s.searchField.placeholderString = L("Arşivde ara")
            s.searchField.target = self
            s.searchField.action = #selector(searchChanged(_:))
            s.searchField.sendsSearchStringImmediately = true
            s.searchField.sendsWholeSearchString = false
            return s
        }
        let specs: [NSToolbarItem.Identifier: (String, String, Selector, String)] = [
            TB.open: (L("Aç"), "folder", #selector(openArchive), L("Arşiv aç")),
            TB.newArchive: (L("Sıkıştır"), "doc.zipper", #selector(newArchive), L("Yeni arşiv oluştur")),
            TB.extractTo: (L("Çıkart…"), "square.and.arrow.down", #selector(extractTo), L("Seçilen klasöre çıkart")),
            TB.extractHere: (L("Buraya"), "arrow.down.doc", #selector(extractHere), L("Arşivin bulunduğu klasöre çıkart")),
            TB.extractFolder: (L("Klasöre"), "folder.badge.plus", #selector(extractToFolder), L("Arşiv adıyla yeni klasöre çıkart")),
            TB.test: (L("Test"), "checkmark.shield", #selector(testArchive), L("Arşivi test et")),
            TB.add: (L("Ekle"), "plus.rectangle.on.folder", #selector(addFiles), L("Arşive dosya ekle")),
            TB.delete: (L("Sil"), "trash", #selector(deleteSelected), L("Seçilenleri arşivden sil")),
            TB.info: (L("Bilgi"), "info.circle", #selector(showInfo), L("Arşiv bilgisi")),
        ]
        guard let (label, symbol, sel, tip) = specs[id] else { return nil }
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = label
        item.paletteLabel = label
        item.toolTip = tip
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        item.target = self
        item.action = sel
        item.isBordered = true
        return item
    }
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool { validate(item.action) }
}

// MARK: - Outline data source / delegate

extension ArchiveWindowController: NSOutlineViewDataSource, NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let f = filtered { return item == nil ? f.count : 0 }
        return ((item as? Node) ?? root).children.count
    }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let f = filtered { return f[index] }
        return ((item as? Node) ?? root).children[index]
    }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if filtered != nil { return false }
        return (item as? Node)?.isDir ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let col = tableColumn, let node = item as? Node else { return nil }
        let id = col.identifier
        var cell = outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView
        if cell == nil {
            let c = NSTableCellView()
            c.identifier = id
            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            tf.lineBreakMode = .byTruncatingMiddle
            tf.font = .systemFont(ofSize: 12)
            c.addSubview(tf)
            c.textField = tf
            if id == Self.nameCol {
                let iv = NSImageView()
                iv.translatesAutoresizingMaskIntoConstraints = false
                c.addSubview(iv)
                c.imageView = iv
                NSLayoutConstraint.activate([
                    iv.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 2),
                    iv.centerYAnchor.constraint(equalTo: c.centerYAnchor),
                    iv.widthAnchor.constraint(equalToConstant: 16),
                    iv.heightAnchor.constraint(equalToConstant: 16),
                    tf.leadingAnchor.constraint(equalTo: iv.trailingAnchor, constant: 4),
                ])
            } else {
                tf.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 4).isActive = true
                if id == Self.sizeCol || id == Self.packedCol || id == Self.ratioCol { tf.alignment = .right }
                if id == Self.lockCol { tf.alignment = .center }
                if id == Self.crcCol || id == Self.dateCol { tf.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular) }
            }
            NSLayoutConstraint.activate([
                tf.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: c.centerYAnchor),
            ])
            cell = c
        }
        let e = node.entry
        switch id {
        case Self.nameCol:
            cell?.textField?.stringValue = filtered != nil ? node.key : node.name
            cell?.imageView?.image = icon(for: node)
        case Self.sizeCol:
            cell?.textField?.stringValue = Fmt.size(node.totalSize)
        case Self.packedCol:
            cell?.textField?.stringValue = Fmt.size(node.totalPacked)
        case Self.ratioCol:
            cell?.textField?.stringValue = e?.ratio ?? ""
        case Self.dateCol:
            cell?.textField?.stringValue = e?.mtime ?? ""
        case Self.crcCol:
            cell?.textField?.stringValue = node.isDir ? "" : (e?.crc ?? "")
        case Self.lockCol:
            cell?.textField?.stringValue = node.containsEncrypted ? "🔒" : ""
        default: break
        }
        return cell
    }

    private static var iconCache: [String: NSImage] = [:]
    private func icon(for node: Node) -> NSImage {
        if node.isDir { return NSWorkspace.shared.icon(for: .folder) }
        let ext = (node.name as NSString).pathExtension.lowercased()
        if let c = Self.iconCache[ext] { return c }
        let img: NSImage
        if let t = UTType(filenameExtension: ext) { img = NSWorkspace.shared.icon(for: t) } else { img = NSWorkspace.shared.icon(for: .data) }
        Self.iconCache[ext] = img
        return img
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        updateStatus()
        if let panel = QLPreviewPanel.shared(), panel.isVisible, panel.dataSource === self {
            prepareQuickLook { panel.reloadData() }
        }
    }

    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let d = outlineView.sortDescriptors.first, let key = d.key else { return }
        sortKey = key
        sortAscending = d.ascending
        root.sortRecursively(key: sortKey, ascending: sortAscending)
        applyFilter()
    }

    // Sürükle-bırak: arşiv dosyası bırakıldığında aç, diğer dosyaları arşive ekle
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        guard info.draggingSource as? NSOutlineView !== outlineView else { return [] }
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty else { return [] }
        outlineView.setDropItem(nil, dropChildIndex: NSOutlineViewDropOnItemIndex)
        return .copy
    }
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty else { return false }
        handleDrop(urls)
        return true
    }

    func handleDrop(_ urls: [URL]) {
        let paths = urls.map { $0.path }
        let archives = paths.filter { AppDelegate.isArchive($0) }
        let others = paths.filter { !AppDelegate.isArchive($0) }
        if self.info != nil, !others.isEmpty {
            // Açık arşive bırakılan karışık seçim: arşiv dosyaları dahil hepsi eklenir (hiçbiri sessizce atlanmaz)
            DispatchQueue.main.async { [weak self] in self?.addItems(paths) }
            return
        }
        // Yalnızca arşivler: aç. Boş pencereye bırakılan başka dosyalar: sıkıştırma penceresi
        for a in archives { AppDelegate.shared.openArchive(a, reuse: self.info == nil ? self : nil) }
        if !others.isEmpty, self.info == nil {
            AppDelegate.shared.compressWithDialog(items: others, host: window) { [weak self] path in
                if let self, let path { AppDelegate.shared.openArchive(path, reuse: self) }
            }
        }
    }

    // Arşivden Finder'a sürükleme (dosya vaadi)
    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItems draggedItems: [Any]) {
        dragNodes = draggedItems.compactMap { $0 as? Node }
        dragDecision = nil
        dragTempDir = nil
        dragExtracted = false
        dragExtractOK = false
        dragPending = dragNodes.count
    }

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let node = item as? Node else { return nil }
        let type: String
        if node.isDir { type = UTType.folder.identifier }
        else { type = UTType(filenameExtension: (node.name as NSString).pathExtension)?.identifier ?? UTType.data.identifier }
        let p = NSFilePromiseProvider(fileType: type, delegate: self)
        p.userInfo = node
        return p
    }
}

extension ArchiveWindowController: NSFilePromiseProviderDelegate {
    func filePromiseProvider(_ p: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        (p.userInfo as? Node)?.name ?? "dosya"
    }
    func operationQueue(for p: NSFilePromiseProvider) -> OperationQueue { promiseQueue }

    func filePromiseProvider(_ p: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let node = p.userInfo as? Node, let info else { completionHandler(nil); return }
        let sem = DispatchSemaphore(value: 0)
        var error: Error? = nil

        DispatchQueue.main.async { [self] in
            let nodes = dragNodes.isEmpty ? [node] : dragNodes
            let destFolder = url.deletingLastPathComponent()

            // Oturum başına bir kez sor
            if dragDecision == nil {
                let list = nodes.prefix(6).map { $0.name }.joined(separator: ", ") + (nodes.count > 6 ? " …" : "")
                let destName = destFolder.lastPathComponent
                let title = nodes.count == 1
                    ? LF("\"%@\" \"%@\" klasörüne çıkartılsın mı?", nodes[0].name, destName)
                    : LF("%d öğe \"%@\" klasörüne çıkartılsın mı?", nodes.count, destName)
                dragDecision = Dialogs.confirm(title, LF("Arşiv: %@\nHedef: %@\nÖğeler: %@", (info.path as NSString).lastPathComponent, AppInfo.abbreviate(destFolder.path), list), okTitle: L("Çıkart"))
            }
            guard dragDecision == true else { error = CocoaError(.userCancelled); sem.signal(); return }

            func moveIntoPlace() {
                guard let tmp = dragTempDir else { error = CocoaError(.fileNoSuchFile); sem.signal(); return }
                do {
                    let src = URL(fileURLWithPath: (tmp as NSString).appendingPathComponent(node.path))
                    if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
                    try FileManager.default.moveItem(at: src, to: url)
                } catch let e { error = e }
                sem.signal()
            }

            if dragExtracted {
                if dragExtractOK { moveIntoPlace() } else { error = CocoaError(.userCancelled); sem.signal() }
                return
            }

            // İlk öğe: sürüklenen tüm öğeleri tek seferde geçici klasöre çıkart
            let tmp = TempDirs.make("drag")
            dragTempDir = tmp
            dragExtracted = true
            Ops.extract(info: info, names: Self.paths(for: nodes), dest: tmp, password: password, host: window, quiet: true) { ok, pw in
                self.password = pw ?? self.password
                self.dragExtractOK = ok
                if ok { moveIntoPlace() } else { error = CocoaError(.userCancelled); sem.signal() }
            }
        }

        sem.wait()
        // Son vaat tamamlanınca geçici klasörü temizle
        dragPending -= 1
        if dragPending <= 0, let tmp = dragTempDir {
            try? FileManager.default.removeItem(atPath: tmp)
            DispatchQueue.main.async { self.dragTempDir = nil }
        }
        completionHandler(error)
    }
}

// MARK: - Hızlı Bakış veri kaynağı

extension ArchiveWindowController: QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { previewURLs.count }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! { previewURLs[index] as NSURL }
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        // Ok tuşlarını listeye ilet (Finder davranışı)
        if event.type == .keyDown, let ch = event.charactersIgnoringModifiers?.unicodeScalars.first,
           ch == UnicodeScalar(NSUpArrowFunctionKey) || ch == UnicodeScalar(NSDownArrowFunctionKey) {
            outline.keyDown(with: event)
            return true
        }
        return false
    }
}
