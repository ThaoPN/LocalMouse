import SwiftUI

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showInMenuBar") private var showInMenuBar = true

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                Toggle("Show in Menu Bar", isOn: $showInMenuBar)
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Config Location") {
                    Text(ConfigManager.shared.configFileURL.path)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LocalMouse")
                        .font(.headline)
                    Text("Because your mouse shouldn't need permission from the cloud.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Works 100% offline. No servers. No cloud. No telemetry. No BS.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .padding()
    }
}

#Preview {
    SettingsView()
}
