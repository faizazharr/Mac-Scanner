## 📋 Pull Request Summary

<!-- Provide a brief explanation of the problem, motivation, or new feature. -->

---

## 🛠️ Changes Made

- 
- 
- 

---

## 🛡️ Safety & Performance Checklist

Please verify each item before requesting review:

- [ ] **Non-Destructive Safety**: Deletions strictly use `FileManager.default.trashItem` (never `rm -rf` or irreversible deletions).
- [ ] **Config Protection**: No root `~/Library/Application Support/<App>` folders are targeted for blind deletion. Only verified caches (`~/Library/Caches/...`) or official prune tools are used.
- [ ] **Zero Background Polling**: Any polling timers stop immediately when views or menu bar popovers close.
- [ ] **Fast File Sizing**: Regular files use instant Mach stat (`fileAllocatedSizeKey`), not spawned `du` subprocesses.
- [ ] **Build Verification**: `swift build` and `./Scripts/build_dmg.sh release` complete with 0 errors and 0 warnings.
- [ ] **Tested on macOS**: Verified on Apple Silicon (M1/M2/M3/M4) or Intel Mac.

---

## 📸 Screenshots / Demos (If Applicable)

<!-- Attach screenshot or screen recording if UI changes were made. -->
