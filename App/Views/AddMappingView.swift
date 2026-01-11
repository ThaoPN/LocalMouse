import SwiftUI

struct AddMappingView: View {
    @Environment(\.dismiss) private var dismiss

    let existingMappings: [ButtonMapping]
    let preselectedButton: MouseButton?

    @State private var selectedButton: MouseButton = .button4
    @State private var selectedClickType: ClickType = .click
    @State private var selectedModifiers: KeyboardModifiers = []
    @State private var selectedActionType: ActionCategory = .navigation
    @State private var selectedAction: ActionType = .navigationSwipe(.back)
    @State private var showDuplicateWarning = false

    let onSave: (ButtonMapping) -> Void

    init(existingMappings: [ButtonMapping] = [], preselectedButton: MouseButton? = nil, onSave: @escaping (ButtonMapping) -> Void) {
        self.existingMappings = existingMappings
        self.preselectedButton = preselectedButton
        self.onSave = onSave

        // Set initial values
        if let button = preselectedButton {
            _selectedButton = State(initialValue: button)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Button Mapping")
                    .font(.title2.bold())
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            Form {
                // Trigger Section
                Section("Trigger") {
                    Picker("Button", selection: $selectedButton) {
                        ForEach(MouseButton.allCases.filter { $0 != .left && $0 != .right }) { button in
                            Text(button.displayName).tag(button)
                        }
                    }

                    Picker("Click Type", selection: $selectedClickType) {
                        ForEach(ClickType.allCases, id: \.self) { clickType in
                            Text(clickType.displayName).tag(clickType)
                        }
                    }

                    ModifierPicker(modifiers: $selectedModifiers)
                }

                // Warning for duplicate
                if isDuplicateTrigger {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("This trigger already exists. Adding will be ignored.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                // Action Section
                Section("Action") {
                    Picker("Category", selection: $selectedActionType) {
                        ForEach(ActionCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .onChange(of: selectedActionType) { newValue in
                        selectedAction = newValue.defaultAction
                    }

                    actionPicker
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Add Mapping") {
                    let trigger = ButtonTrigger(
                        button: selectedButton,
                        clickType: selectedClickType,
                        modifiers: selectedModifiers
                    )
                    let mapping = ButtonMapping(trigger: trigger, action: selectedAction)
                    onSave(mapping)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isDuplicateTrigger)
            }
            .padding()
        }
        .frame(width: 450, height: 520)
    }

    private var isDuplicateTrigger: Bool {
        existingMappings.contains { existing in
            existing.trigger.button == selectedButton &&
            existing.trigger.clickType == selectedClickType &&
            existing.trigger.modifiers == selectedModifiers
        }
    }

    @ViewBuilder
    private var actionPicker: some View {
        switch selectedActionType {
        case .navigation:
            Picker("Direction", selection: Binding(
                get: {
                    if case .navigationSwipe(let dir) = selectedAction { return dir }
                    return .back
                },
                set: { selectedAction = .navigationSwipe($0) }
            )) {
                Text("Back").tag(NavigationDirection.back)
                Text("Forward").tag(NavigationDirection.forward)
            }

        case .symbolicHotkey:
            Picker("System Action", selection: Binding(
                get: {
                    if case .symbolicHotkey(let hotkey) = selectedAction { return hotkey }
                    return .missionControl
                },
                set: { selectedAction = .symbolicHotkey($0) }
            )) {
                ForEach(SymbolicHotkey.allCases, id: \.self) { hotkey in
                    Text(hotkey.displayName).tag(hotkey)
                }
            }

        case .mouseClick:
            Picker("Button", selection: Binding(
                get: {
                    if case .mouseClick(let button) = selectedAction { return button }
                    return .middle
                },
                set: { selectedAction = .mouseClick($0) }
            )) {
                ForEach(MouseButton.allCases) { button in
                    Text(button.displayName).tag(button)
                }
            }

        case .none:
            Text("This button will be disabled")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Modifier Picker

struct ModifierPicker: View {
    @Binding var modifiers: KeyboardModifiers

    var body: some View {
        HStack {
            Text("Modifiers")
            Spacer()
            HStack(spacing: 8) {
                ModifierToggle(label: "⌘", isOn: binding(for: .command))
                ModifierToggle(label: "⌥", isOn: binding(for: .option))
                ModifierToggle(label: "⌃", isOn: binding(for: .control))
                ModifierToggle(label: "⇧", isOn: binding(for: .shift))
            }
        }
    }

    private func binding(for modifier: KeyboardModifiers) -> Binding<Bool> {
        Binding(
            get: { modifiers.contains(modifier) },
            set: { isOn in
                if isOn {
                    modifiers.insert(modifier)
                } else {
                    modifiers.remove(modifier)
                }
            }
        )
    }
}

struct ModifierToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button(label) {
            isOn.toggle()
        }
        .buttonStyle(.bordered)
        .tint(isOn ? .accentColor : .secondary)
    }
}

// MARK: - Action Category

enum ActionCategory: CaseIterable {
    case navigation
    case symbolicHotkey
    case mouseClick
    case none

    var displayName: String {
        switch self {
        case .navigation: return "Navigation"
        case .symbolicHotkey: return "System Action"
        case .mouseClick: return "Mouse Click"
        case .none: return "Disable Button"
        }
    }

    var defaultAction: ActionType {
        switch self {
        case .navigation: return .navigationSwipe(.back)
        case .symbolicHotkey: return .symbolicHotkey(.missionControl)
        case .mouseClick: return .mouseClick(.middle)
        case .none: return .none
        }
    }
}

#Preview {
    AddMappingView(existingMappings: [], preselectedButton: .button4) { _ in }
}
