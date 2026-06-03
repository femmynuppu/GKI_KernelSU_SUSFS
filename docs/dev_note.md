# ⚠️ Developer Notes — Catatan Kesalahan AI (Revisi 2)

> **REVISI PENTING**: Dokumen ini menambahkan kesalahan-kesalahan baru dari Sesi 2
> (iterasi build 1–6) dan **mengoreksi kesalahan terbesar**: di Sesi 1, AI salah
> mendiagnosis SUSFS sebagai penyebab KMI mismatch. Dalang sesungguhnya adalah
> `--lto=none` yang mematikan CFI.

---

## MISTAKE-000: 🔴 DIAGNOSIS TERBESAR YANG SALAH — Menyalahkan SUSFS

**Sesi:** Sesi 1 (31 Mei 2026)  
**Dampak:** Seluruh arah proyek di Sesi 1 salah — waktu 5+ jam terbuang  
**Skor keparahan:** 10/10

### Apa yang AI Klaim (SALAH)
> "Patch SUSFS menambahkan field baru ke struct kritis (task_struct, inode, file).
> Ini menyebabkan offset bergeser +32 byte. Driver MediaTek membaca offset lama
> → deadlock → blackscreen. SUSFS = dalang. Tidak bisa diperbaiki di 6.12."

### Fakta Sebenarnya
SUSFS **TIDAK** menambah field ke struct. SUSFS menggunakan `ANDROID_VENDOR_DATA()` — slot reserved yang sudah dialokasikan Google. Offset struct **TIDAK bergeser satu byte pun**.

```c
// YANG AI KLAIM TERJADI (SALAH):
struct task_struct {
    pid_t pid;           // offset 0
    int susfs_field;     // BARU! ← SALAH, INI TIDAK ADA
    uid_t uid;           // offset bergeser ← SALAH
};

// YANG SEBENARNYA TERJADI:
struct task_struct {
    pid_t pid;                    // offset 0
    uid_t uid;                    // offset 4 ← TIDAK BERGESER
    // ...
    ANDROID_VENDOR_DATA(1);       // slot reserved Google, sudah ada di stock
    // SUSFS menyimpan datanya di slot ini
};
```

### Dalang Sesungguhnya
`--lto=none` di `build.yml` → CFI dimatikan → ABI mismatch dengan driver vendor yang dikompilasi Google dengan CFI aktif.

### Mengapa AI Salah
1. AI **tidak membaca source code SUSFS** untuk memverifikasi apakah SUSFS benar-benar menambah field ke struct.
2. AI **berasumsi** berdasarkan analogi umum ("patch menambah field → struct bergeser") tanpa memeriksa teknik actual yang digunakan SUSFS.
3. AI **tidak membandingkan** konfigurasi build yang berhasil (WildKernels, thin LTO) vs yang gagal (femmynuppu, lto=none).
4. AI terlalu fokus pada **gejala** (CRC mismatch) dan mengabaikan **root cause** (CFI disabled).

### Pelajaran
> **JANGAN PERNAH mendiagnosis akar masalah tanpa membaca source code yang relevan.** Asumsi "patch menambah field" vs "patch pakai slot reserved" adalah perbedaan FUNDAMENTAL yang menentukan apakah KMI bergeser atau tidak. Satu kalimat di source code (`ANDROID_VENDOR_DATA(1)`) membatalkan seluruh analisis 5 jam.

---

## MISTAKE-001: Memaksa `return 1` di Tengah Blok Deklarasi C

**Sesi:** Sesi 1, Commit `2ecb63d`  
**Dampak:** Build failure  
**Waktu terbuang:** ~30 menit  

### Apa yang Terjadi
AI menyisipkan `return 1;` setelah deklarasi pertama di `check_version()`, memotong deklarasi berikutnya → error C90 `mixed declarations`.

### Yang Benar
Baca keseluruhan fungsi (minimal 20 baris) sebelum menyisipkan kode. Atau ubah kondisi `if` alih-alih menyisipkan early return.

### Catatan Tambahan (Sesi 2)
Seluruh bypass CRC ini **TIDAK DIPERLUKAN** — masalah WiFi sebenarnya dari `--lto=none`, bukan CRC mismatch. Jika root cause ditemukan lebih awal, 4 commit bypass tidak perlu dibuat sama sekali.

---

## MISTAKE-002: Salah Menargetkan File untuk `module_sig_check`

**Sesi:** Sesi 1, Commit `762457b`  
**Dampak:** Silent failure — bypass tidak mengena  
**Waktu terbuang:** ~40 menit

### Apa yang Terjadi
AI menargetkan `main.c` padahal `module_sig_check()` sudah dipindah ke `signing.c` sejak kernel ~6.4.

### Pelajaran
> Selalu `grep` dulu untuk menemukan lokasi sebenarnya. Jangan berasumsi berdasarkan kernel lama.

---

## MISTAKE-003: Mematikan CONFIG_RUST → rust_binder.ko Hilang

**Sesi:** Sesi 2, Iterasi 1, Commit `d37d62c`  
**Dampak:** Build failure — rust_binder.ko wajib ada di dist  
**Waktu terbuang:** ~60 menit (1 iterasi build)

### Apa yang AI Pikirkan
> "Rust mungkin tidak kompatibel dengan thin LTO. Matikan CONFIG_RUST untuk menghindari masalah."

### Mengapa Ini Salah
1. GKI android16-6.12 **mewajibkan** `rust_binder.ko` di dist target BUILD.bazel
2. Google sendiri compile 234+ certified build dengan Rust + thin LTO
3. Komentar asli `# Rust 不兼容 thin LTO` adalah **mitos komunitas**, bukan fakta teknis
4. Mematikan Rust tidak mencegah BUILD.bazel dari mensyaratkan `rust_binder.ko`

