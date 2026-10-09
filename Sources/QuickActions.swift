import Foundation

/// Finder sağ tık menüsündeki "Hızlı Eylemler" için ~/Library/Services altına .workflow paketleri üretir.
enum QuickActions {
    struct Action {
        let name: String        // menüde görünen ad
        let flag: String?       // nil → arşivi uygulamada aç
        let icon: String
    }

    static let actions: [Action] = [
        Action(name: "MacRAR ile Aç", flag: nil, icon: "NSActionTemplate"),
        Action(name: "MacRAR • Buraya Çıkart", flag: "--extract-here", icon: "NSActionTemplate"),
        Action(name: "MacRAR • Klasöre Çıkart", flag: "--extract-folder", icon: "NSActionTemplate"),
        Action(name: "MacRAR • Şuraya Çıkart…", flag: "--extract-to", icon: "NSActionTemplate"),
        Action(name: "MacRAR • Test Et", flag: "--test", icon: "NSActionTemplate"),
        Action(name: "MacRAR • Sıkıştır (RAR)", flag: "--compress", icon: "NSActionTemplate"),
        Action(name: "MacRAR • Arşiv Oluştur…", flag: "--compress-dialog", icon: "NSActionTemplate"),
    ]

    static var servicesDir: String {
        (NSHomeDirectory() as NSString).appendingPathComponent("Library/Services")
    }

