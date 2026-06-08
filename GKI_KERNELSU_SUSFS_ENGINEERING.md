# GKI_KernelSU_SUSFS — Deep Engineering Analysis

> Two repos, one codebase: femmynuppu/GKI_KernelSU_SUSFS and ReSukiSU-GKI/GKI_KernelSU_SUSFS
> Role: **Automated GKI kernel builder** — compiles GKI kernels with ReSukiSU + SUSFS
> 1470-line reusable build workflow, 11 workflow files, multi-sublevel patch compat engine
> Both repos are identical copies (ReSukiSU-GKI is the org fork)

---

## 1. Repository Lineage

```
zzh20188/GKI_KernelSU_SUSFS          ← Original (multi-KSU variant)
  └── coolzyd9107/GKI_KernelSU_SUSFS  ← Fork (ReSukiSU-only after c17aae5)
        └── femmynuppu/GKI_KernelSU_SUSFS        ← This fork
        └── ReSukiSU-GKI/GKI_KernelSU_SUSFS      ← Org fork (identical)
```

Both femmynuppu and ReSukiSU-GKI repos are byte-for-byte identical (same README, same workflows, same data files). The ReSukiSU-GKI org is the "official" distribution channel.

Status: **Archived during 2026 Gaokao** (Chinese college entrance exam, June 2026). Author (coolzyd9107) is taking the exam.

---

## 2. Architecture Overview

```
GKI_KernelSU_SUSFS/
├── .github/workflows/
│   ├── build.yml                ← Reusable: 1470-line kernel build engine
│   ├── kernel-custom.yml        ← Dispatch: single sublevel manual trigger
│   ├── main.yml                 ← Bulk orchestrator: all 5 versions at once
│   ├── kernel-a12-5-10.yml      ← Per-version: loops all sublevels
│   ├── kernel-a13-5-15.yml
│   ├── kernel-a14-6-1.yml
│   ├── kernel-a15-6-6.yml
│   ├── kernel-a16-6-12.yml
│   ├── get-manager.yml          ← Download KSU Manager APK + SUSFS module
│   ├── send_bot_notice.yml      ← Telegram notification bot
│   ├── update-pages.yml         ← GitHub Pages data updater
│   └── emergency-cleanup.yml    ← Release artifact cleanup
├── scripts/
│   ├── gki_fetch.py             ← Scrapes Google's kernel/common for sublevels
│   ├── fetch_all.py             ← Batch fetch all versions
│   ├── update_lts.py            ← LTS branch tracker
│   └── update_data.py           ← JSON data generator
├── data/
│   ├── android12/5.10.json      ← Sublevel tracking DB (150 lines)
│   ├── android13/5.15.json
│   ├── android14/6.1.json
│   ├── android15/6.6.json
│   ├── android16/6.12.json
│   └── announcement.json        ← Web dashboard announcement
├── config/
│   ├── config                   ← Custom SUSFS/SukiSU commit overrides
│   ├── zram.config              ← ZRAM kernel config fragment
│   └── stock_defconfig          ← (optional) /proc/config.gz spoofing
├── zram/
│   └── lz4/                     ← LZ4KD + ARMv8 NEON LZ4 acceleration
├── assets/                      ← Screenshots + demo videos
└── hmbird_patch.c               ← OnePlus 8E SoC support patch
```

---

## 3. Workflow Hierarchy

```
main.yml (bulk orchestrator)
  │  Concurrency: cancel-in-progress
  │  Inputs: release_type, ksu_branch, 5x build_<version>, 6x feature toggles
  │
  ├── get-manager (always)
  │     └── Downloads ReSukiSU Manager APK + SUSFS module ZIP
  │
  ├── build-a12-5-10 (conditional) ──→ kernel-a12-5-10.yml ──→ build.yml (matrix)
  ├── build-a13-5-15 (conditional) ──→ kernel-a13-5-15.yml ──→ build.yml (matrix)
  ├── build-a14-6-1  (conditional) ──→ kernel-a14-6-1.yml  ──→ build.yml (matrix)
  ├── build-a15-6-6  (conditional) ──→ kernel-a15-6-6.yml  ──→ build.yml (matrix)
  ├── build-a16-6-12 (conditional) ──→ kernel-a16-6-12.yml ──→ build.yml (matrix)
  │
  ├── collect-rejects (always, if not cancelled)
  │     └── Aggregates .rej files from all builds → AIO-REJ.zip
  │
  └── release (if release_type != Actions && repo == ReSukiSU-GKI)
        └── Creates GitHub Release with generated notes + commit info

kernel-custom.yml (single sublevel dispatch)
  │  Inputs: android_version, kernel_version, sub_level, os_patch_level, revision
  │  Feature toggles: use_zram, use_bbg, use_rekernel, cancel_susfs, droidspaces
  │
  ├── build-custom-kernel ──→ build.yml (single run)
  └── get-ksu-manager ──→ get-manager.yml

build.yml (reusable, 1470 lines)
  │  Inputs: 15 parameters (version info + feature toggles)
  │  Single job: build-kernel, timeout 60min
  │  Steps: 40+ steps
```

