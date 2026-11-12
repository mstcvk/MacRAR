import AppKit

var checks = 0
func check(_ value: @autoclosure () -> Bool, _ label: String) {
    checks += 1
    guard value() else { fatalError("FAIL: \(label)") }
    print("PASS: \(label)")
}
let root = URL(fileURLWithPath: CommandLine.arguments[1])
func archive(_ name: String, password: String? = nil) -> ArchiveInfo {
    guard case .ok(let info) = RarRunner.list(root.appendingPathComponent(name).path, password: password) else { fatalError("Cannot list \(name)") }
    return info
}
func prepare(_ exporter: ArchiveFileExporter, _ paths: [String], password: String? = nil) -> Result<[URL], ArchiveFileExporter.Failure> {
    var result: Result<[URL], ArchiveFileExporter.Failure>?
    exporter.prepare(paths: paths, password: password) { result = $0 }
    let deadline = Date().addingTimeInterval(30)
    while result == nil && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
    guard let result else { fatalError("Export timeout") }
    return result
}
func urls(_ result: Result<[URL], ArchiveFileExporter.Failure>) -> [URL] {
    guard case .success(let urls) = result else { fatalError("Export failed: \(result)") }
    return urls
}
let ex = ArchiveFileExporter(info: archive("fixture.zip"))
let files = urls(prepare(ex, ["nested/тест.txt", "other/тест.txt", "literal*.txt"]))
check(files.count == 3, "Multiple items and duplicate basenames survive export")
check((try? String(contentsOf: files[0], encoding: .utf8)) == "nested content", "Unicode nested filename reads correctly")
check((try? String(contentsOf: files[1], encoding: .utf8)) == "other content", "Duplicate basename is a separate real file")
check((try? String(contentsOf: files[2], encoding: .utf8)) == "literal star", "Wildcard filename extracted literally")
let exportRoot = files[2].deletingLastPathComponent()
check(!FileManager.default.fileExists(atPath: exportRoot.appendingPathComponent("literal-unselected.txt").path), "Wildcard selection does not extract unselected files")
check(ex.cachedURLs(for: ["nested/тест.txt"]) == [files[0]], "Opening and copying reuse the prepared file")
let pb = NSPasteboard(name: NSPasteboard.Name("MacRAR.Export.Tests"))
pb.clearContents()
check(pb.writeObjects(files as [NSURL]), "Pasteboard accepts real file URLs")
let recovered = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
check(recovered == files, "Destination app reads all file URLs, not archive names or promises")
TempDirs.cleanupAll()
check(files.allSatisfy { FileManager.default.fileExists(atPath: $0.path) }, "Exports survive application temporary-directory cleanup")
let parent = urls(prepare(ex, ["nested", "nested/тест.txt"]))
check(parent.count == 1 && parent[0].lastPathComponent == "nested", "Parent selection suppresses duplicate child")
check(ArchiveFileExporter.roots(["./nested", "nested/тест.txt", "nested"]) == ["./nested"], "Canonical parent and duplicate selections collapse")
let tar = ArchiveFileExporter(info: archive("fixture.tar.gz"))
let tarFiles = urls(prepare(tar, ["./nested/тест.txt"]))
check((try? String(contentsOf: tarFiles[0], encoding: .utf8)) == "nested content", "tar.gz with ./ prefix exports the selected file")
let encrypted = ArchiveFileExporter(info: archive("encrypted.zip"))
switch prepare(encrypted, ["secret.txt"], password: "wrong") {
case .failure(.extraction(let r)): check(r.wrongPassword, "Incorrect password reported for retry")
default: fatalError("Wrong password unexpectedly succeeded")
}
check(encrypted.cachedURL(for: "secret.txt") == nil, "Failed exports never enter cache")
let secret = urls(prepare(encrypted, ["secret.txt"], password: "test-password"))
check((try? String(contentsOf: secret[0], encoding: .utf8)) == "secret test", "Retry with correct password succeeds")
let unsafe = ArchiveFileExporter(info: archive("unsafe.zip"))
if case .failure = prepare(unsafe, ["safe.txt"]) { check(true, "Traversal archive refused") }
else { fatalError("Traversal archive allowed") }
let links = root.appendingPathComponent("links")
try FileManager.default.createDirectory(at: links, withIntermediateDirectories: true)
try "inside".write(to: links.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
try FileManager.default.createSymbolicLink(atPath: links.appendingPathComponent("good").path, withDestinationPath: "file.txt")
try ExportPaths.validateLinks(in: links)
check(true, "Internal symlink allowed")
try FileManager.default.createSymbolicLink(atPath: links.appendingPathComponent("bad").path, withDestinationPath: "/etc/hosts")
do { try ExportPaths.validateLinks(in: links); fatalError("External symlink allowed") }
catch { check(true, "External symlink refused before publishing files") }
let shared = ArchiveFileExporter(info: archive("fixture.zip"))
var sharedResults: [[URL]] = []
let first = shared.prepare(paths: ["readme.txt"], password: nil) { sharedResults.append(urls($0)) }
let second = shared.prepare(paths: ["readme.txt"], password: nil) { sharedResults.append(urls($0)) }
check(first === second, "Concurrent warmup and explicit action share one extraction")
let deadline = Date().addingTimeInterval(30)
while sharedResults.count < 2 && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
check(sharedResults.count == 2 && sharedResults[0] == sharedResults[1], "Both waiting actions receive the same prepared files")
var rarFiles: [URL] = []
if let path = ProcessInfo.processInfo.environment["MACRAR_RAR_FIXTURE"] {
    guard case .ok(let info) = RarRunner.list(path, password: nil) else { fatalError("Cannot list RAR fixture") }
    rarFiles = urls(prepare(ArchiveFileExporter(info: info), ["test.txt", "testdir/test.txt"]))
    check(rarFiles.count == 2 && (try? Data(contentsOf: rarFiles[0]))?.count == 20, "RAR exports root and nested files")
    check((try? Data(contentsOf: rarFiles[0])) == (try? Data(contentsOf: rarFiles[1])), "RAR duplicate basenames preserve file contents")
}
// All exported test folders are private to this test run.
for u in Set(files + parent + tarFiles + secret + sharedResults.flatMap { $0 } + rarFiles) {
    var p = u
    while p.deletingLastPathComponent().lastPathComponent != "MacRAR-Exports" { p.deleteLastPathComponent() }
    try? FileManager.default.removeItem(at: p)
}
pb.releaseGlobally()
print("All \(checks) export integration checks passed")
