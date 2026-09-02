// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI

/// Fullscreen Display & Monitor Diagnostics Suite View
struct DeadPixelFullscreenView: View {
    @ObservedObject var engine: DeviceTestingEngine
    @State private var hideHUDTimer: Timer?

    var body: some View {
        let pattern = engine.currentPattern

        ZStack {
            // Pattern Canvas Renderer
            ScreenTestCanvasView(pattern: pattern, motionSpeed: engine.motionSpeed)
                .ignoresSafeArea()

            // Floating Navigation & Status HUD
            if engine.isHUDVisible {
                VStack(spacing: 12) {
                    // Category Selection Pills
                    HStack(spacing: 8) {
                        ForEach(ScreenTestCategory.allCases) { cat in
                            Button {
                                engine.selectCategory(cat)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: cat.icon)
                                        .font(.caption2)
                                    Text(cat.rawValue)
                                        .font(.caption)
                                        .fontWeight(engine.selectedScreenCategory == cat ? .bold : .medium)
                                    Text("[\(cat.shortcutNumber)]")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .opacity(0.7)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    engine.selectedScreenCategory == cat
                                        ? Color.blue
                                        : Color.black.opacity(0.65)
                                )
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(engine.selectedScreenCategory == cat ? 0.8 : 0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Pattern Info & Dismiss Toolbar
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(pattern.name)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)

                                let items = engine.currentCategoryPatterns
                                if items.count > 1 {
                                    Text("(\(engine.currentPatternIndex + 1) / \(items.count))")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }

                            Text(pattern.purpose)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.9))

                            Text(pattern.instructions)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.65))
                        }

                        Spacer()

                        // Previous / Next Buttons
                        if engine.currentCategoryPatterns.count > 1 {
                            Button {
                                engine.previousPattern()
                            } label: {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)

                            Button {
                                engine.nextPattern()
                            } label: {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }

                        // Exit Fullscreen Button
                        Button {
                            engine.exitDeadPixelTester()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Exit (ESC)")
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    // Bottom Hotkey Reference
                    HStack {
                        Text("Click / [Space / →] Next • [←] Prev • [1-7] Category • [H] Toggle HUD • [ESC] Exit")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    Color.black
                        .opacity(0.85)
                        .blur(radius: 8)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .padding(18)
                .frame(maxHeight: .infinity, alignment: .top)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            engine.nextPattern()
            flashHUD()
        }
        .onHover { isHovered in
            if isHovered {
                flashHUD()
            }
        }
        .onAppear {
            scheduleHUDAutoHide()
        }
    }

    private func flashHUD() {
        withAnimation(.easeInOut(duration: 0.2)) {
            engine.isHUDVisible = true
        }
        scheduleHUDAutoHide()
    }

    private func scheduleHUDAutoHide() {
        hideHUDTimer?.invalidate()
        hideHUDTimer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.5)) {
                    engine.isHUDVisible = false
                }
            }
        }
    }
}
