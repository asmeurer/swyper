import SwiftUI

struct AppRuleEditor: View {
    @Binding var mapping: AppMapping
    /// The default mapping, used to show the inherited shortcut for app-specific
    /// rules. `nil` when editing the default mapping itself.
    var defaultMapping: AppMapping?

    private var isAppMapping: Bool { defaultMapping != nil }

    var body: some View {
        Form {
            Section {
                ForEach(SwipeDirection.allCases, id: \.self) { direction in
                    row(for: direction)
                        .padding(.vertical, 2)
                }
            } header: {
                Text(mapping.displayName)
                    .font(.headline)
            } footer: {
                if isAppMapping {
                    Text("Blank directions use the Default shortcut. "
                        + "Disable a direction to turn the gesture off for this app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func row(for direction: SwipeDirection) -> some View {
        HStack {
            Label(direction.displayName, systemImage: direction.symbolName)
                .frame(width: 120, alignment: .leading)

            ShortcutRecorderView(shortcut: Binding(
                get: { mapping.shortcuts[direction] },
                set: { newValue in
                    if let shortcut = newValue {
                        mapping.shortcuts[direction] = shortcut
                        mapping.disabledDirections.remove(direction)
                    } else {
                        mapping.shortcuts.removeValue(forKey: direction)
                    }
                }
            ))
            .frame(width: 140, height: 24)

            if mapping.shortcuts[direction] != nil {
                clearButton(direction)
            } else if isAppMapping {
                inheritanceControls(direction)
            }

            Spacer()
        }
    }

    private func clearButton(_ direction: SwipeDirection) -> some View {
        Button(role: .destructive) {
            mapping.shortcuts.removeValue(forKey: direction)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Clear shortcut")
    }

    @ViewBuilder
    private func inheritanceControls(_ direction: SwipeDirection) -> some View {
        let inherited = defaultMapping?.shortcuts[direction]

        if mapping.disabledDirections.contains(direction) {
            Text("Disabled")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                mapping.disabledDirections.remove(direction)
            } label: {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Restore default")
        } else if let inherited {
            Text("\(inherited.displayString) (default)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                mapping.disabledDirections.insert(direction)
            } label: {
                Image(systemName: "nosign")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Disable this gesture for this app")
        } else {
            Text("No default")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
