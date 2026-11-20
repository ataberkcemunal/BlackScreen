import Cocoa
import CoreGraphics
import Darwin

// BlackScreen puts a pure black window in macOS full screen on the MacBook's
// built-in display. macOS hides the menu bar and Dock there by itself, and
// notification banners still show on top. Click it to quit.
// Brightness is never touched.

// MARK: - Display helpers

/// Returns the built-in (laptop) screen, or nil if there is none
/// (desktop Mac, or MacBook in clamshell mode).
func builtInScreen() -> NSScreen? {
    NSScreen.screens.first { screen in
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return false
        }
        return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0
    }
}

/// True when the built-in display mirrors (or is mirrored by) another display.
/// Blacking it out would then black out the mirrored external monitor too.
func builtInDisplayIsMirrored() -> Bool {
    var ids = [CGDirectDisplayID](repeating: 0, count: 16)
    var count: UInt32 = 0
    guard CGGetOnlineDisplayList(UInt32(ids.count), &ids, &count) == .success else { return false }
    return ids.prefix(Int(count)).contains {
        CGDisplayIsBuiltin($0) != 0 && CGDisplayIsInMirrorSet($0) != 0
    }
}

/// Full screen only stays on one display when "Displays have separate Spaces"
/// is on (the macOS default). Otherwise it would blank the external monitor.
func displaysHaveSeparateSpaces() -> Bool {
    !(UserDefaults(suiteName: "com.apple.spaces")?.bool(forKey: "spans-displays") ?? false)
}

func activateApp() {
    if #available(macOS 14.0, *) {
        NSApp.activate()
    } else {
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Cursor

/// Hides the pointer while it rests on the black screen, like a video player.
///
/// macOS only lets the frontmost app hide the cursor, but while watching
/// something the frontmost app is the player on the external monitor. The
/// private "SetsCursorInBackground" connection property (used by other cursor
/// utilities) lifts that limit; if it's ever unavailable, the cursor simply
/// isn't hidden.
final class CursorHider {
    private let idleDelay: TimeInterval = 1.5
    private var isHidden = false
    private var idleTimer: Timer?

    init() {
        Self.allowCursorChangesInBackground()
    }

    /// Call on every pointer movement / relevant state change.
    /// `overBlackScreen`: the pointer is on the visible black screen.
    func update(overBlackScreen: Bool) {
        idleTimer?.invalidate()
        idleTimer = nil
        show()
        guard overBlackScreen else { return }
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleDelay, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    func show() {
        guard isHidden else { return }
        CGDisplayShowCursor(CGMainDisplayID())
        isHidden = false
    }

    private func hide() {
        guard !isHidden else { return }
        CGDisplayHideCursor(CGMainDisplayID())
        isHidden = true
    }

    private static func allowCursorChangesInBackground() {
        typealias DefaultConnection = @convention(c) () -> Int32
        typealias SetProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
        guard let connSym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_CGSDefaultConnection"),
              let setSym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSSetConnectionProperty")
        else { return }
        let connection = unsafeBitCast(connSym, to: DefaultConnection.self)()
        let setProperty = unsafeBitCast(setSym, to: SetProperty.self)
        _ = setProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
    }
}

// MARK: - Window / view

final class BlackWindow: NSWindow {
    /// `frame` is in global screen coordinates, so it also picks the screen.
    init(frame: NSRect) {
        super.init(contentRect: frame,
                   styleMask: [.titled, .resizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        backgroundColor = .black
        isOpaque = true
        hasShadow = false
        isReleasedWhenClosed = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        [.closeButton, .miniaturizeButton, .zoomButton].forEach {
            standardWindowButton($0)?.isHidden = true
        }
        collectionBehavior = [.fullScreenPrimary]
    }

    /// Fallback when full screen can't be used: a plain borderless window
    /// over the whole display, just below notification banners.
    func coverWithoutFullScreen(_ frame: NSRect) {
        styleMask = [.borderless]
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) - 2)
        setFrame(frame, display: true)
    }
}

final class ClickView: NSView {
    var onClick: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onClick?() }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: BlackWindow?
    private let cursor = CursorHider()
    private var mouseMonitors: [Any] = []

    // BlackScreen runs as a regular app (Dock icon while open): macOS's
    // three-finger swipe skips full-screen spaces of background-only apps.
    func applicationDidFinishLaunching(_ notification: Notification) {
        if builtInDisplayIsMirrored() {
            showAlert("Your displays are mirrored",
                      "BlackScreen would black out your external monitor too. "
                      + "Turn off mirroring in System Settings → Displays, then open BlackScreen again.")
            NSApp.terminate(nil)
            return
        }
        guard let screen = builtInScreen() else {
            showAlert("No built-in display found",
                      "BlackScreen only blacks out a MacBook's built-in display. "
                      + "Open the lid or use it on a Mac with a built-in screen.")
            NSApp.terminate(nil)
            return
        }

        installStandardMenu()

        let window = BlackWindow(frame: screen.frame)
        let view = ClickView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.autoresizingMask = [.width, .height]
        view.onClick = { NSApp.terminate(nil) }
        window.contentView = view
        window.delegate = self
        self.window = window

        let useFullScreen = displaysHaveSeparateSpaces()
        if !useFullScreen {
            window.coverWithoutFullScreen(screen.frame)
        }

        activateApp()
        window.makeKeyAndOrderFront(nil)

        if useFullScreen {
            window.toggleFullScreen(nil)
        }

        installMouseMonitors()
        updateCursor()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(updateCursor),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        updateCursor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        cursor.show()
    }

    // MARK: Cursor

    /// The pointer is "over the black screen" when it's on the built-in
    /// display and the black screen is the visible space there.
    @objc private func updateCursor() {
        guard let window, let screen = builtInScreen() else {
            cursor.show()
            return
        }
        let over = window.isOnActiveSpace && NSMouseInRect(NSEvent.mouseLocation, screen.frame, false)
        cursor.update(overBlackScreen: over)
    }

    /// Mouse-move monitors need no permission (only key monitors do).
    private func installMouseMonitors() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .scrollWheel]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in
            self?.updateCursor()
        }) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            self?.updateCursor()
            return event
        }) {
            mouseMonitors.append(local)
        }
    }

    // MARK: Menu

    /// The usual app menu with "Quit BlackScreen" (⌘Q), like in any Mac app.
    private func installStandardMenu() {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit BlackScreen",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu
    }

    // MARK: Screen changes

    /// Quit when the built-in display goes away (lid closed / clamshell) or
    /// gets mirrored to another display.
    @objc private func screenParametersChanged() {
        if builtInScreen() == nil || builtInDisplayIsMirrored() {
            NSApp.terminate(nil)
        } else {
            updateCursor()
        }
    }

    private func showAlert(_ title: String, _ message: String) {
        activateApp()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
