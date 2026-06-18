import Foundation

/// Records the OS process backing each running connection in a small file, so
/// processes left behind by a previous session (after a force-quit or crash)
/// can be reaped on the next launch.
///
/// PID reuse is guarded against by re-checking, at reap time, that the live
/// process's command line still matches what we launched before terminating it.
final class ProcessRegistry {
    struct Entry: Codable {
        let id: UUID
        let pid: Int32
        let command: String
    }

    private let url: URL
    private let lock = NSLock()

    init(fileURL: URL) {
        self.url = fileURL
    }

    func register(id: UUID, pid: Int32, command: String) {
        mutate { entries in
            entries.removeAll { $0.id == id }
            entries.append(Entry(id: id, pid: pid, command: command))
        }
    }

    func unregister(id: UUID) {
        mutate { $0.removeAll { $0.id == id } }
    }

    /// Terminate processes recorded by a previous session that are still alive
    /// and still look like the command we launched, then clear the record.
    func reapOrphans() {
        let entries = current()
        guard !entries.isEmpty else { return }
        var reaped = 0
        for entry in entries where Self.isAlive(entry.pid) {
            let signature = entry.command.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !signature.isEmpty,
                  let live = Self.psCommand(entry.pid),
                  live.contains(signature) else { continue }
            Self.terminateTree(entry.pid)
            reaped += 1
        }
        if reaped > 0 { NSLog("Tunnelnest: reaped \(reaped) orphaned process(es) from a previous session.") }
        write([])
    }

    // MARK: - File

    private func current() -> [Entry] {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    private func write(_ entries: [Entry]) {
        lock.lock(); defer { lock.unlock() }
        if let data = try? JSONEncoder().encode(entries) { try? data.write(to: url) }
    }

    private func mutate(_ block: (inout [Entry]) -> Void) {
        lock.lock()
        var entries = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? []
        block(&entries)
        if let data = try? JSONEncoder().encode(entries) { try? data.write(to: url) }
        lock.unlock()
    }

    // MARK: - Process helpers

    static func isAlive(_ pid: Int32) -> Bool {
        pid > 0 && kill(pid, 0) == 0
    }

    /// Full command line for a pid (or nil if it isn't running).
    static func psCommand(_ pid: Int32) -> String? {
        guard let out = run("/bin/ps", ["-ww", "-p", "\(pid)", "-o", "command="]) else { return nil }
        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Direct + transitive child pids of `pid`.
    static func descendants(of pid: Int32) -> [Int32] {
        guard let out = run("/usr/bin/pgrep", ["-P", "\(pid)"]) else { return [] }
        let children = out.split(separator: "\n").compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
        return children + children.flatMap { descendants(of: $0) }
    }

    /// Signal a process and all of its descendants (not relying on process
    /// groups, which child processes don't reliably share).
    static func terminateTree(_ pid: Int32, signal sig: Int32 = SIGTERM) {
        for p in ([pid] + descendants(of: pid)) where p > 0 {
            kill(p, sig)
        }
    }

    /// Terminate every recorded process tree (SIGTERM, then SIGKILL any
    /// stragglers) and clear the registry. Used on app shutdown.
    func terminateAll() {
        let entries = current()
        guard !entries.isEmpty else { write([]); return }
        for e in entries { Self.terminateTree(e.pid) }
        usleep(300_000) // brief grace for clean exit
        for e in entries where Self.isAlive(e.pid) {
            Self.terminateTree(e.pid, signal: SIGKILL)
        }
        write([])
    }

    /// The pid of the process LISTENing on a local TCP port, if any.
    static func pidListening(onPort port: Int) -> Int32? {
        guard let out = run("/usr/sbin/lsof", ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"]) else { return nil }
        return out.split(separator: "\n").first
            .flatMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
    }

    private static func run(_ path: String, _ args: [String]) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do { try proc.run() } catch { return nil }
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
