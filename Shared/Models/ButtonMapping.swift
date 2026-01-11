import Foundation
import Carbon

// MARK: - Mouse Button

/// Represents a mouse button (1-indexed: Button 1 = left, Button 2 = right, Button 3 = middle, etc.)
public enum MouseButton: Int, Codable, CaseIterable, Identifiable {
    case left = 1
    case right = 2
    case middle = 3
    case button4 = 4
    case button5 = 5
    case button6 = 6
    case button7 = 7
    case button8 = 8

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .left: return "Left Click"
        case .right: return "Right Click"
        case .middle: return "Middle Click"
        case .button4: return "Button 4"
        case .button5: return "Button 5"
        case .button6: return "Button 6"
        case .button7: return "Button 7"
        case .button8: return "Button 8"
        }
    }

    /// Convert from CGEvent button number (0-indexed)
    public static func fromCGEvent(_ buttonNumber: Int64) -> MouseButton? {
        MouseButton(rawValue: Int(buttonNumber) + 1)
    }
}

// MARK: - Click Type

public enum ClickType: String, Codable, CaseIterable {
    case click = "click"
    case doubleClick = "doubleClick"
    case hold = "hold"

    public var displayName: String {
        switch self {
        case .click: return "Click"
        case .doubleClick: return "Double Click"
        case .hold: return "Hold"
        }
    }
}

// MARK: - Keyboard Modifiers

public struct KeyboardModifiers: OptionSet, Codable, Hashable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let shift = KeyboardModifiers(rawValue: 1 << 0)
    public static let control = KeyboardModifiers(rawValue: 1 << 1)
    public static let option = KeyboardModifiers(rawValue: 1 << 2)
    public static let command = KeyboardModifiers(rawValue: 1 << 3)

    public static let none: KeyboardModifiers = []

    public var displayName: String {
        var parts: [String] = []
        if contains(.command) { parts.append("⌘") }
        if contains(.option) { parts.append("⌥") }
        if contains(.control) { parts.append("⌃") }
        if contains(.shift) { parts.append("⇧") }
        return parts.isEmpty ? "None" : parts.joined()
    }

    /// Convert from CGEventFlags
    public static func fromCGEventFlags(_ flags: CGEventFlags) -> KeyboardModifiers {
        var modifiers: KeyboardModifiers = []
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        return modifiers
    }
}

// MARK: - Action Types

public enum ActionType: Codable, Equatable {
    /// Trigger a system symbolic hotkey (Mission Control, etc.)
    case symbolicHotkey(SymbolicHotkey)

    /// Trigger a keyboard shortcut
    case keyboardShortcut(KeyboardShortcut)

    /// Simulate a different mouse button click
    case mouseClick(MouseButton)

    /// Navigate back/forward (browser, Finder)
    case navigationSwipe(NavigationDirection)

    /// Open an application
    case openApp(bundleId: String)

    /// Run a shell command
    case shellCommand(String)

    /// Do nothing (passthrough)
    case none
}

// MARK: - Symbolic Hotkeys

public enum SymbolicHotkey: Int, Codable, CaseIterable {
    case missionControl = 32
    case missionControlUp = 34
    case missionControlDown = 35
    case appExpose = 33
    case showDesktop = 36
    case launchpad = 160
    case showNotificationCenter = 163
    case doNotDisturb = 175
    case screenshot = 28
    case screenshotRegion = 29
    case screenshotWindow = 31
    case spotlight = 64
    case siri = 176
    case dictation = 164
    case lookUp = 70
    case smartZoom = 128
    case moveLeftSpace = 79
    case moveRightSpace = 81

    public var displayName: String {
        switch self {
        case .missionControl: return "Mission Control"
        case .missionControlUp: return "Mission Control (Up)"
        case .missionControlDown: return "Mission Control (Down)"
        case .appExpose: return "App Exposé"
        case .showDesktop: return "Show Desktop"
        case .launchpad: return "Launchpad"
        case .showNotificationCenter: return "Notification Center"
        case .doNotDisturb: return "Do Not Disturb"
        case .screenshot: return "Screenshot"
        case .screenshotRegion: return "Screenshot Region"
        case .screenshotWindow: return "Screenshot Window"
        case .spotlight: return "Spotlight"
        case .siri: return "Siri"
        case .dictation: return "Dictation"
        case .lookUp: return "Look Up"
        case .smartZoom: return "Smart Zoom"
        case .moveLeftSpace: return "Move Left a Space"
        case .moveRightSpace: return "Move Right a Space"
        }
    }
}

// MARK: - Keyboard Shortcut

public struct KeyboardShortcut: Codable, Equatable {
    public let keyCode: UInt16
    public let modifiers: KeyboardModifiers

    public init(keyCode: UInt16, modifiers: KeyboardModifiers = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Common shortcuts
    public static let copy = KeyboardShortcut(keyCode: UInt16(kVK_ANSI_C), modifiers: .command)
    public static let paste = KeyboardShortcut(keyCode: UInt16(kVK_ANSI_V), modifiers: .command)
    public static let undo = KeyboardShortcut(keyCode: UInt16(kVK_ANSI_Z), modifiers: .command)
    public static let redo = KeyboardShortcut(keyCode: UInt16(kVK_ANSI_Z), modifiers: [.command, .shift])
}

// MARK: - Navigation Direction

public enum NavigationDirection: String, Codable {
    case back = "back"
    case forward = "forward"

    public var displayName: String {
        switch self {
        case .back: return "Back"
        case .forward: return "Forward"
        }
    }
}

// MARK: - Button Trigger

public struct ButtonTrigger: Codable, Hashable {
    public let button: MouseButton
    public let clickType: ClickType
    public let modifiers: KeyboardModifiers

    public init(button: MouseButton, clickType: ClickType = .click, modifiers: KeyboardModifiers = []) {
        self.button = button
        self.clickType = clickType
        self.modifiers = modifiers
    }
}

// MARK: - Button Mapping

public struct ButtonMapping: Codable, Identifiable {
    public let id: UUID
    public let trigger: ButtonTrigger
    public let action: ActionType
    public var isEnabled: Bool

    public init(id: UUID = UUID(), trigger: ButtonTrigger, action: ActionType, isEnabled: Bool = true) {
        self.id = id
        self.trigger = trigger
        self.action = action
        self.isEnabled = isEnabled
    }
}

// MARK: - App Configuration

public struct AppConfig: Codable {
    public var version: Int
    public var mappings: [ButtonMapping]
    public var isEnabled: Bool

    public init(version: Int = 1, mappings: [ButtonMapping] = [], isEnabled: Bool = true) {
        self.version = version
        self.mappings = mappings
        self.isEnabled = isEnabled
    }

    public static let `default` = AppConfig(
        version: 1,
        mappings: [
            // Middle Button
            ButtonMapping(
                trigger: ButtonTrigger(button: .middle, clickType: .click),
                action: .symbolicHotkey(.missionControl)
            ),

            // Button 4
            ButtonMapping(
                trigger: ButtonTrigger(button: .button4, clickType: .click),
                action: .symbolicHotkey(.moveRightSpace)
            ),

            // Button 5
            ButtonMapping(
                trigger: ButtonTrigger(button: .button5, clickType: .click),
                action: .symbolicHotkey(.moveLeftSpace)
            )
        ],
        isEnabled: true
    )
}
