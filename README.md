# MacScanner ⚡

**MacScanner** is an ultra-fast, lightweight (1.7 MB binary), and privacy-first macOS utility designed to monitor disk health, clean application leftovers, analyze system performance, and run hardware diagnostics — all in one native app with 0% background overhead.

---

## 🔒 Privacy & Zero-Data Collection Guarantee

> [!IMPORTANT]
> ### 🛡️ Official Developer Privacy Mandate:
>
> **The developer DOES NOT COLLECT, HARVEST, TRACK, TRANSMIT, OR STORE ANY PRIVATE INFORMATION OR TELEMETRY** from users who install this application, nor from community members contributing to this project.
> - **100% On-Device Local Processing**: All disk analysis, leftover scans, memory/CPU/battery metrics, and hardware tests run strictly in local memory on your Mac.
> - **Zero Telemetry & No Remote Servers**: MacScanner does not connect to any cloud backend, contains zero tracking SDKs, and never phones home. What happens on your Mac stays on your Mac.

---

## 🚀 Key Features

### 🏠 1. System Overview & Hardware Specs
- Instant hardware detection: **Apple Silicon Chip (M-Series)**, CPU/GPU Cores, Unified Memory, and macOS Build.
- **Hardware Peripherals Check**: Real-time status for **Wi-Fi 6E/6 Card Interface**, **Bluetooth Controller**, and **Built-in Speaker System**.
- **Battery Health**: Maximum capacity percentage, cycle count, and condition (Normal/Service).

### 🗑️ 2. Deep Root App Uninstaller
- Scans installed `.app` bundles and uncovers **all hidden root leftovers** across `~/Library/Application Support`, `Caches`, `Containers`, `Group Containers`, `Logs`, and `LaunchAgents`.
- **Automatic Instant Sizing**: Pre-calculates accurate disk space for all installed applications concurrently.
- **Safe Trash Migration**: Uses native macOS Trash (`FileManager.trashItem`) so deletions remain 100% reversible.
- **Self-Uninstall Protection**: Built-in safeguards prevent accidental deletion of MacScanner itself.

### ⏱️ 3. Mac & App Screen Time Screening
- Uptime tracking, estimated active daily screen hours, and battery cycle health.
- **Interactive Statistics Charts**: Compare screen duration, battery impact percentage, and disk footprint using Apple Swift Charts with customizable filters (`[ Screen Time | Battery Impact | Disk Size ]`).

### ⚡ 4. Live System Performance & Root-Cause Inspector
- Real-time Mach-kernel telemetry for **Memory, CPU, GPU, Swap, and Thermal State** with 0% idle CPU footprint.
- **Inline Root-Cause Deep Dive**: Click any process to inspect worker threads, browser extensions, and web cache without disruptive pop-up dialogs. Direct controls for **Force Quit**, **Clear Cache**, and **Activity Monitor**.

### 🎨 5. Designer & Browser Bloat Screener
- Tailored for designers and developers: Clean oversized caches from **Figma, Adobe Creative Cloud (Photoshop, Illustrator, Premiere, After Effects)**, and browsers (Chrome, Safari, Firefox, Edge, Arc) without deleting user drafts or login sessions.

### 🛠️ 6. Hardware Diagnostics & Testing
- **Screen Dead Pixel Tester**: Multi-color canvas with auto-hiding HUD and instant `ESC` exit.
- **Stereo Speaker L/R Engine**: Test left and right stereo audio channels independently.
- **Microphone Level Meter**: Real-time decibel input gauge.
- **Keyboard & Shortcut Tester**: Full 100% isolated key-code testing.
- **Trackpad Multi-Touch Test**: Physical click, haptic feedback, and multi-finger gesture canvas.

---

## 📦 Installation & Download

**[⬇ Download Latest MacScanner.dmg](../../releases/latest)**

1. Open `MacScanner.dmg`.
2. Drag **MacScanner.app** into your **Applications** folder.
3. Open the app and grant Full Disk Access when prompted for complete root cleaning capabilities.

---

## 🤝 Contributor Guidelines & Standards

We welcome open-source contributions! To ensure MacScanner remains lightweight, robust, and safe, all contributors must strictly adhere to the following standards:

1. **Strict Zero-Telemetry Policy**:
   - PRs must **NEVER** introduce external tracking, third-party analytics SDKs, or network telemetry requests.
2. **SOLID & Single-Event Driven (UDF) Architecture**:
   - Separate concerns across protocols in [`Sources/MacScanner/Core/Protocols/ServiceProtocols.swift`](Sources/MacScanner/Core/Protocols/ServiceProtocols.swift).
   - All state mutations must flow through unidirectional action dispatches (`send(_ action:)`).
   - Use dependency injection (`init(service: ...)`) for all ViewModels.
3. **Zero-Bloat & Ultra-Lightweight Footprint**:
   - Keep the binary size minimal (compiled with `-Osize` and symbol stripping).
   - Never spawn unnecessary CLI sub-processes when native Darwin/Mach APIs are available.
   - Stop background polling timers immediately when views disappear (`appear`/`disappear` lifecycle).
4. **Safety First (Reversible Deletions)**:
   - Always use `FileManager.default.trashItem` for file cleanups. Never use `rm -rf` or permanent deletion APIs.
5. **Code Style & Concurrency**:
   - Swift 6 strict concurrency compliance (`@MainActor` for UI, `Task.detached` for heavy I/O).
   - Format code cleanly and verify with `swiftlint`.

For detailed developer workflows and setup instructions, see [**`CONTRIBUTING.md`**](CONTRIBUTING.md) and [**`RELEASING.md`**](RELEASING.md).

---

## 🚀 Release & Semantic Versioning

For instructions on publishing releases via Git tags, see [**`RELEASING.md`**](RELEASING.md).

---

## 📄 Copyright

Copyright © 2026 **Faiz Azhar Ristya Nugraha**. All rights reserved.
