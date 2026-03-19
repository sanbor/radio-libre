import Foundation

actor HistoryService {
    static let shared = HistoryService()

    private let maxEntries = 50
    private let dedupWindowSeconds: TimeInterval = 30 * 60 // 30 minutes
    private let userDefaultsKey = "libreradio.history"
    private let defaults: UserDefaults

    private var entries: [HistoryEntry] = []
    private var loaded = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public API

    func recordPlay(station: StationDTO) {
        loadIfNeeded()

        let now = Date()

        // Dedup: if same station played within 30 minutes, update timestamp
        if let index = entries.firstIndex(where: { $0.stationuuid == station.stationuuid }),
           now.timeIntervalSince(entries[index].playedAt) < dedupWindowSeconds {
            entries[index].playedAt = now
            // Move to front
            let entry = entries.remove(at: index)
            entries.insert(entry, at: 0)
        } else {
            let entry = HistoryEntry(from: station)
            entries.insert(entry, at: 0)
        }

        // Enforce max entries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        save()
    }

    func recentEntries(limit: Int = 10) -> [HistoryEntry] {
        loadIfNeeded()
        return Array(entries.prefix(limit))
    }

    func allEntries() -> [HistoryEntry] {
        loadIfNeeded()
        return entries
    }

    func clearAll() {
        entries = []
        save()
    }

    /// For testing
    func setEntries(_ newEntries: [HistoryEntry]) {
        entries = newEntries
        loaded = true
        save()
    }

    // MARK: - Persistence

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true

        guard let data = defaults.data(forKey: userDefaultsKey) else { return }
        do {
            entries = try JSONDecoder().decode([HistoryEntry].self, from: data)
        } catch {
            entries = []
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: userDefaultsKey)
    }
}
