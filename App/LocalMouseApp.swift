import SwiftUI
import ServiceManagement

@main
struct LocalMouseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var isOpeningSettings = false
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        registerLoginItem()
        startHelper()

        // Create main window but don't show it yet
        createMainWindow()

        // Check if launched at login (no windows should be shown)
        let launchedAtLogin = UserDefaults.standard.bool(forKey: "launchedAtLogin")

        if launchedAtLogin {
            // Hide dock icon when launched at login
            NSApp.setActivationPolicy(.accessory)
        } else {
            // Normal launch - show window
            NSApp.setActivationPolicy(.regular)
            mainWindow?.makeKeyAndOrderFront(nil)
        }

        // Listen for window notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: nil
        )

        // Listen for config changes from UI
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configDidChange),
            name: .configDidChange,
            object: nil
        )
    }

    @objc private func configDidChange() {
        // Update menu bar checkmark
        if let menu = statusItem?.menu,
           let item = menu.items.first(where: { $0.title == "Enabled" }) {
            item.state = ConfigManager.shared.isEnabled() ? .on : .off
        }
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        // When window becomes visible, show dock icon
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        // Don't hide if we're opening settings
        guard !isOpeningSettings else { return }

        // When last window closes, hide dock icon (keep menu bar)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Double check we're not opening settings
            guard !self.isOpeningSettings else { return }

            // Check if any main windows are still visible (exclude status bar window)
            let hasVisibleMainWindow = NSApp.windows.contains { window in
                window.isVisible && window.canBecomeKey
            }

            if !hasVisibleMainWindow {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    private func createMainWindow() {
        // Create window with SwiftUI content
        let contentView = ContentView()
            .frame(minWidth: 600, minHeight: 400)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.title = "LocalMouse"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("MainWindow")

        // Set minimum and maximum size
        window.minSize = NSSize(width: 600, height: 400)
        window.maxSize = NSSize(width: 1200, height: 900)

        mainWindow = window
        print("[LocalMouse] Main window created")
    }

    private func updateActivationPolicy() {
        // Check if any main windows are visible (exclude status bar window)
        let hasVisibleMainWindow = NSApp.windows.contains { window in
            window.isVisible && window.canBecomeKey
        }

        if hasVisibleMainWindow {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func registerLoginItem() {
        // Register app to start at login (macOS 13+)
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                print("[LocalMouse] ✅ Registered as login item")
            } catch {
                print("[LocalMouse] ⚠️ Failed to register login item: \(error)")
            }
        }
    }

    private func setupMenuBar() {
        print("[LocalMouse] Setting up menu bar...")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let statusItem = statusItem else {
            print("[LocalMouse] ❌ Failed to create status item")
            return
        }

        print("[LocalMouse] ✅ Status item created")

        if let button = statusItem.button {
            print("[LocalMouse] ✅ Status item button exists")

            // Try SF Symbol first, fallback to text if not available
            if let image = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "LocalMouse") {
                button.image = image
                print("[LocalMouse] ✅ Using computermouse.fill icon")
            } else if let image = NSImage(systemSymbolName: "cursor.rays", accessibilityDescription: "LocalMouse") {
                button.image = image
                print("[LocalMouse] ✅ Using cursor.rays icon")
            } else {
                // Fallback to text
                button.title = "🖱"
                print("[LocalMouse] ✅ Using emoji icon: 🖱")
            }
        } else {
            print("[LocalMouse] ❌ Status item button is nil")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "LocalMouse", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "e")
        enabledItem.state = ConfigManager.shared.isEnabled() ? .on : .off
        menu.addItem(enabledItem)

        menu.addItem(NSMenuItem.separator())

        // Start at Login option (macOS 13+)
        if #available(macOS 13.0, *) {
            let loginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
            loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
            menu.addItem(loginItem)
            menu.addItem(NSMenuItem.separator())
        }

        menu.addItem(NSMenuItem(title: "Open Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit LocalMouse", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
        print("[LocalMouse] ✅ Menu bar setup complete with \(menu.items.count) items")
    }

    @objc private func toggleEnabled() {
        let newState = !ConfigManager.shared.isEnabled()
        try? ConfigManager.shared.setEnabled(newState)

        if let menu = statusItem?.menu,
           let item = menu.items.first(where: { $0.title == "Enabled" }) {
            item.state = newState ? .on : .off
        }

        // Notify UI to update
        NotificationCenter.default.post(name: .configDidChange, object: nil)
    }

    @objc private func toggleLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    print("[LocalMouse] ✅ Unregistered from login items")
                } else {
                    try SMAppService.mainApp.register()
                    print("[LocalMouse] ✅ Registered as login item")
                }

                // Update menu item state
                if let menu = statusItem?.menu,
                   let item = menu.items.first(where: { $0.title == "Start at Login" }) {
                    item.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
                }
            } catch {
                print("[LocalMouse] ⚠️ Failed to toggle login item: \(error)")
            }
        }
    }

    @objc private func openSettings() {
        print("[LocalMouse] Opening settings window...")

        // Set flag to prevent window from being hidden
        isOpeningSettings = true

        // Show dock icon
        NSApp.setActivationPolicy(.regular)

        // Activate app
        NSApp.activate(ignoringOtherApps: true)

        // Show the main window
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            print("[LocalMouse] Window shown")
        } else {
            print("[LocalMouse] No main window!")
        }

        // Reset flag after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isOpeningSettings = false
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private var hasPromptedForAccessibility = false

    private func startHelper() {
        // Debug: Print bundle ID
        print("[LocalMouse] Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")

        // Simple check without prompt first
        let isTrusted = AXIsProcessTrusted()
        print("[LocalMouse] AXIsProcessTrusted: \(isTrusted)")

        if isTrusted {
            print("[LocalMouse] ✅ Accessibility permissions granted")
            // Start on main thread - event tap needs main run loop
            let success = ButtonInterceptor.shared.start()
            if success {
                print("[LocalMouse] ✅ Button interceptor started")
            } else {
                print("[LocalMouse] ❌ Failed to start button interceptor")
            }
        } else {
            // Only prompt once
            if !hasPromptedForAccessibility {
                hasPromptedForAccessibility = true
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(options)
                print("[LocalMouse] ⚠️ Prompted for accessibility permissions")
            }

            // Retry after a delay (silent check)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.startHelper()
            }
        }
    }
}
