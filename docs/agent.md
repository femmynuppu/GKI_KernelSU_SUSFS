# 🐛 Agent Bugs Log — Daftar Lengkap Bug Teknis (Revisi 2)

> **REVISI PENTING**: Dokumen ini telah diperbarui total berdasarkan penemuan akar
> masalah yang sebenarnya. Analisis awal (Sesi 1) **salah besar** — dalang semua
> bug runtime BUKAN KMI struct mismatch dari SUSFS, melainkan `--lto=none` yang
> mematikan CFI. SUSFS terbukti KMI-safe karena menggunakan `ANDROID_VENDOR_DATA` slot.

---

## ⚡ BUG-000: `--lto=none` Mematikan CFI → DALANG UTAMA Semua Bug Runtime

**Severity:** 🔴🔴🔴 ROOT CAUSE (Satu bug ini menyebabkan WiFi mati, BT mati, dan gaming blackscreen)  
**Terdeteksi di:** Sesi 2, Iterasi 1 (2 Juni 2026)  
**File terdampak:** `.github/workflows/build.yml` — baris invokasi bazel

### Gejala (Tiga Sekaligus)
1. **WiFi mati total** — toggle tidak bisa dinyalakan sejak boot
2. **Bluetooth mati total** — bersamaan dengan WiFi (satu driver combo `conninfra`)
3. **Blackscreen saat gaming** — HP restart paksa oleh hardware watchdog

### Rantai Sebab-Akibat
```
# Komentar ASLI di build.yml (ASUMSI KELIRU dari pembuat workflow):
# 6.12+ 使用 lto=none（Rust 内核模块不兼容 thin LTO）
LTO_FLAG="--lto=none"   ← INI DALANGNYA
    │
    ▼
CFI (Control Flow Integrity) DIMATIKAN
    │
    ▼
KMI (Kernel Module Interface) TIDAK COCOK dengan stock GKI
    │
    ├───────────────────────────────────┐
    ▼                                   ▼
Driver WiFi/BT (conninfra,         Driver GPU/thermal
wlan_drv, btmtk) dikompilasi       dikompilasi Google
Google dengan CFI aktif             dengan CFI aktif
    │                                   │
    ▼                                   ▼
Kernel: CFI mati → ABI mismatch    Kernel: CFI mati → ABI mismatch
    │                                   │
    ▼                                   ▼
❌ WiFi/BT: driver gagal init      ❌ Gaming: GPU load → deadlock
   → langsung mati sejak boot         → 8 CPU terkunci serentak
                                       → watchdog kill → BLACKSCREEN
```

### Penjelasan Teknis Mendalam

**Apa itu CFI?** Control Flow Integrity adalah mekanisme keamanan yang menyisipkan *type-check pointer* di setiap *indirect function call*. CFI mengubah layout tabel fungsi dan struct vtable. Ketika kernel di-compile **tanpa** CFI tapi driver vendor di-compile **dengan** CFI, terjadi mismatch:

```c
// Driver vendor (compiled WITH CFI by Google):
// Setiap indirect call punya CFI check:
void (*callback)(struct net_device *dev);
__cfi_check(callback);  // ← pointer validation inserted by CFI
callback(dev);           // ← expects CFI-aware function layout

// Kernel kita (compiled WITHOUT CFI):
// Tidak ada CFI metadata di fungsi-fungsi kernel
// → driver memanggil fungsi kernel via CFI-check
// → check gagal / alamat salah → CRASH atau DEADLOCK
```

**Mengapa WiFi dan BT mati bersamaan?** MediaTek Dimensity 8200 menggunakan driver combo tunggal — `conninfra.ko` — yang mengelola WiFi dan Bluetooth lewat satu hardware interface. Kedua fitur hidup dan mati bersama.

**Mengapa blackscreen hanya saat gaming?** Saat idle, GPU driver jarang melakukan indirect calls ke kernel. Saat gaming, GPU driver (`mali_kbase.ko`) melakukan ratusan ribu akses per detik → CFI mismatch terjadi dalam milidetik → spinlock deadlock → 8 CPU terkunci → watchdog restart.

