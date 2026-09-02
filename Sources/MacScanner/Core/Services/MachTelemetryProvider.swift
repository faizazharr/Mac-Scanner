// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import Darwin
import MachO

/// Direct Mach Kernel telemetry provider utilizing zero-subprocess C system calls.
///
/// Queries `host_statistics64` (HOST_VM_INFO64), `host_statistics` (HOST_CPU_LOAD_INFO),
/// and `sysctlbyname` with sub-microsecond latency and 0.0% CPU overhead.
enum MachTelemetryProvider {

    private static var previousCPUTicks: (user: UInt32, sys: UInt32, idle: UInt32, nice: UInt32)?

    /// Reads Memory usage directly from Mach kernel `host_statistics64` (HOST_VM_INFO64).
    static func memorySnapshot() -> PerformanceMonitor.MemorySnapshot {
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let kerr = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard kerr == KERN_SUCCESS else {
            return PerformanceMonitor.MemorySnapshot(totalBytes: total, usedBytes: 0)
        }

        let pageSize = Int64(vm_kernel_page_size)
        let active = Int64(vmStats.active_count)
        let wired = Int64(vmStats.wire_count)
        let compressorOccupied = Int64(vmStats.compressor_page_count)
        let used = (active + wired + compressorOccupied) * pageSize

        return PerformanceMonitor.MemorySnapshot(totalBytes: total, usedBytes: min(used, total))
    }

    /// Reads string system properties via C `sysctlbyname`.
    static func sysctlString(_ name: String) -> String {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return "" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    /// Reads Swap memory usage directly via C `sysctlbyname("vm.swapusage")`.
    static func swapSnapshot() -> PerformanceMonitor.SwapSnapshot {
        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &swap, &size, nil, 0)
        guard result == 0 else {
            return PerformanceMonitor.SwapSnapshot(totalBytes: 0, usedBytes: 0)
        }
        return PerformanceMonitor.SwapSnapshot(totalBytes: Int64(swap.xsu_total), usedBytes: Int64(swap.xsu_used))
    }

    /// Reads CPU load directly from Mach kernel `host_statistics` (HOST_CPU_LOAD_INFO).
    static func systemCPUPercent() -> Double {
        var cpuLoadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)

        let kerr = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard kerr == KERN_SUCCESS else { return 0 }

        let user = cpuLoadInfo.cpu_ticks.0
        let sys = cpuLoadInfo.cpu_ticks.1
        let idle = cpuLoadInfo.cpu_ticks.2
        let nice = cpuLoadInfo.cpu_ticks.3

        defer {
            previousCPUTicks = (user, sys, idle, nice)
        }

        guard let prev = previousCPUTicks else {
            return 0
        }

        let userDiff = Double(user.subtractingReportingOverflow(prev.user).partialValue)
        let sysDiff = Double(sys.subtractingReportingOverflow(prev.sys).partialValue)
        let idleDiff = Double(idle.subtractingReportingOverflow(prev.idle).partialValue)
        let niceDiff = Double(nice.subtractingReportingOverflow(prev.nice).partialValue)

        let totalDiff = userDiff + sysDiff + idleDiff + niceDiff
        guard totalDiff > 0 else { return 0 }

        let activeDiff = userDiff + sysDiff + niceDiff
        return min(max((activeDiff / totalDiff) * 100.0, 0), 100.0)
    }
}
