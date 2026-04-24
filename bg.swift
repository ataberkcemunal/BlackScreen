import Cocoa

let size = NSSize(width: 720, height: 420)
let image = NSImage(size: size)

image.lockFocus()

NSColor.black.setFill()
NSRect(origin: .zero, size: size).fill()

let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 34, weight: .semibold),
    .foregroundColor: NSColor.white
]

let subAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 18, weight: .regular),
    .foregroundColor: NSColor(white: 0.7, alpha: 1)
]

"BlackScreen".draw(at: NSPoint(x: 260, y: 315), withAttributes: titleAttrs)
"Drag to Applications".draw(at: NSPoint(x: 275, y: 280), withAttributes: subAttrs)
"→".draw(at: NSPoint(x: 345, y: 165), withAttributes: [
    .font: NSFont.systemFont(ofSize: 52, weight: .regular),
    .foregroundColor: NSColor.white
])

image.unlockFocus()

let data = image.tiffRepresentation!
let rep = NSBitmapImageRep(data: data)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "background.png"))
