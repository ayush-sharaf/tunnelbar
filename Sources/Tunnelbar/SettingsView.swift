import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

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
        .frame(width: 440, height: 380)
    }
}
