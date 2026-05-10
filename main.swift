import AppKit
import SwiftUI

let app = NSApplication.shared
let delegate = MirrorImageApp()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
