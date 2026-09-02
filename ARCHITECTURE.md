# Architecture & Technical Design

Technical documentation for building, understanding, and contributing to **MacScanner**.

---

## 🚀 Building & Packaging

MacScanner is a native Swift Package Manager project, packaged as a Universal 2 (`arm64` + `x86_64`) double-clickable `.app` bundle and a compressed `.dmg` installer:

```bash
# Build MacScanner.app (Universal 2 Binary for Apple Silicon & Intel)
./Scripts/build_app.sh release

# Build and sign MacScanner.dmg installer disk image
./Scripts/build_dmg.sh release

# Run the app
open build/MacScanner.app
```

---

## 🏛️ Unidirectional MVI View Model Pattern

Each feature tab is built as a pair of SwiftUI `View` and `@MainActor` `ObservableObject` View Model:

```swift
@MainActor
final class ExampleViewModel: ObservableObject {
    enum Action {
        case appearIfNeeded
        case rescan
        case doAction(URL)
    }

    @Published private(set) var state: State = ...

    func send(_ action: Action) {
        switch action { ... }
    }
}
```

- **Unidirectional Event Flow**: Views only dispatch actions via `vm.send(.action)`.
- **`private(set)` Encapsulation**: Published state is read-only to views.
- **View Lifecycle Binding**: Polling and background work start on `.appear` and stop immediately on `.disappear`.

---

## 📂 Clean Modular Project Structure

```
Sources/MacScanner/
├── App/
│   ├── MacScannerApp.swift             # App entry point & MenuBar Extra configuration
│   ├── ContentView.swift               # Sidebar layout, tab routing & top-level environment
│   └── MenuBarView.swift               # Menu bar popover with live telemetry & quick actions
│
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift              # Main landing overview & disk capacity gauge
│   │   ├── DeviceInfoCard.swift        # Hardware, chips, battery & peripheral badges
│   │   └── DeviceInfoViewModel.swift   # Hardware specifications state & service bindings
│   │
│   ├── Uninstaller/
│   │   ├── AppUninstallerView.swift    # App leftovers cleaner & disk footprint browser
│   │   ├── AppUninstallerEngine.swift  # Concurrent disk sizing & root leftovers finder
│   │   └── AppInspector.swift          # Deep root directory scanner (~/Library/...)
│   │
│   ├── Screening/
│   │   ├── ScreeningView.swift         # Screen time, uptime & battery impact dashboard
│   │   └── ScreeningEngine.swift       # Daily screen hours calculation & app power tracker
│   │
│   ├── Performance/
│   │   ├── PerformanceView.swift       # Live gauges, sparklines & inline root-cause inspector
│   │   ├── PerformanceViewModel.swift  # Telemetry state management & process actions
│   │   └── AppImpactTracker.swift      # Rolling sustained CPU/RAM load analyzer
│   │
│   ├── HardwareDiagnostics/
│   │   ├── DeviceTestingView.swift     # Interactive screen, audio, mic, keyboard & trackpad tests
│   │   └── DeviceTestingEngine.swift   # CoreAudio tone generator & hardware event monitors
│   │
│   ├── Recommendations/
│   │   ├── RecommendationsViewModel.swift # Reversible trash staging & prune triggers
│   │   └── RecommendationEngine.swift  # Rule-based disk cleanup target evaluator
│   │
│   ├── DesignerBrowser/
│   │   ├── DesignerBrowserView.swift   # Figma/Adobe caches & browser bloat cleaner
│   │   ├── DesignerBrowserViewModel.swift # Designer cache state & actions
│   │   └── DesignerBrowserScanner.swift# 10+ Browser extension detector & cache inspector
│   │
│   └── LargeFiles/
│       ├── LargeFilesViewModel.swift   # Threshold-based large file finder
│       └── BrowserViewModel.swift      # Folder disk hierarchy tree navigator
│
└── Core/
    ├── Protocols/
    │   └── ServiceProtocols.swift      # SOLID service contracts for Dependency Injection
    ├── Models/
    │   ├── Models.swift                # Core models (FileEntry, Recommendation, ByteFormat)
    │   └── DeviceInfo.swift            # Hardware specification & battery data models
    ├── Services/
    │   ├── PerformanceMonitor.swift    # Mach kernel & host statistics telemetry provider
    │   ├── DiskScanner.swift           # High-speed bounded du directory crawler
    │   ├── StorageHistoryStore.swift   # On-device persistent storage growth tracker
    │   ├── PermissionHelper.swift      # Full Disk Access & permission verification
    │   └── Shell.swift                 # Safe asynchronous process runner
    └── UI/
        ├── UIComponents.swift          # Atomic UI components (MetricTile, SectionHeader, FilterSegment)
        ├── SharedStyles.swift          # Design system, glass cards & color tokens
        ├── SizeDonutChart.swift        # Interactive donut chart for storage breakdown
        └── ToastManager.swift          # Global non-blocking notification toast engine
```

Scripts/
  ├── build_app.sh                    # Compiles and code-signs build/MacScanner.app
  ├── build_dmg.sh                    # Packages drag-and-drop installer build/MacScanner.dmg
  ├── create_signing_identity.sh      # Generates local self-signed certificate if needed
  └── generate_icon.swift / .sh       # Programmatically renders MacScanner app icon (.icns)

Resources/
  ├── Info.plist                      # Bundle metadata & privacy usage descriptions
  └── AppIcon.icns                    # Multi-resolution macOS icon bundle

.github/
  ├── workflows/release.yml           # Automated GitHub Release builder on version tags
  ├── pull_request_template.md        # Contributor PR checklist
  └── ISSUE_TEMPLATE/                 # Bug report and Feature request templates
```

---

## ⚡ Performance Architecture Principles

1. **Zero-Subprocess File Sizing**: Regular files use instantaneous kernel stat via `URLResourceKey.fileAllocatedSizeKey` (0 subprocesses, nanosecond resolution).
2. **In-Memory Size Caching**: Directory sizes are cached for 30 seconds to provide instant (0ms) filtering and sorting.
3. **Zero Idle Overhead**: Polling timers stop completely (0% CPU) when views or menu bar popovers are closed.
4. **Mach Kernel Telemetry**: System metrics bypass heavy command-line tools by calling native Mach kernel APIs directly.
