import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(isEnabled: $viewModel.isEnabled)

            Divider()

            // Button Detection Area
            ButtonDetectionView { button in
                viewModel.detectedButton = button
                viewModel.showAddMapping = true
            }

            Divider()

            // Main content
            if viewModel.mappings.isEmpty {
                EmptyStateView {
                    viewModel.showAddMapping = true
                }
            } else {
                MappingListView(
                    mappings: $viewModel.mappings,
                    onDelete: viewModel.deleteMapping,
                    onToggle: viewModel.toggleMapping
                )
            }

            Divider()

            // Footer
            FooterView(
                onAdd: { viewModel.showAddMapping = true },
                onRestoreDefaults: viewModel.restoreDefaults
            )
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $viewModel.showAddMapping) {
            AddMappingView(
                existingMappings: viewModel.mappings,
                preselectedButton: viewModel.detectedButton
            ) { mapping in
                viewModel.addMapping(mapping)
            }
        }
    }
}

// MARK: - Header

struct HeaderView: View {
    @Binding var isEnabled: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("LocalMouse")
                    .font(.title.bold())

                Text("Because your mouse shouldn't need the cloud")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .onChange(of: isEnabled) { newValue in
                    // Save to config and notify menu bar
                    try? ConfigManager.shared.setEnabled(newValue)
                    NotificationCenter.default.post(name: .configDidChange, object: nil)
                }
        }
        .padding()
    }
}

// MARK: - Button Detection Area

struct ButtonDetectionView: View {
    let onButtonDetected: (MouseButton) -> Void

    @State private var isHovering = false
    @State private var lastDetectedButton: MouseButton?

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))

                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isHovering ? Color.accentColor : Color.secondary.opacity(0.3),
                        lineWidth: 2
                    )

                VStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(isHovering ? Color.accentColor : .secondary)

                    if let button = lastDetectedButton {
                        Text("Detected: \(button.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 100)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            .overlay {
                ButtonDetectorRepresentable { button in
                    lastDetectedButton = button
                    onButtonDetected(button)
                }
            }

            Text("Move the mouse pointer inside the '+' field, then **Click** a mouse button to assign an action to it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - NSView for Button Detection

struct ButtonDetectorRepresentable: NSViewRepresentable {
    let onButtonDetected: (MouseButton) -> Void

    func makeNSView(context: Context) -> ButtonDetectorView {
        let view = ButtonDetectorView()
        view.onButtonDetected = onButtonDetected
        return view
    }

    func updateNSView(_ nsView: ButtonDetectorView, context: Context) {
        nsView.onButtonDetected = onButtonDetected
    }
}

class ButtonDetectorView: NSView {
    var onButtonDetected: ((MouseButton) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func otherMouseDown(with event: NSEvent) {
        let buttonNumber = event.buttonNumber
        if let button = MouseButton(rawValue: buttonNumber + 1) {
            onButtonDetected?(button)
        }
    }

    override func mouseDown(with event: NSEvent) {
        // Left click - ignore for detection, used for focus
    }

    override func rightMouseDown(with event: NSEvent) {
        // Right click - could detect but usually has system meaning
        onButtonDetected?(.right)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "computermouse")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No Button Mappings")
                .font(.title2)

            Text("Click a mouse button in the area above to add a mapping.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Mapping List

struct MappingListView: View {
    @Binding var mappings: [ButtonMapping]
    let onDelete: (UUID) -> Void
    let onToggle: (UUID) -> Void

    var body: some View {
        List {
            ForEach(mappings) { mapping in
                MappingRowView(
                    mapping: mapping,
                    onToggle: { onToggle(mapping.id) },
                    onDelete: { onDelete(mapping.id) }
                )
            }
        }
        .listStyle(.inset)
    }
}

struct MappingRowView: View {
    let mapping: ButtonMapping
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            // Trigger description
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if !mapping.trigger.modifiers.isEmpty {
                        Text(mapping.trigger.modifiers.displayName)
                            .font(.caption.monospaced())
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    Text(mapping.trigger.button.displayName)
                        .fontWeight(.medium)

                    Text("(\(mapping.trigger.clickType.displayName))")
                        .foregroundStyle(.secondary)
                }

                Text(actionDescription(mapping.action))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onToggle) {
                Image(systemName: mapping.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(mapping.isEnabled ? Color.green : Color.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help(mapping.isEnabled ? "Disable this mapping" : "Enable this mapping")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete this mapping")
        }
        .padding(.vertical, 4)
        .opacity(mapping.isEnabled ? 1 : 0.5)
    }

    private func actionDescription(_ action: ActionType) -> String {
        switch action {
        case .symbolicHotkey(let hotkey):
            return "→ \(hotkey.displayName)"
        case .keyboardShortcut(let shortcut):
            return "→ Keyboard Shortcut (key \(shortcut.keyCode))"
        case .mouseClick(let button):
            return "→ \(button.displayName)"
        case .navigationSwipe(let direction):
            return "→ Navigate \(direction.displayName)"
        case .openApp(let bundleId):
            return "→ Open \(bundleId)"
        case .shellCommand(let cmd):
            return "→ Run: \(cmd.prefix(30))..."
        case .none:
            return "→ Do nothing"
        }
    }
}

// MARK: - Footer

struct FooterView: View {
    let onAdd: () -> Void
    let onRestoreDefaults: () -> Void

    var body: some View {
        HStack {
            Button("Restore Defaults") {
                onRestoreDefaults()
            }

            Spacer()

            Text("Works 100% offline. No servers. No cloud. No BS.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            Button(action: onAdd) {
                Label("Add Mapping", systemImage: "plus")
            }
        }
        .padding()
    }
}

// MARK: - View Model

class ContentViewModel: ObservableObject {
    @Published var mappings: [ButtonMapping] = []
    @Published var isEnabled: Bool = true
    @Published var showAddMapping: Bool = false
    @Published var detectedButton: MouseButton?

    private var configObserver: NSObjectProtocol?

    init() {
        loadMappings()

        // Listen for config changes from menu bar
        configObserver = NotificationCenter.default.addObserver(
            forName: .configDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadMappings()
        }
    }

    deinit {
        if let observer = configObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func loadMappings() {
        mappings = ConfigManager.shared.getMappings()
        isEnabled = ConfigManager.shared.isEnabled()
    }

    func addMapping(_ mapping: ButtonMapping) {
        // Check for duplicate trigger
        let isDuplicate = mappings.contains { existing in
            existing.trigger.button == mapping.trigger.button &&
            existing.trigger.clickType == mapping.trigger.clickType &&
            existing.trigger.modifiers == mapping.trigger.modifiers
        }

        if isDuplicate {
            print("[LocalMouse] Duplicate mapping ignored")
            return
        }

        try? ConfigManager.shared.addMapping(mapping)
        loadMappings()
        detectedButton = nil
    }

    func deleteMapping(_ id: UUID) {
        try? ConfigManager.shared.removeMapping(id: id)
        loadMappings()
    }

    func toggleMapping(_ id: UUID) {
        if var mapping = mappings.first(where: { $0.id == id }) {
            mapping.isEnabled.toggle()
            try? ConfigManager.shared.updateMapping(mapping)
            loadMappings()
        }
    }

    func restoreDefaults() {
        try? ConfigManager.shared.saveConfig(.default)
        loadMappings()
    }
}

#Preview {
    ContentView()
        .frame(width: 600, height: 500)
}
