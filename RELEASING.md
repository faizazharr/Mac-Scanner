# Panduan Rilis & Semantic Versioning (Release Guide) 🚀

Dokumen ini menjelaskan alur kerja rilis resmi untuk **MacScanner** menggunakan **Semantic Versioning (SemVer)** dan pipeline otomatisasi GitHub Actions.

---

## 📌 1. Standar Semantic Versioning (SemVer)

Setiap tag rilis wajib mengikuti format:
```
vMAJOR.MINOR.PATCH
```

- **`MAJOR` (v1.0.0 → v2.0.0)**: Perubahan arsitektural besar atau pembaruan sistem yang memecah kompatibilitas sebelumnya.
- **`MINOR` (v1.0.0 → v1.1.0)**: Penambahan fitur baru yang kompatibel (misal: penambahan modul hardware test baru, tab screening baru).
- **`PATCH` (v1.0.0 → v1.0.1)**: Perbaikan bug, optimasi performa ringan, atau pembaruan dokumentasi.

---

## 🚀 2. Langkah-Langkah Membuat Rilis Otomatis (GitHub Actions)

Core codebase selalu berada di branch `master`. Untuk memicu build dan rilis otomatis:

### Langkah 1: Pastikan Semua Perubahan Sudah Masuk ke `master`
```bash
git checkout master
git pull origin master
```

### Langkah 2: Buat Semantic Version Tag
Buat tag Git beranotasi dengan pesan rilis yang jelas:
```bash
# Contoh rilis versi 1.0.0
git tag -a v1.0.0 -m "Release v1.0.0: Initial stable release with full screening & uninstaller"
```

### Langkah 3: Push Tag ke GitHub
```bash
git push origin v1.0.0
```

### Langkah 4: Otomatisasi GitHub Actions Bekerja
Setelah tag di-push:
1. Workflow [`.github/workflows/release.yml`](.github/workflows/release.yml) akan otomatis terpicu.
2. Runner macOS akan mengompilasi binary dengan optimasi `-Osize` dan mengemas installer `MacScanner.dmg` dengan kompresi maksimal `zlib-9`.
3. GitHub Release baru akan diterbitkan secara otomatis dengan melampirkan file `MacScanner.dmg` dan catatan perubahan (*release notes*).

---

## 🛠️ 3. Pembuatan Rilis Manual / Lokal (Offline Build)

Jika Anda ingin membuat file installer `.dmg` secara lokal tanpa melalui GitHub Actions:

```bash
# 1. Bersihkan build cache lama
rm -rf build .build

# 2. Eksekusi script release packaging
./Scripts/build_dmg.sh release

# 3. Hasil DMG installer berada di:
open build/MacScanner.dmg
```

---

## 🔒 4. Jaminan Integritas Rilis

- **100% Zero-Telemetry**: Setiap binary rilis terverifikasi bebas dari pelacak analitik eksternal.
- **Ukuran Ringkas**: Ukuran binary rilis terkompresi terjaga di kisaran **~1.7 MB** dan DMG **~2.7 MB**.