---

## 4. build.yml — The Core Build Engine (1470 lines)

### 4.1 Step Sequence

| Step | Purpose |
|------|---------|
| 1. Build info summary | Print all build parameters |
| 2. Free disk space | Remove unused preinstalled packages (~20GB freed) |
| 3. Checkout repo | actions/checkout@v6 |
| 4. Init build env | Set CONFIG, KERNEL_ROOT, tool paths; download repo tool |
| 5. Show config | Display config/config if present |
| 6. Install deps | ccache, python3, git, build-essential, libssl, bison, flex, libelf, dwarves |
| 7. Configure ccache | 2GB max, compression on |
| 8. Restore ccache cache | Cache key: `{version}-{kernel}-{sublevel}-ccache-{sha}` |
| 9. Cache toolchain | kernel-build-tools + mkbootimg (key: `toolchain-linux-v1`) |
| 10. Download toolchain | If cache miss: clone from AOSP `main-kernel-build-2024` branch |
| 11. Generate signing key | RSA 2048-bit for boot.img signing |
| 12. Configure git | BuildBot identity |
| 13. Clone dependencies | AnyKernel3, SUSFS (simonpunk), kernel_patches, SukiSU_patch, Action-Build |
| 14. Init + sync kernel | `repo init --depth=1 -b common-{android}-{kernel}-{spl}` then `repo sync` |
| 15. Stock config spoof | Auto-detect `config/stock_defconfig`, patch Makefile to use it |
| 16. Extract sublevel | Read actual SUBLEVEL from kernel Makefile |
| 17. Fix glibc 2.38 | Sublevel-dependent compat patches for old kernels on new runners |
| 18. OnePlus 8E support | Apply hmbird_patch.c if enabled |
| 19. Determine KSU branch | Custom commit/branch or default main |
| 20. Add KernelSU | `curl setup.sh \| bash` for ReSukiSU |
| 21. Apply SUSFS patches | Copy 50_add_susfs patch + fs/ + include/linux/ files; ~20 per-sublevel compat fixes |
| 22. Apply SUSFS post-patches | 5.15 LTS task_mmu.c fix, 6.1 namespace.c fix, 6.6 base.c/memory.c fixes |
| 23. Clone Droidspaces | If enabled, SYSVIPC kABI patches + POSIX_MQUEUE |
| 24. Backup defconfig | For fragment generation |
| 25. Integrate Droidspaces | Apply slot-specific kABI patches + enable 7 kernel configs |
| 26-35. Build + package | defconfig merge, compile, AnyKernel3 packaging, boot.img signing |
| 36-40. Upload + release | Artifact upload, version tagging |

### 4.2 SUSFS Patch Application Engine

The most complex part. The workflow:

1. **Copies raw patches** from `susfs4ksu/kernel_patches/`:
   - `50_add_susfs_in_gki-{android}-{kernel}.patch` (main patch)
   - `fs/*` (filesystem hooks)
   - `include/linux/*` (header additions)

2. **Pre-patch context fixes** (before applying main patch):
   - A12 5.10 sub ≤43: Fix `base.c` context (int vs size_t)
   - A12 5.10 sub ≤117: Fix `fdinfo.c` (remove mask variable, replace with helper)
   - A13 5.10 sub ≤107: Same fdinfo.c fix
   - A13 5.15 sub ≤41: Same fdinfo.c fix
   - A14 6.1 sub ≤43: Same fdinfo.c fix
   - A15 6.6 sub ≤92: Remove `dma-buf.h` include from `base.c`
   - A15 6.6 sub ≤57: Remove `zswap.h` include from `memory.c`
   - A16 6.12 sub ≥58: Add `dma-buf.h` to `exec.c`

3. **Applies main SUSFS patch** via standard `patch -p1`

