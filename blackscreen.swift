import Cocoa
import CoreGraphics
import Darwin

func builtInDisplayID() -> CGDirectDisplayID {
    for screen in NSScreen.screens {
        if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            let id = CGDirectDisplayID(num.uint32Value)
            if CGDisplayIsBuiltin(id) != 0 {
                return id
            }
        }
    }
    return CGMainDisplayID()
}

func builtInScreen() -> NSScreen {
    let id = builtInDisplayID()
    for screen in NSScreen.screens {
        if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
           CGDirectDisplayID(num.uint32Value) == id {
            return screen
        }
    }
    return NSScreen.main ?? NSScreen.screens[0]
}

func setBrightness(_ value: Float) {
    let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
    guard let handle = dlopen(path, RTLD_NOW) else { return }
    defer { dlclose(handle) }

    typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32
    guard let symbol = dlsym(handle, "DisplayServicesSetBrightness") else { return }

    let function = unsafeBitCast(symbol, to: SetBrightness.self)
    _ = function(builtInDisplayID(), value)
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)

        setBrightness(0.0)

        let screen = builtInScreen()
        let frame = screen.frame

        window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.backgroundColor = .black
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.alphaValue = 0.0

        let view = ClickView(frame: NSRect(origin: .zero, size: frame.size), window: window)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        window.contentView = view

        window.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            window.animator().alphaValue = 1.0
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        setBrightness(1.0)
    }
}

class ClickView: NSView {
    weak var windowRef: NSWindow?

    init(frame frameRect: NSRect, window: NSWindow) {
        self.windowRef = window
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func mouseDown(with event: NSEvent) {
        setBrightness(1.0)

        guard let window = windowRef else {
            NSApp.terminate(nil)
            return
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            window.animator().alphaValue = 0.0
        }, completionHandler: {
            NSApp.terminate(nil)
        })
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
