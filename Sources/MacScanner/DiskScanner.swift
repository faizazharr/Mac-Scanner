// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation

/// All filesystem-scanning primitives, backed by `du`/`find` shelled out via
/// `Process` rather than a manual recursive walk — `du` is APFS-clone aware
/// (won't double-count cloned files) and, for directories with millions of
/// small files (Docker/Xcode caches), dramatically faster than doing the
/// stat() calls ourselves in Swift.
enum DiskScanner {
    /// Size of a single path in bytes, using `du` (fast, APFS-clone aware).
    /// Mildly niced so it doesn't fight the UI thread, but not throttled hard —
    /// the earlier sluggishness was a runaway loop elsewhere, not `du` itself.
    static func size(of url: URL) -> Int64 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nice")
        process.arguments = ["-n", "3", "/usr/bin/du", "-sk", url.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return 0
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let output = String(data: data, encoding: .utf8) else { return 0 }
        let kb = output
            .split(separator: "\t")
            .first
            .flatMap { Int64($0) } ?? 0
        return kb * 1024
    }

    /// Scans the immediate children of `directory`, computing each child's total size concurrently.
    static func scanChildren(of directory: URL, progress: @escaping (FileEntry) -> Void, completion: @escaping ([FileEntry]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            // Note: do NOT use .skipsHiddenFiles — on macOS ~/Library carries the
            // UF_HIDDEN flag (not a dot-prefix), and it's usually the single
            // biggest space consumer. Skipping it would defeat the whole point.
            guard let children = try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            ) else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            var results: [FileEntry] = []
            let lock = NSLock()
            let group = DispatchGroup()
            let semaphore = DispatchSemaphore(value: 8) // concurrent `du` processes — most finish in well under a second, so this is what actually determines how fast a folder shows up

            for child in children {
                group.enter()
                semaphore.wait()
                DispatchQueue.global(qos: .userInitiated).async {
                    defer {
                        semaphore.signal()
                        group.leave()
                    }
                    let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    let bytes = size(of: child)
                    let entry = FileEntry(url: child, sizeBytes: bytes, isDirectory: isDir)

                    lock.lock()
                    results.append(entry)
                    lock.unlock()

                    DispatchQueue.main.async { progress(entry) }
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
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/nice")
            var args = ["-n", "3", "/usr/bin/find", root.path, "-type", "f", "-size", "+\(minMB)M"]
            for ex in exclude {
                args += ["-not", "-path", ex.path + "/*"]
            }
            process.arguments = args

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            var entries: [FileEntry] = []
            do {
                try process.run()
            } catch {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            if let output = String(data: data, encoding: .utf8) {
                let fm = FileManager.default
                for line in output.split(separator: "\n").prefix(limit * 4) {
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
