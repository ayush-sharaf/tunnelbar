# Installing Tunnelnest

Tunnelnest is a native macOS menu-bar app. It is **open-source and not notarized
by Apple** (no paid developer account), so a downloaded copy carries macOS's
"quarantine" flag and Gatekeeper would normally block it. Every install method
below handles that for you — pick one.

- **Requirements:** macOS 14 (Sonoma) or later, Apple Silicon.
- Tunnelnest runs whatever commands you give it, so the CLI tools those commands
  use (e.g. `cloudflared`, `node`/`npm`, `ngrok`) must be installed and on your
  `PATH`. If one isn't, Tunnelnest tells you which tool to install.

---

## Option 1 — One-line install (recommended)

Paste this into **Terminal** and press Return:

```sh
curl -fsSL https://tunnelnest.vercel.app/install.sh | bash
```

It downloads the latest release, installs **Tunnelnest.app** into
`/Applications`, removes the Gatekeeper quarantine flag, and launches it — no
prompts. The menu-bar icon (⫶ connected dots) appears at the top-right.

> Don't want to pipe to `bash`? The same script lives in the repo — read it
> first, then run it:
> ```sh
> curl -fsSL https://raw.githubusercontent.com/ayush-sharaf/tunnelnest/main/website/install.sh -o install.sh
> less install.sh        # review
> bash install.sh
> ```

---

## Option 2 — Download the DMG manually

1. Open the [latest release](https://github.com/ayush-sharaf/tunnelnest/releases/latest)
   and download **`Tunnelnest-x.y.dmg`**.
2. Open the DMG and drag **Tunnelnest** onto the **Applications** shortcut.
3. Clear the quarantine flag once (required — the app isn't notarized):
   ```sh
   xattr -dr com.apple.quarantine /Applications/Tunnelnest.app
   ```
   > On macOS 15+ the old "right-click → Open" bypass no longer works, so this
   > command is the reliable way. It only removes the download marker.
4. Open **Tunnelnest** from Applications.

---

## Option 3 — Build from source

Requires the Swift toolchain (**Xcode** or the **Command Line Tools**:
`xcode-select --install`). Locally built apps aren't quarantined, so there's no
Gatekeeper step.

```sh
git clone https://github.com/ayush-sharaf/tunnelnest.git
cd tunnelnest
./build.sh          # produces Tunnelnest.app
open Tunnelnest.app
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the dev workflow.

---

## First run

1. Click the menu-bar icon → **Add Connection…** (or open the app for the
   manager window).
2. Paste a command, e.g.
   `cloudflared access tcp --hostname tunnel.example.com/postgres --url localhost:5432`
   or `cd my-app && npm run dev`. Optionally set a working directory.
3. Start it from the menu-bar submenu or the manager window. **Show Logs…**
   streams output; ⌘-click URLs/paths to open them.
4. *(Optional)* Settings → **Open Tunnelnest at login** to launch automatically.

---

## Updating

- **Installed via Option 1:** re-run the same `curl … | bash` command — it always
  fetches the latest release.
- **Installed via DMG:** download the newer DMG and repeat Option 2.
- Either way, **Settings → Check for Updates** (or "Check on launch") tells you
  when a new version is out.

Your connections and settings are preserved across updates. You can also back
them up from **Settings → Connections → Export**.

---

## Uninstalling

```sh
# Quit Tunnelnest first (menu-bar icon → Quit), then:
rm -rf "/Applications/Tunnelnest.app"
rm -rf "$HOME/Library/Application Support/Tunnelnest"   # connections + logs
defaults delete io.github.ayush-sharaf.tunnelnest 2>/dev/null || true
```

---

## Troubleshooting

- **"Tunnelnest is damaged and can't be opened"** — the quarantine flag is still
  set (only happens with a manual DMG install where step 3 was skipped). Run:
  `xattr -dr com.apple.quarantine /Applications/Tunnelnest.app`
- **Nothing opens / no window** — it's a menu-bar app; look at the top-right of
  the screen for the icon. Opening it from Spotlight/Finder shows the window.
- **A connection fails with "'X' not found"** — the command needs a tool that
  isn't installed or isn't on your `PATH`. Install it (e.g. `brew install X`)
  and start the connection again.
- **"port N in use"** — another process is already bound to that port.
  Tunnelnest reclaims its own leftovers automatically; if it's a different
  process, stop it or change the port.
- **See launch output** — run the binary directly:
  `/Applications/Tunnelnest.app/Contents/MacOS/Tunnelnest`
