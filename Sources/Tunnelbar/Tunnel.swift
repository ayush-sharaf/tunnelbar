import Foundation
import Combine

/// A live connection: wraps the persisted config plus the running process
/// (launched through a login shell) and its captured logs. Observable so
/// SwiftUI views update automatically.
final class Tunnel: ObservableObject, Identifiable {
    @Published var config: ConnectionConfig
    @Published private(set) var status: TunnelStatus = .stopped
    @Published private(set) var logs: [LogLine] = []

    var id: UUID { config.id }

    private let logFileURL: URL
    private let registry: ProcessRegistry
    private var process: Process?
    private var outBuffer = ""
    private var errBuffer = ""
    private var intentionalStop = false
    private let maxLines = 5000

    // Log file rotation: cap the on-disk log and keep one rotated backup so it
    // can't grow without bound.
    private let maxLogBytes = 1_000_000
    private var logBytes = 0
    private var rotatedLogURL: URL { logFileURL.appendingPathExtension("1") }

    // Auto-reconnect bookkeeping (only used when the setting is enabled and a
    // running connection drops unexpectedly — never after a manual stop).
    private var startedAt: Date?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var reconnecting = false
    private var reconnectWorkItem: DispatchWorkItem?
    private var didPromptMissingTool = false

    init(config: ConnectionConfig, logsDir: URL, registry: ProcessRegistry) {
        self.config = config
        self.registry = registry
        self.logFileURL = logsDir.appendingPathComponent("\(config.id.uuidString).log")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
           let size = attrs[.size] as? Int {
            logBytes = size
        }
    }

    // MARK: - Lifecycle

    func start() {
        guard !status.isRunning else { return }
        let command = config.command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            setStatus(.failed("empty command"))
            return
        }

        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        intentionalStop = false
        if !reconnecting {
            reconnectAttempts = 0
            didPromptMissingTool = false
        }
        reconnecting = false
        setStatus(.starting)
        appendSystem("$ \(command)")

        // If this command binds a local port that's already taken, reclaim our
        // own leftover on it, or refuse with a clear message (rather than the
        // raw "address already in use" failure).
        if let port = CommandParser.extractPort(command: command),
           let holder = ProcessRegistry.pidListening(onPort: port) {
            let holderCmd = ProcessRegistry.psCommand(holder) ?? ""
            if holderCmd.contains(command) {
                appendSystem("Port \(port) is held by a previous instance (pid \(holder)); reclaiming it…")
                ProcessRegistry.terminateTree(holder)
                usleep(400_000)
            } else {
                appendSystem("Port \(port) is already in use by another process (pid \(holder)). Stop it or use a different port.")
                setStatus(.failed("port \(port) in use"))
                return
            }
        }

        let proc = Process()
        // Run through a login shell so the user's PATH (homebrew, nvm, etc.)
        // is available — this lets cloudflared, npm, etc. resolve.
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        proc.executableURL = URL(fileURLWithPath: shell)
        proc.arguments = ["-l", "-c", command]

