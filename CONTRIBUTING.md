# Contributing to MacScanner

Thank you for your interest in contributing to **MacScanner**! 🎉

MacScanner is an open-source, ultra-fast macOS disk cleaner, designer cache manager, performance monitor, and hardware diagnostics utility designed with extreme respect for user safety, privacy, and system performance.

To maintain the highest quality and safety standards, all contributors must follow the core guidelines below.

---

## 🛡️ 1. Absolute Safety & Non-Destructive Rules (Crucial)

MacScanner handles disk operations and user files. **Safety is our #1 priority.**

1. **Never Delete Application Configuration / User Data**:
   - ❌ **NEVER** target root `~/Library/Application Support/<App>` directories (e.g., `Application Support/Figma`, `Application Support/Docker`). Deleting them destroys login tokens, user drafts, plugins, and settings.
   - ✅ **ONLY** target verified temporary cache folders (e.g., `~/Library/Caches/com.figma.Desktop`, `~/Library/Caches/Adobe/After Effects`) or use official CLI prune utilities (`docker system prune -f`, `xcrun simctl delete unavailable`).
2. **Always Use `FileManager.trashItem`**:
   - ❌ **NEVER** use `rm -rf` or permanent `removeItem` for user cleanup actions.
   - ✅ **ALL** deletions must use `FileManager.default.trashItem(at:resultingItemURL:)` so actions are 100% reversible via macOS Trash.
3. **Priceless Work & Container Protection**:
   - Active database volumes, developer project containers, and git repositories must NEVER be selected by default in automated cleanup actions.

---

## ⚡ 2. Zero-Overhead & Performance Rules

MacScanner must remain invisible in system resource usage (CPU idle < 0.1%, RAM < 40 MB).

1. **No Subprocesses for Regular Files**:
   - ❌ Do NOT spawn `du` or shell processes to measure single files.
   - ✅ Use instant Mach/kernel file attributes (`URLResourceKey.fileAllocatedSizeKey` / `fileSizeKey`) which take 0 microseconds.
2. **Bounded Concurrency for Directory Scanning**:
   - Always bound concurrent `du` tasks using `DispatchSemaphore(value: 8)` and `QoS.utility` to prevent pegging all CPU cores.
3. **Zero Background Polling When Inactive**:
   - ❌ Do NOT keep timers running when a view or menu bar popover is closed or in the background.
   - ✅ Always tie polling start/stop to view lifecycle (`.appear` / `.disappear`).
4. **Non-Blocking UI Thread**:
   - Heavy I/O, directory traversals, or hardware samplers must run on `Task.detached(priority: .utility)` and update state back onto `@MainActor`.
---

## 🔒 3. Developer & Contributor Privacy Agreement

The maintainer and all community members contributing to **MacScanner** **must strictly agree to and comply with the following privacy mandate**:

> 🛡️ **Shared Privacy Commitment:**
> 1. **Zero User Data Harvesting**: Contributors must NEVER write or introduce code that collects, logs, analyzes, or transmits private user information, file lists, hardware serial numbers, or activity telemetry outside the user's Mac.
> 2. **Zero Telemetry & No Tracking**: Do not add third-party analytics SDKs, webhooks, tracking pixels, or remote network endpoints.
> 3. **100% Local & Auditable**: All new features must execute purely *in-memory* on the local Mac and remain 100% open and auditable on GitHub.

---

## 🏗️ 4. SOLID Architecture & Dependency Injection

Every engine and view model in MacScanner strictly follows **SOLID Principles** and **Single-Event Driven (UDF)** patterns:

1. **Dependency Inversion (DIP)**:
   - All data sources, scanners, and shell query providers must conform to segregated protocols in [`Sources/MacScanner/Core/Protocols/ServiceProtocols.swift`](Sources/MacScanner/Core/Protocols/ServiceProtocols.swift).
   - Inject services into ViewModels via constructor: `init(service: any MyServiceProtocol = DefaultMyService())`.
2. **Single-Event Driven (UDF)**:
   - State flows unidirectionally via `send(_ action:)`.
   - Views read state from `@Published private(set)` properties and never mutate state directly.

```swift
@MainActor
final class ExampleViewModel: ObservableObject {
    enum Action {
        case appearIfNeeded
        case rescan
        case doAction(URL)
    }

    @Published private(set) var items: [Item] = []
    @Published private(set) var isScanning = false

    private let service: any ExampleServiceProtocol

    init(service: any ExampleServiceProtocol = DefaultExampleService()) {
        self.service = service
    }

    func send(_ action: Action) {
        switch action {
        case .appearIfNeeded:
            guard items.isEmpty, !isScanning else { return }
            scan()
        case .rescan:
            scan()
        case .doAction(let url):
            handleAction(url)
        }
    }
}
```

3. **Modular Object-Oriented UI Components**:
   - Use reusable components from [`Sources/MacScanner/Core/UI/UIComponents.swift`](Sources/MacScanner/Core/UI/UIComponents.swift) (`MetricTileComponent`, `SectionHeaderComponent`, `FilterSegmentComponent`) instead of rewriting custom tile styling.

---

## ⌨️ 4. Hardware Testing & Diagnostic Rules

When adding or modifying hardware testing modules ([`DeviceTestingEngine.swift`](Sources/MacScanner/Features/HardwareDiagnostics/DeviceTestingEngine.swift)):
- **No Trapping Screens**: Fullscreen diagnostic views are embedded in root view hierarchies with clear `[ESC]` dismissals.
- **Safe Audio Teardown**: Never stop audio engines synchronously inside render completion blocks (prevents deadlock).
- **Shortcut Interception**: Keystroke testing must safely intercept combinations (`Cmd+Q`, `Cmd+W`, `Tab`) without quitting the application or triggering system actions.

---

## 🚀 5. Development & Build Workflow

### Prerequisites
- macOS 14.0+ (Sonoma or Sequoia)
- Xcode 15+ or Swift 5.9+ command-line tools

### Building, Linting & Testing
```bash
# Run Linter (SwiftLint)
swiftlint

# Build Swift Package
swift build

# Build and Sign MacScanner.app
./Scripts/build_app.sh

# Build Release Disk Image (.dmg installer)
./Scripts/build_dmg.sh release

# Launch the Application
open build/MacScanner.app
```

---

## 📝 6. Linter & Pull Request Guidelines

MacScanner uses **SwiftLint** and **GitHub Actions CI** for automated code quality checks on every PR:

Before submitting a PR:
1. Run `swiftlint` locally to fix any formatting or safety violations (e.g. force-unwrapping `!`).
2. Ensure `swift build` passes with **0 errors and 0 warnings**.
3. Run `./Scripts/build_dmg.sh release` to verify bundle creation and code signing.
4. Test on your Mac (verify that no UI lags occur, memory usage remains minimal, and safe deletion works properly).
5. Fill out the PR template completely with a clear description and screenshots/GIFs if modifying UI.

Thank you for helping keep MacScanner fast, safe, and beautiful! 🍏✨

---

## ☕ Support the Project

If you love MacScanner and want to support its open-source development and maintenance:
- 🇮🇩 **Donasi (Indonesia)**: [**https://saweria.co/izarakuro**](https://saweria.co/izarakuro)

