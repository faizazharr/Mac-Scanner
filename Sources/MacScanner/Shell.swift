// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation

/// Runs a command-line tool and captures its stdout as a string. The single
/// place every `Process`+`Pipe` invocation in the app goes through.
enum Shell {
    /// Runs `path` with `args` and returns its stdout, or `""` if it couldn't
    /// be launched. Blocks the calling thread until the process exits —
    /// callers are responsible for dispatching off the main thread.
    static func run(_ path: String, _ args: [String] = []) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Same as `run`, but the target binary is run under `nice` at the given
    /// priority so it doesn't compete with the UI thread for CPU.
    static func runNiced(_ path: String, _ args: [String], niceLevel: Int = 3) -> String {
        run("/usr/bin/nice", ["-n", String(niceLevel), path] + args)
    }
}
