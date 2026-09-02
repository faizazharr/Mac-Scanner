// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI

/// Canvas rendering individual monitor diagnostics test patterns.
struct ScreenTestCanvasView: View {
    let pattern: ScreenTestItem
    let motionSpeed: Double

    var body: some View {
        switch pattern.category {
        case .defectivePixels:
            solidColorView(for: pattern.id)

        case .uniformity:
            uniformityView(for: pattern.id)

        case .gradients:
            gradientView(for: pattern.id)

        case .colorDistances:
            colorDistancesView(for: pattern.id)

        case .sharpness:
            sharpnessView(for: pattern.id)

        case .gamma:
            gammaView(for: pattern.id)

        case .motion:
            motionResponseView()
        }
    }

    // 1. Defective Pixels
    @ViewBuilder
    private func solidColorView(for id: String) -> some View {
        switch id {
        case "pixel_white": Color.white
        case "pixel_black": Color.black
        case "pixel_red": Color(red: 1, green: 0, blue: 0)
        case "pixel_green": Color(red: 0, green: 1, blue: 0)
        case "pixel_blue": Color(red: 0, green: 0, blue: 1)
        case "pixel_cyan": Color(red: 0, green: 1, blue: 1)
        case "pixel_magenta": Color(red: 1, green: 0, blue: 1)
        case "pixel_yellow": Color(red: 1, green: 1, blue: 0)
        case "pixel_gray50": Color(white: 0.5)
        default: Color.white
        }
    }

    // 2. Uniformity
    @ViewBuilder
    private func uniformityView(for id: String) -> some View {
        switch id {
        case "unif_100": Color(white: 1.0)
        case "unif_75": Color(white: 0.75)
        case "unif_50": Color(white: 0.50)
        case "unif_25": Color(white: 0.25)
        default: Color(white: 0.5)
        }
    }

