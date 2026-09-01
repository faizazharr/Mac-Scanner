# Changelog

## v1.1.0 — EIZO-Grade Display & Monitor Diagnostics Suite

Comprehensive monitor testing suite inspired by EIZO (`test.eizo.be`) with 7 display calibration and diagnostic modules:

### Features & Test Modules

- **1. Defective Pixels**: Fullscreen solid primaries and secondaries (White, Black, Red, Green, Blue, Cyan, Magenta, Yellow, 50% Neutral Gray) to detect dead sub-pixels, stuck pixels, and backlight bleeding.
- **2. Luminance Uniformity**: 25%, 50%, 75%, 100% full-field luminance tests to evaluate corner vignetting, hot spots, and panel clouding (mura effect).
- **3. Color & Grayscale Gradients**: Smooth 10-bit continuous linear gradients (Horizontal & Vertical Grayscale, channel-separated RGB bars, full visible spectrum) to detect color banding and dithering artifacts.
- **4. Color Distances & Dynamic Range**: Near-black (1%–10%) and near-white (90%–99%) stepped matrices to detect black crush and highlight clipping.
- **5. Sharpness & Typography**: 1px micro line grid, concentric radial convergence crosshairs, and multi-scale Retina typography (8pt to 28pt) to evaluate scaling distortion and subpixel antialiasing.
- **6. Gamma 2.2 Calibration**: Gamma 2.2 reference target with 16-level grayscale ramp and high-frequency optical blending checkerboard.
- **7. Motion Response (120Hz ProMotion)**: High-framerate animated pursuit UFO test blocks (240px/s, 480px/s, 960px/s) to inspect pixel transition times, motion blur, and overdrive ghosting.
- **Fullscreen HUD & Controls**: Floating category pills with hotkeys `[1-7]`, pattern step navigation with `[Space] / [← / →]`, HUD toggle with `[H]`, and foolproof `[ESC]` exit via custom AppKit `DeadPixelWindow`.

## v1.0.1 — English Localization & Self-Protection Safeguards

Patch release providing 100% clean English localization across all features, enhanced Swift 6 concurrency compliance, and self-uninstallation protection.

### Improvements & Fixes

- **100% English Localization**: Complete localization sweep across all diagnostic modules, tooltips, toasts, confirmation dialogs, and hardware testing interfaces.
- **Uninstaller Self-Protection**: Added bundle identity safeguard to prevent MacScanner from accidentally targeting or uninstalling its own active bundle and assets.
- **Swift 6 Concurrency Compliance**: Refactored timer callbacks and background dispatch closures to satisfy strict actor-isolation guarantees.
- **Enhanced Hardware Diagnostics**: Fully translated keyboard matrix key detection, shortcut interception, stereo audio sweeps, and dead pixel inspection HUD.

## v1.0.0 — First public release

Native macOS disk-usage screener: see where your disk space actually goes,
get risk-tagged cleanup recommendations, find oversized files, watch live
system load, and act on any of it without leaving the app.

### Features

- **Home** — landing page: this Mac's specs, a storage overview, and a card
  per feature so you pick where to go next.
- **Folder Browser** — drill into any folder (single click), size-sorted
  children with a relative-size bar and a percentage donut chart, search
  within the current folder, clickable breadcrumb (including the true
  filesystem root `/`).
- **Cleanup Recommendations** — curated list of known cleanup targets
  (caches, build artifacts, Docker/simulator data, old backups, ...) checked
  against this Mac, each tagged Safe to clean / Review first / Manual review.
- **Large Files** — every file at or above a chosen size threshold anywhere
  under your home folder, filterable by category.
- **Performance** — live Memory/CPU/GPU/Swap/Thermal gauges with a literal
  red-line marker at each critical threshold, sparkline history charts, a
  stable Recommendations panel that only updates when something actually
  changes (not every tick), a list of currently-running resource-heavy apps,
  and a searchable, sortable (CPU/RAM) process list with the ability to quit
  a process directly.

Every list row supports **Reveal in Finder** and **Move to Trash** (with a
confirmation dialog — reversible, nothing permanently deleted).

### Under the hood

- Every tab follows the same single-event-driven view-model shape
  (`enum Action` + `func send(_:)`), keeping state mutation traceable to one
  call site per tab.
- Disk scanning shells out to `du`/`find` (APFS-clone aware, far faster than
  a manual recursive walk for directories with millions of small files);
  performance metrics read `vm_stat`/`sysctl`/`top`/`ioreg`/`ps` directly —
  GPU utilization included, without requiring administrator privileges.
- The live-refresh loop parallelizes its independent subprocess calls and
  only fetches the RAM-sorted process list when that sort mode is actually
  selected, keeping the app's own footprint light while it's polling.
- Signed with a real local code-signing identity (not ad-hoc) so macOS
  treats rebuilds as the same app — folder-access permissions persist
  instead of re-prompting every time.

### Known limitations

- NPU (Apple Neural Engine) utilization isn't shown — macOS only exposes it
  through `powermetrics`, which requires administrator privileges.
- Not notarized (no paid Apple Developer account) — first launch needs a
  right-click ▸ Open, see [DOWNLOAD.md](DOWNLOAD.md).
