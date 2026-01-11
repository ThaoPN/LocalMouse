import Foundation

/// Manages configuration storage and retrieval
/// Stores config locally - no cloud, no server, no BS
public final class ConfigManager {
    public static let shared = ConfigManager()

    private let fileManager = FileManager.default
    private var config: AppConfig

    /// Config file path: ~/Library/Application Support/LocalMouse/config.json
    public var configFileURL: URL {
        Self.getConfigFileURL()
    }

    /// Static helper to get config URL without accessing shared instance
    private static func getConfigFileURL() -> URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let localMouseDir = appSupport.appendingPathComponent("LocalMouse")
        return localMouseDir.appendingPathComponent("config.json")
    }

    private init() {
        self.config = Self.loadConfig() ?? .default
    }

    // MARK: - Public API

    public func getConfig() -> AppConfig {
        return config
    }

    public func saveConfig(_ newConfig: AppConfig) throws {
        self.config = newConfig
        try persistConfig()
    }

    public func getMappings() -> [ButtonMapping] {
        return config.mappings
    }

    public func addMapping(_ mapping: ButtonMapping) throws {
        config.mappings.append(mapping)
        try persistConfig()
    }

    public func updateMapping(_ mapping: ButtonMapping) throws {
        if let index = config.mappings.firstIndex(where: { $0.id == mapping.id }) {
            config.mappings[index] = mapping
            try persistConfig()
        }
    }

    public func removeMapping(id: UUID) throws {
        config.mappings.removeAll { $0.id == id }
        try persistConfig()
    }

    public func setEnabled(_ enabled: Bool) throws {
        config.isEnabled = enabled
        try persistConfig()
    }

    public func isEnabled() -> Bool {
        return config.isEnabled
    }

    public func reloadFromDisk() {
        if let loaded = Self.loadConfig() {
            self.config = loaded
        }
    }

    // MARK: - Private

    private static func loadConfig() -> AppConfig? {
        let configURL = getConfigFileURL()
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            print("[LocalMouse] Failed to load config: \(error)")
            return nil
        }
    }

    private func persistConfig() throws {
        let configURL = configFileURL
        let configDir = configURL.deletingLastPathComponent()

        // Ensure directory exists
        if !fileManager.fileExists(atPath: configDir.path) {
            try fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: .atomic)

        // Notify helper about config change
        NotificationCenter.default.post(name: .configDidChange, object: nil)
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let configDidChange = Notification.Name("LocalMouse.configDidChange")
}
