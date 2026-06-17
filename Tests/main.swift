// Lightweight test runner for Tunnelbar's pure-logic layer.
//
// The project builds with `swiftc` (SwiftPM's manifest API is broken in bare
// Command Line Tools), so instead of an XCTest/SwiftPM target these tests are
// a plain executable compiled from the Foundation-only sources plus this file
// (see scripts/run-tests.sh). It exits non-zero if any check fails.
import Foundation

var failures = 0
var passes = 0

func check(_ condition: Bool, _ message: String) {
    if condition {
        passes += 1
    } else {
        failures += 1
        print("✗ FAIL: \(message)")
    }
}

func eq<T: Equatable>(_ got: T, _ want: T, _ message: String) {
    check(got == want, "\(message) — got \(got), want \(want)")
}

// MARK: - CommandParser.tokenize

eq(CommandParser.tokenize("a b c"), ["a", "b", "c"], "tokenize: simple split")
eq(CommandParser.tokenize("  a   b  "), ["a", "b"], "tokenize: collapses whitespace")
eq(CommandParser.tokenize("a \"b c\" d"), ["a", "b c", "d"], "tokenize: double quotes")
eq(CommandParser.tokenize("'a b' c"), ["a b", "c"], "tokenize: single quotes")
eq(CommandParser.tokenize("a \\\nb"), ["a", "b"], "tokenize: backslash-newline continuation")
eq(CommandParser.tokenize(""), [], "tokenize: empty string")
eq(CommandParser.tokenize("cd app && npm start"),
   ["cd", "app", "&&", "npm", "start"], "tokenize: shell operators kept as tokens")

// MARK: - CommandParser.nameFromHostname

eq(CommandParser.nameFromHostname("tunnel-int.example.com/postgres18"),
   "postgres18", "nameFromHostname: path segment wins")
eq(CommandParser.nameFromHostname("a.b.example.com"),
   "a", "nameFromHostname: first label when no path")
eq(CommandParser.nameFromHostname("host/db/leaf"),
   "leaf", "nameFromHostname: last path segment")

// MARK: - CommandParser.suggestedName

eq(CommandParser.suggestedName(
    command: "cloudflared access tcp --hostname tunnel-int.example.com/postgres18 --url localhost:2346",
    workingDirectory: ""),
   "postgres18", "suggestedName: from --hostname")
eq(CommandParser.suggestedName(
    command: "cloudflared access tcp --hostname=h.example.com/redis --url localhost:6379",
    workingDirectory: ""),
   "redis", "suggestedName: from --hostname=value form")
eq(CommandParser.suggestedName(command: "npm start", workingDirectory: "/Users/x/projects/web-app"),
   "web-app", "suggestedName: from working directory basename")
eq(CommandParser.suggestedName(command: "cd app && npm start", workingDirectory: ""),
   "app", "suggestedName: first meaningful word, skipping cd")

// MARK: - ConnectionConfig

let cfg = ConnectionConfig(name: "x", command: "cd a && npm start", workingDirectory: "~/p")
eq(cfg.commandString, "cd a && npm start", "ConnectionConfig.commandString echoes command")
eq(cfg.name, "x", "ConnectionConfig stores name")

// Codable round-trip
let encoded = try! JSONEncoder().encode([cfg])
let decoded = try! JSONDecoder().decode([ConnectionConfig].self, from: encoded)
eq(decoded.count, 1, "ConnectionConfig: codable round-trip count")
eq(decoded[0].command, cfg.command, "ConnectionConfig: codable round-trip command")
eq(decoded[0].id, cfg.id, "ConnectionConfig: codable round-trip id")

// MARK: - TunnelStatus

check(TunnelStatus.running.isRunning, "status: running.isRunning")
check(TunnelStatus.starting.isRunning, "status: starting.isRunning")
check(!TunnelStatus.stopped.isRunning, "status: stopped not running")
check(!TunnelStatus.stopping.isRunning, "status: stopping not running")
check(!TunnelStatus.failed("boom").isRunning, "status: failed not running")
eq(TunnelStatus.failed("boom").label, "Failed: boom", "status: failed label")
eq(TunnelStatus.running.label, "Running", "status: running label")
eq(TunnelStatus.running.dot, "🟢", "status: running dot")
eq(TunnelStatus.stopped.dot, "⚪️", "status: stopped dot")
eq(TunnelStatus.failed("x").dot, "🔴", "status: failed dot")

// MARK: - UpdateChecker

eq(UpdateChecker.normalize("v1.3"), "1.3", "normalize: strips leading v")
eq(UpdateChecker.normalize("1.3"), "1.3", "normalize: no-op without v")
check(UpdateChecker.compare("1.3", "1.2") == .orderedDescending, "compare: 1.3 > 1.2")
check(UpdateChecker.compare("1.2", "1.3") == .orderedAscending, "compare: 1.2 < 1.3")
check(UpdateChecker.compare("1.2", "1.2") == .orderedSame, "compare: equal")
check(UpdateChecker.compare("1.10", "1.9") == .orderedDescending, "compare: 1.10 > 1.9 (numeric)")
check(UpdateChecker.compare("2.0", "1.9") == .orderedDescending, "compare: major wins")
check(UpdateChecker.compare("1.2.1", "1.2") == .orderedDescending, "compare: extra patch component")

// MARK: - Summary

print("\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
