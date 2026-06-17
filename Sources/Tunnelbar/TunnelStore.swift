import Foundation
import Combine

/// Owns the list of tunnels, persistence, and the resolved cloudflared path.
final class TunnelStore: ObservableObject {
    static let shared = TunnelStore()

    @Published private(set) var tunnels: [Tunnel] = []

    private let supportDir: URL
    private let configURL: URL
    private let logsDir: URL
    private var cancellables: [UUID: AnyCancellable] = [:]

    private init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        supportDir = base.appendingPathComponent("Tunnelbar", isDirectory: true)
        logsDir = supportDir.appendingPathComponent("logs", isDirectory: true)
        configURL = supportDir.appendingPathComponent("connections.json")
        try? fm.createDirectory(at: logsDir, withIntermediateDirectories: true)

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

    func tunnel(_ id: UUID) -> Tunnel? {
        tunnels.first { $0.id == id }
    }

    var runningCount: Int {
        tunnels.filter { $0.status.isRunning }.count
    }

    func stopAll() {
        tunnels.forEach { $0.stop() }
    }

    // MARK: - Persistence

    private func makeTunnel(_ config: ConnectionConfig) -> Tunnel {
        let tunnel = Tunnel(config: config, logsDir: logsDir)
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
            NSLog("Tunnelbar: failed to save connections: \(error)")
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
