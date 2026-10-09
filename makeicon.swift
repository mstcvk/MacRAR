import AppKit

// Kullanım: swift makeicon.swift çıktı.png
// Tema: koyu mor zemin üzerinde izometrik, üst üste istiflenmiş paralel plakalar (arşiv katmanları) + altın kilit rozeti
let out = CommandLine.arguments[1]
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// macOS stili yuvarlatılmış kare
let inset: CGFloat = size * 0.1
let rect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let squircle = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
ctx.saveGState()
let drop = NSShadow(); drop.shadowBlurRadius = 24; drop.shadowOffset = NSSize(width: 0, height: -10); drop.shadowColor = NSColor(white: 0, alpha: 0.35); drop.set()
NSColor.black.setFill(); squircle.fill()
ctx.restoreGState()
ctx.saveGState()
squircle.addClip()
NSGradient(colors: [NSColor(calibratedRed: 0.30, green: 0.16, blue: 0.48, alpha: 1),
                    NSColor(calibratedRed: 0.11, green: 0.06, blue: 0.22, alpha: 1)])!.draw(in: rect, angle: -90)
// yumuşak üst parıltı
NSGradient(colors: [NSColor(white: 1, alpha: 0.10), NSColor(white: 1, alpha: 0)])!
    .draw(in: NSRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2), angle: -90)

// İzometrik plaka: üst yüz eşkenar dörtgen, altında sol ve sağ yan yüzler
func slab(cx: CGFloat, cy: CGFloat, w: CGFloat, t: CGFloat, top: NSColor, left: NSColor, right: NSColor) {
    let h = w * 0.5
    let T = NSPoint(x: cx, y: cy + h), R = NSPoint(x: cx + w, y: cy), B = NSPoint(x: cx, y: cy - h), L = NSPoint(x: cx - w, y: cy)
    let leftFace = NSBezierPath(); leftFace.move(to: L); leftFace.line(to: B); leftFace.line(to: NSPoint(x: B.x, y: B.y - t)); leftFace.line(to: NSPoint(x: L.x, y: L.y - t)); leftFace.close()
    let rightFace = NSBezierPath(); rightFace.move(to: B); rightFace.line(to: R); rightFace.line(to: NSPoint(x: R.x, y: R.y - t)); rightFace.line(to: NSPoint(x: B.x, y: B.y - t)); rightFace.close()
    let topFace = NSBezierPath(); topFace.move(to: T); topFace.line(to: R); topFace.line(to: B); topFace.line(to: L); topFace.close()
    left.setFill(); leftFace.fill()
    right.setFill(); rightFace.fill()
    top.setFill(); topFace.fill()
    // ince kenar ışığı
    NSColor(white: 1, alpha: 0.22).setStroke(); topFace.lineWidth = 3; topFace.stroke()
}

let cx = rect.midX
let w = rect.width * 0.33
let thickness = rect.width * 0.075
let gap = rect.width * 0.115
let baseY = rect.minY + rect.height * 0.30
// alttan üste: koyudan açığa
let palette: [(NSColor, NSColor, NSColor)] = [
    (NSColor(calibratedRed: 0.42, green: 0.30, blue: 0.86, alpha: 1), NSColor(calibratedRed: 0.27, green: 0.18, blue: 0.62, alpha: 1), NSColor(calibratedRed: 0.20, green: 0.12, blue: 0.48, alpha: 1)),
    (NSColor(calibratedRed: 0.55, green: 0.38, blue: 0.95, alpha: 1), NSColor(calibratedRed: 0.36, green: 0.23, blue: 0.72, alpha: 1), NSColor(calibratedRed: 0.27, green: 0.16, blue: 0.56, alpha: 1)),
    (NSColor(calibratedRed: 0.70, green: 0.52, blue: 1.00, alpha: 1), NSColor(calibratedRed: 0.47, green: 0.31, blue: 0.82, alpha: 1), NSColor(calibratedRed: 0.36, green: 0.22, blue: 0.66, alpha: 1)),
    (NSColor(calibratedRed: 0.86, green: 0.74, blue: 1.00, alpha: 1), NSColor(calibratedRed: 0.60, green: 0.44, blue: 0.92, alpha: 1), NSColor(calibratedRed: 0.46, green: 0.31, blue: 0.78, alpha: 1)),
]
// plakaların altına yumuşak gölge
ctx.saveGState()
let sh = NSShadow(); sh.shadowBlurRadius = 40; sh.shadowOffset = NSSize(width: 0, height: -18); sh.shadowColor = NSColor(white: 0, alpha: 0.45); sh.set()
for (i, c) in palette.enumerated() {
    slab(cx: cx, cy: baseY + CGFloat(i) * gap, w: w, t: thickness, top: c.0, left: c.1, right: c.2)
}
ctx.restoreGState()
ctx.restoreGState()

// Altın kilit rozeti (şifreli arşiv desteği)
let badgeR = size * 0.105
let bc = NSPoint(x: rect.maxX - badgeR * 1.05, y: rect.maxY - badgeR * 1.05)
ctx.saveGState()
let bsh = NSShadow(); bsh.shadowBlurRadius = 14; bsh.shadowOffset = NSSize(width: 0, height: -5); bsh.shadowColor = NSColor(white: 0, alpha: 0.4); bsh.set()
let badge = NSBezierPath(ovalIn: NSRect(x: bc.x - badgeR, y: bc.y - badgeR, width: badgeR * 2, height: badgeR * 2))
NSGradient(colors: [NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.35, alpha: 1), NSColor(calibratedRed: 0.95, green: 0.68, blue: 0.12, alpha: 1)])!.draw(in: badge, angle: -90)
ctx.restoreGState()
if let lock = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil),
   let li = lock.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: badgeR * 1.05, weight: .bold)) {
    let tinted = NSImage(size: li.size, flipped: false) { r in
        li.draw(in: r)
        NSColor(calibratedRed: 0.24, green: 0.11, blue: 0.36, alpha: 1).set()
        r.fill(using: .sourceAtop)
        return true
    }
    let s = badgeR * 1.15
    let ar = li.size.width / li.size.height
    tinted.draw(in: NSRect(x: bc.x - s * ar / 2, y: bc.y - s / 2, width: s * ar, height: s))
}
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("icon written:", out)
