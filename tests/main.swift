import Foundation

var checks = 0
var failures = 0

func expect<T: Equatable>(_ actual: T, _ expected: T, _ label: String) {
    checks += 1
    if actual != expected {
        failures += 1
        print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)")
    }
}

func flat(_ levels: [ArchivePath.Level]?) -> [[String]]? {
    levels?.map { [$0.key, $0.path, $0.name] }
}

// safeComponents: "./" önekleri atılır, ".." ve mutlak yol reddedilir
expect(ArchivePath.safeComponents("./"), [], "safe: ./ is archive root")
expect(ArchivePath.safeComponents("."), [], "safe: . is archive root")
expect(ArchivePath.safeComponents(""), [], "safe: empty is archive root")
expect(ArchivePath.safeComponents("./dir/a.txt"), ["dir", "a.txt"], "safe: ./ prefix dropped")
expect(ArchivePath.safeComponents("dir/"), ["dir"], "safe: trailing slash")
expect(ArchivePath.safeComponents("a//b"), ["a", "b"], "safe: empty component dropped")
expect(ArchivePath.safeComponents("../x"), nil, "safe: leading .. rejected")
expect(ArchivePath.safeComponents("./../x"), nil, "safe: ./.. rejected")
expect(ArchivePath.safeComponents("a/../../x"), nil, "safe: inner .. rejected")
expect(ArchivePath.safeComponents("/abs/x"), nil, "safe: absolute rejected")

// topLevel: çıkartma çakışma denetiminin baktığı ad
expect(ArchivePath.topLevel("./dir/a.txt"), "dir", "top: ./ prefix")
expect(ArchivePath.topLevel("file.txt"), "file.txt", "top: plain file")
expect(ArchivePath.topLevel("./"), nil, "top: archive root is not a name")
expect(ArchivePath.topLevel("../x"), nil, "top: unsafe is not a name")

// rawPrefix: 7zz'ye giden ham önek, ara klasörler için de doğru
expect(ArchivePath.rawPrefix("./dir/a.txt", depth: 1), "./dir", "raw: depth 1")
expect(ArchivePath.rawPrefix("./dir/a.txt", depth: 2), "./dir/a.txt", "raw: depth 2")
expect(ArchivePath.rawPrefix("dir/a.txt", depth: 1), "dir", "raw: no ./ prefix")

// levels
expect(flat(ArchivePath.levels("./dir/a.txt")),
       [["dir", "./dir", "dir"], ["dir/a.txt", "./dir/a.txt", "a.txt"]], "levels: nested")
expect(flat(ArchivePath.levels("./")), [], "levels: archive root gives none")
expect(flat(ArchivePath.levels("../x")), nil, "levels: unsafe gives nil")

// Ağaç: gerçek Node.buildTree (ArchiveWindow.swift) ve ArchiveEntry (RarEngine.swift)
let entries = [
    ArchiveEntry(name: "./", isDirectory: true),
    ArchiveEntry(name: "./dir", isDirectory: true),
    ArchiveEntry(name: "./dir/a.txt", isDirectory: false, size: 3),
    ArchiveEntry(name: "./dir/a.txt", isDirectory: false, size: 3),
    ArchiveEntry(name: "./dir/sub/b.txt", isDirectory: false, size: 5),
    ArchiveEntry(name: "../evil.sh", isDirectory: false),
    ArchiveEntry(name: "/abs.txt", isDirectory: false),
    ArchiveEntry(name: "top.txt", isDirectory: false),
]
let root = Node.buildTree(entries)
var all: [Node] = []
root.flatten(into: &all)

expect(root.children.map { $0.name }, ["dir", "top.txt"], "tree: root children, dirs first")
expect(all.contains { $0.name == "." || $0.name == ".." }, false, "tree: no . or .. node")
expect(all.contains { $0.path.contains("evil") || $0.path.contains("abs") }, false, "tree: unsafe entries excluded")

let dir = root.children.first { $0.name == "dir" }
expect(dir?.path, "./dir", "tree: dir raw path kept for 7zz")
expect(dir?.key, "dir", "tree: dir normalized key")
expect(dir?.children.map { $0.name }, ["sub", "a.txt"], "tree: dir children")

let aTxt = dir?.children.first { $0.name == "a.txt" }
expect(aTxt?.children.count, 0, "tree: a.txt is a leaf")
expect(aTxt?.path, "./dir/a.txt", "tree: file raw path kept")
expect(aTxt?.entry?.size, 3, "tree: duplicate entry collapsed to one node")

let sub = dir?.children.first { $0.name == "sub" }
expect(sub?.path, "./dir/sub", "tree: implicit dir gets raw prefix")
expect(sub?.children.first?.path, "./dir/sub/b.txt", "tree: nested file raw path")
expect(sub?.children.first?.key, "dir/sub/b.txt", "tree: nested file normalized key")
expect(dir?.totalSize, 8, "tree: sizes aggregate")

// Windows ayırıcılı ".." ve klasör sınırı
expect(ArchivePath.safeComponents("..\\x"), nil, "safe: backslash .. rejected")
expect(ArchivePath.safeComponents("dir\\..\\x"), nil, "safe: inner backslash .. rejected")
expect(ArchivePath.safeComponents("a\\b"), ["a\\b"], "safe: backslash inside a name kept")
expect(ArchivePath.isInsideDir("a/b", of: ["a"]), true, "inside: child of dir")
expect(ArchivePath.isInsideDir("ab", of: ["a"]), false, "inside: prefix without boundary")
expect(ArchivePath.isInsideDir("a", of: ["a"]), false, "inside: dir is not inside itself")
expect(ArchivePath.isInsideDir("./dir/a.txt", of: ["./dir"]), true, "inside: raw ./ prefix")
expect(ArchivePath.isInsideDir("a/b/c", of: ["a/b"]), true, "inside: nested")

if failures > 0 {
    print("\(failures) of \(checks) checks FAILED")
    exit(1)
}
print("all \(checks) checks passed")
