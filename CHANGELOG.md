# Changelog

## v1.0.0 — First public release

Native macOS disk-usage screener: see where your disk space actually goes,
get risk-tagged cleanup recommendations, find oversized files, watch live
system load, and act on any of it without leaving the app.

### Features

- **Home** — landing page: this Mac's specs, a storage overview, and a card
  per feature so you pick where to go next.
- **Folder Browser** — drill into any folder (single click), size-sorted
  children with a relative-size bar and a percentage donut chart, search
  within the current folder, clickable breadcrumb (including the true
  filesystem root `/`).
- **Cleanup Recommendations** — curated list of known cleanup targets
  (caches, build artifacts, Docker/simulator data, old backups, ...) checked
  against this Mac, each tagged Safe to clean / Review first / Manual review.
- **Large Files** — every file at or above a chosen size threshold anywhere
  under your home folder, filterable by category.
- **Performance** — live Memory/CPU/GPU/Swap/Thermal gauges with a literal
  red-line marker at each critical threshold, sparkline history charts, a
  stable Recommendations panel that only updates when something actually
  changes (not every tick), a list of currently-running resource-heavy apps,
  and a searchable, sortable (CPU/RAM) process list with the ability to quit
  a process directly.

Every list row supports **Reveal in Finder** and **Move to Trash** (with a
confirmation dialog — reversible, nothing permanently deleted).

### Under the hood

- Every tab follows the same single-event-driven view-model shape
  (`enum Action` + `func send(_:)`), keeping state mutation traceable to one
  call site per tab.
- Disk scanning shells out to `du`/`find` (APFS-clone aware, far faster than
  a manual recursive walk for directories with millions of small files);
  performance metrics read `vm_stat`/`sysctl`/`top`/`ioreg`/`ps` directly —
  GPU utilization included, without requiring administrator privileges.
- The live-refresh loop parallelizes its independent subprocess calls and
  only fetches the RAM-sorted process list when that sort mode is actually
  selected, keeping the app's own footprint light while it's polling.
- Signed with a real local code-signing identity (not ad-hoc) so macOS
  treats rebuilds as the same app — folder-access permissions persist
  instead of re-prompting every time.

### Known limitations

- NPU (Apple Neural Engine) utilization isn't shown — macOS only exposes it
  through `powermetrics`, which requires administrator privileges.
- Not notarized (no paid Apple Developer account) — first launch needs a
  right-click ▸ Open, see [DOWNLOAD.md](DOWNLOAD.md).