        let dir = config.workingDirectory.trimmingCharacters(in: .whitespaces)
        if !dir.isEmpty {
            proc.currentDirectoryURL = URL(fileURLWithPath: (dir as NSString).expandingTildeInPath)
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
            self?.ingest(s, into: \.outBuffer, isError: false)
        }
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
            // Many tools (cloudflared, node) log to stderr; treat as info.
            self?.ingest(s, into: \.errBuffer, isError: false)
        }

        proc.terminationHandler = { [weak self] p in
            DispatchQueue.main.async {
                guard let self = self else { return }
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                self.process = nil
                self.registry.unregister(id: self.id)
                if self.intentionalStop {
                    self.appendSystem("Stopped.")
                    self.setStatus(.stopped)
                } else {
                    let code = p.terminationStatus
                    self.appendSystem("Process exited (code \(code)).")
                    // Exit 127 = "command not found": a required tool isn't
                    // installed / on PATH. Surface it by name and don't bother
                    // auto-reconnecting (it would just fail again).
                    if code == 127, let tool = self.detectMissingTool() {
                        self.setStatus(.failed("‘\(tool)’ not found"))
                        self.promptMissingTool(tool)
                    } else {
                        self.setStatus(code == 0 ? .stopped : .failed("exited with code \(code)"))
                        self.handleUnexpectedExit()
                    }
                }
            }
        }

        do {
            try proc.run()
            process = proc
            startedAt = Date()
            registry.register(id: id, pid: proc.processIdentifier, command: command)
            setStatus(.running)
        } catch {
            appendSystem("Failed to launch: \(error.localizedDescription)")
            setStatus(.failed(error.localizedDescription))
        }
    }

    func stop() {
        // Cancel any pending auto-reconnect so a manual stop always wins.
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        reconnectAttempts = 0
        reconnecting = false

        guard let proc = process, proc.isRunning else {
            setStatus(.stopped)
            return
        }
        intentionalStop = true
        setStatus(.stopping)
        appendSystem("Stopping…")
        // Terminate the process and its descendants (e.g. node spawned by npm),
        // which don't reliably share a killable process group.
        ProcessRegistry.terminateTree(proc.processIdentifier)
        proc.terminate()
    }

    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.start()
        }
    }

    /// Scan recent log lines for a shell "command not found" message and return
    /// the missing program name, if any.
    private func detectMissingTool() -> String? {
        for line in logs.reversed().prefix(25) {
            if let tool = CommandParser.parseMissingCommand(line.text) { return tool }
        }
        return nil
    }

    /// Tell the app to prompt the user about a missing tool — once per failure
    /// run, so retries/reconnects don't spam alerts.
    private func promptMissingTool(_ tool: String) {
        guard !didPromptMissingTool else { return }
        didPromptMissingTool = true
        NotificationCenter.default.post(
            name: .tmMissingTool,
            object: nil,
            userInfo: ["tool": tool, "connection": config.name]
        )
    }

    /// Called on the main thread when a *running* connection exits without a
    /// manual stop. Reconnects only if the user enabled auto-reconnect, with a
    /// capped number of attempts and a backoff to avoid crash loops.
    private func handleUnexpectedExit() {
        guard AppSettings.shared.autoReconnect else { return }

        // A connection that stayed up for a while is treated as a fresh drop.
        if let startedAt, Date().timeIntervalSince(startedAt) >= 10 {
            reconnectAttempts = 0
        }
        reconnectAttempts += 1

        guard reconnectAttempts <= maxReconnectAttempts else {
            appendSystem("Auto-reconnect gave up after \(maxReconnectAttempts) attempts.")
            reconnecting = false
            return
        }

        let delay = Double(min(30, 3 * reconnectAttempts))
        appendSystem("Auto-reconnecting (attempt \(reconnectAttempts)/\(maxReconnectAttempts)) in \(Int(delay))s…")
        reconnecting = true
        let item = DispatchWorkItem { [weak self] in self?.start() }
        reconnectWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func clearLogs() {
        logs.removeAll()
        try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(at: rotatedLogURL)
        logBytes = 0
    }

    // MARK: - Log handling

    private func ingest(_ text: String, into keyPath: ReferenceWritableKeyPath<Tunnel, String>, isError: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var buffer = self[keyPath: keyPath] + text
            while let nl = buffer.firstIndex(of: "\n") {
                let line = String(buffer[buffer.startIndex..<nl])
                buffer = String(buffer[buffer.index(after: nl)...])
                if !line.isEmpty { self.appendLine(line, isError: isError) }
            }
            self[keyPath: keyPath] = buffer
        }
    }

    private func appendSystem(_ text: String) {
        if Thread.isMainThread {
            appendLine("» \(text)", isError: false)
        } else {
            DispatchQueue.main.async { [weak self] in self?.appendLine("» \(text)", isError: false) }
        }
    }

    /// Must be called on the main thread.
    private func appendLine(_ text: String, isError: Bool) {
        let line = LogLine(date: Date(), text: text, isError: isError)
        logs.append(line)
        if logs.count > maxLines { logs.removeFirst(logs.count - maxLines) }
        appendToFile(line)
    }

    private func appendToFile(_ line: LogLine) {
        let formatter = ISO8601DateFormatter()
        let entry = "\(formatter.string(from: line.date)) \(line.text)\n"
        guard let data = entry.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: logFileURL) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        } else {
            try? data.write(to: logFileURL)
        }
        logBytes += data.count
        if logBytes > maxLogBytes { rotateLogFile() }
    }

    /// Roll the log over when it gets large: keep one backup (`<id>.log.1`).
    private func rotateLogFile() {
        let fm = FileManager.default
        try? fm.removeItem(at: rotatedLogURL)
        try? fm.moveItem(at: logFileURL, to: rotatedLogURL)
        logBytes = 0
    }

    private func setStatus(_ s: TunnelStatus) {
        if Thread.isMainThread {
            status = s
        } else {
            DispatchQueue.main.async { [weak self] in self?.status = s }
        }
    }
}
