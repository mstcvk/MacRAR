import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
AppDelegate.shared = delegate
app.delegate = delegate

// Komut satırı argümanları (Finder hızlı eylemleri "open -n -a MacRAR --args --komut dosya..." ile çağırır)
var args = Array(CommandLine.arguments.dropFirst())
// macOS'un eklediği -psn_... / -NSDocumentRevisionsDebugMode gibi argümanları ayıkla
args.removeAll { $0.hasPrefix("-psn_") || $0 == "-NSDocumentRevisionsDebugMode" || $0 == "YES" }

if let flagIndex = args.firstIndex(where: { $0.hasPrefix("--") }) {
    let flag = args[flagIndex]
    let paths = Array(args[(flagIndex + 1)...]).filter { !$0.hasPrefix("--") }.map { ($0 as NSString).standardizingPath }
    switch flag {
    case "--extract-here":     delegate.pendingCommand = .extractHere(paths)
    case "--extract-folder":   delegate.pendingCommand = .extractFolder(paths)
    case "--extract-to":       delegate.pendingCommand = .extractTo(paths)
    case "--test":             delegate.pendingCommand = .test(paths)
    case "--compress":         delegate.pendingCommand = .compress(paths)
    case "--compress-dialog":  delegate.pendingCommand = .compressDialog(paths)
    case "--set-default":      delegate.pendingCommand = .setDefault
    case "--install-quick-actions": delegate.pendingCommand = .installQuickActions
    default:
        delegate.pendingFiles = paths
    }
} else {
    delegate.pendingFiles = args.filter { !$0.hasPrefix("-") }.map { ($0 as NSString).standardizingPath }
}

app.run()
