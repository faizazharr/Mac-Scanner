# MacScanner

A native macOS disk-usage screener: see where your disk space actually goes,
get risk-tagged cleanup recommendations, find oversized files, watch live
system load, and act on any of it (reveal in Finder / move to Trash) without
leaving the app.

Built because Finder's own "About This Mac ▸ Storage" view answers "what
category is big" but not "which specific folder, and is it safe to delete" —
and it has no idea your Mac is about to overheat because three heavy apps are
running at once.

## Download

**Just want to run it — no Xcode, no building?** See **[DOWNLOAD.md](DOWNLOAD.md)**
for a plain-language guide: download the zip from
[Releases](../../releases), unzip, open. Two minutes, no developer tools.

## Features

- **Home** — the landing page: this Mac's specs at a glance and a card for
  each feature below, so you pick where to go rather than being dropped into
  one specific tool.
- **Folder Browser** — drill into any folder (single click), see immediate
  children sorted by size with a relative-size bar and a percentage donut
  chart, search within the current folder, jump anywhere via a clickable
  breadcrumb (including the true filesystem root `/`, not just your home
  folder).
- **Cleanup Recommendations** — a curated list of known cleanup targets
  (caches, build artifacts, Docker/simulator data, old backups, ...) checked
  against this Mac, each tagged Safe / Review first / Manual review.
- **Large Files** — every individual file at or above a chosen size
  threshold anywhere under your home folder.
- **Performance** — live RAM/CPU/thermal/swap gauges, each with a literal
  red-line marker at its critical threshold and a concrete "what to do"
  line the moment it turns orange or red (not just a color with no
  explanation), plus which currently-running apps are heavy enough to be a
  factor if you run something else demanding alongside them.

Every list row supports **Reveal in Finder** and **Move to Trash** (with a
confirmation dialog — Trash is reversible, nothing is permanently deleted).

## Requirements

- **To run it:** macOS 14.0 or later — see [DOWNLOAD.md](DOWNLOAD.md).
- **To build it:** Xcode 15+ / Swift 5.9+ toolchain, additionally.

## Building & running

This is a Swift Package Manager project, packaged into a real double-clickable
`.app` bundle (not run via `swift run`, which doesn't produce a bundle macOS
treats as a normal app):

```bash
./Scripts/build_app.sh
open build/MacScanner.app
```

The build script also code-signs the app. It prefers a real local signing
identity (e.g. an "Apple Development" certificate from Xcode) over an ad-hoc
signature — see [Why code signing matters here](#why-code-signing-matters-here).

### One-time signing setup (optional)

If you don't already have a local code-signing identity (check with
`security find-identity -v -p codesigning`), `Scripts/create_signing_identity.sh`
generates a self-signed one and imports it into your login keychain. The
build script falls back to it automatically if no better identity exists.

## Why code signing matters here

Two unrelated macOS behaviors both depend on the app having a *stable*
signature:

1. **CPU watchdog.** Scanning a large folder tree is legitimately
   CPU-intensive. An unsigned app looks like a stray background process to
   `RunningBoard`/`symptomsd`, which can kill it outright for sustained CPU
   use — the same load a signed, "jetsam-managed" GUI app is expected to
   produce during normal use.
2. **TCC (folder-access permissions).** Ad-hoc signatures (`codesign --sign -`)
   are derived from the binary's own content, so they change on every
   rebuild. macOS treats each rebuild as a "different app" and re-prompts for
   folder access every time. A real identity's Team ID stays constant across
   rebuilds, so permission grants persist.

## Architecture

Each tab is a `View` + `ObservableObject` view model pair. Every view model
follows the same single-event-driven shape:

```swift
enum Action { case doThing, case doOtherThing(with: Value) }
func send(_ action: Action) { switch action { ... } }
```

All published state is `private(set)` — the view can only read it and raise
actions, never mutate it directly. That keeps every state transition
traceable to one call site (`send`) instead of scattered across whichever
button happened to call a public method, and keeps the view itself a thin
presentation layer.

### Project structure

```
Sources/MacScanner/
  MacScannerApp.swift             App entry point
  ContentView.swift                Tab bar root + shared UI components (SearchField, TrashConfirmation, ...)
  HomeView.swift                   Home tab: device summary + navigation cards
  Models.swift                     FileEntry, Recommendation, ByteFormat
  BrowserViewModel.swift           Folder Browser state + actions
  RecommendationsViewModel.swift   Cleanup Recommendations state + actions
  LargeFilesViewModel.swift        Large Files state + actions
  PerformanceView.swift            Performance tab UI (gauges, advice, process list)
  PerformanceViewModel.swift       Performance tab state + actions
  PerformanceMonitor.swift         Live RAM/CPU/thermal/swap snapshot + risk thresholds
  DeviceInfoCard.swift             Shared "This Mac" spec card (Home + Performance)
  DeviceInfoViewModel.swift        One-time device-info fetch, shared across tabs
  DeviceInfo.swift                 Hardware/software spec parsing (system_profiler, sysctl)
  DiskScanner.swift                `du`/`find` process wrappers (the actual scanning)
  RecommendationEngine.swift       The fixed candidate list + evaluation logic
  SizeDonutChart.swift             Swift Charts donut chart component
  SharedStyles.swift               Card background + pill styling used across every tab
  Shell.swift                      Single shared `Process`-running helper

Scripts/
  build_app.sh                     Builds and signs the .app bundle
  create_signing_identity.sh       One-time local signing identity setup
  generate_icon.swift / .sh        Renders and packages the app icon (AppIcon.icns)

Resources/
  Info.plist                       App bundle metadata
  AppIcon.icns                     App icon
```

### Why `du`/`find` instead of a manual Swift walk

`du` is APFS-clone aware (won't double-count cloned files) and, for
directories with millions of small files (Docker/Xcode/Gradle caches), far
faster than driving `FileManager` enumeration + `stat()` from Swift directly.
`DiskScanner` shells out to both via `Process`, mildly niced so scanning
doesn't compete with the UI thread for CPU.

### Caching

`BrowserViewModel` caches each folder's scan result by path. Revisiting a
folder (breadcrumb, tab switch and back) is instant. If you navigate away
before a scan finishes, the result is still cached once it lands in the
background — and if you navigate back into a folder that's *already* being
scanned, no duplicate scan is started; the view just waits on the one already
running.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Copyright

Copyright © 2026 Faiz Azhar Ristya Nugraha — see [LICENSE](LICENSE).
