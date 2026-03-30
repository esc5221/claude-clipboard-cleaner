import AppKit
import ServiceManagement

// MARK: - Clipboard Cleaner

class ClipboardCleaner: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var lastChangeCount = 0
    private var isEnabled = true
    private var cleanCount = 0

    private var statsItem: NSMenuItem!
    private var toggleItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        startMonitoring()
    }

    // MARK: - Menu Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "scissors", accessibilityDescription: "Claude Clipboard Cleaner") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "✂"
            }
        }

        let menu = NSMenu()

        toggleItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled(_:)), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = .on
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        statsItem = NSMenuItem(title: "Cleaned: 0", action: nil, keyEquivalent: "")
        statsItem.isEnabled = false
        menu.addItem(statsItem)

        menu.addItem(NSMenuItem.separator())

        if #available(macOS 13.0, *) {
            launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
            launchAtLoginItem.target = self
            launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
            menu.addItem(launchAtLoginItem)
            menu.addItem(NSMenuItem.separator())
        }

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Clipboard Monitoring

    private func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    private func checkClipboard() {
        guard isEnabled else { return }

        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        // Uses cleanClaudeOutput() from CleanLogic.swift
        guard let text = pb.string(forType: .string),
              let cleaned = cleanClaudeOutput(text) else { return }

        pb.clearContents()
        pb.setString(cleaned, forType: .string)
        lastChangeCount = pb.changeCount

        cleanCount += 1
        statsItem.title = "Cleaned: \(cleanCount)"
        flashIcon()
    }

    // MARK: - UI Feedback

    private func flashIcon() {
        guard let button = statusItem.button else { return }
        let original = button.image
        if let check = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil) {
            check.isTemplate = true
            button.image = check
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            button.image = original
        }
    }

    // MARK: - Actions

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        isEnabled.toggle()
        sender.state = isEnabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    sender.state = .off
                } else {
                    try SMAppService.mainApp.register()
                    sender.state = .on
                }
            } catch {
                // silently fail
            }
        }
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = ClipboardCleaner()
app.delegate = delegate
app.run()
