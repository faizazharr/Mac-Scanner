// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation

/// Provider for graphics hardware acceleration metrics via macOS `IOAccelerator` registry.
enum GPUAcceleratorProvider {

    /// Queries the IOKit registry for active GPU device utilization percentage.
    static func queryGPUUtilizationPercent() -> Double? {
        let output = Shell.run("/usr/sbin/ioreg", ["-r", "-c", "IOAccelerator", "-d", "1"])
        guard let match = output.range(of: #""Device Utilization %"=(\d+)"#, options: .regularExpression) else {
            return nil
        }
        let digits = output[match].filter(\.isNumber)
        return digits.isEmpty ? nil : Double(digits)
    }
}
