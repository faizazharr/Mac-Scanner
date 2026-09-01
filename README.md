# MacScanner

See where your Mac's storage actually goes, what's safe to clean up, and
whether your Mac is running hot — all in one app, no Terminal required.

Finder's own "About This Mac ▸ Storage" tells you a category is big. It
doesn't tell you *which folder*, whether it's safe to delete, or that your
Mac is about to overheat because three heavy apps are running at once.
MacScanner does.

## Download

**[⬇ Download the latest version](../../releases/latest)** — unzip, drag to
Applications, open. No Xcode, no developer tools, no Terminal.

First time opening it, macOS will ask you to confirm since it's not from the
App Store — see **[DOWNLOAD.md](DOWNLOAD.md)** for the two-minute walkthrough.

## What it does

### 🏠 Home
Open the app and immediately see your Mac's specs (model, chip, memory,
battery health) and how full your storage is, with a card for each tool
below so you can jump straight to what you need.

### 📁 Folder Browser
Click into any folder and see what's actually taking up space — sorted
largest first, with a size bar next to each item and a colour-coded pie
chart of the biggest offenders. Search within a folder, filter by file type
(Video, Archives, Disk Images, Documents...), and jump anywhere with one
click, including outside your home folder.

### ✨ Cleanup Recommendations
A checklist of common space-wasters on your Mac — app caches, old backups,
Docker/simulator data, build leftovers — each one sized and labeled **Safe
to clean**, **Review first**, or **Manual review**, so you know exactly
what you're deleting before you delete it.

### 📄 Large Files
Find every individual file over a size you choose (100 MB up to 5 GB+),
filterable by type, searchable by name. Great for tracking down that one
forgotten video export or old disk image.

### ⚡ Performance
Live gauges for Memory, CPU, GPU, Swap, and Thermal state — each one flags
red the moment it's a real problem, with plain-language advice on what to
do about it (not just a scary color). See which apps are currently the
heaviest, watch trends over time on a live chart, and quit a runaway
process directly from the list.

### On any of the above
Every item — a folder, a cache, a large file, a process — can be **revealed
in Finder** or **moved to Trash** with one click. Nothing is ever
permanently deleted without a confirmation, and Trash is always reversible.

## Requirements

macOS 14.0 (Sonoma) or later. That's it — see
**[DOWNLOAD.md](DOWNLOAD.md)** to get started.

## For developers

Building from source, contributing, or curious how it works under the
hood? See **[ARCHITECTURE.md](ARCHITECTURE.md)**.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Copyright

Copyright © 2026 Faiz Azhar Ristya Nugraha — see [LICENSE](LICENSE).
