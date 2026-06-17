# Installing Tunnelbar

Tunnelbar is **not signed by Apple** (no paid Apple Developer account), so
macOS Gatekeeper needs a one-time nudge to trust it. This is normal for
open-source / in-house apps. Total time: ~30 seconds.

## Steps

1. **Open the DMG** (`Tunnelbar-1.0.dmg`), then drag **Tunnelbar** onto the
   **Applications** shortcut.
   *(If you got a `.zip` instead, double-click it and move `Tunnelbar.app` into
   your `Applications` folder.)*

2. **Clear the quarantine flag.** Open **Terminal** (⌘-Space → "Terminal") and
   paste this exact line, then press Return:

   ```sh
   xattr -dr com.apple.quarantine /Applications/Tunnelbar.app
   ```

   > On macOS 15+ (Sequoia/Tahoe) the old "right-click → Open" trick no longer
   > works, so this command is the reliable way. It only removes the
   > download-quarantine marker — it doesn't change anything else.

3. **Launch it.** Double-click **Tunnelbar** in Applications. The manager window
   opens, and a small menu-bar icon (⫶ connected dots) appears in the top-right
   of your screen. There is no Dock icon by default.

4. *(Optional)* **Launch at login:** System Settings → General → **Login
   Items** → **＋** → add Tunnelbar.

## Requirements

- macOS 14 or later (Apple Silicon).
- Whatever CLI tools your commands use must be installed and on your `PATH`
  (e.g. `cloudflared`, `node`/`npm`). Commands run through your login shell, so
  Homebrew tools are picked up automatically.

## Using it

- Click the menu-bar icon → **Add Connection…** (or just open the app).
- Paste a command, e.g.
  `cloudflared access tcp --hostname tunnel-int.example.com/postgres --url localhost:2346`
  or `cd my-app && npm start`. Optionally set a working directory.
- Start/stop each connection from the menu-bar submenu or the manager window.
- Open **Show Logs…** to watch live output; **⌘-click** URLs or file paths in
  the logs to open them.

## Troubleshooting

- **"Tunnelbar is damaged and can't be opened"** — you skipped step 2. Run the
  `xattr` command above.
- **Nothing appears** — check the menu bar (it's a menu-bar app). To see launch
  output, run it from Terminal:
  `/Applications/Tunnelbar.app/Contents/MacOS/Tunnelbar`.
