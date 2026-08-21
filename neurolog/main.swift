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

func appendEvent(_ text: String) {
    let ts = ISO8601DateFormatter.string(from: Date(), timeZone: .current,
                                         formatOptions: [.withFullDate, .withTime, .withColonSeparatorInTime])
    let row = "\(ts),\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\"\n"
    if !FileManager.default.fileExists(atPath: eventsFile.path) {
        try? FileManager.default.createDirectory(at: eventsFile.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? "ts,raw\n".write(to: eventsFile, atomically: true, encoding: .utf8)
    }
    if let handle = try? FileHandle(forWritingTo: eventsFile) {
        handle.seekToEndOfFile()
        handle.write(row.data(using: .utf8)!)
        try? handle.close()
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
        statusItem.button?.title = "🧠"
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
        appendEvent(sender.title)
        flashConfirmation()
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
            appendEvent(field.stringValue)
            flashConfirmation()
        }
    }

    func flashConfirmation() {
        statusItem.button?.title = "✅"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.statusItem.button?.title = "🧠"
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
