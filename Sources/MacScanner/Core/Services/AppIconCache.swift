// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import AppKit

/// High-performance thread-safe application icon cache.
///
/// Prevents repeated filesystem I/O and bundle parsing by memoizing app icons
/// in a bounded memory cache (`NSCache`) with automatic eviction under memory pressure.
final class AppIconCache: @unchecked Sendable {
    static let shared = AppIconCache()

    private let cache = NSCache<NSString, NSImage>()
    private let fallbackIcon = NSImage(size: NSSize(width: 32, height: 32))

    private init() {
        // Limit cache size to 150 icons (approx. 15-20 MB in RAM)
        cache.countLimit = 150
        cache.totalCostLimit = 25 * 1024 * 1024 // 25 MB
    }

    /// Retrieves the cached icon for an application at a specific path or URL,
    /// loading it from the disk only on cache miss.
    func icon(for path: String) -> NSImage {
        let key = path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 64, height: 64)
        cache.setObject(icon, forKey: key, cost: 64 * 64 * 4)
        return icon
    }

    /// Convenience overload taking a `URL`.
    func icon(for url: URL) -> NSImage {
        icon(for: url.path)
    }

    /// Clears the in-memory icon cache.
    func clear() {
        cache.removeAllObjects()
    }
}
