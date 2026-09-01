// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation

/// The fixed list of known cleanup targets (caches, build artifacts, VM
/// disks, backups, ...) checked against this Mac, and the logic to evaluate
/// which of them actually exist and how big they are.
enum RecommendationEngine {
    static func candidates() -> [Recommendation] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let lib = home.appendingPathComponent("Library")

        var list: [(String, URL, String, RiskLevel)] = [
            ("User Cache Files", lib.appendingPathComponent("Caches"),
             "App and system caches. Regenerated automatically as needed.", .safe),

            ("Trash", home.appendingPathComponent(".Trash"),
             "Already deleted files waiting for permanent removal.", .safe),

            ("Xcode DerivedData", lib.appendingPathComponent("Developer/Xcode/DerivedData"),
             "Build intermediates. Safe to delete, Xcode rebuilds on next build.", .safe),

            ("Xcode Archives", lib.appendingPathComponent("Developer/Xcode/Archives"),
             "Old app archives from Xcode Organizer. Check you don't need them for App Store re-submission.", .caution),

            ("iOS/Simulator Devices", lib.appendingPathComponent("Developer/CoreSimulator/Devices"),
             "Simulator disk images. Safe to erase unused simulators via Xcode > Devices.", .caution),

            ("Homebrew Cache", lib.appendingPathComponent("Caches/Homebrew"),
             "Downloaded package archives. Run `brew cleanup` instead of deleting manually.", .safe),

            ("npm Cache", home.appendingPathComponent(".npm"),
             "Downloaded npm package tarballs. Run `npm cache clean --force` instead of deleting manually.", .safe),

            ("Yarn Cache", lib.appendingPathComponent("Caches/Yarn"),
             "Downloaded yarn package cache.", .safe),

            ("pip Cache", lib.appendingPathComponent("Caches/pip"),
             "Downloaded Python package cache.", .safe),

            ("CocoaPods Cache", home.appendingPathComponent(".cocoapods/repos"),
             "CocoaPods spec repos and downloaded pods.", .caution),

            ("Docker Data", lib.appendingPathComponent("Containers/com.docker.docker"),
             "Docker Desktop images, containers, volumes. Deleting removes all local images/containers.", .caution),

            ("iOS Device Backups", lib.appendingPathComponent("Application Support/MobileSync/Backup"),
             "Full iPhone/iPad backups from Finder/iTunes. Often huge — verify you don't need them before deleting.", .caution),

            ("Mail Downloads", lib.appendingPathComponent("Containers/com.apple.mail/Data/Library/Mail Downloads"),
             "Cached email attachments. Safe to delete, re-downloads on open.", .safe),

            ("System Logs", lib.appendingPathComponent("Logs"),
             "App and diagnostic logs. Safe to delete.", .safe),

            ("Application Support (review)", lib.appendingPathComponent("Application Support"),
             "Mixed: app data, some large caches disguised as support files. Inspect subfolders before deleting anything.", .manual),

            ("Downloads Folder", home.appendingPathComponent("Downloads"),
             "Installers/files you downloaded. Sort by date, remove what you no longer need.", .manual),

            ("Desktop", home.appendingPathComponent("Desktop"),
             "Files on your Desktop. Worth a manual look if unusually large.", .manual),

            ("Photos Library", home.appendingPathComponent("Pictures/Photos Library.photoslibrary"),
             "Your Photos library. Do not delete — consider offloading originals to iCloud instead.", .manual),

            ("Time Machine Local Snapshots", URL(fileURLWithPath: "/System/Volumes/Data/.MobileBackups"),
             "Local Time Machine snapshots macOS manages automatically; usually not directly deletable.", .manual),

            ("Adobe Media Cache", lib.appendingPathComponent("Application Support/Adobe/Common"),
             "Adobe apps' media cache files.", .caution),

            ("Xcode iOS DeviceSupport", lib.appendingPathComponent("Developer/Xcode/iOS DeviceSupport"),
             "Debug symbols per iOS version connected to Xcode. Safe to delete old OS versions you no longer debug on.", .safe),
        ]

        // Deduplicate in case of path overlaps (defensive, not expected).
        list.removeAll { _ in false }

        return list.map { title, url, explanation, risk in
            Recommendation(title: title, path: url, explanation: explanation, risk: risk)
        }
    }

    static func evaluate(_ recommendations: [Recommendation], progress: @escaping (Recommendation) -> Void, completion: @escaping ([Recommendation]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            var results: [Recommendation] = []
            let semaphore = DispatchSemaphore(value: 6)
            let group = DispatchGroup()
            let lock = NSLock()

            for var rec in recommendations {
                group.enter()
                semaphore.wait()
                DispatchQueue.global(qos: .userInitiated).async {
                    defer {
                        semaphore.signal()
                        group.leave()
                    }
                    var isDir: ObjCBool = false
                    let exists = fm.fileExists(atPath: rec.path.path, isDirectory: &isDir)
                    rec.exists = exists
                    if exists {
                        rec.sizeBytes = DiskScanner.size(of: rec.path)
                    }
                    lock.lock()
                    results.append(rec)
                    lock.unlock()
                    DispatchQueue.main.async { progress(rec) }
                }
            }

            group.wait()
            let sorted = results
                .filter { $0.exists }
                .sorted { $0.sizeBytes > $1.sizeBytes }
            DispatchQueue.main.async { completion(sorted) }
        }
    }
}
