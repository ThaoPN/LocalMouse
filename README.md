# LocalMouse

> **The Tale of the $100 Paperweight**
>
> It's a beautiful Monday morning. You're coding. Life is good. You reach for your Logitech M650's middle button to open Mission Control.
>
> *Click.*
>
> Nothing.
>
> *Click side button to switch desktop spaces.*
>
> Still nothing.
>
> You open Logi Options+. The app opens. The loading indicator spins. And spins. And spins...
>
> Still spinning.
>
> It's been 5 minutes. Still spinning.
>
> **Your $100 mouse just became a $20 mouse because Logitech's servers are taking a coffee break.**
>
> Welcome to 2024, where your mouse needs cloud permission to... click buttons. 🤦

---

## Because Your Mouse Shouldn't Need Permission From The Cloud

Tired of your $100 mouse becoming a paperweight every time Logitech's servers decide to take a coffee break?

LocalMouse is a revolutionary concept in mouse software: **it actually works offline**. Crazy, right?

### Features that shouldn't be features but here we are:

- ✅ **Works without internet** - Shocking, we know
- ✅ **No server dependency** - Your mouse buttons don't need to phone home
- ✅ **Instant response** - No waiting for cloud validation to click a button
- ✅ **Privacy** - We don't know what you click, and we don't care
- ✅ **Always works** - Even when Logitech's infrastructure doesn't

### What we DON'T offer:

- ❌ Unnecessary cloud sync for local settings
- ❌ Telemetry about your clicking habits
- ❌ Error messages about server connectivity for offline features
- ❌ A 200MB Electron app for 5 button mappings

**LocalMouse**: Making your premium mouse work like it's 2010. *When things just worked.*

---

## Architecture

LocalMouse uses a three-component system:

```
LocalMouse/
├── App/                    # SwiftUI menu bar application
│   ├── LocalMouseApp.swift
│   ├── Views/
│   └── ViewModels/
├── Helper/                 # Background event interceptor
│   ├── main.swift          # Entry point
│   ├── ButtonInterceptor.swift  # CGEventTap-based mouse event interception
│   └── ActionExecutor.swift     # Executes mapped actions
└── Shared/                 # Common code
    ├── ButtonMapping.swift      # Data models (MouseButton, ActionType, etc.)
    ├── ConfigManager.swift      # JSON config persistence
    └── CGSPrivate.swift        # CoreGraphics Services private APIs
```

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

## Requirements

- macOS 13.0+
- Xcode or Swift Package Manager
- Accessibility permission (required for CGEventTap)

## Installation & Building

### For Users (No Apple Developer Account Required)

If you don't have an Apple Developer account, you can still build and run LocalMouse using a free Apple ID:

1. **Clone the repository**
   ```bash
   git clone https://github.com/ThaoPN/LocalMouse.git
   cd LocalMouse
   ```

2. **Open in Xcode**
   ```bash
   open LocalMouse.xcodeproj
   ```

3. **Configure Signing**
   - Select the `LocalMouse` project in the navigator (left sidebar)
   - Select the `LocalMouse` target
   - Go to "Signing & Capabilities" tab
   - **Enable "Automatically manage signing"**
   - Select your **Team** (your Apple ID - it's free!)
     - If you don't see a team, click "Add an Account..." and sign in with your Apple ID
   - Change the **Bundle Identifier** to something unique (e.g., `com.yourname.LocalMouse`)
     - This is required because the default bundle ID might be taken

4. **Build and Run**
   - Press `Cmd + R` or click the Play button
   - The app will appear in your menu bar

5. **Grant Accessibility Permission**
   - On first run, you'll be prompted to grant Accessibility permission
   - Go to **System Settings → Privacy & Security → Accessibility**
   - Enable LocalMouse

### For Developers

#### With Xcode
```bash
open LocalMouse.xcodeproj
# Or build from command line
xcodebuild -project LocalMouse.xcodeproj -scheme LocalMouse -configuration Debug build
```

#### With Swift Package Manager
```bash
swift build -c debug    # Debug build
swift build -c release  # Release build
swift run LocalMouseHelper  # Run helper directly for testing
```

### Troubleshooting

**"Developer cannot be verified"**
- Go to **System Settings → Privacy & Security**
- Click "Open Anyway" next to the LocalMouse warning

**Code signing fails**
- Make sure you've changed the Bundle Identifier to something unique
- Try cleaning the build folder: `Cmd + Shift + K` in Xcode

**Helper process not working**
- Check if Accessibility permission is granted
- Try quitting and restarting the app

## How It Works

1. **App**: SwiftUI menu bar interface for configuring button mappings, manages launch at login
2. **Helper**: Background process that intercepts mouse events and executes configured actions
3. **Config Sync**: Changes saved by App are automatically detected by Helper (file watching + NotificationCenter)

### Supported Actions

- **Symbolic Hotkeys**: Mission Control, Show Desktop, spaces navigation, etc.
- **Keyboard Shortcuts**: Custom key combinations with modifiers
- **Mouse Clicks**: Remap to different mouse buttons
- **Navigation Swipes**: Browser back/forward (Cmd+[ / Cmd+])
- **Launch Apps**: Open applications by bundle ID
- **Shell Commands**: Execute custom shell scripts

### Click Types

- **Click**: Button down then up within 0.3s
- **Double-click**: Two clicks within 0.3s
- **Hold**: Button held for ≥0.3s

### Default Mappings

- Middle button → Mission Control
- Button 4 → Move right a space
- Button 5 → Move left a space

## Config File

All configuration is stored in:
```
~/Library/Application Support/LocalMouse/config.json
```

No servers. No cloud. No BS.

## License

MIT - Do whatever you want with it.
