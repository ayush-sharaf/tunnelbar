import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Start as a menu-bar (accessory) app: no Dock icon until the window opens.
app.setActivationPolicy(.accessory)
app.run()
