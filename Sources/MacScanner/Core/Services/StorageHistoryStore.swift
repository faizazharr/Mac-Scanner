// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation

/// One point-in-time record of every Cleanup Recommendation candidate's
/// size, keyed by its filesystem path.
struct StorageSnapshot: Codable {
    let date: Date
    let sizesByPath: [String: Int64]
}

/// How much a specific cleanup target has grown since an earlier snapshot —
/// what actually answers "what activity keeps eating my disk space", as
/// opposed to "what's biggest right now" (which the plain size list already
/// shows, but says nothing about whether it's still growing).
struct StorageGrowthEntry: Identifiable {
    let id: String
    let title: String
    let deltaBytes: Int64
    let daysSpan: Double
}

/// Persists periodic size snapshots of the Cleanup Recommendations
/// candidates to disk, so growth can be tracked *across app launches* —
/// this is the one piece of state in the app that outlives a single
/// session, because "is this still growing" is meaningless within one.
///
/// Deliberately simple: a small JSON file, not a database. The data is
/// just a handful of path→byte-count numbers, capped at `maxSnapshots`
/// entries, so this can never itself become something worth cleaning up.
final class StorageHistoryStore {
    static let shared = StorageHistoryStore()

    private let maxSnapshots = 60
    /// Don't bother recording a new snapshot more often than this — rapid
    /// rescans within one sitting would otherwise fill the history with
    /// near-duplicate points that add noise, not signal.
    private let minSnapshotInterval: TimeInterval = 6 * 60 * 60 // 6 hours

    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let dir = appSupport.appendingPathComponent("MacScanner", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("storage-history.json")
    }

    /// Records a new snapshot from the current scan results, unless one was
    /// already taken too recently.
    func recordSnapshot(from results: [Recommendation]) {
        var history = load()
        if let last = history.last, Date().timeIntervalSince(last.date) < minSnapshotInterval {
            return
        }
        let sizes = Dictionary(uniqueKeysWithValues: results.filter(\.exists).map { ($0.path.path, $0.sizeBytes) })
        history.append(StorageSnapshot(date: Date(), sizesByPath: sizes))
        if history.count > maxSnapshots {
            history.removeFirst(history.count - maxSnapshots)
        }
        save(history)
    }

    /// Growth per candidate since the oldest snapshot still on file that's
    /// at least a day old — i.e. "since we started tracking, or the last
    /// day+, whichever is longer ago". Only positive growth is returned;
    /// something shrinking isn't "what's eating your disk".
    func growth(against results: [Recommendation]) -> [StorageGrowthEntry] {
        let history = load()
        guard let baseline = history.first(where: { Date().timeIntervalSince($0.date) >= 24 * 60 * 60 }) else {
            return []
        }
        let daysSpan = Date().timeIntervalSince(baseline.date) / (24 * 60 * 60)

        return results.compactMap { rec -> StorageGrowthEntry? in
            guard rec.exists, let previous = baseline.sizesByPath[rec.path.path] else { return nil }
            let delta = rec.sizeBytes - previous
            guard delta > 0 else { return nil }
            return StorageGrowthEntry(id: rec.path.path, title: rec.title, deltaBytes: delta, daysSpan: daysSpan)
        }
        .sorted { $0.deltaBytes > $1.deltaBytes }
    }

    // MARK: - Private

    private func load() -> [StorageSnapshot] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([StorageSnapshot].self, from: data)) ?? []
    }

    private func save(_ history: [StorageSnapshot]) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
