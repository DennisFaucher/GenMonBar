import AppKit
import SwiftUI

final class StatusBarController: NSObject {
    private struct Item {
        let widgetID: UUID
        let statusItem: NSStatusItem
        var timer: Timer?
        var lastResult: RunResult?
        var lastRun: Date?
    }

    private var items: [UUID: Item] = [:]
    private let store = ConfigStore.shared
    private var settingsWindow: NSWindow?

    func start() {
        store.onChange { [weak self] _ in self?.reconcile() }
        reconcile()
    }

    func reconcile() {
        let widgets = store.config.widgets.filter(\.enabled)

        for (id, item) in items where !widgets.contains(where: { $0.id == id }) {
            item.timer?.invalidate()
            StatusItemCenter.shared.remove(item.statusItem)
            items[id] = nil
        }

        for widget in widgets {
            if var existing = items[widget.id] {
                existing.timer?.invalidate()
                existing.timer = makeTimer(for: widget)
                items[widget.id] = existing
                refresh(widget)
            } else {
                let statusItem = StatusItemCenter.shared.add()
                if let button = statusItem.button {
                    button.title = title(for: widget, text: "…")
                    button.font = NSFont.menuBarFont(ofSize: 0)
                }
                statusItem.menu = makeMenu(for: widget)
                var item = Item(widgetID: widget.id, statusItem: statusItem, timer: nil, lastResult: nil, lastRun: nil)
                item.timer = makeTimer(for: widget)
                items[widget.id] = item
                refresh(widget)
            }
        }
    }

    private func makeTimer(for widget: Widget) -> Timer {
        let interval = max(widget.interval, 1)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh(widget)
        }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private func refresh(_ widget: Widget) {
        guard let item = items[widget.id] else { return }
        if let button = item.statusItem.button, item.lastResult == nil {
            button.title = title(for: widget, text: "…")
        }
        WidgetRunner.run(widget.command) { [weak self] result in
            guard let self, var current = self.items[widget.id] else { return }
            current.lastResult = result
            current.lastRun = Date()
            self.items[widget.id] = current
            if let button = current.statusItem.button {
                button.title = self.title(for: widget, text: WidgetRunner.displayText(for: result))
                button.toolTip = self.tooltip(for: widget, result: result)
            }
            current.statusItem.menu = self.makeMenu(for: widget)
        }
    }

    /// "emoji text" — or just "text" when the emoji field is blank.
    private func title(for widget: Widget, text: String) -> String {
        let emoji = widget.emoji.trimmingCharacters(in: .whitespaces)
        return emoji.isEmpty ? text : "\(emoji) \(text)"
    }

    private func tooltip(for widget: Widget, result: RunResult) -> String {
        var lines = [widget.command, "Last run: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))"]
        let out = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !out.isEmpty { lines.append(contentsOf: ["", out]) }
        if let error = result.error { lines.append(contentsOf: ["", "Error: \(error)"]) }
        return lines.joined(separator: "\n")
    }

    private func makeMenu(for widget: Widget) -> NSMenu {
        let menu = NSMenu()

        let header = NSMenuItem(title: widget.name, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        if let result = items[widget.id]?.lastResult {
            let out = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            let preview = out.isEmpty ? "(no output)" : String(out.prefix(120))
            let previewItem = NSMenuItem(title: preview, action: nil, keyEquivalent: "")
            previewItem.isEnabled = false
            menu.addItem(previewItem)
        }

        menu.addItem(.separator())

        let runNow = NSMenuItem(title: "Run Now", action: #selector(runNow(_:)), keyEquivalent: "r")
        runNow.target = self
        runNow.representedObject = widget.id
        menu.addItem(runNow)

        let copy = NSMenuItem(title: "Copy Output", action: #selector(copyOutput(_:)), keyEquivalent: "c")
        copy.target = self
        copy.representedObject = widget.id
        menu.addItem(copy)

        menu.addItem(.separator())

        let edit = NSMenuItem(title: "Edit Widgets…", action: #selector(editWidgets), keyEquivalent: ",")
        edit.target = self
        menu.addItem(edit)

        let quit = NSMenuItem(title: "Quit GenMonBar", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func runNow(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let widget = store.config.widgets.first(where: { $0.id == id }) else { return }
        refresh(widget)
    }

    @objc private func copyOutput(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let result = items[id]?.lastResult else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result.output, forType: .string)
    }

    @objc private func editWidgets() {
        if settingsWindow == nil {
            let view = SettingsView()
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "GenMonBar Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.collectionBehavior.insert(.fullScreenAuxiliary)
            window.setContentSize(NSSize(width: 560, height: 420))
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.orderFrontRegardless()
        settingsWindow?.makeKeyAndOrderFront(nil)
        // Activation of an LSUIElement app is async; re-assert key status next runloop tick.
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.settingsWindow else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

/// Owns the extra status items (one per widget) in the space right of the system items.
final class StatusItemCenter {
    static let shared = StatusItemCenter()
    private var items: [NSStatusItem] = []

    func add() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        items.append(item)
        return item
    }

    func remove(_ item: NSStatusItem) {
        NSStatusBar.system.removeStatusItem(item)
        items.removeAll { $0 === item }
    }
}
