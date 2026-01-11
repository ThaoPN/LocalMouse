# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LocalMouse is a macOS mouse button remapping utility that works completely offline without cloud dependencies. The core philosophy is local-first: all configuration is stored in `~/Library/Application Support/LocalMouse/config.json` with no server communication.

## Build Commands

### Building with Xcode
```bash
# Open project in Xcode
open LocalMouse.xcodeproj

# Build from command line (Xcode required)
xcodebuild -project LocalMouse.xcodeproj -scheme LocalMouse -configuration Debug build
```

### Building with Swift Package Manager
```bash
# Build the helper executable
swift build -c debug

# Build for release
swift build -c release

# Run the helper directly (for testing)
swift run LocalMouseHelper
```

## Architecture

### Three-Component System

1. **App** (`App/`): SwiftUI menu bar application
   - Menu bar interface with NSStatusItem
   - Settings UI for configuring button mappings
   - Manages launch at login via SMAppService
   - Activation policy switches between `.regular` (dock visible) and `.accessory` (menu bar only)

2. **Helper** (`Helper/`): Background event interceptor
   - Entry point: `Helper/main.swift`
   - `ButtonInterceptor`: CGEventTap-based mouse event interception
   - `ActionExecutor`: Executes mapped actions (shortcuts, hotkeys, etc.)
   - Watches config file for changes using DispatchSource

3. **Shared** (`Shared/`): Common code
   - `ButtonMapping.swift`: Core data models (MouseButton, ActionType, SymbolicHotkey)
   - `ConfigManager.swift`: JSON config persistence, NotificationCenter integration
   - `CGSPrivate.swift`: CoreGraphics Services private APIs for symbolic hotkeys

### Event Flow

```
Mouse Button Click
    ↓
ButtonInterceptor.handleEvent (CGEventTap callback)
    ↓
processButtonEvent (detect click/double-click/hold)
    ↓
executeAction (find matching ButtonMapping)
    ↓
ActionExecutor.execute (trigger system hotkey, keyboard shortcut, etc.)
```

### Key Implementation Details

**Button Numbering**: MouseButton enum uses 1-indexed buttons (Button 1 = left, Button 2 = right, Button 3 = middle, etc.) but CGEvent uses 0-indexed. Convert with `MouseButton.fromCGEvent(_:)`.

**CGEventTap Lifecycle**:
- Must be added to MAIN run loop (`CFRunLoopGetMain()`)
- Handle `.tapDisabledByTimeout` and `.tapDisabledByUserInput` to re-enable
- Left/right clicks are passed through, only intercept middle and extra buttons

**Symbolic Hotkeys via CGS Private API**:
- `CGSPrivate.swift` declares private CoreGraphics Services functions
- `SymbolicHotKeyManager.post(_:)` checks if hotkey has usable binding
- If no binding exists, creates one with "out of reach" virtual key code (400+)
- Posts keyboard events to trigger system hotkeys (Mission Control, spaces, etc.)

**Click Type Detection**:
- **Click**: Button down then up within 0.3s
- **Double-click**: Two clicks within 0.3s threshold
- **Hold**: Button held for ≥0.3s, triggers on hold threshold
- State tracked per-button in `clickStates` dictionary

**Config Synchronization**:
- App saves config → posts `Notification.Name.configDidChange`
- Helper watches config directory with DispatchSource
- Both reload from disk when changes detected

## Requirements

- macOS 13.0+ (specified in Package.swift)
- Accessibility permissions (required for CGEventTap)
- No external dependencies (pure Swift + system frameworks)

## Development Workflow

### Testing Accessibility
The app will prompt for Accessibility permissions on first run. Grant access in:
**System Settings → Privacy & Security → Accessibility**

### Debugging Event Interception
The helper process logs extensively with `[LocalMouse]` prefix:
```bash
# Run helper directly to see logs
swift run LocalMouseHelper
```

### Config File Location
```bash
# View current config
cat ~/Library/Application\ Support/LocalMouse/config.json

# Watch config changes in real-time
fswatch ~/Library/Application\ Support/LocalMouse/config.json
```

## Important Patterns

**Modifier Keys**: Use `KeyboardModifiers` struct (OptionSet) not CGEventFlags directly. Convert with `KeyboardModifiers.fromCGEventFlags(_:)`.

**Action Types**: All actions implement the `ActionType` enum:
- `.symbolicHotkey(SymbolicHotkey)` - System shortcuts via CGS
- `.keyboardShortcut(KeyboardShortcut)` - Custom key combinations
- `.mouseClick(MouseButton)` - Simulate different mouse button
- `.navigationSwipe(NavigationDirection)` - Back/forward (Cmd+[ / Cmd+])
- `.openApp(bundleId:)` - Launch application
- `.shellCommand(String)` - Execute shell command
- `.none` - Passthrough

**Default Mappings**: See `AppConfig.default` in `ButtonMapping.swift`:
- Middle button → Mission Control
- Button 4 → Move right a space
- Button 5 → Move left a space

## Common Tasks

### Adding New Symbolic Hotkey
1. Add case to `SymbolicHotkey` enum in `ButtonMapping.swift`
2. Add `displayName` implementation
3. If has CGS support: map in `CGSSymbolicHotKey` enum + extension
4. If no CGS support: add fallback in `ActionExecutor.executeSymbolicHotkey(_:)`

### Adding New Action Type
1. Add case to `ActionType` enum
2. Implement execution in `ActionExecutor.execute(_:)`
3. Add UI picker in SwiftUI views if needed

### Modifying Click Detection Thresholds
Change constants in `ButtonInterceptor`:
- `holdThreshold`: Currently 0.3s
- `doubleClickThreshold`: Currently 0.3s
