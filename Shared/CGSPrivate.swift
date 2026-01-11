import Foundation
import CoreGraphics

// MARK: - CGS Symbolic HotKey Types

/// Symbolic HotKey identifiers from CGSHotKeys.h
/// These are the system-wide symbolic hotkey IDs used by macOS
public enum CGSSymbolicHotKey: Int32 {
    // Spaces / Mission Control
    case exposeAllWindows = 32           // Mission Control
    case exposeAllWindowsSlow = 34
    case exposeApplicationWindows = 33    // App Expose
    case exposeApplicationWindowsSlow = 35
    case exposeDesktop = 36               // Show Desktop
    case exposeDesktopsSlow = 37

    // Spaces navigation
    case spaces = 75                      // Mission Control (alternate)
    case spacesSlow = 76
    case spaceLeft = 79                   // Move left a space
    case spaceLeftSlow = 80
    case spaceRight = 81                  // Move right a space
    case spaceRightSlow = 82
    case spaceDown = 83                   // App Expose (alternate)
    case spaceDownSlow = 84
    case spaceUp = 85                     // Mission Control (alternate)
    case spaceUpSlow = 86

    // Screenshot
    case screenshot = 28
    case screenshotToClipboard = 29
    case screenshotRegion = 30
    case screenshotRegionToClipboard = 31

    // Spotlight
    case spotlightSearchField = 64
    case spotlightWindow = 65

    // Dictionary
    case lookUpWordInDictionary = 70

    // Launchpad / Dashboard
    case dashboard = 62                   // Launchpad (replaced Dashboard)
    case dashboardSlow = 63
}

/// CGS Modifier Flags matching Carbon/HIToolbox flags
public struct CGSModifierFlags: OptionSet {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let alphaShift  = CGSModifierFlags(rawValue: 1 << 16) // Caps Lock
    public static let shift       = CGSModifierFlags(rawValue: 1 << 17)
    public static let control     = CGSModifierFlags(rawValue: 1 << 18)
    public static let alternate   = CGSModifierFlags(rawValue: 1 << 19) // Option
    public static let command     = CGSModifierFlags(rawValue: 1 << 20)
    public static let numericPad  = CGSModifierFlags(rawValue: 1 << 21)
    public static let help        = CGSModifierFlags(rawValue: 1 << 22)
    public static let function    = CGSModifierFlags(rawValue: 1 << 23) // Fn key
}

// MARK: - CGS Private API Declarations

/// Check if a symbolic hotkey is enabled
/// Returns true if the hotkey is enabled in System Settings
@_silgen_name("CGSIsSymbolicHotKeyEnabled")
public func CGSIsSymbolicHotKeyEnabled(_ hotKey: Int32) -> Bool

/// Set whether a symbolic hotkey is enabled
@_silgen_name("CGSSetSymbolicHotKeyEnabled")
public func CGSSetSymbolicHotKeyEnabled(_ hotKey: Int32, _ isEnabled: Bool) -> CGError

/// Get the current configuration for a symbolic hotkey
/// - Parameters:
///   - hotKey: The symbolic hotkey ID
///   - outKeyEquivalent: Output: the unicode key equivalent (or 65535 if not set)
///   - outVirtualKeyCode: Output: the virtual key code
///   - outModifiers: Output: the modifier flags
@_silgen_name("CGSGetSymbolicHotKeyValue")
public func CGSGetSymbolicHotKeyValue(
    _ hotKey: Int32,
    _ outKeyEquivalent: UnsafeMutablePointer<UniChar>,
    _ outVirtualKeyCode: UnsafeMutablePointer<CGKeyCode>,
    _ outModifiers: UnsafeMutablePointer<UInt32>
) -> CGError

/// Set the configuration for a symbolic hotkey
/// - Parameters:
///   - hotKey: The symbolic hotkey ID
///   - keyEquivalent: The unicode key equivalent (use 65535 for none)
///   - virtualKeyCode: The virtual key code
///   - modifiers: The modifier flags
@_silgen_name("CGSSetSymbolicHotKeyValue")
public func CGSSetSymbolicHotKeyValue(
    _ hotKey: Int32,
    _ keyEquivalent: UniChar,
    _ virtualKeyCode: CGKeyCode,
    _ modifiers: UInt32
) -> CGError

// MARK: - Swift Wrapper

public final class SymbolicHotKeyManager {
    public static let shared = SymbolicHotKeyManager()

    /// Key equivalent value meaning "not set"
    private let keyEquivalentNull: UniChar = 65535

    /// Virtual key code meaning "not set"
    private let vkcNull: CGKeyCode = 65535

    /// Base VKC for our custom bindings (out of reach of real keyboard)
    private let vkcOutOfReach: CGKeyCode = 400

    /// Cache which hotkeys we've already configured with custom bindings
    private var configuredHotkeys: Set<Int32> = []

    private init() {}

