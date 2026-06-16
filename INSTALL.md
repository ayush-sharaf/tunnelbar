# Installing Tunnel Manager

Tunnel Manager is an internal tool that is **not signed by Apple** (no paid
Apple Developer account), so macOS Gatekeeper needs a one-time nudge to trust
it. This is normal for in-house apps. Total time: ~30 seconds.

## Steps

1. **Open the DMG** (`TunnelManager-1.0.dmg`) you were sent, then drag
   **Tunnel Manager** onto the **Applications** shortcut.
   *(If you got a `.zip` instead, double-click it and move `TunnelManager.app`
   into your `Applications` folder.)*

2. **Clear the quarantine flag.** Open **Terminal** (⌘-Space → "Terminal") and
   paste this exact line, then press Return:

   ```sh
   xattr -dr com.apple.quarantine /Applications/TunnelManager.app
   ```

   > On macOS 15+ (Sequoia/Tahoe) the old "right-click → Open" trick no longer
   > works, so this command is the reliable way. It only removes the
   > download-quarantine marker — it doesn't change anything else.

3. **Launch it.** Double-click **Tunnel Manager** in Applications. A small
   menu-bar icon (⫶ connected dots) appears in the top-right of your screen —
   that's the app. There is no Dock icon by default.

4. *(Optional)* **Launch at login:** System Settings → General → **Login
   Items** → **＋** → add Tunnel Manager.

## Requirements

- macOS 14 or later (Apple Silicon).
- Whatever CLI tools your commands use must be installed and on your `PATH`
  (e.g. `cloudflared`, `node`/`npm`). Commands run through your login shell, so
  Homebrew tools are picked up automatically.

## Using it

- Click the menu-bar icon → **Add Connection…**
- Paste a command, e.g.
  `cloudflared access tcp --hostname tunnel-int.softwareartistry.com/postgre18 --url localhost:2346`
  or `cd test-app && npm start`. Optionally set a working directory.
- Start/stop each connection from the menu-bar submenu or the manager window.
- Open **Show Logs…** to watch live output; **⌘-click** URLs or file paths in
  the logs to open them.

## Troubleshooting

- **"TunnelManager is damaged and can't be opened"** — you skipped step 2. Run
  the `xattr` command above.
- **App quits immediately / nothing appears** — check the menu bar (it's a
  menu-bar app, not a window app). If still failing, run it from Terminal to see
  output: `/Applications/TunnelManager.app/Contents/MacOS/TunnelManager`.
