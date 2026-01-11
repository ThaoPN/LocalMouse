import Foundation
import CoreGraphics
import Carbon
import AppKit

/// Executes actions triggered by button mappings
/// All actions run locally - no server calls, no cloud dependency
public final class ActionExecutor {
    public static let shared = ActionExecutor()

    private init() {}

    // MARK: - Public API

    public func execute(_ action: ActionType) {
        switch action {
        case .symbolicHotkey(let hotkey):
            executeSymbolicHotkey(hotkey)

        case .keyboardShortcut(let shortcut):
            executeKeyboardShortcut(shortcut)

        case .mouseClick(let button):
            executeMouseClick(button)

        case .navigationSwipe(let direction):
            executeNavigationSwipe(direction)

        case .openApp(let bundleId):
            executeOpenApp(bundleId)

        case .shellCommand(let command):
            executeShellCommand(command)

        case .none:
            break
        }
    }

    // MARK: - Symbolic Hotkey

    private func executeSymbolicHotkey(_ hotkey: SymbolicHotkey) {
        print("[LocalMouse] Executing symbolic hotkey: \(hotkey.displayName)")

        // Try to use CGS private API for hotkeys that have CGS mappings
        if let cgsHotKey = hotkey.cgsHotKey {
            SymbolicHotKeyManager.shared.post(cgsHotKey)
            print("[LocalMouse] Executed symbolic hotkey via CGS API: \(hotkey.displayName)")
            return
        }

        // Fallback to manual keyboard shortcuts for hotkeys without CGS support
        switch hotkey {
        case .showNotificationCenter:
            // There's no direct key for this, use AppleScript fallback
            executeAppleScript("tell application \"System Events\" to click menu bar item 1 of menu bar 1 of application process \"Control Center\"")

        case .doNotDisturb:
            executeAppleScript("tell application \"System Events\" to keystroke \"d\" using {option down, command down}")

        case .screenshotWindow:
            postKeyEvent(keyCode: UInt16(kVK_ANSI_4), modifiers: [.maskCommand, .maskShift])
            // Then space to select window mode
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.postKeyEvent(keyCode: UInt16(kVK_Space), modifiers: [])
            }

        case .siri:
            // Hold Command+Space or use dedicated key
            executeAppleScript("tell application \"System Events\" to tell process \"Siri\" to click menu bar item 1 of menu bar 2")

        case .dictation:
            // Double-tap Fn or use keyboard shortcut
            postKeyEvent(keyCode: UInt16(kVK_Function), modifiers: [])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.postKeyEvent(keyCode: UInt16(kVK_Function), modifiers: [])
            }

        case .smartZoom:
            // Smart Zoom - double tap with two fingers or Ctrl+Scroll
            // Use AppleScript as fallback
            executeAppleScript("tell application \"System Events\" to key code 44 using control down")

        default:
            // All other hotkeys should have CGS mappings
            print("[LocalMouse] Warning: No CGS mapping for \(hotkey.displayName)")
        }

        print("[LocalMouse] Executed symbolic hotkey: \(hotkey.displayName)")
    }

    // MARK: - Keyboard Shortcut

    private func executeKeyboardShortcut(_ shortcut: KeyboardShortcut) {
        var flags: CGEventFlags = []
        if shortcut.modifiers.contains(.command) { flags.insert(.maskCommand) }
        if shortcut.modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if shortcut.modifiers.contains(.control) { flags.insert(.maskControl) }
        if shortcut.modifiers.contains(.shift) { flags.insert(.maskShift) }

        postKeyEvent(keyCode: shortcut.keyCode, modifiers: flags)
        print("[LocalMouse] Executed keyboard shortcut: keyCode=\(shortcut.keyCode)")
    }

    // MARK: - Mouse Click

    private func executeMouseClick(_ button: MouseButton) {
        let location = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let cgLocation = CGPoint(x: location.x, y: screenHeight - location.y)

        let buttonNumber = CGMouseButton(rawValue: UInt32(button.rawValue - 1))!

        let eventType: CGEventType
        let eventTypeUp: CGEventType

        switch button {
        case .left:
            eventType = .leftMouseDown
            eventTypeUp = .leftMouseUp
        case .right:
            eventType = .rightMouseDown
            eventTypeUp = .rightMouseUp
        default:
            eventType = .otherMouseDown
            eventTypeUp = .otherMouseUp
        }

        if let downEvent = CGEvent(mouseEventSource: nil, mouseType: eventType, mouseCursorPosition: cgLocation, mouseButton: buttonNumber) {
            downEvent.post(tap: .cghidEventTap)
        }

        if let upEvent = CGEvent(mouseEventSource: nil, mouseType: eventTypeUp, mouseCursorPosition: cgLocation, mouseButton: buttonNumber) {
            upEvent.post(tap: .cghidEventTap)
        }

        print("[LocalMouse] Executed mouse click: \(button.displayName)")
    }

    // MARK: - Navigation Swipe

    private func executeNavigationSwipe(_ direction: NavigationDirection) {
        // Browser/Finder back/forward using Cmd+[ and Cmd+]
        let keyCode: UInt16
        switch direction {
        case .back:
            keyCode = UInt16(kVK_ANSI_LeftBracket)
        case .forward:
            keyCode = UInt16(kVK_ANSI_RightBracket)
        }

        postKeyEvent(keyCode: keyCode, modifiers: [.maskCommand])
        print("[LocalMouse] Executed navigation: \(direction.displayName)")
    }

    // MARK: - Open App

    private func executeOpenApp(_ bundleId: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
            print("[LocalMouse] Opened app: \(bundleId)")
        } else {
            print("[LocalMouse] Failed to find app: \(bundleId)")
        }
    }

    // MARK: - Shell Command

    private func executeShellCommand(_ command: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            try? process.run()
            print("[LocalMouse] Executed shell command: \(command)")
        }
    }

    // MARK: - Helpers

    private func postKeyEvent(keyCode: UInt16, modifiers: CGEventFlags) {
        // Use session event tap to inject key events at the correct level
        let tapLoc = CGEventTapLocation.cgSessionEventTap

        // Create key events without event source (allows system to recognize as synthetic events)
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            print("[LocalMouse] Failed to create key events")
            return
        }

        // Set modifier flags
        keyDown.flags = modifiers
        keyUp.flags = modifiers

        // Create modifier restore event (important for system hotkeys)
        guard let modRestoreEvent = CGEvent(source: nil) else {
            print("[LocalMouse] Failed to create modifier restore event")
            return
        }

        // Post events
        keyDown.post(tap: tapLoc)
        keyUp.post(tap: tapLoc)
        modRestoreEvent.post(tap: tapLoc)

        print("[LocalMouse] Posted key event: keyCode=\(keyCode), modifiers=\(modifiers.rawValue)")
    }

    private func executeAppleScript(_ script: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            try? process.run()
        }
    }
}
