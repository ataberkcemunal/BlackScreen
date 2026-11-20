import Carbon
import Cocoa
import CoreGraphics

// BlackScreen puts a pure black window in macOS full screen on the MacBook's
// built-in display. macOS hides the menu bar and Dock there by itself, and
// notification banners still show on top. Click it or press Esc to quit.
// Brightness is never touched.

// MARK: - Hot keys (work without keyboard focus, no Accessibility permission)

/// Registers Esc and ⌘Q as system-wide hot keys. They are only registered
/// while the pointer is over the black screen, so other apps keep their
/// Esc / ⌘Q the rest of the time.
final class HotKeys {
    var onTrigger: (() -> Void)?
    private var refs: [EventHotKeyRef] = []
    private var handlerRef: EventHandlerRef?

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let hotKeys = Unmanaged<HotKeys>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { hotKeys.onTrigger?() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }

    func register() {
        guard refs.isEmpty else { return }
        let keys: [(code: Int, modifiers: Int)] = [(kVK_Escape, 0), (kVK_ANSI_Q, cmdKey)]
        for (index, key) in keys.enumerated() {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: OSType(0x424C_4B53), id: UInt32(index + 1)) // 'BLKS'
            if RegisterEventHotKey(UInt32(key.code), UInt32(key.modifiers), id,
                                   GetApplicationEventTarget(), 0, &ref) == noErr, let ref {
                refs.append(ref)
            }
        }
    }

    func unregister() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
    }
}

// MARK: - Helpers

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

// MARK: - Window / view

final class BlackWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

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
    var onExit: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onExit?() }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: BlackWindow?
    private var isExiting = false
    private let hotKeys = HotKeys()
    private var mouseMonitors: [Any] = []

    // BlackScreen runs as a regular app (Dock icon while open): macOS's
    // three-finger swipe skips full-screen spaces of background-only apps.
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = builtInScreen() else {
            showNoBuiltInDisplayAlert()
            NSApp.terminate(nil)
            return
        }

        let window = BlackWindow(frame: screen.frame)
        let view = ClickView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.autoresizingMask = [.width, .height]
        view.onExit = { [weak self] in self?.dismiss() }
        window.contentView = view
        window.delegate = self
        self.window = window

        if !displaysHaveSeparateSpaces() {
            window.coverWithoutFullScreen(screen.frame)
        }

        activateApp()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)

        if displaysHaveSeparateSpaces() {
            window.toggleFullScreen(nil)
        }

        // Esc / ⌘Q
        hotKeys.onTrigger = { [weak self] in self?.dismiss() }
        installMouseMonitors()
        installMainMenu()
        installKeyMonitor()
        updateHotKeys()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(updateHotKeys),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        updateHotKeys()
    }

    // MARK: Hot keys

    /// Esc / ⌘Q are taken over only while the pointer is on the built-in
    /// display *and* the black screen is visible there (not after swiping
    /// away to the desktop). Everywhere else the keys go to other apps.
    @objc private func updateHotKeys() {
        guard !isExiting, let window, let screen = builtInScreen() else { return }
        let active = window.isOnActiveSpace
            && NSMouseInRect(NSEvent.mouseLocation, screen.frame, false)
        if active { hotKeys.register() } else { hotKeys.unregister() }
    }

    /// Mouse-move monitors need no permission (only key monitors do).
    private func installMouseMonitors() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in
            self?.updateHotKeys()
        }) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            self?.updateHotKeys()
            return event
        }) {
            mouseMonitors.append(local)
        }
    }

    // MARK: Exit

    func dismiss() {
        guard !isExiting else { return }
        isExiting = true
        hotKeys.unregister()
        NSApp.terminate(nil)
    }

    // MARK: Keyboard

    /// Esc closes the app whenever BlackScreen is the active app.
    private func installKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event } // Escape
            self?.dismiss()
            return nil
        }
    }

    /// A minimal main menu so ⌘Q is handled like in any other app.
    private func installMainMenu() {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit BlackScreen",
                        action: #selector(quitFromMenu),
                        keyEquivalent: "q").target = self
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func quitFromMenu() {
        dismiss()
    }

    // MARK: Screen changes

    @objc private func screenParametersChanged() {
        guard !isExiting else { return }
        if builtInScreen() == nil {
            // Built-in display disappeared (lid closed / clamshell).
            dismiss()
        } else {
            updateHotKeys()
        }
    }

    // MARK: Alerts

    private func showNoBuiltInDisplayAlert() {
        activateApp()
        let alert = NSAlert()
        alert.messageText = "No built-in display found"
        alert.informativeText = "BlackScreen only blacks out a MacBook's built-in display. "
            + "Open the lid or use it on a Mac with a built-in screen."
        alert.alertStyle = .warning
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
