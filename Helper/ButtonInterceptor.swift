import Foundation
import CoreGraphics

/// Intercepts mouse button events using CGEventTap
/// This is the core of LocalMouse - works 100% offline, no cloud required
public final class ButtonInterceptor {
    public static let shared = ButtonInterceptor()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false

    /// Click state tracking for double-click and hold detection
    private var clickStates: [MouseButton: ClickState] = [:]

    /// Hold detection threshold (in seconds)
    private let holdThreshold: TimeInterval = 0.3

    /// Double-click threshold (in seconds)
    private let doubleClickThreshold: TimeInterval = 0.3

    private init() {}

    // MARK: - Public API

    public func start() -> Bool {
        guard !isRunning else { return true }

        // Create event tap for mouse button events
        let eventMask: CGEventMask = (1 << CGEventType.otherMouseDown.rawValue) |
                                      (1 << CGEventType.otherMouseUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, userInfo in
                return ButtonInterceptor.shared.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: nil
        ) else {
            print("[LocalMouse] Failed to create event tap. Check Accessibility permissions.")
            return false
        }

        self.eventTap = tap

        // Create run loop source
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source

        // Add to MAIN run loop (important for event tap to work)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

        // Enable the tap
        CGEvent.tapEnable(tap: tap, enable: true)

        isRunning = true
        print("[LocalMouse] Button interceptor started - working offline, as it should be")
        return true
    }

    public func stop() {
        guard isRunning else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        isRunning = false
        print("[LocalMouse] Button interceptor stopped")
    }

    public var running: Bool { isRunning }

    // MARK: - Event Handling

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Handle tap disabled event
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        // Check if LocalMouse is enabled
        guard ConfigManager.shared.isEnabled() else {
            return Unmanaged.passRetained(event)
        }

        // Get button number (CGEvent uses 0-indexed, we use 1-indexed)
        let cgButtonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        guard let button = MouseButton.fromCGEvent(cgButtonNumber) else {
            return Unmanaged.passRetained(event)
        }

        // Skip left and right buttons (let them pass through normally)
        if button == .left || button == .right {
            return Unmanaged.passRetained(event)
        }

        // Get keyboard modifiers
        let modifiers = KeyboardModifiers.fromCGEventFlags(event.flags)

        // Determine if this is a down or up event
        let isDown = type == .otherMouseDown

        // Process the button event
        let result = processButtonEvent(button: button, isDown: isDown, modifiers: modifiers)

        switch result {
        case .passthrough:
            return Unmanaged.passRetained(event)
        case .suppress:
            return nil
        case .replace(let newEvent):
            return Unmanaged.passRetained(newEvent)
        }
    }

    // MARK: - Click Processing

    private func processButtonEvent(button: MouseButton, isDown: Bool, modifiers: KeyboardModifiers) -> EventResult {
        let now = Date()

        if isDown {
            // Button pressed
            let state = clickStates[button] ?? ClickState()

            // Check for double-click
            let isDoubleClick = state.lastClickTime.map { now.timeIntervalSince($0) < doubleClickThreshold } ?? false

            // Update state
            var newState = state
            newState.isPressed = true
            newState.pressTime = now
            newState.clickCount = isDoubleClick ? state.clickCount + 1 : 1
            newState.modifiers = modifiers
            clickStates[button] = newState

            // Schedule hold detection
            scheduleHoldDetection(button: button, pressTime: now)

            // Don't trigger action on down - wait for up or hold
            return .suppress

        } else {
            // Button released
            guard var state = clickStates[button], state.isPressed else {
                return .passthrough
            }

            let pressDuration = now.timeIntervalSince(state.pressTime ?? now)
            let clickType: ClickType

            if pressDuration >= holdThreshold {
                // Already handled by hold detection
                state.isPressed = false
                state.lastClickTime = now
                clickStates[button] = state
                return .suppress
            } else if state.clickCount >= 2 {
                clickType = .doubleClick
            } else {
                clickType = .click
            }

            // Update state
            state.isPressed = false
            state.lastClickTime = now
            clickStates[button] = state

            // Find and execute matching action
            let trigger = ButtonTrigger(button: button, clickType: clickType, modifiers: state.modifiers)
            return executeAction(for: trigger)
        }
    }

    private func scheduleHoldDetection(button: MouseButton, pressTime: Date) {
        DispatchQueue.main.asyncAfter(deadline: .now() + holdThreshold) { [weak self] in
            self?.checkHold(button: button, originalPressTime: pressTime)
        }
    }

    private func checkHold(button: MouseButton, originalPressTime: Date) {
        guard let state = clickStates[button],
              state.isPressed,
              state.pressTime == originalPressTime else {
            return
        }

        // This is a hold
        let trigger = ButtonTrigger(button: button, clickType: .hold, modifiers: state.modifiers)
        _ = executeAction(for: trigger)
    }

    // MARK: - Action Execution

    private func executeAction(for trigger: ButtonTrigger) -> EventResult {
        let mappings = ConfigManager.shared.getMappings()

        // Find matching mapping
        guard let mapping = mappings.first(where: {
            $0.isEnabled &&
            $0.trigger.button == trigger.button &&
            $0.trigger.clickType == trigger.clickType &&
            $0.trigger.modifiers == trigger.modifiers
        }) else {
            // No mapping found - check if we should passthrough or suppress
            // For extra buttons without mapping, we suppress to avoid unwanted behavior
            return .suppress
        }

        // Execute the action
        ActionExecutor.shared.execute(mapping.action)
        return .suppress
    }
}

// MARK: - Supporting Types

private struct ClickState {
    var isPressed: Bool = false
    var pressTime: Date?
    var lastClickTime: Date?
    var clickCount: Int = 0
    var modifiers: KeyboardModifiers = []
}

private enum EventResult {
    case passthrough
    case suppress
    case replace(CGEvent)
}