    /// Post a symbolic hotkey event
    /// This is the main entry point - it will:
    /// 1. Check if the hotkey is enabled
    /// 2. Find or create a usable key binding
    /// 3. Post the keyboard events to trigger the hotkey
    public func post(_ shk: CGSSymbolicHotKey) {
        let hotKeyID = shk.rawValue

        // Check if we've already configured this hotkey with custom binding
        if configuredHotkeys.contains(hotKeyID) {
            // Use the cached custom binding directly
            let customVKC = vkcOutOfReach + CGKeyCode(hotKeyID)
            let customMods: UInt32 = CGSModifierFlags.numericPad.rawValue | CGSModifierFlags.function.rawValue
            postKeyboardEvents(virtualKeyCode: customVKC, modifiers: customMods)
            return
        }

        // Get current hotkey configuration
        var keyEquivalent: UniChar = 0
        var virtualKeyCode: CGKeyCode = 0
        var modifiers: UInt32 = 0

        let err = CGSGetSymbolicHotKeyValue(hotKeyID, &keyEquivalent, &virtualKeyCode, &modifiers)
        if err != .success {
            print("[LocalMouse] Failed to get symbolic hotkey value: \(err)")
        }

        print("[LocalMouse] Symbolic hotkey \(hotKeyID): keq=\(keyEquivalent), vkc=\(virtualKeyCode), mods=\(modifiers)")

        // Check if hotkey is enabled and has usable binding
        let isEnabled = CGSIsSymbolicHotKeyEnabled(hotKeyID)
        let hasUsableBinding = isEnabled && keyEquivalent == keyEquivalentNull && virtualKeyCode != vkcNull

        if hasUsableBinding {
            // Hotkey is enabled with a direct VKC binding - just post the key event
            print("[LocalMouse] Using existing binding: vkc=\(virtualKeyCode), mods=\(modifiers)")
            postKeyboardEvents(virtualKeyCode: virtualKeyCode, modifiers: modifiers)
        } else {
            // Need to create a usable binding
            print("[LocalMouse] Creating custom binding for hotkey \(hotKeyID)")

            // Enable the hotkey if disabled
            if !isEnabled {
                CGSSetSymbolicHotKeyEnabled(hotKeyID, true)
            }

            // Create a binding using an "out of reach" VKC
            // This VKC is too high to be produced by real keyboard input
            let customVKC = vkcOutOfReach + CGKeyCode(hotKeyID)
            // Use fn + numpad flags (required for system hotkeys without key equivalent)
            let customMods: UInt32 = CGSModifierFlags.numericPad.rawValue | CGSModifierFlags.function.rawValue

            let setErr = CGSSetSymbolicHotKeyValue(hotKeyID, keyEquivalentNull, customVKC, customMods)
            if setErr != .success {
                print("[LocalMouse] Failed to set symbolic hotkey value: \(setErr)")
            } else {
                // Mark this hotkey as configured
                configuredHotkeys.insert(hotKeyID)
            }

            // Post the keyboard events
            postKeyboardEvents(virtualKeyCode: customVKC, modifiers: customMods)
        }
    }

    /// Post keyboard events to trigger a hotkey
    private func postKeyboardEvents(virtualKeyCode: CGKeyCode, modifiers: UInt32) {
        let tapLoc = CGEventTapLocation.cgSessionEventTap

        // Create key events without event source (allows system to recognize as synthetic events)
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: virtualKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: virtualKeyCode, keyDown: false) else {
            print("[LocalMouse] Failed to create keyboard events")
            return
        }

        // Get original modifier flags (to restore after key up)
        let originalFlags = keyDown.flags

        // Set modifier flags
        keyDown.flags = CGEventFlags(rawValue: UInt64(modifiers))
        keyUp.flags = originalFlags // Restore original on key up

        // Post events
        keyDown.post(tap: tapLoc)
        keyUp.post(tap: tapLoc)

        print("[LocalMouse] Posted keyboard events: vkc=\(virtualKeyCode), mods=\(modifiers)")
    }
}

// MARK: - Mapping from our SymbolicHotkey enum to CGS

extension SymbolicHotkey {
    /// Get the corresponding CGS symbolic hotkey ID
    var cgsHotKey: CGSSymbolicHotKey? {
        switch self {
        case .missionControl, .missionControlUp:
            return .exposeAllWindows
        case .missionControlDown, .appExpose:
            return .exposeApplicationWindows
        case .showDesktop:
            return .exposeDesktop
        case .launchpad:
            return .dashboard
        case .moveLeftSpace:
            return .spaceLeft
        case .moveRightSpace:
            return .spaceRight
        case .screenshot:
            return .screenshot
        case .screenshotRegion:
            return .screenshotRegion
        case .spotlight:
            return .spotlightSearchField
        case .lookUp:
            return .lookUpWordInDictionary
        // These don't have direct CGS symbolic hotkeys
        case .screenshotWindow, .showNotificationCenter, .doNotDisturb, .siri, .dictation, .smartZoom:
            return nil
        }
    }
}
