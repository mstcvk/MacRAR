import Foundation

// MARK: - Model

enum ArchiveKind {
    case rar        // okuma 7zz, yazma (isteğe bağlı) kullanıcının RAR aracı
    case other      // 7zz (zip, 7z, tar, gz, xz, bz2, zst, iso, cab, ...)
}

struct ArchiveEntry {
    var name: String            // arşiv içindeki tam yol
    var isDirectory: Bool
    var size: Int64 = 0
    var packedSize: Int64 = 0
    var ratio: String = ""
    var mtime: String = ""
    var crc: String = ""
    var encrypted: Bool = false
}

struct ArchiveInfo {
    var path: String
    var kind: ArchiveKind
    var details: String
    var entries: [ArchiveEntry]
    var headersEncrypted: Bool = false
    /// tar.gz / tar.xz gibi: dış katman 7zz ile açılıp iç tar'a aktarılır
    var tarCompressed: Bool { Formats.isTarCompressed(path) }

    var hasEncryptedFiles: Bool { headersEncrypted || entries.contains { $0.encrypted } }
    var fileCount: Int { entries.filter { !$0.isDirectory }.count }
    var totalSize: Int64 { entries.reduce(0) { $0 + $1.size } }
    var totalPacked: Int64 { entries.reduce(0) { $0 + $1.packedSize } }
    var topLevelNames: [String] {
        var seen = Set<String>(); var out: [String] = []
        for e in entries {
            guard let top = ArchivePath.topLevel(e.name), seen.insert(top).inserted else { continue }
            out.append(top)
        }
        return out
    }
    /// ".." veya mutlak yol içeren girdi var mı; varsa çıkartma reddedilir
    var hasUnsafePaths: Bool { entries.contains { ArchivePath.safeComponents($0.name) == nil } }
    /// Dosya ekleme / silme desteklenir mi?
    var supportsModification: Bool {
        if tarCompressed { return false }
        if kind == .rar { return !AppInfo.isAppStore }   // GitHub sürümünde RAR aracı istenir
        return true
    }
}

struct RarResult {
    let code: Int32
    let output: String
    var cancelled: Bool = false

    var ok: Bool { code == 0 || code == 1 }
    var wrongPassword: Bool {
        code == 11 || output.contains("Incorrect password") || output.contains("Wrong password")
            || output.contains("Cannot open encrypted archive")
    }
    var notArchive: Bool { output.contains("is not RAR archive") || output.contains("Cannot open the file as archive") }

    /// Kullanıcıya gösterilecek kısa hata metni
    var errorSummary: String {
        let lines = output.components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: "\u{8}", with: "").trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { !$0.hasPrefix("UNRAR ") && !$0.hasPrefix("RAR ") && !$0.hasPrefix("Trial version") && !$0.hasPrefix("Evaluation copy") && !$0.hasPrefix("7-Zip") && !$0.hasPrefix("64-bit") }
        let interesting = lines.filter { l in
            l.contains("error") || l.contains("Error") || l.contains("ERROR") || l.contains("Incorrect") || l.contains("Wrong")
                || l.contains("failed") || l.contains("Failed") || l.contains("not RAR") || l.contains("Cannot") || l.contains("Can not")
                || l.contains("No files") || l.contains("Checksum") || l.contains("CRC") || l.contains("denied") || l.contains("Total errors")
                || l.contains("Unexpected end") || l.contains("Data Error") || l.contains("Unsupported")
        }
        let chosen = interesting.isEmpty ? Array(lines.suffix(6)) : Array(interesting.suffix(8))
        return chosen.joined(separator: "\n")
    }
}

enum RarTool { case rar, sevenZip }

typealias Stage = (tool: RarTool, args: [String])

// MARK: - Biçim bilgisi

enum Formats {
    /// Uygulamanın açabildiği uzantılar
    static let openable: Set<String> = [
        "rar", "zip", "7z", "tar", "gz", "tgz", "bz2", "tbz", "tbz2", "xz", "txz", "zst", "tzst", "lz4", "lzma", "tlz", "z",
        "cab", "arj", "lzh", "lha", "cpio", "iso", "wim", "swm", "esd", "deb", "rpm", "jar", "war", "ear", "apk", "ipa",
        "xpi", "crx", "nupkg", "msi", "chm", "udf", "vhd", "vhdx", "vmdk", "qcow2", "squashfs", "cramfs", "ext", "ext2", "ext3", "ext4",
        "hfs", "hfsx", "dmg", "xar", "pkg", "ar", "a", "lib", "zipx", "br", "001", "lz", "uue", "bzip2", "gzip", "sfx",
    ]

