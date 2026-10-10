import Foundation

/// Seçimdeki arşiv parçalarından yalnızca açılacak olanları bırakır.
enum Volumes {
    /// Çok parçalı arşivlerde yalnızca ilk parçayı bırakır (ad.part2.rar, ad.7z.002, ad.r00, ad.z01 vb. atlanır)
    static func dedupe(_ rawPaths: [String]) -> [String] {
        // Eski tarz parçalar: ad.rar + ad.r00, ad.r01… ve ad.zip + ad.z01…; ilk parça seçimdeyse diğerleri atlanır
        let lowerSet = Set(rawPaths.map { $0.lowercased() })
        let paths = rawPaths.filter { p in
            let ns = p.lowercased() as NSString
            let ext = ns.pathExtension
            if ext.range(of: #"^r\d\d$"#, options: .regularExpression) != nil { return !lowerSet.contains(ns.deletingPathExtension + ".rar") }
            if ext.range(of: #"^z\d\d$"#, options: .regularExpression) != nil { return !lowerSet.contains(ns.deletingPathExtension + ".zip") }
            return true
        }
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
}
