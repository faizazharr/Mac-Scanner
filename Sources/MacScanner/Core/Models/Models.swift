// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import SwiftUI

/// A single file or folder shown in the Folder Browser or Large Files list.
struct FileEntry: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var sizeBytes: Int64
    var isDirectory: Bool

    var name: String { url.lastPathComponent }
    var sizeString: String { ByteFormat.string(sizeBytes) }

    var category: FileCategory {
        FileCategory.category(for: url, isDirectory: isDirectory)
    }
}

/// How confident `RecommendationEngine` is that a candidate path is safe to delete.
enum RiskLevel: String, CaseIterable {
    case safe = "Safe to clean"
    case caution = "Review first"
    case manual = "Manual review"

    var color: Color {
        switch self {
        case .safe: return .green
        case .caution: return .orange
        case .manual: return .red
        }
    }

    var icon: String {
        switch self {
        case .safe: return "checkmark.shield.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .manual: return "hand.raised.fill"
        }
    }
}

enum RecommendationCategory: String, CaseIterable {
    case designer = "Designer & Creative"
    case developer = "Developer"
    case cache = "Caches & Junk"
    case backup = "Backups & Sync"
    case logs = "System Logs"
    case user = "User Files"

    var icon: String {
        switch self {
        case .designer: return "paintbrush.pointed.fill"
        case .developer: return "hammer.fill"
        case .cache: return "trash.fill"
        case .backup: return "arrow.triangle.2.circlepath.circle.fill"
        case .logs: return "doc.text.magnifyingglass"
        case .user: return "person.crop.circle.fill"
        }
    }
}

/// A known cleanup target evaluated against this Mac by `RecommendationEngine`.
struct Recommendation: Identifiable {
    let id = UUID()
    let title: String
    let path: URL
    let explanation: String
    let risk: RiskLevel
    let category: RecommendationCategory
    let iconName: String
    var sizeBytes: Int64 = 0
    var exists: Bool = false
}

// MARK: - Designer & Browser Models

/// Information about a single browser extension installed on this Mac.
struct BrowserExtensionInfo: Identifiable, Hashable {
    let id = UUID()
    let extensionID: String
    let name: String
    let version: String
    let description: String
    let browserName: String
    let isHeavyCandidate: Bool
}

/// Information about an installed web browser on macOS.
struct BrowserInfo: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let tintColor: Color
    let isInstalled: Bool
    var cacheBytes: Int64 = 0
    var extensions: [BrowserExtensionInfo] = []
    let cacheURL: URL?
    let extensionsURL: URL?

    var extensionsCount: Int { extensions.count }
}

/// Information about a design/creative application's cached data.
struct DesignAppCacheInfo: Identifiable {
    let id = UUID()
    let appName: String
    let icon: String
    let category: String
    var sizeBytes: Int64 = 0
    let path: URL
    let explanation: String
    let safeToClean: Bool
    var exists: Bool = false
}

/// Plain-language diagnostic insight explaining why the Mac might be slow or bloated.
struct DesignerDiagnosticInsight: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let explanation: String
    let icon: String
    let color: Color
    let actionTitle: String?
    let targetURL: URL?
    var browserName: String? = nil
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
