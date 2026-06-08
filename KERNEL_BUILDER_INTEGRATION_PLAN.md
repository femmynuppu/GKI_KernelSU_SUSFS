# KERNEL BUILDER INTEGRATION PLAN
# GKI_KernelSU_SUSFS — What's Present vs What's Missing
# Target: SUSFS v2.1 + ZeroMount VFS + TCP BBR + BBG + Enhanced ZRAM

================================================================================
EXECUTIVE SUMMARY
================================================================================

GKI_KernelSU_SUSFS builds a GKI kernel with SUSFS + BBG + ZRAM LZ4K. The 
Super-Builders project adds ZeroMount VFS (60_ patch) + Enhanced SUSFS (51_ 
patch). Neither project implements TCP BBR. The combined gap is: BBR, ZeroMount,
and SUSFS v2.1 upgrade — all missing from GKI_KernelSU_SUSFS; BBR missing from
both.

================================================================================
1. WHAT GKI_KernelSU_SUSFS CURRENTLY BUILDS
================================================================================

Feature                      Status     Source                        build.yml Ref
──────────────────────────   ────────   ───────────────────────────   ────────────
SUSFS (50_ base patch)       ✅ YES     simonpunk/susfs4ksu GitLab     lines 440-718
SUSFS configs                 ✅ YES     Hardcoded CONFIG_KSU_SUSFS_*   lines 1167-1181
BBG (Baseband Guard)          ✅ YES     vc-teahouse/Baseband-guard     lines 1050-1058
ZRAM LZ4 v1.10.0 upgrade      ✅ YES     Local zram/ sources           lines 921-931
ZRAM ARM64 NEON acceleration  ✅ YES     zram/apply_lz4_neon.sh        line 931
ZRAM LZ4KD + LZ4K_OPLUS       ✅ YES     SukiSU_patch repo             lines 938-951
ZRAM defconfig fragment       ✅ YES     config/zram.config            lines 1045-1048
Re-Kernel                     ⚠️ OPT     Sakion-Team/Re-Kernel         lines 1060-1120
Droidspaces                   ⚠️ OPT     ravindu644/Droidspaces-OSS    lines 731-852
Droidspaces NTSync            ⚠️ OPT     Goldzxcbug/NTsync patches     lines 854-907
Unicode bypass fix             ✅ YES     Action-Build/patches          lines 909-917
Stock config spoofing          ✅ YES     config/stock_defconfig        lines 311-351
OnePlus 8E support            ⚠️ OPT     hmbird_patch.c                lines 397-403

================================================================================
2. WHAT IS MISSING (GAPS)
================================================================================

2.1 TCP BBR — COMPLETELY ABSENT
──────────────────────────────────────────────────────────────────────────────
Status: NOT PRESENT anywhere in the entire GKI_KernelSU_SUSFS repository.

Evidence:
  - grep for 'bbr', 'tcp_cong', 'CONFIG_TCP_CONG_BBR', 'CONFIG_TCP_CONG'
    across entire repo → ZERO matches
  - No defconfig fragment for BBR
  - No kernel config step enables any TCP congestion control
  - build.yml lines 1122-1181 (Configure Kernel Options / SUSFS Config): 
    Only KSU, SUSFS, and ZRAM configs. No TCP settings.

What needs to be added:
  - CONFIG_TCP_CONG_BBR=y (enables the BBR module/algorithm)
  - CONFIG_DEFAULT_BBR=y (sets BBR as default congestion control)
  - CONFIG_TCP_CONG_CUBIC=y or =n (BBR replaces CUBIC as default)
  - CONFIG_DEFAULT_TCP_CONG="bbr"

Where to add in build.yml:
  After line 1131 (end of "Configure Kernel Options" block), BEFORE
  "Add SUSFS Config" step (line 1165), add a BBR config injection step.

2.2 ZeroMount VFS — COMPLETELY ABSENT
──────────────────────────────────────────────────────────────────────────────
Status: NOT PRESENT in GKI_KernelSU_SUSFS. Exists ONLY in Super-Builders.

