import AppKit

/// Real files for the clipboard, drag destinations and external editors.
/// Exported files deliberately outlive the archive window and application process:
/// Finder/Telegram/editors can read them after MacRAR has closed. macOS owns cleanup
/// of this temporary directory; TempDirs.cleanupAll() must not delete these files.
final class ArchiveFileExporter {
    enum Failure: Error {
        case extraction(RarResult)
        case file(Error)
    }
    final class Task {
        let job = RarJob()
        var completions: [(Result<[URL], Failure>) -> Void] = []
        var observers: [(RarJob.Event) -> Void] = []
        func cancel() { job.cancel() }
    }

    let info: ArchiveInfo
    private var cache: [String: URL] = [:]
    private var tasks: [String: Task] = [:]
    var isPreparing: Bool { !tasks.isEmpty }

    init(info: ArchiveInfo) { self.info = info }

    static func roots(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        let unique = paths.filter {
            guard let c = ArchivePath.safeComponents($0), !c.isEmpty else { return false }
            return seen.insert(c.joined(separator: "/")).inserted
        }
        return unique.filter { path in
            let key = ArchivePath.safeComponents(path)!.joined(separator: "/")
            return !seen.contains { key.hasPrefix($0 + "/") }
        }
    }

    func cachedURL(for path: String) -> URL? {
        guard let components = ArchivePath.safeComponents(path), !components.isEmpty else { return nil }
        let key = components.joined(separator: "/")
        for (parent, url) in cache {
            let candidate: URL
            if key == parent { candidate = url }
            else if key.hasPrefix(parent + "/") { candidate = url.appendingPathComponent(String(key.dropFirst(parent.count + 1))) }
            else { continue }
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    func cachedURLs(for paths: [String]) -> [URL]? {
        let roots = Self.roots(paths)
        guard !roots.isEmpty else { return nil }
        let urls = roots.compactMap { cachedURL(for: $0) }
        return urls.count == roots.count ? urls : nil
    }

    @discardableResult
    func prepare(paths: [String], password: String?, onEvent: ((RarJob.Event) -> Void)? = nil,
                 completion: @escaping (Result<[URL], Failure>) -> Void) -> Task? {
        precondition(Thread.isMainThread)
        if let ready = cachedURLs(for: paths) { completion(.success(ready)); return nil }
        let paths = Self.roots(paths)
        guard !info.hasUnsafePaths, !paths.isEmpty else {
            completion(.failure(.file(NSError(domain: "MacRAR.Export", code: 1,
                userInfo: [NSLocalizedDescriptionKey: L("Arşiv güvenli olmayan veya boş bir dosya yolu içeriyor.")]))))
            return nil
        }
        let key = paths.sorted().joined(separator: "\0")
        if let task = tasks[key] {
            task.completions.append(completion)
            if let onEvent { task.observers.append(onEvent) }
            return task
        }
        let task = Task()
        task.completions = [completion]
        if let onEvent { task.observers.append(onEvent) }
        tasks[key] = task
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("MacRAR-Exports", isDirectory: true)
        let destination = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
        } catch {
            tasks.removeValue(forKey: key)
            completion(.failure(.file(error)))
            return nil
        }
        let started = Date()
        let quarantine = Quarantine.value(of: info.path)
        task.job.onEvent = { [weak task] event in task?.observers.forEach { $0(event) } }
        let stages = Ops.extractStages(info: info, names: paths, dest: destination.path, password: password, mode: .overwrite)
        task.job.start(stages: stages) { [self, task] result in
            // Quarantine propagation and directory validation can walk large trees.
            DispatchQueue.global(qos: .userInitiated).async {
                if let quarantine {
                    Quarantine.apply(quarantine, dest: destination.path, tops: self.info.topLevelNames, since: started)
                }
                var outcome: Result<[URL], Failure>
                if !result.ok || result.cancelled {
                    outcome = .failure(.extraction(result))
                } else {
                    do {
                        let urls = try paths.map { try ExportPaths.file($0, in: destination) }
                        try ExportPaths.validateLinks(in: destination)
                        outcome = .success(urls)
                    } catch { outcome = .failure(.file(error)) }
                }
                let final = outcome
                DispatchQueue.main.async {
                    self.tasks.removeValue(forKey: key)
                    if case .success(let urls) = final {
                        for (path, url) in zip(paths, urls) {
                            self.cache[ArchivePath.safeComponents(path)!.joined(separator: "/")] = url
                        }
                    } else {
                        try? FileManager.default.removeItem(at: destination)
                    }
                    task.completions.forEach { $0(final) }
                    task.completions.removeAll()
                    task.observers.removeAll()
                }
            }
        }
        return task
    }
}

/// Never publish an absent file, a traversal path or an external symlink as a file URL.
enum ExportPaths {
    static func file(_ path: String, in directory: URL) throws -> URL {
        guard let parts = ArchivePath.safeComponents(path), !parts.isEmpty else { throw CocoaError(.fileReadInvalidFileName) }
        let url = directory.appendingPathComponent(parts.joined(separator: "/"))
        guard FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileNoSuchFile) }
        try validate(url, in: directory)
        return url
    }
    static func validate(_ url: URL, in directory: URL) throws {
        let root = directory.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        guard url.resolvingSymlinksInPath().standardizedFileURL.path.hasPrefix(root) else {
            throw NSError(domain: "MacRAR.Export", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: L("Arşivdeki bir bağlantı çıkartılan dosyaların dışına işaret ediyor.")])
        }
    }
    static func validateLinks(in directory: URL) throws {
        if let walker = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isSymbolicLinkKey]) {
            for case let url as URL in walker {
                if try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true {
                    try validate(url, in: directory)
                }
            }
        }
    }
}

/// For the asynchronously prepared drag. The table supplies its own source for cached files.
final class ExportDragSource: NSObject, NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
}
