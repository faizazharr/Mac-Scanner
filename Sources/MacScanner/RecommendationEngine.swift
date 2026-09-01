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

        let list: [(String, URL, String, RiskLevel, RecommendationCategory, String)] = [
            ("User Cache Files", lib.appendingPathComponent("Caches"),
             "App and system caches. Safe to clear; regenerated automatically as needed.",
             .safe, .cache, "sparkles"),

            ("Trash", home.appendingPathComponent(".Trash"),
             "Already deleted files waiting for permanent emptying.",
             .safe, .cache, "trash.fill"),

            ("Xcode DerivedData", lib.appendingPathComponent("Developer/Xcode/DerivedData"),
             "Build intermediates and index caches. Xcode rebuilds these automatically on next build.",
             .safe, .developer, "hammer.fill"),

            ("Xcode Archives", lib.appendingPathComponent("Developer/Xcode/Archives"),
             "Old app build archives from Xcode Organizer. Safe to delete if not needed for symbolication.",
             .caution, .developer, "archivebox.fill"),

            ("iOS/Simulator Devices", lib.appendingPathComponent("Developer/CoreSimulator/Devices"),
             "Simulator disk images and installed runtime apps. Erase unused simulators to reclaim massive space.",
             .caution, .developer, "iphone.gen3"),

            ("Homebrew Cache", lib.appendingPathComponent("Caches/Homebrew"),
             "Downloaded package archives and bottles.",
             .safe, .developer, "mug.fill"),

            ("npm Cache", home.appendingPathComponent(".npm"),
             "Downloaded npm package tarballs and metadata cache.",
             .safe, .developer, "shippingbox.fill"),

            ("Yarn Cache", lib.appendingPathComponent("Caches/Yarn"),
             "Downloaded Yarn package cache.",
             .safe, .developer, "cube.box.fill"),

            ("pip Cache", lib.appendingPathComponent("Caches/pip"),
             "Downloaded Python package wheels and archives.",
             .safe, .developer, "chevron.left.forwardslash.chevron.right"),

            ("CocoaPods Cache", home.appendingPathComponent(".cocoapods/repos"),
             "CocoaPods spec repos and downloaded pods.",
             .caution, .developer, "puzzlepiece.extension.fill"),

            ("Docker Data", lib.appendingPathComponent("Containers/com.docker.docker"),
             "Docker Desktop container layers, virtual disk (raw.qcow2/Docker.raw), and volumes.",
             .caution, .developer, "shippingbox.and.arrow.backward.fill"),

            ("iOS Device Backups", lib.appendingPathComponent("Application Support/MobileSync/Backup"),
             "Full iPhone and iPad backups created via Finder/iTunes.",
             .caution, .backup, "ipad.and.iphone"),

            ("Mail Downloads", lib.appendingPathComponent("Containers/com.apple.mail/Data/Library/Mail Downloads"),
             "Cached email attachments. Safe to delete; re-downloads when you reopen the email.",
             .safe, .cache, "envelope.badge.shield.half.filled"),

            ("System & Diagnostic Logs", lib.appendingPathComponent("Logs"),
             "App diagnostic logs and crash logs. Safe to delete.",
             .safe, .logs, "doc.text.magnifyingglass"),

            ("Adobe Media Cache", lib.appendingPathComponent("Application Support/Adobe/Common"),
             "Adobe Premiere / After Effects peak files and audio scratch caches.",
             .caution, .cache, "photo.stack.fill"),

            ("Xcode iOS DeviceSupport", lib.appendingPathComponent("Developer/Xcode/iOS DeviceSupport"),
             "Debug symbols per iOS device connected to Xcode. Safe to delete old OS versions you no longer test.",
             .safe, .developer, "wrench.and.screwdriver.fill"),

            ("Application Support (Inspect)", lib.appendingPathComponent("Application Support"),
             "Mixed application data. Contains app configurations as well as large leftover caches.",
             .manual, .user, "folder.badge.gearshape"),

            ("Downloads Folder", home.appendingPathComponent("Downloads"),
             "Installers, DMGs, and files downloaded from browsers.",
             .manual, .user, "arrow.down.circle.fill"),

            ("Desktop", home.appendingPathComponent("Desktop"),
             "Files accumulated on your Desktop workspace.",
             .manual, .user, "menubar.dock.rectangle"),

            ("Photos Library", home.appendingPathComponent("Pictures/Photos Library.photoslibrary"),
             "Your personal Photos library. Do not delete — consider enabling Optimize Mac Storage in iCloud.",
             .manual, .user, "photo.on.rectangle.angled")
        ]

        return list.map { title, url, explanation, risk, category, icon in
            Recommendation(title: title, path: url, explanation: explanation, risk: risk, category: category, iconName: icon)
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