Evidence:
  - grep for 'zeromount', 'ZeroMount', 'zero_mount' in GKI_KernelSU_SUSFS 
    → ZERO matches
  - grep for 'getname', 'vfs_getname' in GKI_KernelSU_SUSFS → ZERO matches
  - grep for '60_' in build.yml → ZERO matches
  - build.yml has no zeromount toggle input parameter

Super-Builders has it (NOT in GKI_KernelSU_SUSFS):
  - KerNEL_CUSTOM_WORKFLOW_ANALYSIS.md lines 49-53: `add_zeromount` toggle
  - SUPER_BUILDERS_ENGINEERING.md line 49: 60_ layer = ZeroMount VFS
  - build-resukisu.yml lines 273-281: Apply ZeroMount Patch step

The 60_zeromount patch provides:
  - VFS getname() interception for path redirection
  - Directory entry injection (files appear in ls/readdir)
  - d_path spoofing for /proc/PID/fd symlinks
  - mmap metadata spoofing
  - SELinux xattr injection
  - statfs spoofing (EROFS_SUPER_MAGIC)
  - Write protection for injected files
  - Bloom filter (4096-bit, 3-hash pre-check)
  - ioctl control via /dev/zeromount miscdevice (11 commands)

What needs to be added:
  - A new `use_zeromount` boolean input to build.yml (similar to use_bbg)
  - A step to apply the 60_zeromount-{android}-{kernel}.patch from
    Super-Builders' android12-5.10/SukiSU-Ultra/patches/ directory
  - The patch must be downloaded or vendored into GKI_KernelSU_SUSFS
  - Kernel config: CONFIG_ZEROMOUNT=y (if the patch defines a Kconfig symbol)

2.3 SUSFS v2.1 — VERSION GAP
──────────────────────────────────────────────────────────────────────────────
Status: SUSFS IS present, but version may be outdated vs upstream v2.1.0.

Evidence:
  - build.yml line 257: clones from simonpunk/susfs4ksu via branch 
    `gki-{android_version}-{kernel_version}`
  - config/config line 16: custom=false (uses latest of each branch)
  - susfs4ksu README line 15: "Since v2.0.0, SUSFS does not rely on 
    kernel features like KPROBES..."
  - Engineering doc mentions SUSFS_VERSION from branch (e.g., "1.5.3")
  - The actual version depends on which branch/tag is cloned at build time
  - The upstream susfs4ksu repo (C:/PROJECT/susfs4ksu) is checked out on 
    branch gki-android12-5.10 — this is the *upstream reference*, not the
    version used in builds (which clones fresh from GitLab each time)

What needs to be verified:
  - Does simonpunk/susfs4ksu have v2.1.0 tags on the branches used?
  - The config/config custom commit mechanism (lines 260-272) allows 
    pinning to specific commits — useful for v2.1.0 if it's on a branch

What may be missing (v2.1 features):
  - New CONFIG_KSU_SUSFS_* options that v2.1.0 introduces
  - Possible new Kconfig entries that need enabling in defconfig
  - New source files in kernel_patches/fs/ or kernel_patches/include/linux/
  - Userspace module changes (already covered by susfs4ksu module)

2.4 Enhanced SUSFS (51_ patch) — ABSENT
──────────────────────────────────────────────────────────────────────────────
Status: NOT PRESENT in GKI_KernelSU_SUSFS. Only in Super-Builders.

Evidence:
  - No '51_' references in build.yml or entire GKI_KernelSU_SUSFS repo
  - Super-Builders SUPER_BUILDERS_ENGINEERING.md line 218:
    "51_enhanced_susfs — additional SUSFS patch layer for live clones"

The 51_ patch adds:
  - Kstat redirect (virtual-path stat → real-path metadata)
  - Unicode filter (blocks invisible/confusable Unicode path attacks)
  - AS_FLAGS collision guards (BUILD_BUG_ON for inode flag bits)

2.5 BBG — PRESENT but MINOR CONFIG GAP
──────────────────────────────────────────────────────────────────────────────
Status: PRESENT and enabled by default (use_bbg defaults to true at line 63).

