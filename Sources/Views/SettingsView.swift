import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(ConfigManager.self) private var configManager
    @Environment(FrontAppMonitor.self) private var appMonitor
    @State private var selectedID: String? = "default"
    @State private var showingAppPicker = false
    @State private var swipeIndicatorOpacity: Double = 0
    @State private var displayedSwipeDirection: SwipeDirection?

    var body: some View {
        @Bindable var cm = configManager

        VStack(spacing: 0) {
        NavigationSplitView {
            List(selection: $selectedID) {
                Section("Mappings") {
                    NavigationLink(value: "default") {
                        Label("Default", systemImage: "globe")
                    }

                    ForEach(cm.config.appMappings) { mapping in
                        NavigationLink(value: mapping.id) {
                            HStack {
                                AppIconView(bundleID: mapping.bundleID)
                                    .frame(width: 20, height: 20)
                                Text(mapping.displayName)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        cm.config.appMappings.remove(atOffsets: indexSet)
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        showingAppPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }

                    Button {
                        if let selectedID, selectedID != "default" {
                            cm.config.appMappings.removeAll { $0.id == selectedID }
                            self.selectedID = "default"
                        }
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(selectedID == nil || selectedID == "default")
                }
            }
        } detail: {
            if let selectedID {
                if selectedID == "default" {
                    AppRuleEditor(mapping: $cm.config.defaultMapping)
                } else if let index = cm.config.appMappings.firstIndex(where: { $0.id == selectedID }) {
                    AppRuleEditor(mapping: $cm.config.appMappings[index])
                } else {
                    Text("Select a mapping")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Select a mapping")
                    .foregroundStyle(.secondary)
            }
        }
        Divider()

        HStack(spacing: 12) {
            Text("Sensitivity")
                .font(.callout)
            Text("Low")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: $cm.config.swipeSensitivity, in: 0...1)
                .frame(maxWidth: 200)
            Text("High")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(String(format: "(%.2f)", cm.config.swipeThresholdValue))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()

            Spacer()

            if let direction = displayedSwipeDirection {
                Label(direction.displayName, systemImage: direction.symbolName)
                    .font(.callout.bold())
                    .foregroundColor(.accentColor)
                    .opacity(swipeIndicatorOpacity)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .onChange(of: cm.lastSwipeTime) {
            displayedSwipeDirection = cm.lastSwipeDirection
            swipeIndicatorOpacity = 1.0
            withAnimation(.easeOut(duration: 1.5)) {
                swipeIndicatorOpacity = 0
            }
        }

        } // VStack
        .frame(minWidth: 550, minHeight: 350)
        .sheet(isPresented: $showingAppPicker) {
            AppPickerSheet(configManager: configManager) { bundleID, name in
                let mapping = AppMapping(bundleID: bundleID, displayName: name)
                cm.config.appMappings.append(mapping)
                selectedID = bundleID
            }
        }
    }
}

// MARK: - App Picker Sheet

struct AppPickerSheet: View {
    let configManager: ConfigManager
    let onSelect: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var apps: [RunningAppInfo] = []

    var filteredApps: [RunningAppInfo] {
        if searchText.isEmpty { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Application")
                .font(.headline)
                .padding()

            TextField("Search...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            List(filteredApps) { app in
                Button {
                    onSelect(app.bundleID, app.name)
                    dismiss()
                } label: {
                    HStack {
                        AppIconView(bundleID: app.bundleID)
                            .frame(width: 24, height: 24)
                        Text(app.name)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(
                    configManager.config.appMappings.contains { $0.bundleID == app.bundleID }
                )
            }
            .frame(minHeight: 250)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 350, height: 400)
        .onAppear {
            apps = getRunningApps()
        }
    }

    private func getRunningApps() -> [RunningAppInfo] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> RunningAppInfo? in
                guard let bundleID = app.bundleIdentifier,
                      let name = app.localizedName else { return nil }
                return RunningAppInfo(bundleID: bundleID, name: name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

struct RunningAppInfo: Identifiable {
    var id: String { bundleID }
    let bundleID: String
    let name: String
}

// MARK: - App Icon View

struct AppIconView: View {
    let bundleID: String?

    var body: some View {
        if let bundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "app")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.secondary)
        }
    }
}
