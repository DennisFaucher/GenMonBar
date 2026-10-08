import Foundation

struct Widget: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var emoji: String
    var command: String
    var interval: TimeInterval = 60
    var enabled: Bool = true

    var name: String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "(no command)" : trimmed
    }
}

struct Config: Codable, Equatable {
    var widgets: [Widget] = []

    static let defaultConfig = Config(widgets: [
        Widget(emoji: "🍺", command: "brew outdated --greedy | wc -l | tr -d ' '", interval: 3600)
    ])
}

final class ConfigStore {
    static let shared = ConfigStore()

    let configURL: URL
    private(set) var config: Config
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var lastWriteDate: Date?
    private var observers: [(Config) -> Void] = []

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("GenMonBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        configURL = dir.appendingPathComponent("config.json")

        if let data = try? Data(contentsOf: configURL),
           let decoded = try? JSONDecoder().decode(Config.self, from: data) {
            config = decoded
        } else {
            config = Config.defaultConfig
            save()
        }
        startWatching()
    }

    func onChange(_ handler: @escaping (Config) -> Void) {
        observers.append(handler)
    }

    func update(_ transform: (inout Config) -> Void) {
        transform(&config)
        save()
        notify()
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        lastWriteDate = Date()
        try? data.write(to: configURL, options: .atomic)
    }

    private func reloadIfChanged() {
        guard let data = try? Data(contentsOf: configURL),
              let decoded = try? JSONDecoder().decode(Config.self, from: data),
              decoded != config else { return }
        if let lastWriteDate, Date().timeIntervalSince(lastWriteDate) < 1.0 { return }
        config = decoded
        notify()
    }

    private func notify() {
        let snapshot = config
        observers.forEach { $0(snapshot) }
    }

    private func startWatching() {
        fileWatcher?.cancel()
        fileWatcher = nil
        let fd = open(configURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            // Editors replace the file (rename), which invalidates the fd — always re-arm.
            self.startWatching()
            self.reloadIfChanged()
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        fileWatcher = source
    }
}
