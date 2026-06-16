import SwiftUI

// MARK: - Manager Window

struct ManagerView: View {
    @ObservedObject var store: TunnelStore
    @Binding var selection: UUID?
    @Environment(\.tmAddTrigger) private var addTrigger
    @State private var showingAdd = false
    @State private var editing: ConnectionConfig?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(store.tunnels) { tunnel in
                    TunnelRow(tunnel: tunnel)
                        .tag(tunnel.id)
                        .contextMenu {
                            Button("Edit…") { editing = tunnel.config }
                            Button("Delete", role: .destructive) { store.remove(tunnel) }
                        }
                }
            }
            .frame(minWidth: 240)
            .navigationTitle("Tunnels")
            .toolbar {
                ToolbarItem {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Add a connection")
                }
            }
            .overlay {
                if store.tunnels.isEmpty {
                    ContentUnavailableView(
                        "No Connections",
                        systemImage: "point.3.connected.trianglepath.dotted",
                        description: Text("Click + to add a command to run.")
                    )
                }
            }
        } detail: {
            if let id = selection, let tunnel = store.tunnel(id) {
                TunnelDetailView(store: store, tunnel: tunnel) {
                    editing = tunnel.config
                }
                .id(tunnel.id)
            } else {
                Text("Select a tunnel")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 760, minHeight: 460)
        .sheet(isPresented: $showingAdd) {
            ConnectionEditor(store: store, existing: nil)
        }
        .sheet(item: $editing) { config in
            ConnectionEditor(store: store, existing: config)
        }
        .onChange(of: addTrigger) {
            showingAdd = true
        }
    }
}

struct TunnelRow: View {
    @ObservedObject var tunnel: Tunnel

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(tunnel.config.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(tunnel.config.command)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var color: Color {
        switch tunnel.status {
        case .stopped:  return .gray
        case .starting, .stopping: return .yellow
        case .running:  return .green
        case .failed:   return .red
        }
    }
}

// MARK: - Detail

struct TunnelDetailView: View {
    @ObservedObject var store: TunnelStore
    @ObservedObject var tunnel: Tunnel
    var onEdit: () -> Void

    @State private var autoScroll = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            LogView(tunnel: tunnel, autoScroll: $autoScroll)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tunnel.config.name).font(.title2).bold()
                    Text(tunnel.status.label)
                        .font(.subheadline)
                        .foregroundStyle(statusColor)
                }
                Spacer()
                controls
            }
            VStack(alignment: .leading, spacing: 3) {
                labeledRow("Command", tunnel.config.command)
                if !tunnel.config.workingDirectory.isEmpty {
                    labeledRow("Directory", tunnel.config.workingDirectory)
                }
            }
            .font(.callout)
        }
        .padding()
    }

    private var controls: some View {
        HStack(spacing: 8) {
            if tunnel.status.isRunning {
                Button(role: .destructive) { tunnel.stop() } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
            } else {
                Button { tunnel.start() } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            Button { tunnel.restart() } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Restart")
            Button { onEdit() } label: {
                Image(systemName: "pencil")
            }
            .help("Edit")
            Menu {
                Button("Copy command") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(tunnel.config.commandString, forType: .string)
                }
                Button("Clear logs") { tunnel.clearLogs() }
                Divider()
                Button("Delete", role: .destructive) { store.remove(tunnel) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value).textSelection(.enabled)
            Spacer()
        }
    }

    private var statusColor: Color {
        switch tunnel.status {
        case .running: return .green
        case .failed:  return .red
        case .starting, .stopping: return .orange
        case .stopped: return .secondary
        }
    }
}

// MARK: - Logs

struct LogView: View {
    @ObservedObject var tunnel: Tunnel
    @Binding var autoScroll: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Logs").font(.headline)
                Text("⌘-click links to open")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                Button("Clear") { tunnel.clearLogs() }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            LogTextView(lines: tunnel.logs, autoScroll: autoScroll)
        }
    }
}

// MARK: - NSTextView-backed log view (terminal-like, ⌘-click to open links)

