// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// Searchable and sortable table of live macOS processes.
///
/// Displays per-process CPU usage percentages, real memory footprint, parent bundle
/// mapping, and direct SIGTERM termination actions.
struct ProcessListView: View {
    let processes: [ProcessStats]
    @ObservedObject var vm: PerformanceViewModel
    @Binding var pendingKillPID: (pid: Int32, name: String)?

    enum ProcessSort: String, CaseIterable {
        case cpu = "CPU"
        case memory = "RAM"
    }

    @State private var processSort: ProcessSort = .cpu

    private var filteredProcesses: [ProcessStats] {
        processes.filter { p in
            vm.processSearchQuery.isEmpty || p.name.localizedCaseInsensitiveContains(vm.processSearchQuery)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("All Active Processes", systemImage: "list.bullet.rectangle.portrait.fill")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                HStack {
                    Image(systemName: "magnifyingglass").font(.caption2).foregroundStyle(.secondary)
                    TextField("Filter processes…", text: $vm.processSearchQuery)
                        .textFieldStyle(.plain)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(width: 160)

                Picker("Sort by", selection: $processSort) {
                    ForEach(ProcessSort.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 140)
            }

            ForEach(filteredProcesses.prefix(20)) { process in
                let info = AppInspector.friendlyInfo(for: process.name)
                let isSelected = vm.inspectedApp?.appName.lowercased() == process.name.lowercased() ||
                                 vm.inspectedApp?.appName.lowercased() == info.displayName.lowercased()

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if isSelected {
                            vm.send(.inspectApp(""))
                        } else {
                            vm.send(.inspectApp(process.name))
                        }
                    }
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(info.color.opacity(0.15))
                                .frame(width: 24, height: 24)
                            Image(systemName: info.icon)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(info.color)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text(info.displayName)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text("PID: \(process.pid)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                            if let parent = process.parentAppName {
                                Text("Belongs to \(parent)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if processSort == .cpu {
                            Text("\(process.cpuPercent, specifier: "%.1f")% CPU")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundStyle(process.cpuPercent >= 40 ? .red : (process.cpuPercent >= 15 ? .orange : .primary))
                                .frame(width: 85, alignment: .trailing)

                            Text(ByteFormat.string(process.memoryBytes))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 75, alignment: .trailing)
                        } else {
                            Text(ByteFormat.string(process.memoryBytes))
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundStyle(process.memoryBytes >= 500 * 1024 * 1024 ? .blue : .primary)
                                .frame(width: 85, alignment: .trailing)

                            Text("\(process.cpuPercent, specifier: "%.1f")% CPU")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 75, alignment: .trailing)
                        }

                        Button {
                            pendingKillPID = (process.pid, info.displayName)
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help("Terminate process (SIGTERM)")
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(isSelected ? Color.blue.opacity(0.08) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .glassCard()
    }
}