### Pelajaran
> **Jangan percaya komentar di kode tanpa verifikasi.** Komentar bisa saja asumsi keliru dari pembuat sebelumnya. Verifikasi dengan sumber resmi (dalam hal ini: dokumentasi Google GKI).

---

## MISTAKE-004: Fix rust_binder di Blok Bersyarat (Droidspaces)

**Sesi:** Sesi 2, Iterasi 2–3, Commit `3f9701d`  
**Dampak:** Fix tidak berjalan saat droidspaces=off  
**Waktu terbuang:** ~120 menit (2 iterasi build)

### Apa yang AI Lakukan
AI menemukan bahwa `init_ipc_ns` dan `put_ipc_ns` perlu diekspor agar `rust_binder.ko` bisa di-compile. Fix ini sudah **ada** di `build.yml`, tapi tersembunyi di dalam step Droidspaces (`if: inputs.droidspaces != 'off'`). AI menduplikasi fix ke blok unconditional.

### Mengapa Masih Gagal
Ekspor simbol saja tidak cukup. Masalah sebenarnya: flag eksplisit `--lto=thin` memicu config-transition variant `lto_thin` di Kleaf yang menggunakan jalur build Rust yang berbeda dan gagal di CI. Pendekatan yang benar: **jangan beri flag `--lto`** sama sekali → biarkan GKI default (yang sudah thin+CFI).

### Pelajaran
> **Ketika fix pertama gagal, jangan terus menambal hal yang sama.** Mundur satu langkah dan pertanyakan: "Apakah saya mengejar akar masalah yang benar, atau hanya gejala?"

---

## MISTAKE-005: Menghapus rust_binder.ko dari BUILD.bazel

**Sesi:** Sesi 2, Iterasi 4, Commit `650c07f`  
**Dampak:** Tidak efektif — sed pattern tidak match  
**Waktu terbuang:** ~60 menit

### Apa yang AI Pikirkan
> "Kalau rust_binder.ko tidak bisa di-compile, hapus saja dari BUILD.bazel dist requirements."

### Mengapa Ini Pendekatan yang Salah
1. `rust_binder.ko` adalah komponen wajib GKI — menghapusnya dari dist bisa menyebabkan masalah runtime
2. Sed pattern yang digunakan tidak match dengan format BUILD.bazel yang sebenarnya
3. Ini adalah "menyembunyikan masalah" bukan "memperbaiki masalah"

### Apa yang Akhirnya Berhasil (Iterasi 5)
Meniru pendekatan WildKernels: **jangan beri flag `--lto`** → Kleaf menggunakan konfigurasi default GKI yang sudah handle Rust + thin LTO dengan benar. Plus gunakan `bazel run :dist -- --destdir=` alih-alih `bazel build :dist`.

### Pelajaran
> **Sebelum menghapus komponen dari build system, pelajari bagaimana proyek yang sukses menangani masalah yang sama.** WildKernels sudah membuktikan bahwa rust_binder.ko bisa di-build — artinya masalahnya bukan di Rust itu sendiri, tapi cara kita memanggil Kleaf.

---

## MISTAKE-006: `--dist_dir` vs `--destdir` 

**Sesi:** Sesi 2, Iterasi 5, Commit `2246121`  
**Dampak:** Build failure — argumen tidak dikenali  
**Waktu terbuang:** ~60 menit

### Apa yang Terjadi
Saat porting dari WildKernels, AI menggunakan `--dist_dir` untuk android16-6.12. Ternyata varian ini menggunakan `--destdir`. Dua argumen berbeda tergantung versi kernel.

### Pelajaran
> **Saat porting kode dari proyek lain, periksa SETIAP argumen CLI — bukan hanya struktur umum.** Nama argumen yang mirip (`dist_dir` vs `destdir`) bisa memiliki arti berbeda di versi berbeda.

---

## MISTAKE-007: Salah Mendakwa Re-Kernel & BBG (Sesi 1)

**Sesi:** Sesi 1, Commit `51a515b`  
**Dampak:** Fitur yang tidak bersalah dimatikan

### Apa yang Terjadi
AI menyalahkan Re-Kernel (CPU scheduler) sebagai penyebab gaming crash berdasarkan korelasi (gaming → CPU intensif → crash). Log pstore membuktikan penyebabnya adalah CFI mismatch, bukan scheduler.

### Pelajaran
> **Korelasi ≠ kausalitas.** Selalu analisis log sebelum menyalahkan komponen.

---

## 📊 Ringkasan Kesalahan per Sesi

| Sesi | Jumlah Kesalahan | Waktu Terbuang | Kesalahan Terparah |
|------|----------------:|:--------------:|---------------------|
| Sesi 1 | 4 | ~5 jam | MISTAKE-000: Salah diagnosis SUSFS |
| Sesi 2 | 4 | ~5 jam | MISTAKE-003: Matikan Rust |
| **Total** | **8** | **~10 jam** | |

### Pola Kesalahan yang Berulang
1. **Asumsi tanpa verifikasi** (MISTAKE-000, 003, 005) — percaya komentar/teori tanpa baca source
2. **Tidak belajar dari proyek yang sukses** (MISTAKE-004, 005) — baru lihat WildKernels di iterasi 5
3. **Mengejar gejala, bukan root cause** (MISTAKE-001, 002, 007) — fokus pada CRC/signature padahal masalahnya CFI
