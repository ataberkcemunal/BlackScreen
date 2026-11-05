import AppKit
import CoreGraphics

// Usage: swift make_icon.swift <output.png>
let size: CGFloat = 1024
let out = CommandLine.arguments[1]

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
                    bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func linear(_ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [])
}

func radial(_ colors: [CGColor], center: CGPoint, radius: CGFloat) {
    let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: nil)!
    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0,
                           endCenter: center, endRadius: radius, options: [])
}

func rounded(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// MARK: Squircle background (macOS icon grid: 824pt body, 100pt margin)
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = rounded(body, 185)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.35))
ctx.addPath(bodyPath); ctx.setFillColor(rgb(0x14161F)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(bodyPath); ctx.clip()
linear([rgb(0x2C3150), rgb(0x0B0C13)], from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))
// soft cinematic glow behind the laptop
radial([rgb(0x6C7BFF, 0.38), rgb(0x6C7BFF, 0)], center: CGPoint(x: 512, y: 600), radius: 420)
ctx.restoreGState()

// MARK: Laptop
let lid = CGRect(x: 236, y: 372, width: 552, height: 364)
let base = CGRect(x: 168, y: 330, width: 688, height: 46)

// lid shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: rgb(0x000000, 0.5))
ctx.addPath(rounded(lid, 30)); ctx.setFillColor(rgb(0xA9ADB6)); ctx.fillPath()
ctx.restoreGState()

// aluminium lid
ctx.saveGState()
ctx.addPath(rounded(lid, 30)); ctx.clip()
linear([rgb(0xE3E6EC), rgb(0x9DA2AC)], from: CGPoint(x: lid.midX, y: lid.maxY), to: CGPoint(x: lid.midX, y: lid.minY))
ctx.restoreGState()

// black screen
let screen = lid.insetBy(dx: 18, dy: 18)
ctx.addPath(rounded(screen, 14)); ctx.setFillColor(rgb(0x000000)); ctx.fillPath()

// MARK: Moon + stars on the screen
ctx.saveGState()
ctx.addPath(rounded(screen, 14)); ctx.clip()

let moonC = CGPoint(x: screen.midX + 6, y: screen.midY + 6)
let moonR: CGFloat = 96
radial([rgb(0xFFE8A8, 0.26), rgb(0xFFE8A8, 0)], center: moonC, radius: moonR * 2.2)

// crescent = moon disc minus an offset disc
let cut = CGPoint(x: moonC.x + moonR * 0.5, y: moonC.y + moonR * 0.32)
let cutR = moonR * 0.84
ctx.addRect(screen)
ctx.addEllipse(in: CGRect(x: cut.x - cutR, y: cut.y - cutR, width: cutR * 2, height: cutR * 2))
ctx.clip(using: .evenOdd) // everything except the cut disc
ctx.addEllipse(in: CGRect(x: moonC.x - moonR, y: moonC.y - moonR, width: moonR * 2, height: moonR * 2))
ctx.clip()
linear([rgb(0xFFF3CF), rgb(0xF3C96B)], from: CGPoint(x: moonC.x, y: moonC.y + moonR), to: CGPoint(x: moonC.x, y: moonC.y - moonR))
ctx.restoreGState()

func star(_ c: CGPoint, _ r: CGFloat, _ a: CGFloat) {
    ctx.saveGState()
    ctx.addPath(rounded(screen, 14)); ctx.clip()
    radial([rgb(0xFFFFFF, a), rgb(0xFFFFFF, 0)], center: c, radius: r * 3)
    ctx.setFillColor(rgb(0xFFFFFF, a))
    ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    ctx.restoreGState()
}
star(CGPoint(x: screen.midX + 130, y: screen.midY + 92), 6, 0.9)
star(CGPoint(x: screen.midX + 172, y: screen.midY + 20), 4, 0.7)
star(CGPoint(x: screen.midX - 150, y: screen.midY + 70), 4.5, 0.6)

// MARK: Base
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: rgb(0x000000, 0.55))
ctx.addPath(rounded(base, 22)); ctx.setFillColor(rgb(0xB5B9C2)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(rounded(base, 22)); ctx.clip()
linear([rgb(0xEEF0F4), rgb(0x8E939D)], from: CGPoint(x: base.midX, y: base.maxY), to: CGPoint(x: base.midX, y: base.minY))
ctx.restoreGState()

// thumb notch
let notch = CGRect(x: base.midX - 64, y: base.maxY - 14, width: 128, height: 14)
ctx.addPath(rounded(notch, 7)); ctx.setFillColor(rgb(0x7D828C)); ctx.fillPath()

// MARK: Export
let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
