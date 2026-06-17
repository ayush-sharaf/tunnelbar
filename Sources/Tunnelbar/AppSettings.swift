import AppKit
import ServiceManagement

/// Appearance options offered in Settings.
enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light:  return NSAppearance(named: .aqua)
        case .dark:   return NSAppearance(named: .darkAqua)
        }
    }
}

/// App-wide user settings, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let themeKey = "theme"

    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
            applyTheme()
        }
    }

    /// Whether the app launches automatically when the user logs in.
    @Published var launchAtLogin: Bool {
        didSet { updateLoginItem(launchAtLogin) }
    }

    var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—" }
    var build: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—" }

    private init() {
        let raw = UserDefaults.standard.string(forKey: themeKey) ?? AppTheme.system.rawValue
        theme = AppTheme(rawValue: raw) ?? .system
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    /// Apply the chosen appearance to the whole app.
    func applyTheme() {
        NSApp.appearance = theme.appearance
    }

    private func updateLoginItem(_ enabled: Bool) {
        do {
            let service = SMAppService.mainApp
            if enabled {
                if service.status != .enabled { try service.register() }
            } else {
                if service.status == .enabled { try service.unregister() }
            }
        } catch {
            NSLog("Tunnelbar: failed to update login item: \(error)")
        }
    }
}
