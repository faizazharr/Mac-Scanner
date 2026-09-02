# MacScanner Project Roadmap 🗺️

This document outlines the planned technical milestones and feature enhancements for **MacScanner**. Community feedback and pull requests are warmly encouraged!

---

## 📍 Current Release: v1.2.0 (Live)
- [x] **Universal 2 Binary**: 100% native compilation for Apple Silicon (`arm64`) & Intel 64-bit (`x86_64`).
- [x] **Background Services Monitor**: Real-time Launch Agents, Launch Daemons, and XPC service tracking with dynamic `.app` bundle owner detection and live CPU/RAM metrics.
- [x] **7-Module Display & Monitor Diagnostics Suite**: Defective Pixels, Luminance Uniformity, 10-Bit Gradients, Dynamic Range, Sharpness & Typography, Gamma 2.2, 120Hz ProMotion Motion Response.
- [x] **Sub-0.2s Spotlight Metadata Large Files Scanner**: Instant search with scope filters, size presets, and batch trash actions.
- [x] **Hardware-Adaptive Cooling & Memory Profiles**: Proportional memory scaling (8 GB – 192 GB+) and cooling profiles (Fanless MacBook Air & MacBook Neo, Active-Fan MacBook Pro, Desktop AC).
- [x] **Non-Alarmist Virtual Memory Diagnostics**: Intelligent context-aware status evaluation with educational popovers.
- [x] **Designer & Browser Bloat Screener**: Safe cache purging for Figma, Adobe CC, Sketch, and modern browsers.

---

## 🔮 Upcoming Milestones

### 📌 Milestone 1: Homebrew Cask & CLI Companion (v1.3.0)
- [ ] **Official Homebrew Cask**: `brew install --cask macscanner` distribution formula.
- [ ] **Headless CLI Companion**: Lightweight command-line utility (`macscanner scan`, `macscanner stats`) for terminal power users and automated shell scripts.
- [ ] **Auto-Update Framework**: Lightweight, privacy-preserving in-app update checks using Sparkle / GitHub Releases API (opt-in).

### 📌 Milestone 2: Notification Center & MenuBar Customization (v1.3.0)
- [ ] **Customizable MenuBar Extra**: Let users select which mini-gauge appears directly on the macOS menu bar (e.g. CPU %, RAM %, or Temp icon).
- [ ] **macOS Notification Center Widgets**: Interactive desktop and Notification Center widgets for live memory and battery health.
- [ ] **Threshold Alerts**: Optional user-configurable notifications (e.g., alert when disk space falls below 10 GB).

### 📌 Milestone 3: Advanced Hardware Diagnostics & Benchmarking (v1.4.0)
- [ ] **NVMe SSD Speed Benchmark**: Safe sequential and random 4K read/write speed benchmark without wearing flash storage.
- [ ] **Thermal Throttling History Chart**: Historical timeline visualizing when thermal regulation stepped in during heavy compilation or rendering.
- [ ] **Multi-Monitor Display Testing**: Seamless display diagnostic switching across multiple connected external monitors.

---

## 🤝 How to Suggest New Features
Have an idea or want to work on a roadmap item?
1. Open a discussion or feature request in [**GitHub Issues**](../../issues).
2. Check [**`CONTRIBUTING.md`**](CONTRIBUTING.md) for architectural guidelines and code standards.
3. Submit a pull request!
