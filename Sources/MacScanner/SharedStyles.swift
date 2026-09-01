// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI

// MARK: - File Category & Visual Helpers

enum FileCategory: String, CaseIterable {
    case all = "All"
    case video = "Video"
    case archive = "Archive"
    case diskImage = "Disk Image"
    case audio = "Audio"
    case document = "Document"
    case code = "Code / Data"
    case app = "App"
    case other = "Other"

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .video: return "film.fill"
        case .archive: return "archivebox.fill"
        case .diskImage: return "opticaldiscdrive.fill"
        case .audio: return "music.note"
        case .document: return "doc.text.fill"
        case .code: return "curlybraces"
        case .app: return "app.badge.fill"
        case .other: return "doc.fill"
        }
    }

    var color: Color {
        switch self {
        case .all: return .accentColor
        case .video: return .purple
        case .archive: return .orange
        case .diskImage: return .pink
        case .audio: return .red
        case .document: return .blue
        case .code: return .cyan
        case .app: return .indigo
        case .other: return .secondary
        }
    }

    static func category(for url: URL, isDirectory: Bool) -> FileCategory {
        if isDirectory {
            if url.pathExtension.lowercased() == "app" { return .app }
            return .other
        }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "mkv", "avi", "m4v", "webm", "flv", "wmv":
            return .video
        case "zip", "tar", "gz", "tgz", "rar", "7z", "bz2", "xz":
            return .archive
        case "dmg", "iso", "img", "vdi", "vmdk", "qcow2":
            return .diskImage
        case "mp3", "wav", "flac", "m4a", "aac", "ogg", "aiff":
            return .audio
        case "pdf", "doc", "docx", "pages", "xls", "xlsx", "numbers", "ppt", "pptx", "key", "txt", "md", "rtf":
            return .document
        case "swift", "js", "ts", "json", "py", "rs", "go", "c", "cpp", "h", "sql", "db", "sqlite", "sqlite3", "xml", "yaml", "yml":
            return .code
        case "app":
            return .app
        default:
            return .other
        }
    }
}

// MARK: - Modern Glassmorphic Card Styling

struct GlassCardBackground: ViewModifier {
    var tint: Color = .secondary
    var opacity: Double = 0.06
    var cornerRadius: CGFloat = 14
    var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(isHovered ? opacity * 1.8 : opacity))
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                (isHovered ? tint : Color.white).opacity(isHovered ? 0.35 : 0.15),
                                (isHovered ? tint : Color.clear).opacity(isHovered ? 0.15 : 0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isHovered ? tint.opacity(0.18) : Color.black.opacity(0.12),
                radius: isHovered ? 8 : 4,
                x: 0,
                y: isHovered ? 3 : 2
            )
    }
}

extension View {
    func glassCard(tint: Color = .secondary, opacity: Double = 0.06, cornerRadius: CGFloat = 14, isHovered: Bool = false) -> some View {
        modifier(GlassCardBackground(tint: tint, opacity: opacity, cornerRadius: cornerRadius, isHovered: isHovered))
    }

    /// Legacy compatibility alias
    func cardStyle(tint: Color = .secondary, opacity: Double = 0.08) -> some View {
        modifier(GlassCardBackground(tint: tint, opacity: opacity, cornerRadius: 12))
    }
}

// MARK: - Status Pill & Badges

struct Pill: View {
    let text: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.caption2)
                .bold()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(color.opacity(0.16))
        .foregroundStyle(color)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(0.3), lineWidth: 0.8)
        )
    }
}

// MARK: - Section Headers

struct SectionHeader: View {
    let title: String
    let subtitle: String?
    let icon: String
    var iconColor: Color = .accentColor

    init(_ title: String, subtitle: String? = nil, icon: String, iconColor: Color = .accentColor) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Circular Storage Progress Ring

struct StorageRingGauge: View {
    let usedBytes: Int64
    let totalBytes: Int64
    let freeBytes: Int64
    var size: CGFloat = 130
    var lineWidth: CGFloat = 12

    private var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    private var tint: Color {
        if usedFraction >= 0.90 { return .red }
        if usedFraction >= 0.75 { return .orange }
        return .green
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Fill
            Circle()
                .trim(from: 0, to: CGFloat(min(max(usedFraction, 0), 1)))
                .stroke(
                    LinearGradient(
                        colors: [tint.opacity(0.7), tint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: usedFraction)

            // Center Content
            VStack(spacing: 2) {
                Text("\(Int(usedFraction * 100))%")
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("USED")
                    .font(.system(size: size * 0.08, weight: .heavy))
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }
        }
    }
}