    /// Tüm eylemleri kurar, kurulan sayısını döner.
    @discardableResult
    static func installAll() -> Int {
        let appPath = Bundle.main.bundlePath
        let fm = FileManager.default
        try? fm.createDirectory(atPath: servicesDir, withIntermediateDirectories: true)
        // Eski sürümleri temizle
        if let items = try? fm.contentsOfDirectory(atPath: servicesDir) {
            for i in items where i.hasPrefix("RAR • ") || i.hasPrefix("MacRAR • ") || i == "MacRAR ile Aç.workflow" {
                try? fm.removeItem(atPath: (servicesDir as NSString).appendingPathComponent(i))
            }
        }
        var count = 0
        for a in actions {
            let quotedApp = shellQuote(appPath)
            let cmd: String
            if let flag = a.flag {
                cmd = "open -n -a \(quotedApp) --args \(flag) \"$@\""
            } else {
                cmd = "open -a \(quotedApp) \"$@\""
            }
            if write(action: a, command: cmd) { count += 1 }
        }
        refreshServices()
        return count
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func write(action: Action, command: String) -> Bool {
        let bundle = (servicesDir as NSString).appendingPathComponent(action.name + ".workflow")
        let contents = (bundle as NSString).appendingPathComponent("Contents")
        let fm = FileManager.default
        do {
            try fm.createDirectory(atPath: contents, withIntermediateDirectories: true)
            try infoPlist(name: action.name, icon: action.icon).write(toFile: (contents as NSString).appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
            try documentWflow(command: command).write(toFile: (contents as NSString).appendingPathComponent("document.wflow"), atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    private static func refreshServices() {
        let pbs = "/System/Library/CoreServices/pbs"
        for arg in ["-flush", "-update"] {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: pbs)
            p.arguments = [arg]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit()
        }
    }

    private static func infoPlist(name: String, icon: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>NSServices</key>
            <array>
                <dict>
                    <key>NSBackgroundColorName</key>
                    <string>background</string>
                    <key>NSIconName</key>
                    <string>\(icon)</string>
                    <key>NSMenuItem</key>
                    <dict>
                        <key>default</key>
                        <string>\(xmlEscape(name))</string>
                    </dict>
                    <key>NSMessage</key>
                    <string>runWorkflowAsService</string>
                    <key>NSRequiredContext</key>
                    <dict>
                        <key>NSApplicationIdentifier</key>
                        <string>com.apple.finder</string>
                    </dict>
                    <key>NSSendFileTypes</key>
                    <array>
                        <string>public.item</string>
                    </array>
                </dict>
            </array>
        </dict>
        </plist>
        """
    }

    private static func documentWflow(command: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>AMApplicationBuild</key>
            <string>534</string>
            <key>AMApplicationVersion</key>
            <string>2.10</string>
            <key>AMDocumentVersion</key>
            <string>2</string>
            <key>actions</key>
            <array>
                <dict>
                    <key>action</key>
                    <dict>
                        <key>AMAccepts</key>
                        <dict>
                            <key>Container</key>
                            <string>List</string>
                            <key>Optional</key>
                            <true/>
                            <key>Types</key>
                            <array>
                                <string>com.apple.cocoa.path</string>
                            </array>
                        </dict>
                        <key>AMActionVersion</key>
                        <string>2.0.3</string>
                        <key>AMApplication</key>
                        <array>
                            <string>Automator</string>
                        </array>
                        <key>AMParameterProperties</key>
                        <dict>
                            <key>COMMAND_STRING</key>
                            <dict/>
                            <key>CheckedForUserDefaultShell</key>
                            <dict/>
                            <key>inputMethod</key>
                            <dict/>
                            <key>shell</key>
                            <dict/>
                            <key>source</key>
                            <dict/>
                        </dict>
                        <key>AMProvides</key>
                        <dict>
                            <key>Container</key>
                            <string>List</string>
                            <key>Types</key>
                            <array>
                                <string>com.apple.cocoa.string</string>
                            </array>
                        </dict>
                        <key>ActionBundlePath</key>
                        <string>/System/Library/Automator/Run Shell Script.action</string>
                        <key>ActionName</key>
                        <string>Run Shell Script</string>
                        <key>ActionParameters</key>
                        <dict>
                            <key>COMMAND_STRING</key>
                            <string>\(xmlEscape(command))</string>
                            <key>CheckedForUserDefaultShell</key>
                            <true/>
                            <key>inputMethod</key>
                            <integer>1</integer>
                            <key>shell</key>
                            <string>/bin/zsh</string>
                            <key>source</key>
                            <string></string>
                        </dict>
                        <key>BundleIdentifier</key>
                        <string>com.apple.RunShellScript</string>
                        <key>CFBundleVersion</key>
                        <string>2.0.3</string>
                        <key>CanShowSelectedItemsWhenRun</key>
                        <false/>
                        <key>CanShowWhenRun</key>
                        <true/>
                        <key>Category</key>
                        <array>
                            <string>AMCategoryUtilities</string>
                        </array>
                        <key>Class Name</key>
                        <string>RunShellScriptAction</string>
                        <key>InputUUID</key>
                        <string>\(UUID().uuidString)</string>
                        <key>Keywords</key>
                        <array>
                            <string>Shell</string>
                            <string>Script</string>
                        </array>
                        <key>OutputUUID</key>
                        <string>\(UUID().uuidString)</string>
                        <key>UUID</key>
                        <string>\(UUID().uuidString)</string>
                        <key>UnlocalizedApplications</key>
                        <array>
                            <string>Automator</string>
                        </array>
                        <key>arguments</key>
                        <dict>
                            <key>0</key>
                            <dict>
                                <key>default value</key>
                                <integer>0</integer>
                                <key>name</key>
                                <string>inputMethod</string>
                                <key>required</key>
                                <string>0</string>
                                <key>type</key>
                                <string>0</string>
                                <key>uuid</key>
                                <string>0</string>
                            </dict>
                            <key>1</key>
                            <dict>
                                <key>default value</key>
                                <false/>
                                <key>name</key>
                                <string>CheckedForUserDefaultShell</string>
                                <key>required</key>
                                <string>0</string>
                                <key>type</key>
                                <string>0</string>
                                <key>uuid</key>
                                <string>1</string>
                            </dict>
                            <key>2</key>
                            <dict>
                                <key>default value</key>
                                <string></string>
                                <key>name</key>
                                <string>source</string>
                                <key>required</key>
                                <string>0</string>
                                <key>type</key>
                                <string>0</string>
                                <key>uuid</key>
                                <string>2</string>
                            </dict>
                            <key>3</key>
                            <dict>
                                <key>default value</key>
                                <string></string>
                                <key>name</key>
                                <string>COMMAND_STRING</string>
                                <key>required</key>
                                <string>0</string>
                                <key>type</key>
                                <string>0</string>
                                <key>uuid</key>
                                <string>3</string>
                            </dict>
                            <key>4</key>
                            <dict>
                                <key>default value</key>
                                <string>/bin/sh</string>
                                <key>name</key>
                                <string>shell</string>
                                <key>required</key>
                                <string>0</string>
                                <key>type</key>
                                <string>0</string>
                                <key>uuid</key>
                                <string>4</string>
                            </dict>
                        </dict>
                        <key>conversionLabel</key>
                        <integer>0</integer>
                        <key>isViewVisible</key>
                        <integer>1</integer>
                        <key>location</key>
                        <string>309.000000:305.000000</string>
                        <key>nibPath</key>
                        <string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib</string>
                    </dict>
                    <key>isViewVisible</key>
                    <integer>1</integer>
                </dict>
            </array>
            <key>connectors</key>
            <dict/>
            <key>workflowMetaData</key>
            <dict>
                <key>applicationBundleID</key>
                <string>com.apple.finder</string>
                <key>applicationBundleIDsByPath</key>
                <dict>
                    <key>/System/Library/CoreServices/Finder.app</key>
                    <string>com.apple.finder</string>
                </dict>
                <key>applicationPath</key>
                <string>/System/Library/CoreServices/Finder.app</string>
                <key>applicationPaths</key>
                <array>
                    <string>/System/Library/CoreServices/Finder.app</string>
                </array>
                <key>inputTypeIdentifier</key>
                <string>com.apple.Automator.fileSystemObject</string>
                <key>outputTypeIdentifier</key>
                <string>com.apple.Automator.nothing</string>
                <key>presentationMode</key>
                <integer>15</integer>
                <key>processesInput</key>
                <false/>
                <key>serviceApplicationBundleID</key>
                <string>com.apple.finder</string>
                <key>serviceApplicationPath</key>
                <string>/System/Library/CoreServices/Finder.app</string>
                <key>serviceInputTypeIdentifier</key>
                <string>com.apple.Automator.fileSystemObject</string>
                <key>serviceOutputTypeIdentifier</key>
                <string>com.apple.Automator.nothing</string>
                <key>serviceProcessesInput</key>
                <false/>
                <key>systemImageName</key>
                <string>NSActionTemplate</string>
                <key>useAutomaticInputType</key>
                <false/>
                <key>workflowTypeIdentifier</key>
                <string>com.apple.Automator.servicesMenu</string>
            </dict>
        </dict>
        </plist>
        """
    }
}