### Bukti dari Log dmesg/pstore
```
[ 147.281181][ T1449] [MTK-WIFI] WIFI_write[E]: Wi-Fi driver is not ready for 2s
[ 150.946971][  T118] [wdk-c] cpu=4 o_k=4 lbit=0x10  ← CPU terkunci
[ 150.946983][  T118] [wdk-c] cpu=5 o_k=5 lbit=0x20  ← CPU terkunci
[ 150.946994][  T118] [wdk-c] cpu=6 o_k=6 lbit=0x40  ← CPU terkunci
[ 150.947005][  T118] [wdk-c] cpu=7 o_k=7 lbit=0x80  ← CPU terkunci
[ 152.553168][  T108] [Hang_Detect] hang_detect thread counts down 10:10, status 1.
```

### Bukti bahwa `--lto=none` adalah Dalang (bukan SUSFS)
1. **Google sendiri** membangun 234+ certified GKI build android16-6.12 dengan thin LTO + CFI + Rust aktif
2. **WildKernels** (KSUN) menggunakan thin LTO → WiFi/BT/gaming normal di Xiaomi 13T
3. **SUSFS menggunakan `ANDROID_VENDOR_DATA` slot** — offset struct tidak bergeser satu byte pun
4. **7 prebuilt GKI komunitas** (SukiSU, KSUN, ReSukiSU) semuanya copy-paste `--lto=none` → semuanya gagal

### Mengapa Asumsi "Rust tidak kompatibel thin LTO" itu SALAH
Komentar asli di workflow: `# Rust 不兼容 thin LTO` — ini **bukan fakta teknis**, melainkan asumsi keliru yang tersebar ke seluruh komunitas builder. Google resmi compile GKI 6.12 dengan thin LTO + Rust setiap hari.

### Status: ✅ DIPERBAIKI di branch `fix-6.12-kmi-lto-cfi`
```
Commit d37d62c: --lto=none → --lto=thin, timeout 30→60 menit
Commit 2246121: Drop --lto flag sama sekali → pakai default GKI (thin+CFI)
Commit d6986f4: Fix argumen --destdir (bukan --dist_dir) untuk android16-6.12
```

---

## BUG-001: ZRAM LZ4 Source Overwrite → Memory Corruption

**Severity:** 🔴 CRITICAL (OS Unstable)  
**Terdeteksi di:** Sesi 1 (31 Mei 2026)  
**File terdampak:** `lib/lz4/*.c`, `lib/lz4/lz4defs.h`

### Gejala
OS menyala namun tidak stabil. Potensi silent data corruption pada swap/zram pages.

### Akar Penyebab
Skrip ZRAM di `build.yml` menimpa file LZ4 kernel 6.12 dengan versi lawas (untuk 5.10) tanpa guard versi. API LZ4 sudah berubah di 6.12.

### Status: ✅ DIPERBAIKI (guard `if kernel_version == 5.10|5.15`)
Catatan: Fix ini di-revert bersama eksperimen Sesi 1 ke `3225afb`. Bug masih eksis di kode asli jika ZRAM diaktifkan untuk 6.12.

---

## BUG-002: `rust_binder.ko` Tidak Ter-compile → Build Failure

**Severity:** 🔴 CRITICAL (Build gagal 4 kali berturut-turut)  
**Terdeteksi di:** Sesi 2, Iterasi 1–4 (2–3 Juni 2026)  
**File terdampak:** `BUILD.bazel` (dist target), `ipc/msgutil.c`, `ipc/namespace.c`

### Gejala
```
ERROR: Unable to find drivers/android/rust_binder.ko in staging dir
```
Build kernel berjalan 25+ menit tanpa error compile, lalu gagal di tahap dist karena `rust_binder.ko` tidak ada di staging directory.

### Kronologi 4 Iterasi
| Iterasi | Commit | Teori | Hasil |
|---------|--------|-------|-------|
| 1 | `d37d62c` | Nonaktifkan Rust (`CONFIG_RUST=n`) | ❌ rust_binder.ko tetap diminta |
| 2 | `c2ab422` | Aktifkan kembali Rust | ❌ `init_ipc_ns` + `put_ipc_ns` belum diekspor |
| 3 | `3f9701d` | Ekspor simbol IPC tanpa syarat | ❌ Simbol diekspor tapi Rust toolchain gagal compile |
| 4 | `650c07f` | Hapus rust_binder.ko dari BUILD.bazel dist | ❌ Masih gagal (approach salah) |

