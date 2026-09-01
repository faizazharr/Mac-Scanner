# Architecture

Technical notes for building from source or contributing. If you just want
to use the app, see [README.md](README.md) and [DOWNLOAD.md](DOWNLOAD.md).

## Building & running

Swift Package Manager project, packaged into a real double-clickable `.app`
bundle (not run via `swift run`, which doesn't produce a bundle macOS treats
as a normal app):

```bash
./Scripts/build_app.sh
open build/MacScanner.app
```

The build script also code-signs the app, preferring a real local signing
identity (e.g. an "Apple Development" certificate from Xcode) over an
ad-hoc signature — see [Why code signing matters](#why-code-signing-matters).

### One-time signing setup (optional)

If you don't already have a local code-signing identity (check with
`security find-identity -v -p codesigning`), `Scripts/create_signing_identity.sh`
generates a self-signed one and imports it into your login keychain. The
build script falls back to it automatically if no better identity exists.

## Why code signing matters

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

## View model pattern

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

## Project structure

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
  PerformanceMonitor.swift         Live RAM/CPU/GPU/thermal/swap snapshot + risk thresholds
  DeviceInfoCard.swift             Shared "This Mac" spec card (Home + Performance)
  DeviceInfoViewModel.swift        One-time device-info fetch, shared across tabs
  DeviceInfo.swift                 Hardware/software spec parsing (system_profiler, sysctl)
  DiskScanner.swift                `du`/`find` process wrappers (the actual scanning)
  RecommendationEngine.swift       The fixed candidate list + evaluation logic
  SizeDonutChart.swift             Swift Charts donut chart component
  SharedStyles.swift               Card background + pill styling used across every tab
  Shell.swift                      Single shared `Process`-running helper
  ToastManager.swift               Transient toast notifications (e.g. "Moved to Trash")

Scripts/
  build_app.sh                     Builds and signs the .app bundle
  create_signing_identity.sh       One-time local signing identity setup
  generate_icon.swift / .sh        Renders and packages the app icon (AppIcon.icns)

Resources/
  Info.plist                       App bundle metadata
  AppIcon.icns                     App icon

.github/workflows/
  release.yml                      Auto-builds and attaches the app to a GitHub Release on tag push
```

## Why `du`/`find` instead of a manual Swift walk

`du` is APFS-clone aware (won't double-count cloned files) and, for
directories with millions of small files (Docker/Xcode/Gradle caches), far
faster than driving `FileManager` enumeration + `stat()` from Swift directly.
`DiskScanner` shells out to both via `Process`, mildly niced so scanning
doesn't compete with the UI thread for CPU.

## Folder Browser caching

`BrowserViewModel` caches each folder's scan result by path. Revisiting a
folder (breadcrumb, tab switch and back) is instant. If you navigate away
before a scan finishes, the result is still cached once it lands in the
background — and if you navigate back into a folder that's *already* being
scanned, no duplicate scan is started; the view just waits on the one
already running.

## Performance tab internals

- **GPU utilization** is read from `ioreg`'s IOAccelerator registry
  (`Device Utilization %`) rather than `powermetrics`, which needs
  administrator privileges. NPU (Neural Engine) usage has no equivalent
  unprivileged source and isn't shown.
- **Live capture is parallelized**: the ~5-6 independent subprocess calls
  per tick (`vm_stat`, `sysctl`, `top`, `ioreg`, `ps`) run concurrently via
  `DispatchGroup` rather than sequentially.
- **The RAM-sorted process list is fetched lazily** — only while that sort
  mode is actually selected, since it's a second full process-table scan.
  Otherwise it's derived for free by re-sorting the already-fetched
  CPU-ranked list.
- **Recommendation text is debounced per metric**, not per tick: each row
  (Memory/CPU/GPU/Swap/Thermal) only regenerates its advice sentence when
  that specific metric's risk level or named offending process actually
  changes — not every 4-second poll, and not dragged along by an unrelated
  metric's jitter. Status pills still update live, matching the gauges.
