import Cocoa

let size = NSSize(width: 720, height: 420)
let image = NSImage(size: size)

image.lockFocus()

NSColor.black.setFill()
NSRect(origin: .zero, size: size).fill()

let title = "BlackScreen"
let subtitle = "Drag to Applications"

let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 34, weight: .semibold),
    .foregroundColor: NSColor.white
]

let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 18, weight: .regular),
    .foregroundColor: NSColor(white: 0.7, alpha: 1)
]

title.draw(at: NSPoint(x: 260, y: 320), withAttributes: titleAttrs)
subtitle.draw(at: NSPoint(x: 270, y: 285), withAttributes: subtitleAttrs)

let arrowAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 48, weight: .regular),
    .foregroundColor: NSColor(white: 0.85, alpha: 1)
]

"→".draw(at: NSPoint(x: 340, y: 170), withAttributes: arrowAttrs)

image.unlockFocus()

let data = image.tiffRepresentation!
let rep = NSBitmapImageRep(data: data)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "dmg-background.png"))
