import AppKit

// Kullanım: swift makeicon.swift çıktı.png
let out = CommandLine.arguments[1]
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// macOS stili yuvarlatılmış kare (kenar boşluğu ile)
let inset: CGFloat = size * 0.1
let rect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.22, yRadius: rect.width * 0.22)
ctx.saveGState()
path.addClip()
let grad = NSGradient(colors: [NSColor(calibratedRed: 0.55, green: 0.20, blue: 0.65, alpha: 1),
                               NSColor(calibratedRed: 0.25, green: 0.08, blue: 0.40, alpha: 1)])!
grad.draw(in: rect, angle: -90)
ctx.restoreGState()

// Kitap yığını (sıkıştırılmış ciltler) — soyut çizgiler
let barColors = [NSColor(white: 1, alpha: 0.18), NSColor(white: 1, alpha: 0.12), NSColor(white: 1, alpha: 0.08)]
for (i, c) in barColors.enumerated() {
    let h = rect.height * 0.07
    let y = rect.minY + rect.height * 0.13 + CGFloat(i) * h * 1.35
    let bar = NSBezierPath(roundedRect: NSRect(x: rect.minX + rect.width * 0.14, y: y, width: rect.width * 0.72, height: h), xRadius: h / 2, yRadius: h / 2)
    c.setFill(); bar.fill()
}

// "RAR" yazısı
let para = NSMutableParagraphStyle(); para.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: size * 0.30, weight: .heavy),
    .foregroundColor: NSColor.white,
    .paragraphStyle: para,
]
let text = NSAttributedString(string: "RAR", attributes: attrs)
let ts = text.size()
text.draw(in: NSRect(x: rect.minX, y: rect.midY - ts.height * 0.38, width: rect.width, height: ts.height))

// Kilit rozeti (şifreli arşiv desteği)
let badgeR = size * 0.11
let badgeCenter = NSPoint(x: rect.maxX - badgeR * 1.1, y: rect.maxY - badgeR * 1.1)
let badge = NSBezierPath(ovalIn: NSRect(x: badgeCenter.x - badgeR, y: badgeCenter.y - badgeR, width: badgeR * 2, height: badgeR * 2))
NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.2, alpha: 1).setFill(); badge.fill()
if let lock = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil) {
    let cfg = NSImage.SymbolConfiguration(pointSize: badgeR * 1.1, weight: .bold)
    let li = lock.withSymbolConfiguration(cfg)!
    let tinted = NSImage(size: li.size, flipped: false) { r in
        li.draw(in: r)
        NSColor(calibratedRed: 0.3, green: 0.1, blue: 0.4, alpha: 1).set()
        r.fill(using: .sourceAtop)
        return true
    }
    let s = badgeR * 1.2
    tinted.draw(in: NSRect(x: badgeCenter.x - s / 2, y: badgeCenter.y - s / 2, width: s, height: s))
}
img.unlockFocus()

let tiff = img.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
print("icon written:", out)
