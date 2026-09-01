// swift-tools-version: 5.9
// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import PackageDescription

let package = Package(
    name: "MacScanner",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacScanner",
            path: "Sources/MacScanner"
        )
    ]
)
