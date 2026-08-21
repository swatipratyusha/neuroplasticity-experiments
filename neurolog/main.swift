// NeuroLog — menu bar quick logger for the study.
// One-tap presets + free-text notes, appended as ts,"raw" to data/events.csv.
// This is the self-initiated stream: things you notice, kept separate from the
// probe's randomly-timed sampling so the two can be analysed independently.
import AppKit

// launchd starts us through `open -a`, which passes no environment, so the
// data root arrives as the first launch argument; env and the default are the
// fallbacks for a hand-started app.
func resolveNeuroHome() -> URL {
    let args = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") }
    if let path = args.first ?? ProcessInfo.processInfo.environment["NEURO_HOME"] {
        return URL(fileURLWithPath: path)
    }
    return FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/neuroplasticity")
}
let neuroHome = resolveNeuroHome()
let eventsFile = neuroHome.appendingPathComponent("data/events.csv")

// Returns false when the event did not reach disk. The caller must not claim
// success it did not get: a logger that confirms every tap while silently
// dropping rows is worse than one that visibly fails.
@discardableResult
func appendEvent(_ text: String) -> Bool {
    let ts = ISO8601DateFormatter.string(from: Date(), timeZone: .current,
                                         formatOptions: [.withFullDate, .withTime, .withColonSeparatorInTime])
    let row = "\(ts),\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\"\n"
    do {
        if !FileManager.default.fileExists(atPath: eventsFile.path) {
            try FileManager.default.createDirectory(at: eventsFile.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try "ts,raw\n".write(to: eventsFile, atomically: true, encoding: .utf8)
        }
        let handle = try FileHandle(forWritingTo: eventsFile)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(row.utf8))
        return true
    } catch {
        NSLog("NeuroLog: could not append to \(eventsFile.path): \(error)")
        return false
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    // Edit freely — these are the events worth one tap rather than a sentence.
    let presets = [
        "Interrupted — person talking",
        "Interrupted — notification / chat",
        "Interrupted — call / meeting",
        "Focus dipping",
        "Overloaded — too many threads",
        "Entering deep focus",
        "Back from break",
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        showIcon()
        let menu = NSMenu()
        for preset in presets {
            let item = NSMenuItem(title: preset, action: #selector(logPreset(_:)), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let custom = NSMenuItem(title: "Custom note…", action: #selector(logCustom), keyEquivalent: "n")
        custom.target = self
        menu.addItem(custom)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NeuroLog",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        statusItem.menu = menu
    }

    @objc func logPreset(_ sender: NSMenuItem) {
        flash(appendEvent(sender.title))
    }

    @objc func logCustom() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Log a note"
        alert.informativeText = "What just happened / how is focus?"
        alert.addButton(withTitle: "Log")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty {
            flash(appendEvent(field.stringValue))
        }
    }

    // MenuIcon.png is 36px tall and drawn for exactly this size; asking for 18pt
    // renders it 1:1 on a Retina menu bar. Scaling any larger artwork down to
    // here turns it to mush — see neurolog/make_icon.py.
    func showIcon() {
        guard let url = Bundle.main.url(forResource: "MenuIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            statusItem.button?.title = "🧠"        // never leave the menu bar blank
            return
        }
        let height: CGFloat = 18
        image.size = NSSize(width: image.size.width * height / image.size.height, height: height)
        image.isTemplate = true                    // macOS tints it for light and dark bars
        statusItem.button?.image = image
        statusItem.button?.title = ""
    }

    func flash(_ ok: Bool) {
        statusItem.button?.image = nil
        statusItem.button?.title = ok ? "✅" : "⚠️"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.statusItem.button?.title = ""
            self.showIcon()
        }
    }
}

// Held for the app's lifetime: exempts us from App Nap so the menu opens
// instantly even after hours of idling.
let activity = ProcessInfo.processInfo.beginActivity(
    options: [.userInitiatedAllowingIdleSystemSleep],
    reason: "menu bar must respond instantly")

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
