// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation

/// Represents the physical form factor and cooling envelope of the Mac.
enum DeviceFormFactor: String, Sendable {
    case fanlessLaptop = "Fanless Laptop"       // MacBook Air (Passive Aluminum Cooling)
    case activeFanLaptop = "Active Fan Laptop"   // MacBook Pro (Active Dual-Fan System)
    case desktop = "Desktop Workstation"        // Mac mini, Mac Studio, Mac Pro, iMac (AC Power)

    var coolingDescription: String {
        switch self {
        case .fanlessLaptop:
            return "Passive Cooling (Silent & Fanless)"
        case .activeFanLaptop:
            return "Active Air Cooling (Dual Thermal Fans)"
        case .desktop:
            return "High Thermal Headroom (Desktop Ventilation)"
        }
    }
}

/// Represents the memory capacity tier for intelligent workload scaling.
enum MemoryCapacityTier: String, Sendable {
    case base = "Base (8 GB – 12 GB)"
    case mainstream = "Mainstream (16 GB – 24 GB)"
    case pro = "Pro / Max (32 GB – 64 GB)"
    case ultra = "Ultra / Workstation (96 GB – 192 GB+)"

    var description: String {
        switch self {
        case .base: return "Lightweight to standard multitasking; aggressive macOS memory compression."
        case .mainstream: return "High multitasking headroom for development and creative tools."
        case .pro: return "Heavy multi-app workflows, virtualization, and 4K/8K media editing."
        case .ultra: return "Massive dataset processing, local LLMs, and 3D rendering pipelines."
        }
    }
}

/// Static hardware/software facts about this Mac — doesn't change during a
/// session, so callers should fetch it once (on tab appear) rather than on
/// the same timer as the live `PerformanceMonitor` snapshot.
struct DeviceInfo: Sendable {
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

    /// Form factor and cooling profile
    var formFactor: DeviceFormFactor {
        let id = modelIdentifier.lowercased()
        let name = modelName.lowercased()
        if id.contains("macbookair") || id.contains("neo") || name.contains("neo") || id == "macbook10,1" || id == "macbook9,1" || id == "macbook8,1" {
            return .fanlessLaptop
        } else if id.contains("macbook") {
            return .activeFanLaptop
        } else {
            return .desktop
        }
    }

    /// Proportional memory tier
    var memoryTier: MemoryCapacityTier {
        let gigabytes = memoryBytes / (1024 * 1024 * 1024)
        if gigabytes < 14 {
            return .base
        } else if gigabytes < 28 {
            return .mainstream
        } else if gigabytes < 72 {
            return .pro
        } else {
            return .ultra
        }
    }

    var isAppleSilicon: Bool {
        architecture.contains("arm64") || chip.contains("Apple")
    }

    /// `nil` on a Mac without a battery (e.g. a Mac mini/Studio).
    let batteryCycleCount: Int?
    let batteryCondition: String?
    let batteryMaxCapacityPercent: Int?

    // Connectivity & Peripherals Hardware
    let wifiCardModel: String
    let wifiStatus: String
    let wifiIsInstalled: Bool

    let bluetoothChipset: String
    let bluetoothStatus: String
    let bluetoothIsInstalled: Bool

    let speakerModel: String
    let speakerStatus: String
    let speakerIsInstalled: Bool

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
        let wifiData = Shell.run("/usr/sbin/system_profiler", ["SPAirPortDataType"])
        let btData = Shell.run("/usr/sbin/system_profiler", ["SPBluetoothDataType"])
        let audioData = Shell.run("/usr/sbin/system_profiler", ["SPAudioDataType"])

        let osVersion = Shell.run("/usr/bin/sw_vers", ["-productVersion"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let osBuild = Shell.run("/usr/bin/sw_vers", ["-buildVersion"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let arch = Shell.run("/usr/bin/uname", ["-m"])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let (perfCores, effCores) = parseCoreSplit(field(hardware, "Total Number of Cores"))

        let capacityDigits: String? = field(power, "Maximum Capacity")?
            .trimmingCharacters(in: CharacterSet(charactersIn: "%"))
            .trimmingCharacters(in: .whitespaces)

        // Parse Wi-Fi
        let wifiInstalled = wifiData.contains("Interfaces:") || wifiData.contains("en0")
        let phyModes = field(wifiData, "Supported PHY Modes") ?? "802.11 a/b/g/n/ac/ax"
        let wifiModel = phyModes.contains("ax") ? "Wi-Fi 6E (802.11ax)" : (phyModes.contains("ac") ? "Wi-Fi 5 (802.11ac)" : "AirPort Extreme")
        let rawWifiStatus = field(wifiData, "Status") ?? (wifiInstalled ? "Ready" : "Not Detected")
        let wifiStatusLabel = rawWifiStatus == "Connected" ? "Connected & Normal" : (wifiInstalled ? "Installed & Ready (Normal)" : "Not Detected / Error")

        // Parse Bluetooth
        let btInstalled = btData.contains("Bluetooth Controller:")
        let btChip = field(btData, "Chipset") ?? "Apple Bluetooth Controller"
        let btTransport = field(btData, "Transport") ?? "PCIe"
        let btModel = "\(btChip) (\(btTransport))"
        let btStatusLabel = btInstalled ? "Installed & Normal" : "Not Detected / Error"

        // Parse Audio / Speakers
        let audioInstalled = audioData.contains("MacBook") || audioData.contains("Speakers") || audioData.contains("Output Channels")
        let speakerName = field(audioData, "Output Source") ?? "MacBook High-Fidelity Speakers"
        let sampleRate = field(audioData, "Current SampleRate") ?? "48000"
        let sampleRateKHz = (Int(sampleRate) ?? 48000) / 1000
        let speakerModel = "\(speakerName) (\(sampleRateKHz) kHz Stereo)"
        let speakerStatusLabel = audioInstalled ? "Installed & Normal" : "Not Detected / Error"

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
            batteryMaxCapacityPercent: capacityDigits.flatMap { Int($0) },
            wifiCardModel: wifiModel,
            wifiStatus: wifiStatusLabel,
            wifiIsInstalled: wifiInstalled,
            bluetoothChipset: btModel,
            bluetoothStatus: btStatusLabel,
            bluetoothIsInstalled: btInstalled,
            speakerModel: speakerModel,
            speakerStatus: speakerStatusLabel,
            speakerIsInstalled: audioInstalled
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
