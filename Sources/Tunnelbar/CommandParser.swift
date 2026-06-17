import Foundation

/// Helpers for working with pasted commands. We no longer split commands into
/// host/url fields — a connection is just a shell command — but we still use a
/// tokenizer to suggest a friendly default name.
enum CommandParser {

    /// Tokenize a shell-ish command string, honoring quotes and backslash-newline
    /// line continuations.
    static func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var hasCurrent = false
        var iterator = input.makeIterator()
        var pending: Character? = nil

        func next() -> Character? {
            if let p = pending { pending = nil; return p }
            return iterator.next()
        }

        while let c = next() {
            if c == "\\" && !inSingle {
                if let n = next() {
                    if n == "\n" { continue }
                    current.append(n)
                    hasCurrent = true
                }
                continue
            }
            if c == "'" && !inDouble { inSingle.toggle(); hasCurrent = true; continue }
            if c == "\"" && !inSingle { inDouble.toggle(); hasCurrent = true; continue }
            if (c == " " || c == "\t" || c == "\n" || c == "\r") && !inSingle && !inDouble {
                if hasCurrent { tokens.append(current); current = ""; hasCurrent = false }
                continue
            }
            current.append(c)
            hasCurrent = true
        }
        if hasCurrent { tokens.append(current) }
        return tokens
    }

    /// Suggest a friendly name for a command + working directory.
    /// Prefers a cloudflared `--hostname` path, then the working-dir name,
    /// then the first command word.
    static func suggestedName(command: String, workingDirectory: String) -> String {
        let tokens = tokenize(command)

        // cloudflared --hostname host/db -> "db"
        if let idx = tokens.firstIndex(where: { $0 == "--hostname" || $0.hasPrefix("--hostname=") }) {
            var host = ""
            if tokens[idx].hasPrefix("--hostname=") {
                host = String(tokens[idx].dropFirst("--hostname=".count))
            } else if idx + 1 < tokens.count {
                host = tokens[idx + 1]
            }
            if !host.isEmpty { return nameFromHostname(host) }
        }

        // Use the working directory's last component.
        let dir = workingDirectory.trimmingCharacters(in: .whitespaces)
        if !dir.isEmpty {
            let base = (dir as NSString).lastPathComponent
            if !base.isEmpty && base != "/" { return base }
        }

        // Otherwise the first meaningful command word.
        for tok in tokens where tok != "cd" && tok != "&&" && tok != "sudo" {
            let base = (tok as NSString).lastPathComponent
            if !base.isEmpty { return base }
        }
        return ""
    }

    /// Extract the missing program name from a shell "command not found" line,
    /// across zsh/bash/sh phrasings. Returns nil if the line isn't one.
    ///
    ///   zsh:  "zsh:1: command not found: cloudflared"
    ///   bash: "bash: line 1: cloudflared: command not found"
    static func parseMissingCommand(_ line: String) -> String? {
        if let r = line.range(of: "command not found: ") {
            let rest = line[r.upperBound...].trimmingCharacters(in: .whitespaces)
            let name = rest.split(separator: " ").first.map(String.init) ?? rest
            return name.isEmpty ? nil : name
        }
        if let r = line.range(of: ": command not found") {
            let left = String(line[..<r.lowerBound])
            let name = left.split(separator: ":").last
                .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
            return name.isEmpty ? nil : name
        }
        return nil
    }

    static func nameFromHostname(_ hostname: String) -> String {
        if hostname.contains("/"), let last = hostname.split(separator: "/").last {
            return String(last)
        }
        if let firstLabel = hostname.split(separator: ".").first {
            return String(firstLabel)
        }
        return hostname
    }
}