Implementation:
  - Line 1053: `if: inputs.use_bbg`
  - Lines 1056-1058:
    1. Downloads and runs setup.sh from vc-teahouse/Baseband-guard
    2. Appends CONFIG_BBG=y to gki_defconfig
    3. Modifies common/security/Kconfig to add baseband_guard to LSM defaults

BBG is adequately covered. No gap.

================================================================================
3. EXISTING ZRAM FEATURE — DETAILED INVENTORY
================================================================================

Source files in zram/ directory:
  zram/lz4/lz4.h                  — LZ4 v1.10.0 header (984 lines)
  zram/lz4/lz4.c                  — LZ4 v1.10.0 compression
  zram/lz4/lz4hc.h                — LZ4 HC header
  zram/lz4/lz4hc.c                — LZ4 HC compression
  zram/lz4/Makefile               — Build: lz4.o, lz4hc.o, ARM64 NEON objects
  zram/lz4/lz4armv8/lz4accel.h   — ARM64 NEON detection + SIMD wrappers
  zram/lz4/lz4armv8/lz4accel.c   — ARM64 NEON accelerator C glue
  zram/lz4/lz4armv8/lz4armv8.S   — ARM64 NEON hand-written ASM decompressor
  zram/include/linux/lz4.h        — Kernel compatibility wrapper
  zram/apply_lz4_neon.sh          — Injects NEON calls into crypto/lz4.c,
                                     crypto/lz4hc.c, fs/f2fs/compress.c,
                                     fs/incfs/data_mgmt.c

ZRAM build steps (build.yml lines 921-1048):
  1. Replace kernel lib/lz4/ with v1.10.0 (line 927-930)
  2. Replace include/linux/lz4.h (line 930)
  3. Run apply_lz4_neon.sh (line 931) — patches 4 kernel files
  4. Fix f2fs Makefile (lines 933-935)
  5. Copy LZ4K/LZ4KD/LZ4K_OPLUS from SukiSU_patch (lines 938-951)
  6. Apply lz4kd.patch + lz4k_oplus.patch (lines 943-951)
  7. Configure kernel options (lines 1008-1048):
     - 5.10: CONFIG_ZSMALLOC=y, CONFIG_ZRAM=y, CONFIG_CRYPTO_LZO=y,
             CONFIG_ZRAM_DEF_COMP_LZ4KD=y
     - 5.15/6.1: Change ZRAM/ZSMALLOC from =m to =y
     - 6.6: Change ZRAM from =m to =y, add ZSMALLOC=y
     - All: Append config/zram.config fragment
  8. config/zram.config enables:
     CONFIG_CRYPTO_LZ4HC=y
     CONFIG_CRYPTO_LZ4K=y
     CONFIG_CRYPTO_LZ4KD=y
     CONFIG_CRYPTO_842=y
     CONFIG_CRYPTO_LZ4K_OPLUS=y

ZRAM assessment: ADEQUATE. The LZ4 v1.10.0 + NEON + LZ4KD + LZ4K_OPLUS
stack is comprehensive. No ZRAM feature gaps identified.

================================================================================
4. INTEGRATION GAPS — PRECISE FILE:LINE REFERENCE TABLE
================================================================================

ID   Feature               Status      File:Line(s)                    Action Required
───  ────────────────────  ─────────   ──────────────────────────────  ────────────────
G1   TCP BBR               MISSING     build.yml: NOWHERE              Add config step
G2   ZeroMount VFS driver  MISSING     build.yml: NOWHERE              Add patch step
G3   ZeroMount toggle      MISSING     build.yml:56-71 (inputs)        Add use_zeromount
G4   SUSFS v2.1 version    UNCERTAIN   build.yml:257 (clone branch)    Verify upstream tag
G5   Enhanced SUSFS 51_    MISSING     build.yml: NOWHERE              Add patch step
G6   ZRAM defconfig gap    MINOR       build.yml:1045-1048             Verify   config
                                                                       covers all algos
G7   ZRAM 6.12 module fix  PRESENT     build.yml:1324-1327             LTO=none for Rust