    // 3. Gradients
    @ViewBuilder
    private func gradientView(for id: String) -> some View {
        switch id {
        case "grad_gray_h":
            LinearGradient(colors: [.black, .white], startPoint: .leading, endPoint: .trailing)

        case "grad_gray_v":
            LinearGradient(colors: [.black, .white], startPoint: .top, endPoint: .bottom)

        case "grad_rgb_bars":
            VStack(spacing: 0) {
                LinearGradient(colors: [.black, .red], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.black, .green], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.black, .blue], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.black, .white], startPoint: .leading, endPoint: .trailing)
            }

        case "grad_spectrum":
            LinearGradient(
                colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                startPoint: .leading,
                endPoint: .trailing
            )

        default:
            LinearGradient(colors: [.black, .white], startPoint: .leading, endPoint: .trailing)
        }
    }

    // 4. Color Distances & Dynamic Range
    @ViewBuilder
    private func colorDistancesView(for id: String) -> some View {
        if id == "dist_near_black" {
            // 10 near-black tiles (0% to 10%) on black field
            ZStack {
                Color.black
                VStack(spacing: 20) {
                    Text("Near-Black Shadow Range Steps")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))

                    HStack(spacing: 12) {
                        ForEach(0..<10) { step in
                            let val = Double(step) * 0.01 + 0.01 // 1% to 10%
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(white: val))
                                    .frame(width: 80, height: 80)
                                Text("\(Int(val * 100))%")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                }
            }
        } else if id == "dist_near_white" {
            // 10 near-white tiles (90% to 100%) on white field
            ZStack {
                Color.white
                VStack(spacing: 20) {
                    Text("Near-White Highlight Steps")
                        .font(.headline)
                        .foregroundStyle(.black.opacity(0.8))

                    HStack(spacing: 12) {
                        ForEach(0..<10) { step in
                            let val = 0.90 + Double(step) * 0.01 // 90% to 99%
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(white: val))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.black.opacity(0.15), lineWidth: 1)
                                    )
                                Text("\(Int(val * 100))%")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.black.opacity(0.7))
                            }
                        }
                    }
                }
            }
        } else {
            // Saturation Step Matrix
            ZStack {
                Color.black
                VStack(spacing: 16) {
                    Text("Saturation Distinguishability Matrix")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))

                    let colors: [Color] = [.red, .green, .blue, .cyan, .purple, .yellow]
                    VStack(spacing: 10) {
                        ForEach(colors.indices, id: \.self) { cIdx in
                            HStack(spacing: 8) {
                                ForEach([0.80, 0.88, 0.94, 1.0], id: \.self) { sat in
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(colors[cIdx].opacity(sat))
                                        .frame(width: 100, height: 42)
                                        .overlay(
                                            Text("\(Int(sat * 100))%")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.white)
                                        )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 5. Sharpness & Lines
    @ViewBuilder
    private func sharpnessView(for id: String) -> some View {
        if id == "sharp_1px_grid" {
            GeometryReader { geo in
                Canvas { context, size in
                    let step: CGFloat = 16
                    var path = Path()
                    for x in stride(from: 0, to: size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: 0, to: size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(path, with: .color(Color.white.opacity(0.35)), lineWidth: 1)
                }
                .drawingGroup()
                .background(Color.black)
            }
        } else if id == "sharp_convergence" {
            GeometryReader { geo in
                ZStack {
                    Color.black
                    Canvas { context, size in
                        let centers = [
                            CGPoint(x: size.width / 2, y: size.height / 2),
                            CGPoint(x: 100, y: 100),
                            CGPoint(x: size.width - 100, y: 100),
                            CGPoint(x: 100, y: size.height - 100),
                            CGPoint(x: size.width - 100, y: size.height - 100)
                        ]
                        var path = Path()
                        for c in centers {
                            for r in stride(from: 10, through: 70, by: 15) {
                                path.addEllipse(in: CGRect(x: c.x - CGFloat(r), y: c.y - CGFloat(r), width: CGFloat(r * 2), height: CGFloat(r * 2)))
                            }
                        }
                        context.stroke(path, with: .color(.white), lineWidth: 1)
                    }
                    .drawingGroup()
                }
            }
        } else {
            // Multi-scale typography
            ZStack {
                Color.white
                VStack(alignment: .leading, spacing: 14) {
                    Text("MacScanner Display Typography & Subpixel Antialiasing Scale:")
                        .font(.headline)
                        .foregroundStyle(.black)

                    Divider()

                    ForEach([8, 10, 12, 14, 18, 24, 28], id: \.self) { pts in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(pts)pt:")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 45, alignment: .leading)
                            Text("The quick brown fox jumps over the lazy dog • 1234567890 • QWERTYUIOPASDFGHJKLZXCVBNM")
                                .font(.system(size: CGFloat(pts)))
                                .foregroundStyle(.black)
                        }
                    }
                }
                .padding(40)
            }
        }
    }

    // 6. Gamma 2.2
    @ViewBuilder
    private func gammaView(for id: String) -> some View {
        if id == "gamma_ramp" {
            ZStack {
                Color.black
                VStack(spacing: 20) {
                    Text("Gamma 2.2 16-Step Grayscale Ramp")
                        .font(.headline)
                        .foregroundStyle(.white)

                    HStack(spacing: 4) {
                        ForEach(0..<16) { step in
                            let norm = Double(step) / 15.0
                            let lum = pow(norm, 2.2)
                            VStack(spacing: 6) {
                                Rectangle()
                                    .fill(Color(white: lum))
                                    .frame(maxWidth: .infinity, maxHeight: 240)
                                Text(String(format: "%.2f", lum))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }
        } else {
            ZStack {
                Color(white: 0.5)
                VStack(spacing: 16) {
                    Text("Gamma 2.2 Optical Blending Target")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ZStack {
                        Rectangle()
                            .fill(Color(white: 0.5))
                            .frame(width: 200, height: 200)

                        Rectangle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 200, height: 200)

                        Text("2.2")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.6))
                    }
                    Text("Step back 2-3 meters: the inner box should blend into the 50% neutral gray field.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }

    // 7. Motion Response & Ghosting (Smooth 60/120Hz Animation)
    @ViewBuilder
    private func motionResponseView() -> some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                let width = geo.size.width
                let time = timeline.date.timeIntervalSinceReferenceDate
                let period = max(1.0, width / motionSpeed)
                let progress = (time.truncatingRemainder(dividingBy: period)) / period
                let posX = progress * width

                ZStack {
                    Color.black

                    VStack(spacing: 80) {
                        Divider().background(Color.white.opacity(0.2))
                        Divider().background(Color.white.opacity(0.2))
                        Divider().background(Color.white.opacity(0.2))
                    }

                    // Track 1: High Contrast White Block
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .frame(width: 80, height: 50)
                        .position(x: posX, y: geo.size.height * 0.35)

                    // Track 2: Saturated Red Block
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red)
                        .frame(width: 80, height: 50)
                        .position(x: (posX + width * 0.3).truncatingRemainder(dividingBy: width), y: geo.size.height * 0.50)

                    // Track 3: High Contrast Cyan Block
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.cyan)
                        .frame(width: 80, height: 50)
                        .position(x: (posX + width * 0.6).truncatingRemainder(dividingBy: width), y: geo.size.height * 0.65)
                }
            }
        }
        .drawingGroup()
    }
}
