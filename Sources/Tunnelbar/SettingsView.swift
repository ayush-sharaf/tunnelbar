import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    private let store = TunnelStore.shared
    @State private var importMessage: String?

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $settings.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("General") {
                Toggle("Open Tunnelbar at login", isOn: $settings.launchAtLogin)
                Text("When enabled, Tunnelbar starts automatically (in the menu bar) when you log in.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Auto-reconnect dropped connections", isOn: $settings.autoReconnect)
                Text("If a running connection drops unexpectedly, restart it automatically. Connections you stop yourself are left alone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Connections") {
                HStack {
                    Button("Export…") { exportConnections() }
                    Button("Import…") { importConnections() }
                    Spacer()
                    if let importMessage {
                        Text(importMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("Back up your connections to a JSON file, or import them on another machine.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Application", value: "Tunnelbar")
                LabeledContent("Version", value: "\(settings.version) (\(settings.build))")
                Link("GitHub Repository",
                     destination: URL(string: "https://github.com/ayush-sharaf/tunnelbar")!)
                Link("Report an Issue",
                     destination: URL(string: "https://github.com/ayush-sharaf/tunnelbar/issues")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 420)
    }

    private func exportConnections() {
        guard let data = store.exportData() else {
            importMessage = "Nothing to export."
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "tunnelbar-connections.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                importMessage = "Exported \(store.tunnels.count) connection(s)."
            } catch {
                importMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private func importConnections() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
            let count = store.importConnections(from: data)
            importMessage = count > 0 ? "Imported \(count) connection(s)." : "No valid connections found."
        }
    }
}
