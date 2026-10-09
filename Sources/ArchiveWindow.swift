import AppKit
import UniformTypeIdentifiers

// MARK: - Ağaç düğümü

final class Node: NSObject {
    let name: String
    let path: String
    let isDir: Bool
    var entry: ArchiveEntry?
    var children: [Node] = []
    weak var parent: Node?

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

    func sortRecursively() {
        children.sort { a, b in
            if a.isDir != b.isDir { return a.isDir }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
        children.forEach { $0.sortRecursively() }
    }

    static func buildTree(_ entries: [ArchiveEntry]) -> Node {
        let root = Node(name: "", path: "", isDir: true)
        var map: [String: Node] = ["": root]
        func ensure(_ path: String) -> Node {
            if let n = map[path] { return n }
            let parentPath = (path as NSString).deletingLastPathComponent
            let parent = ensure(parentPath)
            let n = Node(name: (path as NSString).lastPathComponent, path: path, isDir: true)
            n.parent = parent
            parent.children.append(n)
            map[path] = n
            return n
        }
        for e in entries {
            let clean = e.name.hasSuffix("/") ? String(e.name.dropLast()) : e.name
            if e.isDirectory {
                ensure(clean).entry = e
            } else {
                let parent = ensure((clean as NSString).deletingLastPathComponent)
                let n = Node(name: (clean as NSString).lastPathComponent, path: clean, isDir: false)
                n.entry = e
                n.parent = parent
                parent.children.append(n)
                map[clean] = n
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

    private let outline = NSOutlineView()
    private let scroll = NSScrollView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let emptyLabel = NSTextField(wrappingLabelWithString: "Bir arşiv açmak için ⌘O kullanın\nveya bir arşiv dosyasını (RAR, ZIP, 7z…) bu pencereye sürükleyin.")
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
        w.title = "MacRAR"
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
        outline.addTableColumn(col(Self.nameCol, "Ad", width: 320, min: 160))
        outline.addTableColumn(col(Self.lockCol, "🔒", width: 28, min: 28, align: .center))
        outline.addTableColumn(col(Self.sizeCol, "Boyut", width: 90, align: .right))
        outline.addTableColumn(col(Self.packedCol, "Paketli", width: 90, align: .right))
        outline.addTableColumn(col(Self.ratioCol, "Oran", width: 55, align: .right))
        outline.addTableColumn(col(Self.dateCol, "Değiştirilme", width: 140))
        outline.addTableColumn(col(Self.crcCol, "CRC32", width: 80))
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
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        let statusBar = NSVisualEffectView()
        statusBar.material = .titlebar
        statusBar.blendingMode = .withinWindow
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        statusBar.addSubview(statusLabel)

        content.addSubview(scroll)
        content.addSubview(statusBar)
        content.addSubview(emptyLabel)
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
            emptyLabel.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
            emptyLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
        ])
        updateStatus()
    }

    private func buildContextMenu() -> NSMenu {
        let m = NSMenu()
        m.addItem(withTitle: "Aç", action: #selector(openSelected), keyEquivalent: "")
        m.addItem(.separator())
        m.addItem(withTitle: "Seçilenleri Buraya Çıkart", action: #selector(extractSelectedHere), keyEquivalent: "")
        m.addItem(withTitle: "Seçilenleri Şuraya Çıkart…", action: #selector(extractSelectedTo), keyEquivalent: "")
        m.addItem(.separator())
        m.addItem(withTitle: "Arşivden Sil", action: #selector(deleteSelected), keyEquivalent: "")
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
        applyFilter()
        window?.title = (path as NSString).lastPathComponent
        window?.subtitle = (path as NSString).deletingLastPathComponent.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        window?.representedURL = URL(fileURLWithPath: path)
        outline.reloadData()
        if root.children.count == 1, let only = root.children.first, only.isDir {
            outline.expandItem(only)
        }
        if ProcessInfo.processInfo.environment["MACRAR_DEBUG_EXPAND"] != nil {
            outline.expandItem(nil, expandChildren: true)
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
            filtered = all.filter { $0.path.localizedCaseInsensitiveContains(filterText) }
        }
        outline.reloadData()
        updateStatus()
    }

    private func updateStatus() {
        emptyLabel.isHidden = info != nil
        guard let info else {
            statusLabel.stringValue = "Arşiv açık değil"
            return
        }
        var parts: [String] = []
        let sel = selectedNodes()
        if !sel.isEmpty {
            let size = sel.reduce(0) { $0 + $1.totalSize }
            parts.append("Seçili: \(sel.count) öğe, \(Fmt.size(size))")
        } else if let f = filtered {
            parts.append("\(f.count) eşleşme")
        } else {
            parts.append("\(info.fileCount) dosya, \(Fmt.size(info.totalSize)) (paketli \(Fmt.size(info.totalPacked)))")
        }
        var det = info.details
        if info.headersEncrypted, !det.contains("encrypted headers") { det += ", encrypted headers" }
        det = det.replacingOccurrences(of: "encrypted headers", with: "şifreli başlıklar")
            .replacingOccurrences(of: "solid", with: "katı")
            .replacingOccurrences(of: "recovery record", with: "kurtarma kaydı")
            .replacingOccurrences(of: "volume", with: "parça")
            .replacingOccurrences(of: "lock", with: "kilitli")
        if info.hasEncryptedFiles && !info.headersEncrypted { det += ", şifreli dosyalar" }
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
        let dirs = nodes.filter { $0.isDir }.map { $0.path + "/" }
        return nodes.filter { n in !dirs.contains { n.path.hasPrefix($0) } }.map { $0.path }
    }

    // MARK: Eylemler

    @objc func openArchive(_ sender: Any?) {
        let files = Dialogs.chooseFiles(title: "Arşiv Aç", prompt: "Aç", archivesOnly: true)
        for f in files { AppDelegate.shared.openArchive(f, reuse: self.info == nil ? self : nil) }
    }

    @objc func newArchive(_ sender: Any?) {
        let items = Dialogs.chooseFiles(title: "Sıkıştırılacak dosya ve klasörleri seçin", prompt: "Seç", archivesOnly: false)
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
        guard let dest = Dialogs.chooseFolder(title: "Nereye çıkartılsın?", prompt: "Çıkart",
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
        guard let dest = Dialogs.chooseFolder(title: "Seçilenler nereye çıkartılsın?", prompt: "Çıkart",
                                              initial: (info.path as NSString).deletingLastPathComponent) else { return }
        doExtract(names: names, dest: dest)
    }

    private func doExtract(names: [String]?, dest: String) {
        guard let info else { return }
        Ops.extract(info: info, names: names, dest: dest, password: password, host: window) { [weak self] ok, pw in
            self?.password = pw ?? self?.password
            if ok { Ops.revealInFinder(dest) }
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
        let items = Dialogs.chooseFiles(title: "Arşive eklenecek dosya ve klasörleri seçin", prompt: "Ekle", archivesOnly: false)
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
        guard Dialogs.confirm("\(names.count) öğe arşivden silinsin mi?", "\(list)\n\nBu işlem geri alınamaz.", okTitle: "Sil", destructive: true) else { return }
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
        let text = """
        Dosya: \(info.path)
        Arşiv boyutu: \(Fmt.size(fileSize))
        Biçim: \(info.details)
        Dosya sayısı: \(info.fileCount)
        Klasör sayısı: \(info.entries.count - info.fileCount)
        Toplam boyut: \(Fmt.size(info.totalSize))
        Paketli boyut: \(Fmt.size(info.totalPacked))
        Şifreli: \(info.hasEncryptedFiles ? "Evet" : "Hayır")
        """
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
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("MacRAR-\(UUID().uuidString)").path
        Ops.extract(info: info, names: [n.path], dest: tmp, password: password, host: window, quiet: true) { [weak self] ok, pw in
            self?.password = pw ?? self?.password
            guard ok else { return }
            let target = (tmp as NSString).appendingPathComponent(n.path)
            NSWorkspace.shared.open(URL(fileURLWithPath: target))
        }
    }

    @objc func searchChanged(_ sender: NSSearchField) {
        filterText = sender.stringValue.trimmingCharacters(in: .whitespaces)
        applyFilter()
    }

    @objc func selectAllItems(_ sender: Any?) {
        outline.selectAll(nil)
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
            s.label = "Ara"
            s.searchField.placeholderString = "Arşivde ara"
            s.searchField.target = self
            s.searchField.action = #selector(searchChanged(_:))
            s.searchField.sendsSearchStringImmediately = true
            s.searchField.sendsWholeSearchString = false
            return s
        }
        let specs: [NSToolbarItem.Identifier: (String, String, Selector, String)] = [
            TB.open: ("Aç", "folder", #selector(openArchive), "Arşiv aç"),
            TB.newArchive: ("Sıkıştır", "doc.zipper", #selector(newArchive), "Yeni arşiv oluştur"),
            TB.extractTo: ("Çıkart…", "square.and.arrow.down", #selector(extractTo), "Seçilen klasöre çıkart"),
            TB.extractHere: ("Buraya", "arrow.down.doc", #selector(extractHere), "Arşivin bulunduğu klasöre çıkart"),
            TB.extractFolder: ("Klasöre", "folder.badge.plus", #selector(extractToFolder), "Arşiv adıyla yeni klasöre çıkart"),
            TB.test: ("Test", "checkmark.shield", #selector(testArchive), "Arşivi test et"),
            TB.add: ("Ekle", "plus.rectangle.on.folder", #selector(addFiles), "Arşive dosya ekle"),
            TB.delete: ("Sil", "trash", #selector(deleteSelected), "Seçilenleri arşivden sil"),
            TB.info: ("Bilgi", "info.circle", #selector(showInfo), "Arşiv bilgisi"),
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
            cell?.textField?.stringValue = filtered != nil ? node.path : node.name
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

    func outlineViewSelectionDidChange(_ notification: Notification) { updateStatus() }

    // Sürükle-bırak: arşiv dosyası bırakıldığında aç, diğer dosyaları arşive ekle
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        guard info.draggingSource as? NSOutlineView !== outlineView else { return [] }
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty else { return [] }
        outlineView.setDropItem(nil, dropChildIndex: NSOutlineViewDropOnItemIndex)
        return .copy
    }
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty else { return false }
        let paths = urls.map { $0.path }
        let archives = paths.filter { AppDelegate.isArchive($0) }
        let others = paths.filter { !AppDelegate.isArchive($0) }
        if self.info == nil || others.isEmpty {
            for a in archives { AppDelegate.shared.openArchive(a, reuse: self.info == nil ? self : nil) }
            if !others.isEmpty, self.info == nil {
                AppDelegate.shared.compressWithDialog(items: others, host: window) { [weak self] path in
                    if let self, let path { AppDelegate.shared.openArchive(path, reuse: self) }
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in self?.addItems(others) }
        }
        return true
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
                    ? "\"\(nodes[0].name)\" \"\(destName)\" klasörüne çıkartılsın mı?"
                    : "\(nodes.count) öğe \"\(destName)\" klasörüne çıkartılsın mı?"
                dragDecision = Dialogs.confirm(title, "Arşiv: \((info.path as NSString).lastPathComponent)\nHedef: \(destFolder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))\nÖğeler: \(list)", okTitle: "Çıkart")
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
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("MacRAR-drag-\(UUID().uuidString)").path
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
