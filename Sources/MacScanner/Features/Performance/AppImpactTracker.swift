// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation

/// One app's *sustained* impact over the current session.
struct AppImpactRecord: Identifiable {
    let id: String
    let name: String
    let sampleCount: Int
    let avgCPUPercent: Double
    let peakCPUPercent: Double
    let avgMemoryBytes: Int64
    let firstSeen: Date
    let lastSeen: Date
    let isSystemDaemon: Bool
    let cpuSecondsConsumed: Double

    var sessionDuration: TimeInterval { lastSeen.timeIntervalSince(firstSeen) }
}

/// Accumulates per-app CPU/RAM impact across polling ticks, grouping helper
/// processes (e.g. "Google Chrome Helper (Renderer)") under their owning
/// app so the ranking answers "which *app*", matching how a person actually
/// thinks about it.
final class AppImpactTracker {
    private struct Accumulator {
        var sampleCount = 0
        var cpuSum: Double = 0
        var cpuPeak: Double = 0
        var memSum: Int64 = 0
        var cpuSecondsConsumed: Double = 0
        var firstSeen = Date()
        var lastSeen = Date()
        var isSystemDaemon = false
    }

    private let maxTrackedApps = 300
    private var accumulators: [String: Accumulator] = [:]

    func record(_ processes: [ProcessStats], intervalSeconds: Double) {
        let now = Date()

        var perAppCPU: [String: Double] = [:]
        var perAppMem: [String: Int64] = [:]
        var perAppIsSystem: [String: Bool] = [:]

        for process in processes {
            let key = process.canonicalAppName
            perAppCPU[key, default: 0] += process.cpuPercent
            perAppMem[key, default: 0] += process.memoryBytes
            perAppIsSystem[key] = process.isSystemDaemon
        }

        for (name, cpu) in perAppCPU {
            var acc = accumulators[name] ?? Accumulator(firstSeen: now, lastSeen: now)
            acc.sampleCount += 1
            acc.cpuSum += cpu
            acc.cpuPeak = max(acc.cpuPeak, cpu)
            acc.memSum += perAppMem[name] ?? 0
            acc.cpuSecondsConsumed += (cpu / 100) * intervalSeconds
            acc.lastSeen = now
            acc.isSystemDaemon = perAppIsSystem[name] ?? false
            accumulators[name] = acc
        }

        if accumulators.count > maxTrackedApps {
            let kept = accumulators
                .sorted { $0.value.cpuSecondsConsumed > $1.value.cpuSecondsConsumed }
                .prefix(maxTrackedApps)
            accumulators = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
        }
    }

    /// Ranked by total CPU-seconds consumed. Prioritizes user applications over system daemons.
    func rankedBySustainedImpact(limit: Int = 8, userAppsOnly: Bool = false) -> [AppImpactRecord] {
        let records = accumulators
            .filter { $0.value.sampleCount >= 2 }
            .filter { !userAppsOnly || !$0.value.isSystemDaemon }
            .map { name, acc in
                AppImpactRecord(
                    id: name,
                    name: name,
                    sampleCount: acc.sampleCount,
                    avgCPUPercent: acc.cpuSum / Double(acc.sampleCount),
                    peakCPUPercent: acc.cpuPeak,
                    avgMemoryBytes: acc.memSum / Int64(acc.sampleCount),
                    firstSeen: acc.firstSeen,
                    lastSeen: acc.lastSeen,
                    isSystemDaemon: acc.isSystemDaemon,
                    cpuSecondsConsumed: acc.cpuSecondsConsumed
                )
            }

        // Sort: user apps first (or all sorted by sustained CPU)
        let sorted = records.sorted { (a, b) -> Bool in
            if userAppsOnly {
                return a.cpuSecondsConsumed > b.cpuSecondsConsumed
            }
            if a.isSystemDaemon != b.isSystemDaemon {
                return !a.isSystemDaemon // user apps come first
            }
            return a.cpuSecondsConsumed > b.cpuSecondsConsumed
        }

        return Array(sorted.prefix(limit))
    }
}
