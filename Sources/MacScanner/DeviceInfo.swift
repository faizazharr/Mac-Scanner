// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation

/// Static hardware/software facts about this Mac — doesn't change during a
/// session, so callers should fetch it once (on tab appear) rather than on
/// the same timer as the live `PerformanceMonitor` snapshot.
struct DeviceInfo {
    let modelName: String
    let modelIdentifier: String
    let chip: String
    let performanceCores: Int
    let efficiencyCores: Int
    let gpuCores: Int
    let metalSupport: String
    let memoryBytes: Int64
    let macOSVersion: String
    let macOSBuild: String
    let architecture: String

    /// `nil` on a Mac without a battery (e.g. a Mac mini/Studio).
    let batteryCycleCount: Int?
    let batteryCondition: String?
    let batteryMaxCapacityPercent: Int?

    var totalCores: Int { performanceCores + efficiencyCores }
}

enum DeviceInfoProvider {
    /// Deliberately excludes identifying fields `system_profiler` also
    /// reports (serial number, hardware UUID) — not relevant to "what can
    /// this Mac do", and not something a general utility should surface.
    static func fetch() -> DeviceInfo {
        let hardware = Shell.run("/usr/sbin/system_profiler", ["SPHardwareDataType"])
        let displays = Shell.run("/usr/sbin/system_profiler", ["SPDisplaysDataType"])
        let power = Shell.run("/usr/sbin/system_profiler", ["SPPowerDataType"])
        let osVersion = Shell.run("/usr/bin/sw_vers", ["-productVersion"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let osBuild = Shell.run("/usr/bin/sw_vers", ["-buildVersion"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let arch = Shell.run("/usr/bin/uname", ["-m"])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let (perfCores, effCores) = parseCoreSplit(field(hardware, "Total Number of Cores"))

        // Broken out of the initializer below — chaining `.flatMap` directly
        // off an optional-chained `String?` resolves against Sequence.flatMap
        // (mapping characters) rather than Optional.flatMap; binding the
        // trimmed string first avoids the ambiguity.
        let capacityDigits: String? = field(power, "Maximum Capacity")?
            .trimmingCharacters(in: CharacterSet(charactersIn: "%"))
            .trimmingCharacters(in: .whitespaces)

        return DeviceInfo(
            modelName: field(hardware, "Model Name") ?? "Unknown Mac",
            modelIdentifier: field(hardware, "Model Identifier") ?? "—",
            chip: field(hardware, "Chip") ?? field(hardware, "Processor Name") ?? "—",
            performanceCores: perfCores,
            efficiencyCores: effCores,
            gpuCores: Int(field(displays, "Total Number of Cores") ?? "") ?? 0,
            metalSupport: field(displays, "Metal Support") ?? "—",
            memoryBytes: Int64(ProcessInfo.processInfo.physicalMemory),
            macOSVersion: osVersion.isEmpty ? "—" : osVersion,
            macOSBuild: osBuild,
            architecture: arch.isEmpty ? "—" : arch,
            batteryCycleCount: field(power, "Cycle Count").flatMap { Int($0) },
            batteryCondition: field(power, "Condition"),
            batteryMaxCapacityPercent: capacityDigits.flatMap { Int($0) }
        )
    }

    // MARK: - Private

    /// Extracts the value after the first "`key`: " on any line of a
    /// `system_profiler` text block.
    private static func field(_ text: String, _ key: String) -> String? {
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(key):") else { continue }
            let value = trimmed.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    /// "10 (4 Performance and 6 Efficiency)" → (4, 6). Falls back to
    /// (total, 0) if the parenthetical breakdown isn't present.
    private static func parseCoreSplit(_ raw: String?) -> (performance: Int, efficiency: Int) {
        guard let raw else { return (0, 0) }
        if let perfMatch = raw.range(of: #"(\d+) Performance"#, options: .regularExpression),
           let effMatch = raw.range(of: #"(\d+) Efficiency"#, options: .regularExpression) {
            let perf = Int(raw[perfMatch].filter(\.isNumber)) ?? 0
            let eff = Int(raw[effMatch].filter(\.isNumber)) ?? 0
            return (perf, eff)
        }
        let total = Int(raw.prefix { $0.isNumber }) ?? 0
        return (total, 0)
    }
}