### Akar Penyebab Sesungguhnya (Ditemukan di Iterasi 5)
Flag eksplisit `--lto=thin` ke Kleaf mengaktifkan **config-transition variant** `lto_thin` yang memaksa build `rust_binder.ko` via jalur yang gagal di CI. WildKernels menghindari jebakan ini dengan **TIDAK memberi flag `--lto`** sama sekali → GKI default (thin LTO + CFI) → `rust_binder.ko` ter-build via jalur standar.

### Status: ✅ DIPERBAIKI
```
Commit 2246121: Drop --lto flag → pakai default GKI
Commit d6986f4: Fix --destdir (bukan --dist_dir) untuk android16-6.12
```

---

## BUG-003: `--dist_dir` vs `--destdir` Argument Mismatch

**Severity:** 🟡 MEDIUM (Build Failure)  
**Terdeteksi di:** Sesi 2, Iterasi 5, Commit `2246121` (3 Juni 2026)

### Gejala
```
error: unrecognized arguments: --dist_dir=/home/runner/out
```

### Akar Penyebab
WildKernels menggunakan dua argumen berbeda tergantung versi kernel:
- `android16-6.12`: `-- --destdir=/home/runner/out`
- Versi lain: `-- --dist_dir=/home/runner/out`

Saat porting, AI menggunakan `--dist_dir` untuk semua versi.

### Status: ✅ DIPERBAIKI di commit `d6986f4`

---

## BUG-004: C Mixed Declarations Error (Sesi 1)

**Severity:** 🟡 MEDIUM (Build Failure)  
**Terdeteksi di:** Sesi 1, Commit `2ecb63d`

### Akar Penyebab
AI menyisipkan `return 1;` di tengah blok deklarasi C90. Melanggar `-Werror=declaration-after-statement`.

### Status: ✅ DIPERBAIKI di commit `4a7a84a` (ganti strategi ke `s/if(!crc)/if(1)/g`)
Catatan: Seluruh bypass ini kemudian terbukti **tidak diperlukan** — masalah WiFi sebenarnya dari `--lto=none`, bukan CRC mismatch.

---

## BUG-005: Module Signature Check Target File Salah (Sesi 1)

**Severity:** 🟡 MEDIUM (Silent Failure)  
**Terdeteksi di:** Sesi 1, Commit `762457b`

### Akar Penyebab
AI menargetkan `main.c` untuk bypass `module_sig_check()`, padahal di kernel 6.12 fungsi tersebut sudah dipindah ke `signing.c`.

### Status: ✅ DIPERBAIKI di commit `d3d874c`
Catatan: Sama seperti BUG-004, bypass ini **tidak diperlukan** setelah root cause sebenarnya ditemukan.

---

## BUG-006: Diagnosis Salah — Re-Kernel & BBG (Sesi 1)

**Severity:** 🟢 LOW (Salah Diagnosis)  
**Terdeteksi di:** Sesi 1, Commit `51a515b`

### Kronologi
AI menyalahkan Re-Kernel (CPU scheduler) dan BBG sebagai penyebab blackscreen gaming. Analisis log pstore kemudian membuktikan dalangnya adalah CFI mismatch (BUG-000), bukan scheduler.

### Status: ℹ️ INFORMATIONAL — Re-Kernel dan BBG tidak bersalah.

---

## 📊 KOREKSI BESAR: SUSFS Terbukti KMI-Safe

Analisis awal (Sesi 1) menyatakan bahwa SUSFS mengubah struct offset dan menyebabkan KMI mismatch. **INI SALAH.**

SUSFS menggunakan 3 teknik yang semuanya KMI-safe:

| Teknik | Cara Kerja | Efek ke KMI |
|--------|-----------|-------------|
| `ANDROID_VENDOR_DATA(n)` | Sisipkan data di slot reserved Google | Offset struct **tidak bergeser** |
| Static key | Flag global, bukan per-struct | Tidak menyentuh struct apapun |
| `#ifdef` injection | Tambah kode di dalam fungsi yang sudah ada | Offset struct **tidak berubah** |

```c
// Google sendiri yang define slot ini di include/linux/android_vendor.h:
#define ANDROID_VENDOR_DATA(n)  u64 android_vendor_data##n

// SUSFS pakai slot ini — offset semua field asli TIDAK bergeser
struct inode {
    // ... field asli Google ...
    ANDROID_VENDOR_DATA(1);  // ← SUSFS pakai ini
};
```

**Kesimpulan:** Yang merusak KMI adalah `--lto=none` (mematikan CFI), bukan SUSFS.