4. **Post-patch fixes** (after applying, per sublevel):
   - A12 5.10 sub ≤209: `goto show_pad → return 0` in `task_mmu.c`
   - A12 5.10 SPL=2024-11: `vm_flags_clear()` → manual bit clear (missing helper)
   - A13 5.15 SPL=2024-11: Same `vm_flags_clear()` fix
   - A13 5.15 sub ≤148: `goto show_pad` fix
   - A13 5.15: Missing `susfs_def.h` include in `task_mmu.c` (conditional injection)
   - A14 6.1: Missing `susfs_def.h` in `base.c` and `namespace.c`
   - A14 6.1 sub ≤75: `goto show_pad` fix
   - A15 6.6: Missing `susfs_def.h` in `base.c` and `memory.c`
   - A16 6.12: `setuid_hook.c` duplicate definition fix
   - A16 6.12: Missing `susfs_def.h` in `exec.c`

### 4.3 glibc 2.38 Compatibility

GitHub Actions `ubuntu-latest` ships glibc 2.38+. Old kernel build tools break:

```
android13-5.10 (sub ≤186): Needs fix
android13-5.15 (sub ≤119): Needs fix
android14-6.1  (sub ≤43):  Needs fix
```

Fixes applied:
- `tools/bpf/resolve_btfids/Makefile`: Add `EXTRA_CFLAGS`
- `tools/lib/subcmd/parse-options.c`: Move `int i` declaration (C89 compat)

### 4.4 Kernel Source Acquisition

Uses AOSP `repo` tool (not sparse checkout):
```bash
repo init --depth=1 \
  -u https://android.googlesource.com/kernel/manifest \
  -b common-{android_version}-{kernel_version}-{os_patch_level}
repo sync -c -j$(nproc) --no-tags --fail-fast
```

Deprecated branch handling: if `git ls-remote` returns "deprecated" in the branch name, the manifest XML is patched to use `deprecated/{branch}`.

---

## 5. Data System

### 5.1 gki_fetch.py

Scrapes Google's `kernel/common` repo to discover available kernel sublevels:

```
For each (android_version, kernel_version) pair:
  1. Generate date range (start → end or current month)
  2. For each YYYY-MM:
     a. Fetch Makefile from common-{android}-{kernel}-{date}
     b. Try deprecated/ prefix on failure
     c. Parse VERSION, PATCHLEVEL, SUBLEVEL
  3. Also fetch LTS branch Makefile
  4. Output JSON → data/{android}/{kernel}.json
```

### 5.2 JSON Data Format (android12/5.10.json)
```json
{
  "android_version": "android12",
  "kernel_version": "5.10",
  "lts": "5.10.256",
  "entries": [
    {"date": "2021-08", "kernel": "5.10.43"},
    {"date": "2021-09", "kernel": "5.10.43"},
    ...
  ]
}
```

The JSON files serve as:
1. Input for per-version workflows (kernel-a12-5-10.yml reads them to build matrix)
2. Data source for GitHub Pages dashboard (update-pages.yml)
3. Sublevel validation reference

---

## 6. Feature Toggle Matrix

| Feature | Input | Default | Implementation |
|---------|-------|---------|----------------|
| SUSFS | `cancel_susfs` (inverted) | false (= SUSFS ON) | Patches from simonpunk/susfs4ksu |
| ZRAM LZ4K | `use_zram` | false | Copy zram/lz4/ files → kernel source |
| BBG (反格机) | `use_bbg` | false | Apply kernel_patches BBG patch |
| Re-Kernel | `use_rekernel` | false | Apply kernel_patches rekernel patch |
| Droidspaces | `droidspaces` | "off" | SYSVIPC kABI patches + config enables |
| Droidspaces NTSync | `droidspaces_ntsync` | false | Additional CONFIG enables |
| OnePlus 8E | `supp_op` | false | Include hmbird_patch.c in drivers |
| Stock config spoof | Auto-detect | N/A | Replaces `/proc/config.gz` generator |

### 6.1 Droidspaces Slot System

Droidspaces needs SYSVIPC kABI fix patches. Three slot configurations exist because different kernel sublevels have different kABI padding:

| Slot | Patch | Recommended |
|------|-------|-------------|
| 678 | `fix_sysvipc_kabi_6_7_8.patch` | ✅ Recommended |
| 123 | `fix_sysvipc_kabi_1_2_3.patch` | Alternative |
| 345 | `fix_sysvipc_kabi_3_4_5.patch` | Alternative |

6.12 kernel: single patch (no slot selection needed).

---

## 7. Release System

