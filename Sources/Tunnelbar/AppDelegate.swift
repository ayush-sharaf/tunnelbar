import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private(set) static weak var shared: AppDelegate?

    private let store = TunnelStore.shared
    private var statusItem: NSStatusItem!
    private var managerWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var selection = Selection()
    private var cancellable: AnyCancellable?

    /// Box so SwiftUI and AppKit share the selected tunnel id.
    final class Selection: ObservableObject {
        @Published var id: UUID?
    }

    /// Convenience for SwiftUI views to open the Settings window.
    static func openSettings() {
        shared?.showSettings()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        AppSettings.shared.applyTheme()
        setupMainMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "point.3.connected.trianglepath.dotted",
                                   accessibilityDescription: "Tunnelbar")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // Refresh the status-bar glyph when tunnel counts change.
        cancellable = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateStatusButton() }
        }
        updateStatusButton()

        // Show the manager window on launch so opening the app from Spotlight /
        // Finder / Dock reveals the UI (not just the status-bar icon).
        openManager()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stopAll()
    }

    /// Called when the app is re-activated while already running (e.g. opened
    /// again from Spotlight, Finder, or the Dock). Re-show the manager window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openManager()
        return true
    }

    /// Build the application main menu. Without this, standard keyboard
    /// shortcuts like ⌘V (paste), ⌘C, ⌘A have no responder to route to, so
    /// text fields can't be pasted into.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        let settingsItem = appMenu.addItem(withTitle: "Settings…",
                                           action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        let quitItem = appMenu.addItem(withTitle: "Quit Tunnelbar",
                                       action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        appItem.submenu = appMenu

        // Edit menu (gives text fields cut/copy/paste/select-all)
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    private func updateStatusButton() {
        guard let button = statusItem.button else { return }
        let running = store.runningCount
        button.title = running > 0 ? " \(running)" : ""
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: "Tunnelbar", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        if store.tunnels.isEmpty {
            let empty = NSMenuItem(title: "No connections", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for tunnel in store.tunnels {
                let item = NSMenuItem(
                    title: "\(tunnel.status.dot)  \(tunnel.config.name)",
                    action: nil,
                    keyEquivalent: ""
                )
                item.submenu = submenu(for: tunnel)
                item.toolTip = "\(tunnel.config.command) · \(tunnel.status.label)"
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        addItem(to: menu, title: "Open Manager…", key: "o", action: #selector(openManager))
        addItem(to: menu, title: "Add Connection…", key: "n", action: #selector(addConnection))
        addItem(to: menu, title: "Settings…", key: ",", action: #selector(showSettings))
        menu.addItem(.separator())
        addItem(to: menu, title: "Quit Tunnelbar", key: "q", action: #selector(quit))
    }

    private func submenu(for tunnel: Tunnel) -> NSMenu {
        let sub = NSMenu()

        if tunnel.status.isRunning {
            addItem(to: sub, title: "Stop", key: "", action: #selector(stopTunnel(_:)), represented: tunnel.id)
            addItem(to: sub, title: "Restart", key: "", action: #selector(restartTunnel(_:)), represented: tunnel.id)
        } else {
            addItem(to: sub, title: "Start", key: "", action: #selector(startTunnel(_:)), represented: tunnel.id)
        }
        sub.addItem(.separator())
        addItem(to: sub, title: "Show Logs…", key: "", action: #selector(showLogs(_:)), represented: tunnel.id)
        addItem(to: sub, title: "Copy Command", key: "", action: #selector(copyCommand(_:)), represented: tunnel.id)

        let status = NSMenuItem(title: tunnel.status.label, action: nil, keyEquivalent: "")
        status.isEnabled = false
        sub.addItem(.separator())
        sub.addItem(status)
        return sub
    }

    @discardableResult
    private func addItem(to menu: NSMenu, title: String, key: String,
                         action: Selector, represented: Any? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.representedObject = represented
        menu.addItem(item)
        return item
    }

    // MARK: - Actions

    private func tunnel(from sender: NSMenuItem) -> Tunnel? {
        guard let id = sender.representedObject as? UUID else { return nil }
        return store.tunnel(id)
    }

    @objc private func startTunnel(_ sender: NSMenuItem) { tunnel(from: sender)?.start() }
    @objc private func stopTunnel(_ sender: NSMenuItem) { tunnel(from: sender)?.stop() }
    @objc private func restartTunnel(_ sender: NSMenuItem) { tunnel(from: sender)?.restart() }

    @objc private func copyCommand(_ sender: NSMenuItem) {
        guard let t = tunnel(from: sender) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(t.config.commandString, forType: .string)
    }

    @objc private func showLogs(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        selection.id = id
        openManager()
    }

    @objc private func addConnection() {
        openManager()
        // Defer so the window exists before posting.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .tmAddConnection, object: nil)
        }
    }

    @objc private func openManager() {
        if managerWindow == nil {
            let root = ManagerRoot(store: store, selection: selection)
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Tunnelbar"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 860, height: 520))
            window.center()
            window.isReleasedWhenClosed = false
            managerWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        managerWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        store.stopAll()
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let tmAddConnection = Notification.Name("tmAddConnection")
}

/// Bridges the AppKit-owned selection box into SwiftUI.
struct ManagerRoot: View {
    @ObservedObject var store: TunnelStore
    @ObservedObject var selection: AppDelegate.Selection
    @State private var triggerAdd = false

    var body: some View {
        ManagerView(store: store, selection: $selection.id)
            .onReceive(NotificationCenter.default.publisher(for: .tmAddConnection)) { _ in
                triggerAdd.toggle()
            }
            // Re-emit add intent via an environment-free state toggle handled in ManagerView.
            .environment(\.tmAddTrigger, triggerAdd)
    }
}

// Simple environment key so the menu's "Add Connection…" can open the sheet.
private struct TMAddTriggerKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var tmAddTrigger: Bool {
        get { self[TMAddTriggerKey.self] }
        set { self[TMAddTriggerKey.self] = newValue }
    }
}
