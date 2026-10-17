/// Arşiv girdi adlarını yerel dosya sistemi işlemleri için çözümler (çakışma denetimi, ağaç, karantina).
/// Seçim, çıkartma ve silme işlemleri ham adı 7zz'ye geri verir; bu tip yalnızca yerel yol üretmek içindir.
/// Foundation gerektirmez: `tests/` altındaki birim testleri bu dosyayı tek başına derler.
enum ArchivePath {
    struct Level {
        let key: String     // arşiv içindeki normalize yol: "dir/a.txt"
        let path: String    // aynı düzeyin ham yolu, 7zz'ye verilir: "./dir/a.txt" → "./dir"
        let name: String    // son bileşen: "a.txt"
    }

    /// "./a//b/" → ["a", "b"]. "." ve boş bileşenler atılır (tar `./` önekleri). Mutlak yol ya da ".." içeren
    /// ad nil döner: arşivin dışındaki bir yere yazılabileceği için bu girdiler yerel işlemlere girmez.
    static func safeComponents(_ raw: String) -> [String]? {
        if raw.hasPrefix("/") { return nil }
        var out: [String] = []
        for part in raw.split(separator: "/") {
            if part == ".." { return nil }
            if part != "." { out.append(String(part)) }
        }
        return out
    }

    /// Üst düzey ad. Arşiv kökündeki girdi ("./") ve güvenli olmayan yollar için nil.
    static func topLevel(_ raw: String) -> String? {
        safeComponents(raw)?.first
    }

    /// Yolun her düzeyi (ara klasörler dahil). Arşiv kökü için boş dizi, güvenli olmayan yol için nil.
    static func levels(_ raw: String) -> [Level]? {
        guard let comps = safeComponents(raw) else { return nil }
        var out: [Level] = []
        var key = ""
        for (i, comp) in comps.enumerated() {
            key = i == 0 ? comp : key + "/" + comp
            out.append(Level(key: key, path: rawPrefix(raw, depth: i + 1), name: comp))
        }
        return out
    }

    /// Ham addaki ilk `depth` anlamlı bileşenin ham önekini verir ("./dir/a.txt", 1 → "./dir").
    /// Ara klasörler arşivde ayrı bir girdi olmayabilir; 7zz'nin eşleştireceği ad bu önektir.
    static func rawPrefix(_ raw: String, depth: Int) -> String {
        var seen = 0
        for part in raw.split(separator: "/") where part != "." {
            seen += 1
            if seen == depth { return String(raw[..<part.endIndex]) }
        }
        return raw
    }
}
