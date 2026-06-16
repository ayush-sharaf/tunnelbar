# Tunnel Manager

A native macOS menu-bar app for managing your `cloudflared access` tunnel
connections through a UI instead of juggling terminal windows.

## Features

- **Menu-bar icon** — every tunnel shows a live status dot (🟢 running /
  ⚪️ stopped / 🟡 transitioning / 🔴 failed). Start, stop, restart, view logs,
  or copy the command from a submenu. The icon shows a count of running tunnels.
- **Add by pasting** — paste a full command like
  `cloudflared access tcp --hostname tunnel-int.softwareartistry.com/postgre18 --url localhost:2346`
  and click **Parse**; it auto-fills Name / Hostname / Local URL. You can also
  edit fields manually.
- **Manager window** — list of all tunnels with start/stop controls and a
  **live, streaming log view** per tunnel (auto-scroll, clear, copy).
- **Manual control** — tunnels only start/stop when you tell them to. No
  auto-reconnect.
- **Persistent** — connections are saved to
  `~/Library/Application Support/TunnelManager/connections.json`.
  Per-tunnel logs are written to `…/TunnelManager/logs/<id>.log`.

## Build

Requires the Swift toolchain (Command Line Tools is enough) and `cloudflared`
on your `PATH` (auto-detected at `/opt/homebrew/bin`, `/usr/local/bin`, etc.).

```sh
./build.sh        # compiles and produces TunnelManager.app
open TunnelManager.app
```

> Note: this project builds with `swiftc` directly (see `build.sh`) rather than
> `swift build`, because SwiftPM's manifest API is broken in bare Command Line
> Tools installs without full Xcode.

## Install / autostart

- Drag `TunnelManager.app` into `/Applications`.
- To launch at login: System Settings → General → Login Items → add the app.

## Project layout

| File | Purpose |
|------|---------|
| `Sources/TunnelManager/main.swift` | Entry point; starts as an accessory (menu-bar) app |
| `AppDelegate.swift` | Status-bar item, dynamic menu, manager window |
| `Models.swift` | `ConnectionConfig`, `TunnelStatus`, `LogLine` |
| `CommandParser.swift` | Parses pasted `cloudflared …` commands |
| `Tunnel.swift` | Spawns/monitors the `cloudflared` process, captures logs |
| `TunnelStore.swift` | Connection list, persistence, `cloudflared` discovery |
| `Views.swift` | SwiftUI manager window, detail, logs, add/edit editor |
