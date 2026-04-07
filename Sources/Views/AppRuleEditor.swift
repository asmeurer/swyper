import SwiftUI

struct AppRuleEditor: View {
    @Binding var mapping: AppMapping

    var body: some View {
        Form {
            Section {
                ForEach(SwipeDirection.allCases, id: \.self) { direction in
                    HStack {
                        Label(direction.displayName, systemImage: direction.symbolName)
                            .frame(width: 120, alignment: .leading)

                        ShortcutRecorderView(shortcut: Binding(
                            get: { mapping.shortcuts[direction] },
                            set: { newValue in
                                if let shortcut = newValue {
                                    mapping.shortcuts[direction] = shortcut
                                } else {
                                    mapping.shortcuts.removeValue(forKey: direction)
                                }
                            }
                        ))
                        .frame(width: 140, height: 24)

                        if mapping.shortcuts[direction] != nil {
                            Button(role: .destructive) {
                                mapping.shortcuts.removeValue(forKey: direction)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text(mapping.displayName)
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
    }
}
