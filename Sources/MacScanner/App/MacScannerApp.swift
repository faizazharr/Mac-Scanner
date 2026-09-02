// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

/// App entry point: the main window plus a menu bar extra, both reading
/// from the same live `PerformanceViewModel`/`DeviceInfoViewModel` — one
/// polling loop regardless of which one (or both) is currently visible.
@main
struct MacScannerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var deviceVM = DeviceInfoViewModel()
    @StateObject private var performanceVM = PerformanceViewModel()

    /// Named so the menu bar's "Open MacScanner" button can reliably reopen
    /// it via `openWindow(id:)` — this SDK doesn't expose the zero-argument
    /// `openWindow()` overload for an unnamed WindowGroup.
    static let mainWindowID = "main"

    var body: some Scene {
        Window("MacScanner", id: Self.mainWindowID) {
            ContentView(deviceVM: deviceVM, performanceVM: performanceVM)
                .frame(minWidth: 1040, minHeight: 600)
        }
        .windowResizability(.automatic)

        MenuBarExtra {
            MenuBarContentView(vm: performanceVM, deviceVM: deviceVM)
        } label: {
            MenuBarLabel(vm: performanceVM)
        }
        .menuBarExtraStyle(.window)
    }
}
