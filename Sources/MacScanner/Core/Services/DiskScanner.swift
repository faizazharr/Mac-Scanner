// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation

/// All filesystem-scanning primitives with genuinely zero-subprocess sizing
/// (files *and* directories) and thread-safe in-memory caching.
enum DiskScanner {
    private static var sizeCache: [String: (size: Int64, timestamp: Date)] = [:]
    private static let sizeCacheLock = NSLock()
    /// A stale entry was previously only *ignored* on read, never removed —
    /// every distinct directory path sized in a session (Folder Browser,
    /// Recommendations, App Uninstaller's ~370 candidate paths, Screening,
    /// Designer & Browsers) stayed in the dictionary forever. Pruned back to
    /// `maxCacheEntries` once the count exceeds `pruneTriggerEntries`.
    ///
    /// The gap between the two matters: pruning sorts every entry by
    /// timestamp, which isn't free. Triggering it right at the cap (prune to
    /// 1000, next insert hits 1001, prune again) means paying that sort cost
    /// on nearly *every single call* once the cache is full — with several
    /// scanners hammering this cache concurrently (App Uninstaller, Screening,
    /// Folder Browser, Recommendations all funnel through the same lock),
    /// that showed up as real, sustained multi-core CPU burn. A 300-entry
    /// buffer means the sort only happens once per ~300 insertions instead
    /// of once per insertion.
    private static let maxCacheEntries = 1000
    private static let pruneTriggerEntries = 1300

    /// How long a directory's size stays cached before a rescan recomputes
    /// it. Bumped from 30s: now that sizing doesn't spawn `du`, a rescan is
    /// far cheaper than it used to be, but there's still no reason to redo
    /// a multi-hundred-thousand-file walk (e.g. a big node_modules tree)
    /// more often than roughly "once a minute" — directory sizes don't
    /// change that fast in practice, and this is what "Rescan" is for.
    private static let cacheTTL: TimeInterval = 60.0

