import Carbon
import Cocoa
import CoreGraphics
import Darwin

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

// MARK: - Display helpers

func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
    guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
        return nil
    }
    return CGDirectDisplayID(number.uint32Value)
}

/// Returns the built-in (laptop) screen, or nil if there is none
/// (desktop Mac, or MacBook in clamshell mode).
func builtInScreen() -> (screen: NSScreen, id: CGDirectDisplayID)? {
    for screen in NSScreen.screens {
        if let id = displayID(of: screen), CGDisplayIsBuiltin(id) != 0 {
            return (screen, id)
        }
    }
    return nil
}

// MARK: - Brightness (private DisplayServices framework)

enum Brightness {
    private typealias Getter = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias Setter = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let handle = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        RTLD_LAZY
    )

    private static let getter: Getter? = handle
        .flatMap { dlsym($0, "DisplayServicesGetBrightness") }
        .map { unsafeBitCast($0, to: Getter.self) }

    private static let setter: Setter? = handle
        .flatMap { dlsym($0, "DisplayServicesSetBrightness") }
        .map { unsafeBitCast($0, to: Setter.self) }

    static func get(_ id: CGDirectDisplayID) -> Float? {
        guard let getter else { return nil }
        var value: Float = 0
        return getter(id, &value) == 0 ? value : nil
    }

    static func set(_ id: CGDirectDisplayID, _ value: Float) {
        _ = setter?(id, min(max(value, 0), 1))
    }
}

// MARK: - Brightness session (survives crashes / force quits)

/// Remembers the user's original brightness so it can be restored on exit.
/// The value is also persisted while the screen is blacked out: if the app is
/// killed with SIGKILL (Force Quit), the next launch restores the real value
/// instead of treating 0 as the "original" brightness.
final class BrightnessSession {
    private static let defaultsKey = "savedBrightness"
    private let displayID: CGDirectDisplayID
    private let original: Float
    private var restored = false

    init(displayID: CGDirectDisplayID) {
        self.displayID = displayID
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.defaultsKey) != nil {
            // Previous session did not exit cleanly.
            original = defaults.float(forKey: Self.defaultsKey)
        } else {
            original = Brightness.get(displayID) ?? 1.0
            defaults.set(original, forKey: Self.defaultsKey)
        }
    }

    func dim() {
        Brightness.set(displayID, 0.0)
    }

    func restore() {
        guard !restored else { return }
        restored = true
        Brightness.set(displayID, original)
        UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
        UserDefaults.standard.synchronize()
    }
}

// MARK: - Window / view

final class BlackWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

func activateApp() {
    if #available(macOS 14.0, *) {
        NSApp.activate()
    } else {
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class ClickView: NSView {
    var onExit: (() -> Void)?
    var onHoverChanged: ((Bool) -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    override func mouseDown(with event: NSEvent) {
        onExit?()
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let fadeDuration: TimeInterval = 0.25
    private var window: BlackWindow!
    private var session: BrightnessSession?
    private var isExiting = false
    private var signalSources: [DispatchSourceSignal] = []
    private var keyMonitor: Any?
    private let hotKeys = HotKeys()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard let builtIn = builtInScreen() else {
            showNoBuiltInDisplayAlert()
            NSApp.terminate(nil)
            return
        }
        let screen = builtIn.screen

        let session = BrightnessSession(displayID: builtIn.id)
        self.session = session
        installSignalHandlers()

        window = BlackWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.alphaValue = 0.0

        let view = ClickView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        view.onExit = { [weak self] in self?.dismiss() }
        window.contentView = view

        hotKeys.onTrigger = { [weak self] in self?.dismiss() }
        view.onHoverChanged = { [weak self] inside in
            if inside { self?.hotKeys.register() } else { self?.hotKeys.unregister() }
        }
        if NSMouseInRect(NSEvent.mouseLocation, screen.frame, false) {
            hotKeys.register()
        }

        installMainMenu()
        installKeyMonitor()

        activateApp()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)

        session.dim()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            window.animator().alphaValue = 1.0
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // macOS may reset brightness after sleep/wake; re-apply it.
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(reapplyDim),
                              name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(reapplyDim),
                              name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        session?.restore()
    }

    // MARK: Exit

    func dismiss() {
        guard !isExiting else { return }
        isExiting = true

        hotKeys.unregister()
        session?.restore()

        guard let window else {
            NSApp.terminate(nil)
            return
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = fadeDuration
            window.animator().alphaValue = 0.0
        }, completionHandler: {
            NSApp.terminate(nil)
        })
    }

    // MARK: Keyboard

    /// Esc closes the app whenever BlackScreen is the active app,
    /// regardless of which view is first responder.
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.dismiss()
                return nil
            }
            return event
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

    /// Restore brightness when killed via SIGTERM / SIGINT / SIGHUP
    /// (e.g. `kill`, Ctrl+C in Terminal, logout).
    private func installSignalHandlers() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in
                self?.session?.restore()
                Darwin.exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    // MARK: Screen changes

    @objc private func screenParametersChanged() {
        guard !isExiting else { return }
        guard let builtIn = builtInScreen() else {
            // Built-in display disappeared (lid closed / clamshell).
            dismiss()
            return
        }
        window.setFrame(builtIn.screen.frame, display: true)
    }

    @objc private func reapplyDim() {
        guard !isExiting else { return }
        session?.dim()
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
