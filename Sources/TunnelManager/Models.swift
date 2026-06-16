import Foundation

/// The persisted configuration for a single managed connection / process.
/// A connection is just a shell command (run via a login shell) with an
/// optional working directory — e.g. a cloudflared access command, or
/// `npm start` inside a project directory.
struct ConnectionConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    /// The full shell command, e.g.
    /// `cloudflared access tcp --hostname host/db --url localhost:2346`
    /// or `cd test-app && npm start`.
    var command: String
    /// Optional working directory the command runs in. May be empty.
    var workingDirectory: String

    init(id: UUID = UUID(),
         name: String,
         command: String,
         workingDirectory: String = "") {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
    }

    /// Backwards/forwards-compatible decoding: older saves may not have
    /// `command`/`workingDirectory`.
    enum CodingKeys: String, CodingKey {
        case id, name, command, workingDirectory
    }

    /// The command, used for display and copy.
    var commandString: String { command }
}

/// Runtime status of a connection's process.
enum TunnelStatus: Equatable {
    case stopped
    case starting
    case running
    case stopping
    case failed(String)

    var label: String {
        switch self {
        case .stopped:  return "Stopped"
        case .starting: return "Starting…"
        case .running:  return "Running"
        case .stopping: return "Stopping…"
        case .failed(let m): return "Failed: \(m)"
        }
    }

    /// Status indicator used in the menu-bar menu.
    var dot: String {
        switch self {
        case .stopped:  return "⚪️"
        case .starting, .stopping: return "🟡"
        case .running:  return "🟢"
        case .failed:   return "🔴"
        }
    }

    var isRunning: Bool {
        switch self {
        case .running, .starting: return true
        default: return false
        }
    }
}

/// A single captured log line.
struct LogLine: Identifiable {
    let id = UUID()
    let date: Date
    let text: String
    let isError: Bool
}
