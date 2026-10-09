import AppKit

#if APPSTORE
/// App Store sürümü: Finder sağ tık menüsündeki komutlar uygulamanın kendi Servisleri ile sağlanır
/// (sandbox içinde ~/Library/Services'e yazılamaz). Tanımlar Info.plist → NSServices içinde.
final class ServiceProvider: NSObject {
    private func paths(_ pboard: NSPasteboard) -> [String] {
        let urls = pboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return urls.map { $0.path }
    }
    private func run(_ make: ([String]) -> Command, _ pboard: NSPasteboard) {
        let p = paths(pboard)
        guard !p.isEmpty else { return }
        let cmd = make(p)
        DispatchQueue.main.async { AppDelegate.shared.runServiceCommand(cmd) }
    }
    @objc func extractHere(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run({ .extractHere(Formats.filterArchives($0)) }, pboard)
    }
    @objc func extractToFolder(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run({ .extractFolder(Formats.filterArchives($0)) }, pboard)
    }
    @objc func extractTo(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run({ .extractTo(Formats.filterArchives($0)) }, pboard)
    }
    @objc func testArchive(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run({ .test(Formats.filterArchives($0)) }, pboard)
    }
    @objc func compress(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run({ .compressDialog($0) }, pboard)
    }
    @objc func quickCompress(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run({ .compress($0) }, pboard)
    }
}
#endif
