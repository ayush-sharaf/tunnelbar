# Tunnelbar

A native macOS **menu-bar app** for managing your `cloudflared` tunnels — and
any other long-running command — through a simple UI, instead of juggling
terminal windows.

> Add a connection by pasting a command, start/stop it from the menu bar, and
> watch its live logs. Built in Swift, no Electron, ~1 MB.

![status: menu-bar app](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![language: Swift](https://img.shields.io/badge/Swift-6-orange)
![license: MIT](https://img.shields.io/badge/license-MIT-green)

## Features

- **Menu-bar icon** — every connection shows a live status dot (🟢 running /
  ⚪️ stopped / 🟡 transitioning / 🔴 failed). Start, stop, restart, view logs,
  or copy the command from a submenu. The icon shows a count of running ones.
- **Add by pasting any command** — e.g.
  `cloudflared access tcp --hostname tunnel-int.example.com/postgres --url localhost:2346`
  or `cd my-app && npm start`. Optionally set a working directory. Commands run
  through your login shell, so Homebrew/nvm tools resolve automatically.
- **Manager window** with a list of connections and a **live, streaming log
  view** per connection. **⌘-click** URLs or file paths in the logs to open
  them (like Terminal.app).
- **Manual control** — connections start/stop only when you tell them to.
- **Persistent** — connections are saved to
  `~/Library/Application Support/Tunnelbar/connections.json`; per-connection
  logs go to `…/Tunnelbar/logs/<id>.log`.

## Install

### Download a build
Grab the latest `Tunnelbar-x.y.dmg` from the
[Releases](https://github.com/ayush-sharaf/tunnel-management/releases) page,
open it, and drag **Tunnelbar** into **Applications**. Because the app isn't
notarized by Apple, clear the download quarantine once:

```sh
xattr -dr com.apple.quarantine /Applications/Tunnelbar.app
```

See [INSTALL.md](INSTALL.md) for the full walkthrough.

### Build from source
Requires the Swift toolchain (Xcode **or** the Command Line Tools) and
`cloudflared` on your `PATH` if you use cloudflared connections.

```sh
git clone https://github.com/ayush-sharaf/tunnel-management.git
cd tunnel-management
./build.sh          # compiles and produces Tunnelbar.app
open Tunnelbar.app
```

To produce shareable artifacts (DMG + zip in `dist/`):

```sh
./package.sh
```

> Note: the build uses `swiftc` directly (see `build.sh`) rather than
> `swift build`, because SwiftPM's manifest API is broken in bare Command Line
> Tools installs without full Xcode. With full Xcode, `swift build` also works.

## Usage

1. Click the menu-bar icon → **Add Connection…** (or open the app to get the
   manager window).
2. Paste a command, optionally set a working directory and name.
3. Start/stop from the menu-bar submenu or the manager window.
4. **Show Logs…** to watch live output; ⌘-click links to open them.

## Requirements

- macOS 14 (Sonoma) or later, Apple Silicon.
- The CLI tools your commands use (`cloudflared`, `node`/`npm`, …) installed and
  on your `PATH`.

## Project layout

| File | Purpose |
|------|---------|
| `Sources/Tunnelbar/main.swift` | Entry point; starts as an accessory (menu-bar) app |
| `AppDelegate.swift` | Status-bar item, dynamic menu, manager window |
| `Models.swift` | `ConnectionConfig`, `TunnelStatus`, `LogLine` |
| `CommandParser.swift` | Tokenizes commands; suggests connection names |
| `Tunnel.swift` | Spawns/monitors the process, captures logs |
| `TunnelStore.swift` | Connection list & persistence |
| `Views.swift` | SwiftUI manager window, detail, logs, add/edit editor |

## Contributing

Issues and PRs welcome. Keep changes focused and match the surrounding code
style. There are no external dependencies — just Swift + AppKit/SwiftUI.

## License

[MIT](LICENSE) © 2026 Ayush Sharaf
