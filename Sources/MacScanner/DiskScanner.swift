// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation

/// All filesystem-scanning primitives with Zero-Subprocess file sizing and
/// thread-safe in-memory caching for directories.
enum DiskScanner {
    private static var sizeCache: [String: (size: Int64, timestamp: Date)] = [:]
    private static let sizeCacheLock = NSLock()

    /// Size of a single path in bytes.
    /// Regular files use instantaneous kernel stat (0 subprocesses).
    /// Directories use `du` with 30s TTL in-memory caching.
    static func size(of url: URL) -> Int64 {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue {
            // Instant 0ms stat lookup for files
            if let values = try? url.resourceValues(forKeys: [.fileAllocatedSizeKey, .fileSizeKey]) {
                if let allocated = values.fileAllocatedSize { return Int64(allocated) }
                if let size = values.fileSize { return Int64(size) }
            }
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                return size
            }
        }

        // For directories: use cached du
        let path = url.path
        let now = Date()

        sizeCacheLock.lock()
        if let cached = sizeCache[path], now.timeIntervalSince(cached.timestamp) < 30.0 {
            sizeCacheLock.unlock()
            return cached.size
        }
        sizeCacheLock.unlock()

        let output = Shell.runNiced("/usr/bin/du", ["-sk", path])
        let kb = output
            .split(separator: "\t")
            .first
            .flatMap { Int64($0) } ?? 0
        let bytes = kb * 1024

        sizeCacheLock.lock()
        sizeCache[path] = (bytes, now)
        sizeCacheLock.unlock()

        return bytes
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

    /// Finds files at or above `minBytes` under `root`, skipping the given subpaths.
    static func findLargeFiles(root: URL, minMB: Int, exclude: [URL], limit: Int = 200, completion: @escaping ([FileEntry]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var args = [root.path, "-type", "f", "-size", "+\(minMB)M"]
            for ex in exclude {
                args += ["-not", "-path", ex.path + "/*"]
            }
            let output = Shell.runNiced("/usr/bin/find", args)

            var entries: [FileEntry] = []
            let fm = FileManager.default
            for line in output.split(separator: "\n").prefix(limit * 4) {
                let path = String(line)
                let url = URL(fileURLWithPath: path)
                guard let attrs = try? fm.attributesOfItem(atPath: path),
                      let size = attrs[.size] as? Int64 else { continue }
                entries.append(FileEntry(url: url, sizeBytes: size, isDirectory: false))
            }

            entries.sort { $0.sizeBytes > $1.sizeBytes }
            let top = Array(entries.prefix(limit))
            DispatchQueue.main.async { completion(top) }
        }
    }
}
