import Foundation
import Combine

/// Owns the list of tunnels, persistence, and the resolved cloudflared path.
final class TunnelStore: ObservableObject {
    static let shared = TunnelStore()

    @Published private(set) var tunnels: [Tunnel] = []

    private let supportDir: URL
    private let configURL: URL
    private let logsDir: URL
    private let registry: ProcessRegistry
    private var cancellables: [UUID: AnyCancellable] = [:]

    private init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        supportDir = base.appendingPathComponent("Tunnelnest", isDirectory: true)

        // Carry over data from the app's former name ("Tunnelbar") so existing
        // connections and logs survive the rename.
        let legacyDir = base.appendingPathComponent("Tunnelbar", isDirectory: true)
        if !fm.fileExists(atPath: supportDir.path),
           fm.fileExists(atPath: legacyDir.path) {
            try? fm.moveItem(at: legacyDir, to: supportDir)
        }

        logsDir = supportDir.appendingPathComponent("logs", isDirectory: true)
        configURL = supportDir.appendingPathComponent("connections.json")
        registry = ProcessRegistry(fileURL: supportDir.appendingPathComponent("running.json"))
        try? fm.createDirectory(at: logsDir, withIntermediateDirectories: true)

        // Clean up processes left running by a previous session (force-quit/crash).
        registry.reapOrphans()
        load()
    }

    // MARK: - CRUD

    func add(_ config: ConnectionConfig) {
        let tunnel = makeTunnel(config)
        tunnels.append(tunnel)
        save()
    }

    func update(_ config: ConnectionConfig) {
        guard let tunnel = tunnels.first(where: { $0.id == config.id }) else { return }
        let wasRunning = tunnel.status.isRunning
        tunnel.config = config
        save()
        // Apply the edited command immediately by restarting a live connection.
        if wasRunning { tunnel.restart() }
    }

    func remove(_ tunnel: Tunnel) {
        tunnel.stop()
        cancellables[tunnel.id] = nil
        tunnels.removeAll { $0.id == tunnel.id }
        save()
    }

    /// Reorder connections (drag-and-drop in the list). Order is persisted.
    func move(from source: IndexSet, to destination: Int) {
        tunnels.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - Export / Import

    /// Encode all connection configs as pretty JSON for backup/sharing.
    func exportData() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(tunnels.map { $0.config })
    }

    /// Import connections from exported JSON, appending them with fresh ids so
    /// they never clobber existing entries. Returns the number imported.
    @discardableResult
    func importConnections(from data: Data) -> Int {
        guard let configs = try? JSONDecoder().decode([ConnectionConfig].self, from: data) else {
            return 0
        }
        for var cfg in configs {
            cfg.id = UUID()
            tunnels.append(makeTunnel(cfg))
        }
        if !configs.isEmpty { save() }
        return configs.count
    }

    func tunnel(_ id: UUID) -> Tunnel? {
        tunnels.first { $0.id == id }
    }

    var runningCount: Int {
        tunnels.filter { $0.status.isRunning }.count
    }

    func stopAll() {
        tunnels.forEach { $0.stop() }
    }

    /// Stop everything and guarantee no child processes survive the app:
    /// stop each connection, then SIGTERM/SIGKILL any recorded process trees
    /// and clear the registry. Called on quit and on termination signals.
    func shutdown() {
        tunnels.forEach { $0.stop() }
        registry.terminateAll()
    }

    // MARK: - Persistence

    private func makeTunnel(_ config: ConnectionConfig) -> Tunnel {
        let tunnel = Tunnel(config: config, logsDir: logsDir, registry: registry)
        // Re-publish child object changes so list views and the menu refresh.
        cancellables[config.id] = tunnel.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.objectWillChange.send() }
        }
        return tunnel
    }

    func save() {
        let configs = tunnels.map { $0.config }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(configs)
            try data.write(to: configURL, options: .atomic)
        } catch {
            NSLog("Tunnelnest: failed to save connections: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: configURL),
              let configs = try? JSONDecoder().decode([ConnectionConfig].self, from: data) else {
            return
        }
        tunnels = configs.map { makeTunnel($0) }
    }
}
