// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation

/// A single file or folder shown in the Folder Browser or Large Files list.
struct FileEntry: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var sizeBytes: Int64
    var isDirectory: Bool

    var name: String { url.lastPathComponent }

    var sizeString: String { ByteFormat.string(sizeBytes) }
}

/// How confident `RecommendationEngine` is that a candidate path is safe to delete.
enum RiskLevel: String {
    case safe = "Safe to clean"
    case caution = "Review first"
    case manual = "Manual review"
}

/// A known cleanup target (e.g. `~/Library/Caches`) evaluated against this
/// Mac by `RecommendationEngine`. `exists`/`sizeBytes` are only meaningful
/// after evaluation — a freshly built candidate has neither.
struct Recommendation: Identifiable {
    let id = UUID()
    let title: String
    let path: URL
    let explanation: String
    let risk: RiskLevel
    var sizeBytes: Int64 = 0
    var exists: Bool = false
}

/// Human-readable byte formatting (e.g. "161.55 GB"), shared across every view.
enum ByteFormat {
    static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    static func string(_ bytes: Int64) -> String {
        formatter.string(fromByteCount: bytes)
    }
}