    static func isArchive(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        if openable.contains(ext) { return true }
        return ext.range(of: #"^r\d\d$"#, options: .regularExpression) != nil
    }

    static func kind(of path: String) -> ArchiveKind {
        let ext = (path as NSString).pathExtension.lowercased()
        if ext == "rar" || ext.range(of: #"^r\d\d$"#, options: .regularExpression) != nil { return .rar }
        return .other
    }

    static func filterArchives(_ paths: [String]) -> [String] { paths.filter { isArchive($0) } }

    static func isMultiVolume(_ path: String) -> Bool {
        let name = (path as NSString).lastPathComponent
        return name.range(of: #"\.part\d+\.rar$|\.\d{3}$|\.r\d\d$|\.z\d\d$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func isTarCompressed(_ path: String) -> Bool {
        let lower = (path as NSString).lastPathComponent.lowercased()
        let ext = (lower as NSString).pathExtension
        if ["tgz", "tbz", "tbz2", "txz", "tzst", "tlz"].contains(ext) { return true }
        for suffix in [".tar.gz", ".tar.bz2", ".tar.xz", ".tar.zst", ".tar.lz4", ".tar.z", ".tar.lzma", ".tar.lz", ".tar.br"] {
            if lower.hasSuffix(suffix) { return true }
        }
        return false
    }
}

// MARK: - Runner

enum RarRunner {
    static let resourceDir: URL = {
        if let r = Bundle.main.resourceURL,
           FileManager.default.fileExists(atPath: r.appendingPathComponent("7zz").path) {
            return r
        }
        return URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
    }()

    static func url(_ tool: RarTool) -> URL {
        switch tool {
        case .rar: return RarTools.rarURL ?? URL(fileURLWithPath: "/nonexistent/rar")
        case .sevenZip: return resourceDir.appendingPathComponent("7zz")
        }
    }

    /// rar (a / d) için şifre argümanları. DİKKAT: rar, "-p-" verilince "-" karakterini şifre olarak kullanır;
    /// bu yüzden şifre yoksa hiçbir anahtar verilmez.
    static func rarPasswordArgs(_ pw: String?, encryptHeaders: Bool = false) -> [String] {
        guard let pw, !pw.isEmpty else { return [] }
        return [(encryptHeaders ? "-hp" : "-p") + pw]
    }

    /// 7zz için şifre argümanı ("-p" tek başına: boş şifre, etkileşimli sorma yok)
    static func passwordArg7z(_ pw: String?) -> String {
        guard let pw, !pw.isEmpty else { return "-p" }
        return "-p" + pw
    }

    static func makeProcess(_ tool: RarTool, _ args: [String], cwd: String?) -> Process {
        let p = Process()
        p.executableURL = url(tool)
        p.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["LANG"] = "en_US.UTF-8"
        env["LC_ALL"] = "en_US.UTF-8"
        p.environment = env
        if let cwd { p.currentDirectoryURL = URL(fileURLWithPath: cwd) }
        p.standardInput = FileHandle.nullDevice
        return p
    }

    /// Birbirine borulanmış aşamaları eşzamanlı çalıştırır; son aşamanın çıktısı ve çıkış kodu döner.
    static func runStages(_ stages: [Stage], cwd: String? = nil) -> RarResult {
        var processes: [Process] = []
        var prevOut: Pipe? = nil
        for (i, st) in stages.enumerated() {
            let p = makeProcess(st.tool, st.args, cwd: cwd)
            if let prev = prevOut { p.standardInput = prev.fileHandleForReading }
            if i < stages.count - 1 {
                let out = Pipe()
                p.standardOutput = out
                p.standardError = FileHandle.nullDevice
                prevOut = out
            }
            processes.append(p)
        }
        guard let last = processes.last else { return RarResult(code: -1, output: "") }
        let pipe = Pipe()
        last.standardOutput = pipe
        last.standardError = pipe
        for p in processes {
            do { try p.run() } catch {
                return RarResult(code: -1, output: LF("Çalıştırılamadı: %@", error.localizedDescription))
            }
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        processes.forEach { $0.waitUntilExit() }
        return RarResult(code: last.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }

    enum ListOutcome {
        case ok(ArchiveInfo)
        case wrongPassword
        case error(RarResult)
    }

    /// Tüm biçimler (RAR dahil) 7zz ile okunur
    static func listStages(_ path: String, password: String?) -> [Stage] {
        if Formats.isTarCompressed(path) {
            return [(.sevenZip, ["x", "-so", passwordArg7z(password), "--", path]),
                    (.sevenZip, ["l", "-si", "-ttar", "-slt"])]
        }
        return [(.sevenZip, ["l", "-slt", passwordArg7z(password), "--", path])]
    }

    static func list(_ path: String, password: String?) -> ListOutcome {
        let r = runStages(listStages(path, password: password))
        if r.wrongPassword { return .wrongPassword }
        if r.notArchive || (!r.ok && !r.output.contains("----------")) { return .error(r) }
        guard r.output.contains("----------") || r.output.contains("Type = ") else { return .error(r) }
        return .ok(parse7zListing(r.output, path: path, kind: Formats.kind(of: path)))
    }

    // MARK: 7zz l -slt ayrıştırma

    static func parse7zListing(_ out: String, path: String, kind: ArchiveKind = .other) -> ArchiveInfo {
        let lines = out.components(separatedBy: "\n")
        // Son "----------" satırından sonrası girdiler; öncesi arşiv başlık blokları
        let sepIndex = lines.lastIndex { $0.trimmingCharacters(in: .whitespaces) == "----------" }
        let headerLines = sepIndex.map { Array(lines[..<$0]) } ?? lines
        let entryLines = sepIndex.map { Array(lines[($0 + 1)...]) } ?? []

        // Başlık: son "Type =" değeri asıl arşiv türüdür (split/gzip gibi dış katmanlar önce gelir)
        var type = ""
        var solid = false
        var volumes = 0
        var outerTypes: [String] = []
        for raw in headerLines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard let r = line.range(of: " = ") else { continue }
            let key = String(line[..<r.lowerBound])
            let value = String(line[r.upperBound...])
            switch key {
            case "Type": if !type.isEmpty { outerTypes.append(type) }; type = value
            case "Solid": solid = (value == "+")
            case "Volumes": volumes = Int(value) ?? 0
            default: break
            }
        }
        if Formats.isTarCompressed(path), type.isEmpty { type = "tar" }

        var entries: [ArchiveEntry] = []
        var block: [String: String] = [:]
        func flush() {
            defer { block = [:] }
            guard let name = block["Path"], !name.isEmpty else { return }
            let attrs = block["Attributes"] ?? ""
            let isDir = block["Folder"] == "+" || attrs.hasPrefix("D")
            var e = ArchiveEntry(name: name.hasSuffix("/") ? String(name.dropLast()) : name, isDirectory: isDir)
            e.size = Int64(block["Size"] ?? "") ?? 0
            e.packedSize = Int64(block["Packed Size"] ?? "") ?? 0
            if e.size > 0, e.packedSize > 0 { e.ratio = "\(Int(Double(e.packedSize) * 100 / Double(e.size)))%" }
            if let m = block["Modified"] { e.mtime = String(m.prefix(19)) }
            e.crc = block["CRC"] ?? ""
            e.encrypted = block["Encrypted"] == "+"
            entries.append(e)
        }
        for raw in entryLines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flush(); continue }
            guard let r = line.range(of: " = ") else {
                if line.hasSuffix(" =") { block[String(line.dropLast(2))] = "" }
                continue
            }
            let key = String(line[..<r.lowerBound])
            let value = String(line[r.upperBound...])
            if key == "Path", block["Path"] != nil { flush() }
            block[key] = value
        }
        flush()

        let pretty: String
        switch type.lowercased() {
        case "": pretty = L("arşiv")
        case "rar5": pretty = "RAR 5"
        case "rar": pretty = "RAR 4"
        case "7z": pretty = "7z"
        default: pretty = type.uppercased()
        }
        var parts: [String] = [pretty]
        if Formats.isTarCompressed(path) {
            let outerExt = (path as NSString).pathExtension.lowercased()
            parts = ["tar + \(outerExt)"]
        }
        if solid { parts.append("solid") }
        if volumes > 1 { parts.append("\(volumes) volume") }
        var info = ArchiveInfo(path: path, kind: kind, details: parts.joined(separator: ", "), entries: entries)
        info.headersEncrypted = false
        return info
    }
}

// MARK: - Streaming job (ilerleme takibi)

final class RarJob {
    enum Event {
        case file(String)       // yeni dosya işleniyor
        case progress(Int)      // yüzde (toplam)
    }

    private var processes: [Process] = []
    private var monitoredTool: RarTool = .sevenZip
    private let queue = DispatchQueue(label: "macrar.job")
    private var buffer = Data()
    private var output = ""
    private(set) var cancelled = false
    var onEvent: ((Event) -> Void)?   // ana kuyrukta çağrılır

    private static let verbs = ["Extracting", "Adding", "Testing", "Updating", "Creating", "Deleting", "Compressing", "Fresh", "Calculating"]
    private static let percentRegex = try! NSRegularExpression(pattern: #"(\d{1,3})%"#)
    private static let percentHeadRegex = try! NSRegularExpression(pattern: #"^\s*(\d{1,3})%"#)
    private static let tailRegex = try! NSRegularExpression(pattern: #"\s*(\d{1,3}%|OK|Failed|CRC failed)\s*$"#)
    private static let sevenNameRegex = try! NSRegularExpression(pattern: #"(?:^|\s)([-+TU])\s(\S.*)$"#)

    /// Aşamalar birbirine borulanır; yalnızca son aşamanın çıktısı izlenir.
    func start(stages: [Stage], cwd: String? = nil, completion: @escaping (RarResult) -> Void) {
        guard let lastStage = stages.last else { return }
        monitoredTool = lastStage.tool
        var procs: [Process] = []
        var prevOut: Pipe? = nil
        for (i, st) in stages.enumerated() {
            let p = RarRunner.makeProcess(st.tool, st.args, cwd: cwd)
            if let prev = prevOut { p.standardInput = prev.fileHandleForReading }
            if i < stages.count - 1 {
                let out = Pipe()
                p.standardOutput = out
                p.standardError = FileHandle.nullDevice
                prevOut = out
            }
            procs.append(p)
        }
        let last = procs[procs.count - 1]
        let pipe = Pipe()
        last.standardOutput = pipe
        last.standardError = pipe
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] h in
            let d = h.availableData
            guard !d.isEmpty, let self else { return }
            self.queue.async { self.consume(d) }
        }
        last.terminationHandler = { [weak self] proc in
            handle.readabilityHandler = nil
            let rest = handle.readDataToEndOfFile()
            guard let self else { return }
            self.queue.async {
                self.consume(rest)
                self.flushPartial()
                for p in self.processes where p !== proc && p.isRunning { p.terminate() }
                let result = RarResult(code: proc.terminationStatus, output: self.output, cancelled: self.cancelled)
                DispatchQueue.main.async { completion(result) }
            }
        }
        processes = procs
        for p in procs {
            do { try p.run() } catch {
                DispatchQueue.main.async {
                    completion(RarResult(code: -1, output: LF("Çalıştırılamadı: %@", error.localizedDescription)))
                }
                return
            }
        }
    }

    func cancel() {
        cancelled = true
        processes.forEach { if $0.isRunning { $0.terminate() } }
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let nl = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<nl]
            buffer.removeSubrange(buffer.startIndex...nl)
            let line = String(decoding: lineData, as: UTF8.self)
            output += Self.lastSegment(line, keepAll: true) + "\n"
            parse(Self.lastSegment(line))
        }
        // Satır sonu gelmeden geri-silme (\u{8}) ile güncellenen ilerleme: yalnızca en son durumu oku
        if !buffer.isEmpty {
            let tail = String(decoding: buffer.suffix(512), as: UTF8.self)
            parse(Self.lastSegment(tail))
            // Uzun süren tek dosyada tampon şişmesin: son geri-silme dizisinden öncesini at
            if buffer.count > 64 * 1024, let cut = buffer.lastIndex(of: 0x08) {
                buffer.removeSubrange(buffer.startIndex...cut)
            }
        }
    }

    /// Geri-silme ile üst üste yazılmış bir satırın ekranda görünen son hali
    private static func lastSegment(_ s: String, keepAll: Bool = false) -> String {
        let parts = s.components(separatedBy: "\u{8}").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if keepAll {
            // Günlük için: tekrar eden yüzde parçalarını at, anlamlı metni koru
            let meaningful = parts.filter { $0.trimmingCharacters(in: .whitespaces).range(of: #"^\d{1,3}%( \d+)?$"#, options: .regularExpression) == nil }
            return meaningful.joined(separator: " ")
        }
        return parts.last ?? ""
    }

    private func flushPartial() {
        if !buffer.isEmpty {
            output += String(decoding: buffer, as: UTF8.self).replacingOccurrences(of: "\u{8}", with: "")
            buffer.removeAll()
        }
    }

    private func parse(_ raw: String) {
        let line = raw.replacingOccurrences(of: "\u{8}", with: "").trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return }
        var pct: Int? = nil
        var fileName: String? = nil

        if monitoredTool == .sevenZip {
            let ns = line as NSString
            let full = NSRange(location: 0, length: ns.length)
            if let m = Self.percentHeadRegex.firstMatch(in: line, range: full) {
                pct = Int(ns.substring(with: m.range(at: 1)))
            }
            if line.contains("ERROR") || line.hasSuffix("--") || line.contains(" Open ") {
                // hata satırları ve "Open --" gibi bilgi satırları dosya değil
            } else if let m = Self.sevenNameRegex.firstMatch(in: line, range: full) {
                var name = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespaces)
                if name.hasSuffix("/") { name.removeLast() }
                if !name.isEmpty, !name.hasPrefix("Everything") { fileName = name }
            }
        } else {
            let ns = line as NSString
            let full = NSRange(location: 0, length: ns.length)
            if let m = Self.percentRegex.matches(in: line, range: full).last {
                pct = Int(ns.substring(with: m.range(at: 1)))
            }
            var candidate: String? = nil
            if line.hasPrefix("... ") {
                candidate = String(line.dropFirst(4))        // parça değişiminden sonra devam eden dosya
            } else {
                for verb in Self.verbs where line.hasPrefix(verb + " ") {
                    let rest = String(line.dropFirst(verb.count)).trimmingCharacters(in: .whitespaces)
                    if rest.hasPrefix("from ") || rest.hasPrefix("archive ") { break }
                    candidate = rest
                    break
                }
            }
            if let c = candidate {
                var name = c.trimmingCharacters(in: .whitespaces)
                while let m = Self.tailRegex.firstMatch(in: name, range: NSRange(location: 0, length: (name as NSString).length)) {
                    name = (name as NSString).substring(to: m.range.location)
                }
                fileName = name.trimmingCharacters(in: .whitespaces)
            }
        }

        guard fileName != nil || pct != nil, let onEvent else { return }
        DispatchQueue.main.async {
            if let f = fileName, !f.isEmpty { onEvent(.file(f)) }
            if let p = pct { onEvent(.progress(p)) }
        }
    }
}

// MARK: - Yardımcılar

/// Oturum boyunca oluşturulan geçici klasörler; çıkışta temizlenir
enum TempDirs {
    private static var created: [String] = []
    private static let lock = NSLock()
    static func make(_ prefix: String = "Archiver") -> String {
        let p = FileManager.default.temporaryDirectory.appendingPathComponent("\(prefix)-\(UUID().uuidString)").path
        lock.lock(); created.append(p); lock.unlock()
        return p
    }
    static func cleanupAll() {
        lock.lock(); let list = created; created = []; lock.unlock()
        for p in list { try? FileManager.default.removeItem(atPath: p) }
    }
}

enum Fmt {
    static let bytes: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()
    static func size(_ n: Int64) -> String { bytes.string(fromByteCount: n) }
}

func isDirectoryPath(_ path: String) -> Bool {
    var isDir: ObjCBool = false
    return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
}

func uniquePath(_ path: String) -> String {
    let fm = FileManager.default
    guard fm.fileExists(atPath: path) else { return path }
    let ns = path as NSString
    let dir = ns.deletingLastPathComponent
    let ext = ns.pathExtension
    let base = (ns.deletingPathExtension as NSString).lastPathComponent
    var i = 2
    while true {
        let candidate = (dir as NSString).appendingPathComponent(ext.isEmpty ? "\(base) \(i)" : "\(base) \(i).\(ext)")
        if !fm.fileExists(atPath: candidate) { return candidate }
        i += 1
    }
}
