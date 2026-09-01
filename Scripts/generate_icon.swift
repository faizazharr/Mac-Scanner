// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.
//
// Renders the app icon (see IconView below) to a 1024x1024 PNG using
// SwiftUI's ImageRenderer. Run via Scripts/generate_icon.sh, which also
// builds the full .iconset and .icns from this PNG.

import SwiftUI
import AppKit

/// MacScanner app icon: a rounded-square gradient (matching the donut chart's
/// own blue→purple palette used throughout the app), a thin partial scan-ring
/// behind the glyph for texture, and a bold magnifying glass on top — legible
/// down to 16x16 since the glass is the only shape that has to read at that size.
struct IconView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.25, green: 0.47, blue: 0.98), Color(red: 0.55, green: 0.25, blue: 0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .trim(from: 0.08, to: 0.62)
                .stroke(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size * 0.62, height: size * 0.62)
                .offset(x: -size * 0.02, y: -size * 0.02)

            Image(systemName: "magnifyingglass")
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: size * 0.02, y: size * 0.012)
        }
        .frame(width: size, height: size)
    }
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

MainActor.assumeIsolated {
    let size: CGFloat = 1024
    let renderer = ImageRenderer(content: IconView(size: size))
    renderer.scale = 1

    guard let nsImage = renderer.nsImage,
          let tiff = nsImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to render icon")
        exit(1)
    }

    do {
        try png.write(to: URL(fileURLWithPath: outputPath))
        print("Wrote \(outputPath)")
    } catch {
        print("Write failed: \(error)")
        exit(1)
    }
}
