// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// Professional Display Diagnostic Categories.
enum ScreenTestCategory: String, CaseIterable, Identifiable, Sendable {
    case defectivePixels = "Defective Pixels"
    case uniformity = "Uniformity"
    case gradients = "Gradients"
    case colorDistances = "Color Distances"
    case sharpness = "Sharpness & Text"
    case gamma = "Gamma 2.2"
    case motion = "Motion Response"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .defectivePixels: return "display"
        case .uniformity: return "circle.lefthalf.filled"
        case .gradients: return "slider.horizontal.3"
        case .colorDistances: return "square.grid.3x3.fill"
        case .sharpness: return "textformat.size"
        case .gamma: return "waveform.path.ecg"
        case .motion: return "bolt.horizontal.fill"
        }
    }

    var shortcutNumber: String {
        switch self {
        case .defectivePixels: return "1"
        case .uniformity: return "2"
        case .gradients: return "3"
        case .colorDistances: return "4"
        case .sharpness: return "5"
        case .gamma: return "6"
        case .motion: return "7"
        }
    }
}

/// Represents a single visual test pattern within a category.
struct ScreenTestItem: Identifiable, Sendable {
    let id: String
    let name: String
    let category: ScreenTestCategory
    let purpose: String
    let instructions: String
}

/// Factory and catalog of all monitor test patterns.
enum ScreenTestCatalog {
    static let allPatterns: [ScreenTestItem] = [
        // 1. Defective Pixels (Solid Colors)
        ScreenTestItem(
            id: "pixel_white",
            name: "Pure White",
            category: .defectivePixels,
            purpose: "Detect black dead pixels & panel dust.",
            instructions: "Inspect panel for dark dots that fail to light up."
        ),
        ScreenTestItem(
            id: "pixel_black",
            name: "Pure Black",
            category: .defectivePixels,
            purpose: "Detect bright stuck pixels & edge backlight bleed.",
            instructions: "Inspect dark screen for stuck lit sub-pixels or edge glow."
        ),
        ScreenTestItem(
            id: "pixel_red",
            name: "Pure Red",
            category: .defectivePixels,
            purpose: "Detect defective red sub-pixels.",
            instructions: "Look for black dots indicating failed red sub-pixels."
        ),
        ScreenTestItem(
            id: "pixel_green",
            name: "Pure Green",
            category: .defectivePixels,
            purpose: "Detect defective green sub-pixels.",
            instructions: "Look for black dots indicating failed green sub-pixels."
        ),
        ScreenTestItem(
            id: "pixel_blue",
            name: "Pure Blue",
            category: .defectivePixels,
            purpose: "Detect defective blue sub-pixels.",
            instructions: "Look for black dots indicating failed blue sub-pixels."
        ),
        ScreenTestItem(
            id: "pixel_cyan",
            name: "Pure Cyan",
            category: .defectivePixels,
            purpose: "Test Green + Blue combined sub-pixel channel.",
            instructions: "Verify color consistency across all screen sectors."
        ),
        ScreenTestItem(
            id: "pixel_magenta",
            name: "Pure Magenta",
            category: .defectivePixels,
            purpose: "Test Red + Blue combined sub-pixel channel.",
            instructions: "Verify uniform pink saturation from edge to edge."
        ),
        ScreenTestItem(
            id: "pixel_yellow",
            name: "Pure Yellow",
            category: .defectivePixels,
            purpose: "Test Red + Green combined sub-pixel channel.",
            instructions: "Check for color purity and absence of tint cast."
        ),
        ScreenTestItem(
            id: "pixel_gray50",
            name: "50% Neutral Gray",
            category: .defectivePixels,
            purpose: "Detect sub-pixel balance & Dirty Screen Effect (DSE).",
            instructions: "Inspect for color shifts, cloudy patches, or banding."
        ),

        // 2. Uniformity
        ScreenTestItem(
            id: "unif_100",
            name: "100% White Uniformity",
            category: .uniformity,
            purpose: "Evaluate peak brightness uniformity across corners.",
            instructions: "Check if the 4 corners have lower brightness (vignetting)."
        ),
        ScreenTestItem(
            id: "unif_75",
            name: "75% Light Gray Uniformity",
            category: .uniformity,
            purpose: "Inspect mid-high tone brightness distribution.",
            instructions: "Ensure smooth illumination without hot spots."
        ),
        ScreenTestItem(
            id: "unif_50",
            name: "50% Mid-Tone Gray Uniformity",
            category: .uniformity,
            purpose: "Check for panel clouding (mura effect).",
            instructions: "Ideal for spotting IPS glow and panel manufacturing defects."
        ),
        ScreenTestItem(
            id: "unif_25",
            name: "25% Dark Gray Uniformity",
            category: .uniformity,
            purpose: "Check low-luminance consistency and backlight bleed.",
            instructions: "Look for uneven dark patches in subdued ambient lighting."
        ),

        // 3. Gradients
        ScreenTestItem(
            id: "grad_gray_h",
            name: "Horizontal Grayscale (0–255)",
            category: .gradients,
            purpose: "Test for 8-bit / 10-bit banding in tonal ramp.",
            instructions: "Transition from black to white should be smooth with no visible vertical stripes."
        ),
        ScreenTestItem(
            id: "grad_gray_v",
            name: "Vertical Grayscale (0–255)",
            category: .gradients,
            purpose: "Detect vertical gamma shifts and color banding.",
            instructions: "Evaluate vertical gradation smoothness."
        ),
        ScreenTestItem(
            id: "grad_rgb_bars",
            name: "RGB Color Gradients (R, G, B)",
            category: .gradients,
            purpose: "Evaluate channel-separated digital-to-analog converter linearity.",
            instructions: "Verify each primary color ramps evenly without sudden tone jumps."
        ),
        ScreenTestItem(
            id: "grad_spectrum",
            name: "Full Visible Color Spectrum",
            category: .gradients,
            purpose: "Evaluate gamut coverage and smooth chromatic transitions.",
            instructions: "Check rainbow gradient transitions for clipping or posterization."
        ),

        // 4. Color Distances & Dynamic Range
        ScreenTestItem(
            id: "dist_near_black",
            name: "Near-Black Contrast Steps (0% to 10%)",
            category: .colorDistances,
            purpose: "Detect black crush and shadow detail clipping.",
            instructions: "You should be able to distinguish subtle numbered boxes against pure black."
        ),
        ScreenTestItem(
            id: "dist_near_white",
            name: "Near-White Contrast Steps (90% to 100%)",
            category: .colorDistances,
            purpose: "Detect highlight clipping and blown-out whites.",
            instructions: "You should be able to distinguish subtle shaded boxes against pure white."
        ),
        ScreenTestItem(
            id: "dist_matrix",
            name: "Primary & Secondary Step Matrix",
            category: .colorDistances,
            purpose: "Test color differentiation at 90%, 93%, 96%, 99% saturations.",
            instructions: "Check if subtle color tone differences remain distinguishable."
        ),

        // 5. Sharpness & Lines
        ScreenTestItem(
            id: "sharp_1px_grid",
            name: "1px Micro Line & Pixel Grid",
            category: .sharpness,
            purpose: "Evaluate native pixel scaling and display sharpness.",
            instructions: "Lines should be razor-sharp with no shimmering or moiré interference."
        ),
        ScreenTestItem(
            id: "sharp_convergence",
            name: "Radial Convergence & Focus Circles",
            category: .sharpness,
            purpose: "Check optical distortion, focus uniformity, and panel geometry.",
            instructions: "Circles in the center and all four corners should remain perfectly sharp."
        ),
        ScreenTestItem(
            id: "sharp_typography",
            name: "Multi-Scale Typography (8pt to 28pt)",
            category: .sharpness,
            purpose: "Evaluate subpixel font antialiasing (macOS Retina scaling).",
            instructions: "All font sizes down to 8pt should be clean, crisp, and legible."
        ),

        // 6. Gamma 2.2 Calibration
        ScreenTestItem(
            id: "gamma_ramp",
            name: "Gamma 2.2 16-Step Luminance Scale",
            category: .gamma,
            purpose: "Verify tonal response curve matches sRGB / Display P3 2.2 standard.",
            instructions: "Each step should have a visually perceptually uniform brightness jump."
        ),
        ScreenTestItem(
            id: "gamma_interlace",
            name: "Checkerboard Gamma Target",
            category: .gamma,
            purpose: "Detect gamma deviation via high-frequency optical blending.",
            instructions: "Squint from a distance: blended box should match background at 2.2."
        ),

        // 7. Motion Response & Ghosting
        ScreenTestItem(
            id: "motion_pursuit",
            name: "Pursuit UFO Motion Test (60Hz / 120Hz ProMotion)",
            category: .motion,
            purpose: "Measure pixel transition times, motion blur, and overdrive ghosting.",
            instructions: "Follow moving blocks with your eyes to inspect ghost trails or coronas."
        )
    ]

    static func patterns(for category: ScreenTestCategory) -> [ScreenTestItem] {
        allPatterns.filter { $0.category == category }
    }
}