### 7.1 Version Tagging
```
Tag format: {SUSFS_VERSION}-r{N}
  SUSFS_VERSION: from susfs4ksu branch (e.g., "1.5.3")
  N: monotonic counter, reset when SUSFS version changes
  
Example: 1.5.3-r0, 1.5.3-r1, 1.5.3-r2
```

### 7.2 Release Notes
Auto-generated markdown with:
- KSU variant + version
- SUSFS version + commit links per branch
- Feature status table (BBG, LZ4, etc.)
- Commit references for ReSukiSU + SUSFS (5 branches)
- Risk disclaimer (Chinese + English)
- Post-flash guide

### 7.3 Artifacts
- `AnyKernel3-*.zip` — flashable kernel ZIP per sublevel
- `*-Rejects.zip` — `.rej` files from failed patch hunks
- `AIO-REJ.zip` — aggregated rejects from all builds
- Manager APK + SUSFS module ZIP

---

## 8. Concurrency & Optimization

### 8.1 main.yml Concurrency
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```
New dispatch cancels running build. Prevents queue buildup.

### 8.2 ccache Strategy
```
Cache key: {android}-{kernel}-{sublevel}-ccache-{sha}
Restore keys: {android}-{kernel}-{sublevel}-ccache-
```
SHA-specific primary key + prefix fallback. Hit rate ~60% on sequential sublevel builds.

### 8.3 Toolchain Caching
```
Cache paths: kernel-build-tools, mkbootimg
Cache key: toolchain-linux-v1 (static — never expires)
```
AOSP build tools rarely change, so single static key.

### 8.4 Disk Space
`endersonmenezes/free-disk-space@v3` removes:
- Android SDK, .NET, Haskell, tool cache, swap
- Packages: azure-cli, google-cloud-cli, browsers, postgresql, LLVM, MySQL, dotnet
- Folders: swift, miniconda, azure, node_modules, chromium, powershell, julia, aws-cli
Result: ~20GB freed (critical for repo sync + kernel compile).

---

## 9. Per-Version Workflows (kernel-a12-5-10.yml etc.)

Each reads the corresponding `data/{android}/{kernel}.json` and builds a **matrix strategy** from the `entries` array:

```yaml
strategy:
  fail-fast: false
  matrix:
    include: ${{ fromJson(needs.read-data.outputs.matrix) }}
```

Each matrix entry maps to one `build.yml` call. All sublevels within a version build in parallel.

Example: A12 5.10 has ~40 entries → 40 parallel `build.yml` invocations.

---

## 10. Stock Config Spoofing

Auto-detection mechanism — no workflow toggle needed:

1. Check if `config/stock_defconfig` exists in repo
2. If yes: copy to `$KERNEL_ROOT/common/arch/arm64/configs/stock_defconfig`
3. Patch `common/kernel/Makefile`: replace `$(KCONFIG_CONFIG)` → `arch/arm64/configs/stock_defconfig`
4. Result: `/proc/config.gz` on device shows stock config, not build-time config

This defeats `/proc/config.gz`-based detection that looks for SUSFS/KSU config flags.

---

## 11. Key Engineering Insights

1. **1470-line monolith** — `build.yml` is the single build engine. All per-version workflows are thin wrappers that feed it inputs. Changes to build logic happen in one place.

2. **Sublevel-specific compat patches** — ~30 conditional sed/perl fixes for different kernel sublevels. This is the maintenance burden: every new sublevel may need new context fixes for SUSFS patches.

3. **ReSukiSU-only after c17aae5** — Multi-variant support removed. The kernel driver is still ReSukiSU but supports other managers via multi-manager mode (KowSU, SukiSU-Ultra managers work).

4. **AOSP repo tool** — Uses full `repo sync` (not sparse checkout like Super-Builders). Slower but gets complete kernel tree including all drivers.

5. **fail-fast: false everywhere** — One sublevel failure doesn't block others. Critical for CI reliability across ~200 sublevels.

6. **GitLab SUSFS dependency** — SUSFS patches come from simonpunk's GitLab, not GitHub. GitLab API rate limits differ.

7. **deprecated/ branch handling** — Google deprecates old kernel branches to `deprecated/` prefix. The workflow auto-detects and adjusts.

8. **AnyKernel3 packaging** — Kernels are packaged as AnyKernel3 ZIPs (universal flashable format), not raw Images. AnyKernel3 unpacks the device's current boot.img, replaces the kernel, repacks.

9. **Fork guard** — `release` job only runs on `ReSukiSU-GKI/GKI_KernelSU_SUSFS`. Forks skip release creation.

10. **Gaokao archive** — Repo archived June 2026. Builds stop. Users must fork and self-host.