================================================================================
5. RECOMMENDED INTEGRATION STEPS (IN ORDER)
================================================================================

Step 1: Add use_zeromount input toggle
  File: build.yml, lines 56-71 (inputs section)
  Add: use_zeromount: required: false, type: boolean, default: false

Step 2: Add ZeroMount patch application step
  File: build.yml, after line 1058 (after BBG step, before Re-Kernel)
  Logic: if use_zeromount, download and apply 60_zeromount patch from
  a vendored location (or from Super-Builders repo)

Step 3: Add BBR kernel config step
  File: build.yml, after line 1131 (after "Configure Kernel Options")
  Add step that appends to gki_defconfig:
    CONFIG_TCP_CONG_BBR=y
    CONFIG_DEFAULT_BBR=y
    CONFIG_DEFAULT_TCP_CONG="bbr"

Step 4: Verify SUSFS v2.1.0 availability
  Check if susfs4ksu upstream has v2.1.0 tags on the GKI branches
  If yes, use config/config custom commit to pin to v2.1.0
  If no, the current branch HEAD may already be v2.1.0

Step 5: Optionally add 51_enhanced_susfs patch
  If v2.1.0 compatibility requires it, add step similar to build-resukisu.yml
  lines 259-264

================================================================================
6. SUPER-BUILDERS vs GKI_KernelSU_SUSFS — FEATURE MATRIX
================================================================================

Feature                  Super-Builders        GKI_KernelSU_SUSFS
───────────────────────  ────────────────────  ─────────────────────
SUSFS (50_ base)         ✅ Yes                ✅ Yes
Enhanced SUSFS (51_)     ✅ Yes                ❌ No
ZeroMount VFS (60_)      ✅ Yes                ❌ No
KSU Safety (70_)         ✅ Yes                ❌ No (built into ReSukiSU)
BBG                       ✅ Yes                ✅ Yes
ZRAM LZ4K                 ✅ Yes                ✅ Yes
TCP BBR                   ❌ No                 ❌ No (neither has it)
OverlayFS support         ✅ Yes                ❌ No
ptrace fix                ✅ Yes                ❌ No
perf patches              ✅ Yes                ❌ No
Stock identity spoofing   ✅ Yes (device-profiles) ✅ Partial (stock_defconfig only)
KPM                       ✅ Optional            ✅ Optional (SukiSU/ReSukiSU)

================================================================================
7. FILE INVENTORY FOR REFERENCE
================================================================================

Primary build engine:
  C:/PROJECT/GKI_KernelSU_SUSFS/.github/workflows/build.yml (1470 lines)

Configuration:
  C:/PROJECT/GKI_KernelSU_SUSFS/config/config (28 lines)
  C:/PROJECT/GKI_KernelSU_SUSFS/config/zram.config (7 lines)

ZRAM sources:
  C:/PROJECT/GKI_KernelSU_SUSFS/zram/lz4/ (5 files)
  C:/PROJECT/GKI_KernelSU_SUSFS/zram/lz4/lz4armv8/ (3 files)
  C:/PROJECT/GKI_KernelSU_SUSFS/zram/include/linux/lz4.h
  C:/PROJECT/GKI_KernelSU_SUSFS/zram/apply_lz4_neon.sh

Reference (Super-Builders):
  C:/PROJECT/Super-Builders/.github/workflows/kernel-custom.yml
  C:/PROJECT/Super-Builders/.github/workflows/build-resukisu.yml
  C:/PROJECT/Super-Builders/SUPER_BUILDERS_ENGINEERING.md
  C:/PROJECT/Super-Builders/KERNEL_CUSTOM_WORKFLOW_ANALYSIS.md

Reference (upstream SUSFS):
  C:/PROJECT/susfs4ksu/kernel_patches/ (5 files, android12-5.10 branch only)

Engineering docs:
  C:/PROJECT/GKI_KernelSU_SUSFS/GKI_KERNELSU_SUSFS_ENGINEERING.md
  C:/PROJECT/zeromount/ZEROMOUNT_ENGINEERING.md

================================================================================
END OF PLAN
================================================================================
