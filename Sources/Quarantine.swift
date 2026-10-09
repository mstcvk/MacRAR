import Foundation

/// İnternetten gelen bir arşivin karantina bilgisini (com.apple.quarantine) çıkartılan öğelere aktarır.
/// Aktarılmazsa arşivdeki uygulama ve betikler Gatekeeper denetimine takılmadan çalışabilir
/// (Windows'taki CVE-2025-0411'in macOS karşılığı). Arşiv İzlencesi de aynı şekilde davranır.
enum Quarantine {
    private static let attr = "com.apple.quarantine"

    /// Dosyanın karantina değeri; yoksa nil
    static func value(of path: String) -> Data? {
        let size = getxattr(path, attr, nil, 0, 0, 0)
        guard size > 0 else { return nil }
        var data = Data(count: size)
        let n = data.withUnsafeMutableBytes { getxattr(path, attr, $0.baseAddress, size, 0, 0) }
        return n > 0 ? data.prefix(n) : nil
    }

    /// `dest` içinde bu çıkartmada yazılan her öğeye (`since` sonrası değişenlere) karantina değerini uygular.
    /// tops: arşivin üst düzey adları; önceden var olan klasörlerin içine yazılan dosyaları da bulmak için.
    /// Sembolik bağlar izlenmez, böylece hedef klasörün dışına çıkılmaz.
    static func apply(_ value: Data, dest: String, tops: [String], since: Date) {
        let fm = FileManager.default
        let limit = since.timeIntervalSince1970 - 2   // HFS+/FAT zaman damgaları saniye hassasiyetinde
        func info(_ p: String) -> (changed: Bool, isDir: Bool)? {
            var st = stat()
            guard lstat(p, &st) == 0 else { return nil }
            let ctime = Double(st.st_ctimespec.tv_sec) + Double(st.st_ctimespec.tv_nsec) / 1e9
            return (ctime >= limit, (st.st_mode & S_IFMT) == S_IFDIR)
        }
        func tag(_ p: String) {
            _ = value.withUnsafeBytes { setxattr(p, attr, $0.baseAddress, value.count, 0, XATTR_NOFOLLOW) }
        }

        // Üst düzey adlar + yeniden adlandırılarak (-aou) çıkan yeni öğeler
        var roots = Set(tops)
        for name in (try? fm.contentsOfDirectory(atPath: dest)) ?? [] {
            if info((dest as NSString).appendingPathComponent(name))?.changed == true { roots.insert(name) }
        }
        for name in roots {
            let root = (dest as NSString).appendingPathComponent(name)
            guard let r = info(root) else { continue }
            if r.changed { tag(root) }
            guard r.isDir, let walker = fm.enumerator(atPath: root) else { continue }
            for case let rel as String in walker {
                let p = (root as NSString).appendingPathComponent(rel)
                if info(p)?.changed == true { tag(p) }
            }
        }
    }
}