struct LogTextView: NSViewRepresentable {
    var lines: [LogLine]
    var autoScroll: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = LinkTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.autoresizingMask = [.width]
        textView.isAutomaticLinkDetectionEnabled = false
        textView.delegate = context.coordinator
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand
        ]
        context.coordinator.textView = textView

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coord = context.coordinator
        guard let tv = coord.textView, let storage = tv.textStorage else { return }

        // Logs were cleared -> reset.
        if lines.count < coord.renderedCount {
            storage.setAttributedString(NSAttributedString())
            coord.renderedCount = 0
        }

        guard lines.count > coord.renderedCount else { return }

        let appended = NSMutableAttributedString()
        for line in lines[coord.renderedCount..<lines.count] {
            appended.append(Coordinator.render(line))
        }
        storage.append(appended)
        coord.renderedCount = lines.count

        if autoScroll {
            tv.scrollToEndOfDocument(nil)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: LinkTextView?
        var renderedCount = 0

        private static let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss"
            return f
        }()

        private static let monoFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

        static func render(_ line: LogLine) -> NSAttributedString {
            let time = timeFormatter.string(from: line.date) + "  "
            let result = NSMutableAttributedString()

            result.append(NSAttributedString(string: time, attributes: [
                .font: monoFont,
                .foregroundColor: NSColor.tertiaryLabelColor
            ]))

            let body = NSMutableAttributedString(string: line.text + "\n", attributes: [
                .font: monoFont,
                .foregroundColor: line.isError ? NSColor.systemRed : NSColor.textColor
            ])
            addLinks(to: body)
            result.append(body)
            return result
        }

        /// Detect file paths and URLs and attach `.link` attributes.
        private static func addLinks(to attr: NSMutableAttributedString) {
            let text = attr.string
            let fullRange = NSRange(text.startIndex..., in: text)

            // 1. Absolute / home-relative file paths that exist on disk.
            if let pathRegex = try? NSRegularExpression(pattern: "(~|/)[^\\s\"']+") {
                for match in pathRegex.matches(in: text, range: fullRange) {
                    guard let r = Range(match.range, in: text) else { continue }
                    let raw = String(text[r])
                    let expanded = (raw as NSString).expandingTildeInPath
                    if FileManager.default.fileExists(atPath: expanded) {
                        attr.addAttribute(.link, value: URL(fileURLWithPath: expanded), range: match.range)
                    }
                }
            }

            // 2. Web URLs (override any path match in the same range).
            if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
                for match in detector.matches(in: text, range: fullRange) {
                    if let url = match.url {
                        attr.addAttribute(.link, value: url, range: match.range)
                    }
                }
            }
        }

        /// Open links only when ⌘ is held (terminal-style); otherwise ignore
        /// so the click can be used for text selection.
        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            let cmdHeld = NSApp.currentEvent?.modifierFlags.contains(.command) ?? false
            guard cmdHeld else { return true } // handled (suppress default), but do nothing

            let url: URL?
            if let u = link as? URL { url = u }
            else if let s = link as? String { url = URL(string: s) }
            else { url = nil }

            if let url {
                if url.isFileURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } else {
                    NSWorkspace.shared.open(url)
                }
            }
            return true
        }
    }
}

/// NSTextView subclass for the log output. Links are opened by the delegate
/// only when ⌘ is held, mirroring Terminal.app's behavior.
final class LinkTextView: NSTextView {}

// MARK: - Add / Edit

struct ConnectionEditor: View {
    @ObservedObject var store: TunnelStore
    let existing: ConnectionConfig?

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var command = ""
    @State private var workingDirectory = ""

    private var isEditing: Bool { existing != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isEditing ? "Edit Connection" : "Add Connection")
                .font(.title2).bold()

            VStack(alignment: .leading, spacing: 4) {
                Text("Command")
                    .font(.subheadline).foregroundStyle(.secondary)
                TextEditor(text: $command)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 80)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                Text("e.g. cloudflared access tcp --hostname host/db --url localhost:2346\n  or  cd test-app && npm start")
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Working directory (optional)")
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    TextField("e.g. ~/projects/test-app", text: $workingDirectory)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Button("Choose…") { chooseDirectory() }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    TextField("Display name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    Button("Suggest") {
                        name = CommandParser.suggestedName(command: command,
                                                           workingDirectory: workingDirectory)
                    }
                    .disabled(command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Save" : "Add") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 540)
        .onAppear(perform: loadExisting)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadExisting() {
        guard let c = existing else { return }
        name = c.name
        command = c.command
        workingDirectory = c.workingDirectory
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            workingDirectory = url.path
        }
    }

    private func commit() {
        var finalName = name.trimmingCharacters(in: .whitespaces)
        if finalName.isEmpty {
            finalName = CommandParser.suggestedName(command: command, workingDirectory: workingDirectory)
        }
        let config = ConnectionConfig(
            id: existing?.id ?? UUID(),
            name: finalName,
            command: command.trimmingCharacters(in: .whitespacesAndNewlines),
            workingDirectory: workingDirectory.trimmingCharacters(in: .whitespaces)
        )
        if isEditing {
            store.update(config)
        } else {
            store.add(config)
        }
        dismiss()
    }
}
