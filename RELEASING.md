# Release Guide & Semantic Versioning 🚀

This document outlines the official release workflow for **MacScanner** using **Semantic Versioning (SemVer)** and automated GitHub Actions CI/CD.

---

## 📌 1. Semantic Versioning Standards (SemVer)

All release tags must strictly follow the format:
```
vMAJOR.MINOR.PATCH
```

- **`MAJOR` (v1.0.0 → v2.0.0)**: Substantial architectural overhauls or breaking changes.
- **`MINOR` (v1.0.0 → v1.1.0)**: New backwards-compatible features (e.g. new diagnostic modules, new screening insights).
- **`PATCH` (v1.0.0 → v1.0.1)**: Bug fixes, lightweight optimizations, or documentation improvements.

---

## 🚀 2. Steps to Publish an Automated Release (GitHub Actions)

The core codebase always resides on the `master` branch. To trigger an automated release build:

### Step 1: Ensure Your Master Branch is Up to Date
```bash
git checkout master
git pull origin master
```

### Step 2: Create an Annotated Semantic Version Tag
Create an annotated Git tag with a descriptive release message:
```bash
# Example release for v1.0.0
git tag -a v1.0.0 -m "Release v1.0.0: Official release with full screening & uninstaller"
```

### Step 3: Push the Tag to GitHub
```bash
git push origin v1.0.0
```

### Step 4: Automated GitHub Actions Pipeline
Once the tag is pushed:
1. The [`.github/workflows/release.yml`](.github/workflows/release.yml) workflow is automatically triggered.
2. The macOS runner compiles the binary with `-Osize` whole-module optimization and packages `MacScanner.dmg` with maximum `zlib-9` compression.
3. A GitHub Release is created automatically with `MacScanner.dmg` attached and auto-generated release notes.

---

## 🛠️ 3. Local / Manual Offline Release Build

To build the release `.dmg` installer locally without GitHub Actions:

```bash
# 1. Clean previous build artifacts
rm -rf build .build

# 2. Run the release packaging script
./Scripts/build_dmg.sh release

# 3. Locate the generated DMG installer:
open build/MacScanner.dmg
```

---

## 🔒 4. Release Quality & Integrity

- **100% Zero-Telemetry**: Every release binary is verified to be completely free of external tracking SDKs and remote network requests.
- **Ultra-Compact Footprint**: The release executable is optimized to **~1.7 MB** and the compressed DMG installer to **~2.7 MB**.