    /// Size of a single path in bytes. Zero subprocess spawns for either
    /// files or directories — see https://github.com/faizazharr/Mac-Scanner/issues/1.
    /// Files use an instantaneous kernel stat. Directories are walked
    /// in-process via `FileManager.enumerator`, which was previously done by
    /// spawning `nice du -sk` per directory. That scaled badly: the App
    /// Uninstaller tab alone could spawn 50+ `du` processes serially for a
    /// machine with ~30 apps installed, visibly saturating I/O on 8GB
    /// hardware — and `nice` only lowers CPU scheduling priority, which does
    /// nothing for a process that's I/O-bound, not CPU-bound. Walking
    /// in-process instead means the work happens on *our* thread, so its
    /// QoS (see `scanChildren`'s `.utility` queue) genuinely throttles disk
    /// I/O scheduling — something `nice` on a spawned child process can't do.
    static func size(of url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            // Instant 0ms stat lookup for files.
            if let values = try? url.resourceValues(forKeys: [.fileAllocatedSizeKey, .fileSizeKey]) {
                if let allocated = values.fileAllocatedSize { return Int64(allocated) }
                if let size = values.fileSize { return Int64(size) }
            }
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                return size
            }
            return 0
        }

        let path = url.path
        let now = Date()

        sizeCacheLock.lock()
        if let cached = sizeCache[path], now.timeIntervalSince(cached.timestamp) < cacheTTL {
            sizeCacheLock.unlock()
            return cached.size
        }
        sizeCacheLock.unlock()

        let bytes = directorySize(at: url)

        sizeCacheLock.lock()
        sizeCache[path] = (bytes, now)
        if sizeCache.count > pruneTriggerEntries {
            let expiredCutoff = now.addingTimeInterval(-cacheTTL)
            sizeCache = sizeCache.filter { $0.value.timestamp > expiredCutoff }
            if sizeCache.count > maxCacheEntries {
                let oldestFirst = sizeCache.sorted { $0.value.timestamp < $1.value.timestamp }
                for (staleKey, _) in oldestFirst.prefix(sizeCache.count - maxCacheEntries) {
                    sizeCache.removeValue(forKey: staleKey)
                }
            }
        }
        sizeCacheLock.unlock()

        return bytes
    }

    /// Recursively sums allocated size in-process — no `du` spawn. Skips
    /// summing directory entries themselves (their own on-disk footprint is
    /// a handful of KB, negligible next to their contents) but deliberately
    /// does *not* skip hidden files: on macOS `~/Library` carries the
    /// UF_HIDDEN flag (not a dot-prefix), and it's usually the single
    /// biggest space consumer — an enumerator that skips hidden items would
    /// silently zero it out.
    private static func directorySize(at url: URL) -> Int64 {
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .fileAllocatedSizeKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [],
            errorHandler: { _, _ in true } // keep going past permission-denied subitems
        ) else { return 0 }

        var total: Int64 = 0
        for case let itemURL as URL in enumerator {
            guard let values = try? itemURL.resourceValues(forKeys: Set(resourceKeys)),
                  values.isDirectory != true else { continue }
            if let allocated = values.fileAllocatedSize {
                total += Int64(allocated)
            } else if let size = values.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    /// Clears the size cache (e.g. after a clean action).
    static func invalidateCache() {
        sizeCacheLock.lock()
        sizeCache.removeAll()
        sizeCacheLock.unlock()
    }

    /// Scans the immediate children of `directory`, computing each child's total size concurrently.
    static func scanChildren(of directory: URL, progress: @escaping (FileEntry) -> Void, completion: @escaping ([FileEntry]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            guard let children = try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .fileAllocatedSizeKey, .fileSizeKey],
                options: []
            ) else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            var results: [FileEntry] = []
            let lock = NSLock()
            let group = DispatchGroup()
            let semaphore = DispatchSemaphore(value: 8)

            for child in children {
                let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

                if !isDir {
                    // Regular file: Instant 0ms calculation on current thread
                    let bytes = size(of: child)
                    let entry = FileEntry(url: child, sizeBytes: bytes, isDirectory: false)
                    lock.lock()
                    results.append(entry)
                    lock.unlock()
                    DispatchQueue.main.async { progress(entry) }
                } else {
                    // Directory: Process concurrently with bounded semaphore
                    group.enter()
                    semaphore.wait()
                    DispatchQueue.global(qos: .utility).async {
                        defer {
                            semaphore.signal()
                            group.leave()
                        }
                        let bytes = size(of: child)
                        let entry = FileEntry(url: child, sizeBytes: bytes, isDirectory: true)

                        lock.lock()
                        results.append(entry)
                        lock.unlock()

                        DispatchQueue.main.async { progress(entry) }
                    }
                }
            }

            group.wait()
            let sorted = results.sorted { $0.sizeBytes > $1.sizeBytes }
            DispatchQueue.main.async { completion(sorted) }
        }
    }

    /// Volume total/free space for the volume containing `url`.
    static func volumeInfo(for url: URL) -> (total: Int64, free: Int64)? {
        guard let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]),
              let total = values.volumeTotalCapacity else { return nil }
        let free = values.volumeAvailableCapacityForImportantUsage ?? 0
        return (Int64(total), free)
    }

    /// Finds files at or above `minMB` under `root`, using instant Spotlight indexing with fallback.
    static func findLargeFiles(root: URL, minMB: Int, exclude: [URL] = [], limit: Int = 300, completion: @escaping ([FileEntry]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let minBytes = Int64(minMB) * 1024 * 1024
            let excludePaths = exclude.map { $0.path }

            // 1. Primary: Instant Spotlight metadata search (< 0.2s)
            let mdArgs = ["-onlyin", root.path, "kMDItemFSSize >= \(minBytes)"]
            let mdOutput = Shell.runNiced("/usr/bin/mdfind", mdArgs)

            var entries: [FileEntry] = []
            let fm = FileManager.default
            let lines = mdOutput.split(separator: "\n")

            if !lines.isEmpty {
                for line in lines {
                    let path = String(line)
                    if excludePaths.contains(where: { path.hasPrefix($0) }) { continue }
                    let url = URL(fileURLWithPath: path)
                    guard let attrs = try? fm.attributesOfItem(atPath: path),
                          let size = attrs[.size] as? Int64,
                          size >= minBytes else { continue }
                    entries.append(FileEntry(url: url, sizeBytes: size, isDirectory: false))
                }
            }

            // 2. Fallback: Unix find if Spotlight is disabled on target path
            if entries.isEmpty {
                var findArgs = [root.path, "-type", "f", "-size", "+\(minMB)M"]
                for ex in exclude {
                    findArgs += ["-not", "-path", ex.path + "/*"]
                }
                let findOutput = Shell.runNiced("/usr/bin/find", findArgs)
                for line in findOutput.split(separator: "\n").prefix(limit * 2) {
                    let path = String(line)
                    let url = URL(fileURLWithPath: path)
                    guard let attrs = try? fm.attributesOfItem(atPath: path),
                          let size = attrs[.size] as? Int64 else { continue }
                    entries.append(FileEntry(url: url, sizeBytes: size, isDirectory: false))
                }
            }

            entries.sort { $0.sizeBytes > $1.sizeBytes }
            let top = Array(entries.prefix(limit))
            DispatchQueue.main.async { completion(top) }
        }
    }
}
