import Foundation
import AppKit

/// Helper process entry point
/// Runs in the background, intercepts mouse events, requires no internet connection
/// Because your mouse shouldn't need permission from the cloud
@main
struct HelperMain {
    static func main() {
        print("""

        ╔══════════════════════════════════════════════════════════════╗
        ║                      LocalMouse Helper                        ║
        ║          Because Your Mouse Shouldn't Need The Cloud          ║
        ╚══════════════════════════════════════════════════════════════╝

        """)

        // Check accessibility permissions
        guard checkAccessibilityPermissions() else {
            print("[LocalMouse] ❌ Accessibility permissions not granted.")
            print("[LocalMouse] Please grant Accessibility access in System Preferences > Privacy & Security > Accessibility")
            exit(1)
        }

        print("[LocalMouse] ✅ Accessibility permissions granted")

        // Load configuration
        let config = ConfigManager.shared.getConfig()
        print("[LocalMouse] ✅ Configuration loaded: \(config.mappings.count) button mappings")

        // Start button interceptor
        guard ButtonInterceptor.shared.start() else {
            print("[LocalMouse] ❌ Failed to start button interceptor")
            exit(1)
        }

        print("[LocalMouse] ✅ Button interceptor started")
        print("[LocalMouse] 🖱️  Ready to intercept mouse buttons - working offline, as it should be")
        print("")

        // Watch for config changes
        setupConfigWatcher()

        // Keep the helper running
        RunLoop.main.run()
    }

    private static func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    private static func setupConfigWatcher() {
        // Watch for config file changes
        let configURL = ConfigManager.shared.configFileURL
        let configDir = configURL.deletingLastPathComponent()

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        // Use DispatchSource for file monitoring
        let fd = open(configDir.path, O_EVTONLY)
        guard fd >= 0 else {
            print("[LocalMouse] ⚠️  Could not watch config directory")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .main
        )

        source.setEventHandler {
            print("[LocalMouse] 🔄 Config changed, reloading...")
            ConfigManager.shared.reloadFromDisk()
            let config = ConfigManager.shared.getConfig()
            print("[LocalMouse] ✅ Reloaded: \(config.mappings.count) button mappings")
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()

        print("[LocalMouse] 👀 Watching for config changes")
    }
}
