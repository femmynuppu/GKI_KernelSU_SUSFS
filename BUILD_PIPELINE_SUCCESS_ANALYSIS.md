# BUILD PIPELINE SUCCESS ANALYSIS: GKI_KernelSU_SUSFS

## Overview

This 1470-line reusable GitHub Actions workflow (`workflow_call`) compiles GKI kernels with SUSFS + ReSukiSU + BBG + ZRAM across **5 Android versions** (12–16) × **5 kernel versions** (5.10, 5.15, 6.1, 6.6, 6.12). It has never failed in production.

**Why it works:** Exhaustive ad-hoc compatibility fixes collected iteratively across every android×kernel×sublevel combination. Every conditional exists because a real build failure was encountered and patched. The workflow is a living artifact of trial-and-error hardening, not a clean design.

---

## PHASE 0: PRE-FLIGHT

```
┌─────────────────┐
│ Build Summary   │ Echo all inputs for debugging traceability
└────────┬────────┘
         ▼
┌─────────────────┐
│ Free Disk Space │ Remove ~20GB of pre-installed GH runners software
│ (endersonmenez) │ (Android SDKs, .NET, Haskell, Azure/GCloud CLI, LLVM, browsers...)
└────────┬────────┘   WHY: Kernel source trees are massive. Bazel caches eat disk.
         ▼             Without cleanup, builds fail with "no space left on device."
┌─────────────────┐
│ Checkout Repo   │ actions/checkout@v6
└────────┬────────┘
         ▼
```

## PHASE 1: ENVIRONMENT BOOTSTRAP

```
┌────────────────────────┐
│ Init Build Environment │
│  - Set CONFIG (android-kernel-sublevel identifier)
│  - Export KERNEL_ROOT, DEFCONFIG, SUSFS4KSU, etc. to $GITHUB_ENV
│  - Download `repo` tool from Google Storage → $GITHUB_PATH
└────────┬───────────────┘   WHY: repo is required for AOSP kernel manifest sync.
         ▼                   Placed in PATH, not system-wide, for isolation.
┌────────────────────────┐
│ Show Config File       │ Optional config/config file for custom commit SHAs
└────────┬───────────────┘
         ▼
┌────────────────────────┐
│ Install Dependencies   │ ccache python3 git curl build-essential libssl-dev
│ (apt-get)              │ bison flex libelf-dev dwarves
└────────┬───────────────┘   WHY: dwarves → pahole (BTF generation)
         ▼                   bison/flex → Kconfig parser
┌────────────────────────┐
│ Configure ccache       │ max-size=2G, compression=true
│                        │ CCACHE_COMPILERCHECK="%compiler% -dumpmachine; %compiler% -dumpversion"
│                        │ CCACHE_NOHARDLINK=true
└────────┬───────────────┘   WHY: Avoids false cache hits when toolchain changes.
         ▼                   HARDLINK=true: ccache uses hardlinks to avoid copies.
┌────────────────────────┐
│ Restore ccache Cache   │ Key: android-kernel-sublevel-ccache-{sha}
│ (actions/cache@v5)     │ restore-keys: android-kernel-sublevel-ccache- (fuzzy match)
└────────┬───────────────┘   WHY: Cache key includes SHA for exact match on rebuild
         ▼                   of same commit; falls back to most recent same config.
┌────────────────────────┐
│ Cache Toolchain        │ Key: toolchain-{runner.os}-v1
│ (actions/cache@v5)     │ Caches: kernel-build-tools/, mkbootimg/
│ (if cache miss → clone)│
└────────┬───────────────┘   WHY: kernel-build-tools is ~2GB. Cloning from AOSP
         ▼                   googlesource mirror takes 2–5 minutes. Cache avoids it.
┌────────────────────────┐
│ Generate Signing Key   │ openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048
└────────┬───────────────┘   (Note: Boot image construction is commented out in current version)
         ▼
┌────────────────────────┐
│ Configure Git          │ user.name "BuildBot", user.email "BuildGkiKernel@gmail.com"
└────────┬───────────────┘   WHY: Required for repo and any git am operations.
         ▼
┌────────────────────────┐
│ Clone Dependencies     │
│  - AnyKernel3 (master)             → packaging template
│  - susfs4ksu (gki-{android}-{kernel}) → SUSFS patches from simonpunk
│    * Optional: checkout custom commit from config/config
│  - kernel_patches (WildKernels)     → Samsung min_kdp, etc.
│  - SukiSU_patch (ShirkNeko)         → ZRAM LZ4KD/Oplus patches
│  - Action-Build (Numbersf)          → Unicode bypass patches
└────────────────────────┘
```

## PHASE 2: KERNEL SOURCE ACQUISITION

```
┌──────────────────────────────────────┐
│ Clone GCC 6.4.1 (LineageOS)          │ Only used for 5.x kernel compilation
│ → $KERNEL_ROOT/gcc                   │ (6.x+ uses clang via Bazel)
└────────┬─────────────────────────────┘
         ▼
┌──────────────────────────────────────┐
│ repo init --depth=1                  │
│ -u https://android.googlesource.com  │
│    /kernel/manifest                  │
│ -b common-{android}-{kernel}-{patch} │
│ --repo-rev=v2.16                     │
└────────┬─────────────────────────────┘
         ▼
┌──────────────────────────────────────┐
│ DEPRECATED BRANCH DETECTION          │
│                                      │
│ git ls-remote check:                 │
│   if remote shows "deprecated":      │
│     sed default.xml:                 │
│       "common-{branch}"              │
│       → "deprecated/common-{branch}" │
│                                      │
│ WHY: Google moves old branches under │
│ deprecated/ prefix. Without this,    │
│ repo sync fails with "revision not   │
│ found" on older android12/android13  │
│ branches.                            │
└────────┬─────────────────────────────┘
         ▼
┌──────────────────────────────────────┐
│ repo --trace sync -c -j$(nproc)      │
│ --no-tags --fail-fast                │
│                                      │
│ -c: only current branch (faster)     │
│ --no-tags: skip tag objects (~500MB) │
│ --fail-fast: stop on first error     │
└──────────────────────────────────────┘
```

## PHASE 3: STOCK DEFCONFIG SPOOF (OPTIONAL)

```
┌──────────────────────────────────────┐
│ IF config/stock_defconfig EXISTS:    │
│   1. Copy to arch/arm64/configs/     │
│   2. Patch common/kernel/Makefile:   │
│      $(obj)/config_data:             │
│        $(KCONFIG_CONFIG) FORCE       │
│      → $(obj)/config_data:           │
│        arch/arm64/configs/           │
│        stock_defconfig FORCE         │
│                                      │
│ WHY: Some root-detection apps check  │
│ /proc/config.gz to see if kernel     │
│ supports specific features. This     │
│ replaces the live config with a      │
│ pre-baked "stock" config that hides  │
│ SUSFS/KSU modifications.             │
│                                      │
│ Idempotent: skips if already applied.│
│ Hard error if Makefile missing or    │
│ neither old nor new rule matches.    │
└──────────────────────────────────────┘
```

## PHASE 4: SUBLEVEL EXTRACTION

```
┌──────────────────────────────────────┐
│ Read SUBLEVEL from Makefile          │
│ Fall back to inputs.sub_level if     │
│ extraction fails.                    │
│                                      │
│ WHY: The actual SUBLEVEL may differ  │
│ from the input parameter. Using the  │
│ real value ensures compatibility     │
│ checks use accurate numbers.         │
└──────────────────────────────────────┘
```

## PHASE 5: GLIBC 2.38 COMPATIBILITY FIX

```
┌───────────────────────────────────────────────────────────────┐
│ CONDITION: Ubuntu 24.04 runners ship glibc >= 2.38.          │
│ Old kernels (pre-2023) have code that breaks with >=2.38.    │
│                                                               │
│ TRIGGERS (all must match):                                    │
│   android13 + 5.10  + sub ≤ 186                               │
│   android13 + 5.15  + sub ≤ 119                               │
│   android14 + 6.1   + sub ≤ 43                                │
│   + actual glibc >= 2.38 on runner                           │
│                                                               │
│ FIXES APPLIED:                                                │
│   1. tools/bpf/resolve_btfids/Makefile:                       │
│      Append EXTRA_CFLAGS="$(CFLAGS)" to sub-make invocation  │
│      → Fixes BTF ID resolution link failure                  │
│                                                               │
│   2. tools/lib/subcmd/parse-options.c (5.10/5.15 only):      │
│      Move `int i;` declarations before C99-style for loops    │
│      → Fixes "for loop initial declarations" with -std=gnu89 │
│                                                               │
│ WHY: glibc 2.38 changed _FORTIFY_SOURCE defaults and         │
│ strlcpy/strlcat behavior. Combined with -Werror in kernel,   │
│ old code fails to compile. Android upstream eventually       │
│ fixed these, but sublevels below thresholds predate the fix. │
└───────────────────────────────────────────────────────────────┘
```

## PHASE 6: ONEPLUS 8E SUPPORT (OPTIONAL, `supp_op`)

```
Conditional on inputs.supp_op. Downloads hmbird_patch.c and adds to drivers/Makefile.
```

## PHASE 7: KERNELSU INTEGRATION

```
┌──────────────────────────────┐
│ Determine KSU Branch         │
│  - If ksu_branch specified:  │
│    BRANCH="-s {branch}"      │
│  - Else: BRANCH="-s main"    │
└────────┬─────────────────────┘
         ▼
┌──────────────────────────────┐
│ curl ReSukiSU setup.sh | bash│
│ → Clones KernelSU into       │
│   $KERNEL_ROOT/KernelSU      │
│                              │
│ WHY: setup.sh does the       │
│ integration work: copies     │
│ KernelSU source into kernel  │
│ tree, modifies Kconfig,      │
│ Makefiles, etc.              │
└──────────────────────────────┘
```

## PHASE 8: SUSFS PATCH — THE HEART OF THE PIPELINE

This is the most complex section (~280 lines). The architecture follows a **pre-context → apply → post-context → post-patch fixes** pattern.

```
┌──────────────────────────────────────────────────────────────┐
│ STEP 8a: COPY SUSFS FILES INTO KERNEL TREE                   │
│   - Copy 50_add_susfs_in_gki-{android}-{kernel}.patch        │
│   - Copy fs/* patches (susfs.c, etc.)                         │
│   - Copy include/linux/* headers                              │
└────────┬─────────────────────────────────────────────────────┘
         ▼
┌──────────────────────────────────────────────────────────────┐
│ STEP 8b: KERNELSU-VARIANT SUSFS HANDLING                     │
│   case "Official":                                            │
│     cd KernelSU; apply 10_enable_susfs_for_ksu.patch          │
│     * IF patch targets kernel/Makefile BUT NOT kernel/Kbuild: │
│       sed s|kernel/Makefile|kernel/Kbuild|g                   │
│       → Newer KSU repos renamed Makefile to Kbuild            │
│     * Uses `patch --forward` (skip if already applied)        │
│     * || true (non-fatal — patch may already exist)           │
│                                                               │
│   case "Next"/"SukiSU"/"ReSukiSU":                            │
│     Skip — these variants have built-in SUSFS support         │
└────────┬──────────────────────────────────────────────────────┘
         ▼
┌──────────────────────────────────────────────────────────────┐
│ STEP 8c: PRE-PATCH CONTEXT FIXES                              │
│                                                                │
│ PROBLEM: SUSFS patches are generated against specific kernel   │
│ sublevels. When sublevel differs, patch hunks fail because     │
│ surrounding context lines don't match.                         │
│                                                                │
│ SOLUTION: Before applying the patch, TEMPORARILY rewrite       │
│ the source files so the patch context matches. After applying, │
│ RESTORE to original state (Step 8d).                           │
│                                                                │
│ ╔════════════════════════════════════════════════════════════╗ │
│ ║  ANDROID 12 + 5.10                                         ║ │
│ ╠════════════════════════════════════════════════════════════╣ │
│ ║ sub ≤ 43:  fs/proc/base.c — normalize `this_len` type     ║ │
│ ║             int/size_t → size_t (unified type for patch)   ║ │
│ ║ sub ≤ 117: fs/notify/fdinfo.c — remove comment block       ║ │
│ ║             & replace mask,mark->ignored_mask pattern      ║ │
│ ║             → patch expects simpler fdinfo.c structure     ║ │
│ ╚════════════════════════════════════════════════════════════╝ │
│                                                                │
│ ╔════════════════════════════════════════════════════════════╗ │
│ ║  ANDROID 13 + 5.10                                         ║ │
│ ╠════════════════════════════════════════════════════════════╣ │
│ ║ sub ≤ 107: fs/notify/fdinfo.c — same fdinfo fix as above  ║ │
│ ╚════════════════════════════════════════════════════════════╝ │
│                                                                │
│ ╔════════════════════════════════════════════════════════════╗ │
│ ║  ANDROID 13 + 5.15                                         ║ │
│ ╠════════════════════════════════════════════════════════════╣ │
│ ║ sub ≤ 41:  fs/namespace.c — add mnt_idmapping.h include   ║ │
│ ║             fs/open.c      — add mnt_idmapping.h include   ║ │
│ ║             fs/notify/fdinfo.c — same fdinfo fix           ║ │
│ ╚════════════════════════════════════════════════════════════╝ │
│                                                                │
│ ╔════════════════════════════════════════════════════════════╗ │
│ ║  ANDROID 14 + 6.1                                          ║ │
│ ╠════════════════════════════════════════════════════════════╣ │
│ ║ sub ≤ 25:  fs/proc/base.c — add trace/hooks/sched.h       ║ │
│ ║ sub ≤ 141: fs/proc/base.c — add dma-buf.h include         ║ │
│ ║ sub ≥ 157: fs/namespace.c — remove trace/hooks/blk.h      ║ │
│ ╚════════════════════════════════════════════════════════════╝ │
│                                                                │
│ ╔════════════════════════════════════════════════════════════╗ │
│ ║  ANDROID 15 + 6.6                                          ║ │
│ ╠════════════════════════════════════════════════════════════╣ │
│ ║ sub ≤ 30:  task_mmu.c  — add last_vma_end assignment      ║ │
│ ║ sub ≤ 92:  base.c      — add dma-buf.h include            ║ │
│ ║ sub ≤ 57:  memory.c    — add zswap.h include              ║ │
│ ╚════════════════════════════════════════════════════════════╝ │
│                                                                │
│ ╔════════════════════════════════════════════════════════════╗ │
│ ║  ANDROID 16 + 6.12                                         ║ │
│ ╠════════════════════════════════════════════════════════════╣ │
│ ║ sub ≥ 58:  exec.c — remove dma-buf.h include (was added   ║ │
│ ║             in newer sublevels, patch doesn't expect it)   ║ │
│ ╚════════════════════════════════════════════════════════════╝ │
│                                                                │
│ ╔════════════════════════════════════════════════════════════╗ │
│ ║  KEY INSIGHT: Why android13-5.10 sub≤107 needs fdinfo.c   ║ │
│ ║  fix but android14-6.1 sub≤43 does NOT:                    ║ │
│ ║                                                            ║ │
│ ║  The fdinfo fix targets fs/notify/fdinfo.c which had a     ║ │
│ ║  multi-line comment block that the SUSFS patch's context   ║ │
│ ║  hunk couldn't anchor against. android14-6.1's fdinfo.c   ║ │
│ ║  has a different structure (the comment was already        ║ │
│ ║  removed or formatted differently in that kernel tree).    ║ │
│ ║  Different android×kernel combos inherit from different    ║ │
│ ║  upstream LTS branches, so fixes are version-specific.     ║ │
│ ╚════════════════════════════════════════════════════════════╝ │
└────────┬──────────────────────────────────────────────────────┘
         ▼
┌──────────────────────────────────────────────────────────────┐
│ STEP 8d: APPLY MAIN SUSFS PATCH                              │
│   patch -p1 < 50_add_susfs_in_gki-{android}-{kernel}.patch   │
│   || true  (non-fatal: some hunks may already be applied)     │
└────────┬──────────────────────────────────────────────────────┘
         ▼
┌──────────────────────────────────────────────────────────────┐
│ STEP 8e: RESTORE TEMPORARY CONTEXT CHANGES                    │
│   Reverse all the pre-patch modifications from Step 8c.       │
│   This ensures the source tree ends up in a clean,            │
│   compile-able state with SUSFS changes applied on top        │
│   of ORIGINAL kernel code, not the modified context.          │
│                                                               │
│   For each block in 8c, the inverse operation is performed.   │
│   Example (android13-5.15 sub≤41):                            │
│     * Remove mnt_idmapping.h includes added in pre-patch      │
│     * Restore fdinfo.c comment block                          │
│     * Restore mask,mark->ignored_mask references              │
│     * Fix susfs.c: i_uid_into_mnt(i_user_ns(...),...)         │
│       → i_uid_into_mnt(&init_user_ns,...)                     │
│       (Because post-patch, the patched susfs.c expects        │
│        init_user_ns, not dynamic ns lookup)                    │
└────────┬──────────────────────────────────────────────────────┘
         ▼
┌──────────────────────────────────────────────────────────────┐
│ STEP 8f: POST-PATCH FIXES (COMPILATION FIXES)                │
│   These fix issues that arise AFTER the SUSFS patch is        │
│   applied — symbols not declared, missing includes, etc.      │
│                                                               │
│ ╔════════════════════════════════════════════════════════════╗ │
│ ║ ANDROID 12 + 5.10                                          ║ │
│ ║  - 2024-11: vm_flags_clear() not defined → inline manual  ║ │
│ ║  - sub≤209: goto show_pad → return 0 (removed goto)       ║ │
│ ╚════════════════════════════════════════════════════════════╝ │
│ ║ ANDROID 13 + 5.15                                          ║ │
│ ║  - 2024-11: same vm_flags_clear fix                       ║ │
│ ║  - sub≤148 (not 2024-05): goto show_pad → return 0        ║ │
│ ║  - SUSFS symbols used in task_mmu.c but susfs_def.h not    ║ │
│ ║    included → inject #include conditionally                ║ │
│ ╚════════════════════════════════════════════════════════════╝ │
│ ║ ANDROID 14 + 6.1                                           ║ │
│ ║  - base.c uses SUSFS symbols but no susfs_def.h → inject   ║ │
│ ║  - sub≤75 (not 2024-05): goto show_pad → return 0         ║ │
│ ║  - namespace.c: DEFAULT_KSU_MNT_ID undeclared → inject     ║ │
│ ║    susfs_def.h include + extern declarations                ║ │
│ ╚════════════════════════════════════════════════════════════╝ │
│ ║ ANDROID 15 + 6.6                                           ║ │
│ ║  - base.c: SUSFS symbols but no dma-buf.h → add both      ║ │
│ ║  - memory.c: SUSFS symbols but no susfs_def.h → inject     ║ │
│ ╚════════════════════════════════════════════════════════════╝ │
│ ║ ANDROID 16 + 6.12                                          ║ │
│ ║  - setuid_hook.c: duplicate definition when both            ║ │
│ ║    CONFIG_KSU_MANUAL_HOOK and CONFIG_KSU_SUSFS are set    ║ │
│ ║    → exclude MANUAL_HOOK when SUSFS is active              ║ │
│ ║  - exec.c: SUSFS functions used but susfs_def.h not        ║ │
│ ║    included → inject after dma-buf.h or ksm.h              ║ │
│ ╚════════════════════════════════════════════════════════════╝ │
└──────────────────────────────────────────────────────────────┘
```

---

## PHASE 9: DROIDSPACES + NTSYNC (OPTIONAL)

```
┌───────────────────────────────────────────────┐
│ Droidspaces (container support)               │
│ if inputs.droidspaces != 'off':               │
│                                                │
│  1. Clone Droidspaces-OSS patches             │
│  2. Apply SYSVIPC kABI fix patch:             │
│     - 6.12: kernel-6.12/001.GKI-6.12-...      │
│     - 5.10-6.6: below-kernel-6.12/001...      │
│     * slot-based naming: 678→6_7_8            │
│  3. 5.10: apply POSIX_MQUEUE kABI fix too     │
│  4. 6.12: EXPORT_SYMBOL(init_ipc_ns) and      │
│     EXPORT_SYMBOL(put_ipc_ns) for rust_binder  │
│  5. Enable kernel configs (idempotent):        │
│     CONFIG_SYSVIPC, POSIX_MQUEUE, IPC_NS,     │
│     PID_NS, DEVTMPFS, + netfilter opts         │
│  6. android15+6.6: disable ANDROID_PARANOID_   │
│     NETWORK (required for container networking)│
│                                                │
│ NTSync (Wine/Proton sync)                      │
│ if droidspaces_ntsync:                        │
│  1. Download version-specific compat patches  │
│  2. Apply ntsync_base.patch + compat patch    │
│  3. Enable CONFIG_NTSYNC in defconfig          │
└───────────────────────────────────────────────┘
```

## PHASE 10: ZRAM LZ4 STACK

```
┌──────────────────────────────────────────────┐
│ IF inputs.use_zram:                           │
│                                                │
│  PHASE 10a: UPGRADE LZ4 → 1.10.0              │
│    - Remove old lz4 source files              │
│    - Copy new lz4 from $ZZH_PATCHES/zram/lz4/ │
│    - Copy updated headers                     │
│    - Run apply_lz4_neon.sh (ARM64 NEON accel) │
│    - Patch f2fs Makefile if needed            │
│                                                │
│  PHASE 10b: LZ4KD + LZ4K_OPLUS                │
│    - Copy lz4k includes, lib, crypto          │
│    - Copy lz4k_oplus directory                │
│    - Apply lz4kd.patch (fuzzy -F 3)           │
│    - Apply lz4k_oplus.patch (fuzzy -F 3)      │
│    * Both non-fatal with warning              │
│                                                │
│  WHY: LZ4KD provides better compression       │
│  ratio for ZRAM. LZ4K_OPLUS is a OnePlus-     │
│  optimized variant.                            │
└──────────────────────────────────────────────┘
```

## PHASE 11: WIFI/BLUETOOTH COMPATIBILITY (6.6 ONLY)

```
┌──────────────────────────────────────────────┐
│ IF kernel_version == '6.6':                   │
│                                                │
│  SAMSUNG:                                      │
│    - Add KDP symbols to abi_gki_aarch64_       │
│      galaxy (kdp_set_cred_non_rcu,             │
│      kdp_usecount_dec_and_test,                │
│      kdp_usecount_inc)                         │
│    - Apply min_kdp symbols patch               │
│    - Copy min_kdp.c driver                    │
│    - Add obj-y += min_kdp.o to drivers/Makefile│
│                                                │
│  XIAOMI:                                       │
│    - Add device_find_any_child to              │
│      abi_gki_aarch64_xiaomi symbol list       │
│                                                │
│  Uses ensure_line_once() for idempotency.      │
│  WHY: These symbols are required for WiFi/BT   │
│  on Samsung/Xiaomi devices running 6.6 GKI.   │
│  Without them, kernel modules fail to load.    │
└──────────────────────────────────────────────┘
```

## PHASE 12: ZRAM CONFIG

```
┌──────────────────────────────────────────────┐
│ IF inputs.use_zram:                           │
│                                                │
│  5.10: Explicitly write CONFIG_ZSMALLOC,       │
│        CONFIG_ZRAM, MODULE_SIG=n,              │
│        CONFIG_CRYPTO_LZO,                      │
│        CONFIG_ZRAM_DEF_COMP_LZ4KD              │
│        (5.10 gki_defconfig lacks these)        │
│                                                │
│  5.15/6.1: Convert ZSMALLOC=m → =y             │
│            Convert ZRAM=m → =y                 │
│            (modules need to be built-in for     │
│             ZRAM early mount)                   │
│                                                │
│  6.6: Same conversion                          │
│                                                │
│  android14/15: Remove zram.ko and zsmalloc.ko  │
│  from modules.bzl (Bazel module list) —         │
│  if they're built-in, they can't be modules    │
│                                                │
│  All: Append zram.config fragment               │
│  (ZRAM_DEF_COMP_ZSTD, LZ4, LZO, LZ4HC, etc.)   │
└──────────────────────────────────────────────┘
```

## PHASE 13: BBG (BASEBAND GUARD)

```
┌──────────────────────────────────────────────┐
│ IF inputs.use_bbg:                            │
│   wget setup.sh from vc-teahouse/Baseband-    │
│   guard repo | bash                            │
│   → Adds CONFIG_BBG=y to defconfig            │
│   → Patches security/Kconfig to add           │
│     baseband_guard to default LSM stack       │
│     (selinux → selinux,baseband_guard)         │
│                                                │
│  WHY: BBG prevents baseband formatting        │
│  attacks on devices.                          │
└──────────────────────────────────────────────┘
```

## PHASE 14: RE-KERNEL (OPTIONAL)

```
┌──────────────────────────────────────────────┐
│ IF inputs.use_rekernel:                       │
│   - Clone Re-Kernel repo                     │
│   - Create drivers/rekernel/ with Kconfig     │
│     and Makefile                              │
│   - Mount into drivers/Kconfig tree           │
│   - Enable version-specific macro (KERNEL_5_10│
│     → KERNEL_6_12)                            │
│   - Fix header include paths (out-of-tree     │
│     to in-tree adaptation)                    │
│   - Add seq_file.h for 5.10 (DEFINE_SHOW_     │
│     ATTRIBUTE macro needs it)                 │
│   - Enable CONFIG_REKERNEL=y,                  │
│     CONFIG_REKERNEL_NETWORK=y                 │
│                                                │
│  WHY: Re-Kernel provides GKI Vendor Hook-     │
│  based kernel-level protection features.      │
│  Uses idempotent checks (grep before sed)     │
│  to survive re-runs.                          │
└──────────────────────────────────────────────┘
```

## PHASE 15: KERNEL OPTIONS & CONFIG

```
┌──────────────────────────────────────────────┐
│ UNIVERSAL:                                    │
│   CONFIG_KSU=y                                │
│   CONFIG_TMPFS_XATTR=y                        │
│   CONFIG_TMPFS_POSIX_ACL=y                    │
│                                                │
│ SukiSU/ReSukiSU/Next + KPM:                   │
│   CONFIG_KPM=y (if KPM config symbol exists)  │
│                                                │
│ ReSukiSU + android13-5.15 sub 74-137:          │
│   Enable CONFIG_KALLSYMS + KALLSYMS_ALL        │
│   Unwrap kallsyms_on_each_symbol from          │
│   CONFIG_LIVEPATCH guard (ReSukiSU needs it    │
│   even without LIVEPATCH)                      │
│                                                │
│   WHY: 5.15.74–5.15.137 placed                 │
│   kallsyms_on_each_symbol inside               │
│   #ifdef CONFIG_LIVEPATCH blocks. ReSukiSU     │
│   calls this function without enabling         │
│   LIVEPATCH, causing link failure.             │
│                                                │
│ Disable check_defconfig in build.config.gki    │
│ (allows custom config additions)               │
└──────────────────────────────────────────────┘
```

## PHASE 16: SUSFS CONFIG

```
If enable_susfs, append all SUSFS features to defconfig:
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_KSU_SUSFS_SUS_MAP=y
```

## PHASE 17: KERNEL NAME CONFIGURATION

```
┌──────────────────────────────────────────────┐
│ Two paths:                                    │
│                                                │
│ PATH A: Custom version specified (input)       │
│   - Extract CLEAN_VERSION from version string  │
│   - Map android×kernel to KMI_TAG:            │
│     android14-6.1  → "android14-11"            │
│     android15-6.6  → "android15-8"             │
│     android16-6.12 → "android16-5"             │
│   - 6.1: setlocalversion + CONFIG_LOCALVERSION │
│   - 5.x: setlocalversion only (no KMI_TAG)    │
│   - 6.6+: perl replace in setlocalversion     │
│     (new format with ${KERNELVERSION}...)      │
│                                                │
│ PATH B: Auto-generated name (no custom ver)    │
│   - BID = random 8-digit number                │
│   - GHASH = short git hash                     │
│   - Format: -{KMI_TAG}-g{GHASH}-{BID}-4k       │
│   - Same per-version setlocalversion strategy  │
│                                                │
│ PRE-6.6 CLEANUP:                               │
│   if build/build.sh exists (5.x):              │
│     - Remove -dirty from setlocalversion       │
│   else (6.x Bazel):                            │
│     - Remove protected_exports_list            │
│     - Disable kmi_symbol_list_strict_mode      │
│     - Delete abi_gki_protected_exports_*       │
│     - Remove -maybe-dirty from stamp.bzl       │
│                                                │
│ WHY: Different kernel versions use different   │
│ localversion mechanisms. The KMI_TAG mapping   │
│ ensures compatibility with GKI module loading │
│ expectations. Removing "dirty" prevents the    │
│ kernel from being marked as tainted/development│
└──────────────────────────────────────────────┘
```

## PHASE 18: BUILD TIMESTAMP

```
┌──────────────────────────────────────────────┐
│ Set KBUILD_BUILD_TIMESTAMP from input or NOW  │
│                                                │
│ Patch scripts/mkcompile_h:                     │
│   5.x: Replace UTS_VERSION with fixed string   │
│         "#1 SMP PREEMPT {TIMESTAMP}"           │
│   6.x: More complex perl replacement           │
│         (different format in mkcompile_h)      │
│                                                │
│ WHY: Consistent build timestamps across        │
│ rebuilds. Without this, each build gets a      │
│ different UTS_VERSION, breaking ccache and     │
│ making binary reproducibility impossible.      │
└──────────────────────────────────────────────┘
```

## PHASE 19: COMPILATION — THE FORK IN THE ROAD

```
┌───────────────────────────────────────────────────────────────┐
│                      BUILD DECISION                            │
│                                                                │
│  if build/build.sh EXISTS  →  5.x PATH (traditional)          │
│  else                      →  6.x PATH (Bazel)                │
└───────────────┬───────────────────────────────┬───────────────┘
                ▼                               ▼
┌───────────────────────────┐   ┌───────────────────────────────┐
│ 5.x PATH (traditional)    │   │ 6.x PATH (Bazel)              │
│                            │   │                                │
│ 1. Disable SYSTEM_DLKM=1   │   │ 1. Generate ksu.fragment:     │
│    (don't build system     │   │    diff orig_defconfig vs      │
│     DLKM partition)        │   │    modified → fragment file   │
│                            │   │    → Restore orig defconfig    │
│ 2. Remove MODULES_ORDER    │   │                                │
│    (module ordering not    │   │ WHY: Bazel enforces that      │
│     needed for boot.img)   │   │ defconfig is trimmed to       │
│                            │   │ gki_defconfig. Our additions   │
│ 3. Remove STRICT_MODE      │   │ must go via --defconfig_      │
│    (allow symbol additions)│   │ fragment flag.                 │
│                            │   │                                │
│ 4. LTO=thin build/build.sh │   │ 2. Determine LTO flag:         │
│    CC="/usr/bin/ccache     │   │    - Default: --lto=thin       │
│         clang"             │   │    - 6.12: --lto=none          │
│                            │   │      (Rust kernel modules      │
│ 5. Verify with `strings    │   │       are incompatible with    │
│    Image | grep "Linux     │   │       thin LTO)                │
│    version"`               │   │                                │
│                            │   │ 3. tools/bazel build            │
│ RETRY: nick-fields/retry   │   │    --disk_cache=/home/runner/  │
│   timeout=30min, max=3     │   │      .cache/bazel              │
│   retry_on: timeout        │   │    --config=fast               │
│                            │   │    $LTO_FLAG $FRAG_FLAG         │
│ WHY ccache + clang:        │   │    //common:kernel_aarch64_dist│
│ Clang is the GKI compiler. │   │                                │
│ ccache wraps it for faster │   │ 4. Verify with strings + grep  │
│ recompilation.             │   │                                │
│                            │   │ RETRY: same as 5.x path        │
└───────────────────────────┘   └───────────────────────────────┘

WHY TWO COMPLETELY DIFFERENT BUILD SYSTEMS?
- Pre-6.1: AOSP used build/build.sh with build.config files
- 6.1+: AOSP transitioned to Bazel (Kleaf) for GKI kernel builds
- The workflow must support both because android12/13 use 5.x kernels
  with the old system, while android14+ use 6.x with Bazel
```

---

## PHASE 20: ARTIFACT COLLECTION & PACKAGING

```
┌──────────────────────────────────────────────┐
│ PREPARE BOOT IMAGE                            │
│                                                │
│ Source directory differs by build system:      │
│   android12/13: out/{config}/dist/             │
│   android14+:   bazel-bin/common/kernel_aarch64│
│                                                │
│ Copy: Image, Image.lz4 to bootimgs/ and ./     │
│ Create: Image.gz (gzip -9)                     │
│                                                │
│ ANY KERNEL3 PACKAGE:                           │
│   Copy Image into AnyKernel3 directory         │
│   ZIP: {android}-{kernel}.{sub}-{patch}-       │
│        AnyKernel3.zip                          │
│                                                │
│ (Boot.img construction is commented out —       │
│  the pipeline delivers AnyKernel3 zips, not     │
│  pre-built boot images)                        │
│                                                │
│ WHY AnyKernel3? It's a universal flashable     │
│ ZIP format that works with any device's         │
│ existing ramdisk. Much simpler than building    │
│ per-device boot images with correct ramdisks.  │
└──────────────────────────────────────────────┘
```

## PHASE 21: DIAGNOSTIC COLLECTION

```
┌──────────────────────────────────────────────┐
│ ALWAYS RUN (if: always()):                    │
│                                                │
│ Collect .rej files from patch failures.        │
│ These are the "rejected hunks" from `patch`.   │
│                                                │
│ Structure preserved:                           │
│   patch-rejects/{relative-path}/file.rej       │
│   + original source file for context           │
│                                                │
│ WHY: When a patch partially fails (some hunks  │
│ apply, some don't), the .rej file shows        │
│ exactly what failed. Critical for debugging    │
│ SUSFS compat issues with new kernel sublevels. │
│ Uploaded as separate artifact only if .rej     │
│ files exist.                                   │
└──────────────────────────────────────────────┘
```

## PHASE 22: UPLOAD

```
Artifact: ReSukiSU_kernel-{CONFIG}
Contents: *AnyKernel3.zip
Compression-level: 9 (maximum)
```

---

## ERROR HANDLING STRATEGY

```
┌───────────────────────────────────────────────────────────────┐
│ FATAL ERRORS (exit 1, stop pipeline):                         │
│  - repo sync failure                                          │
│  - Patch reject collection infrastructure errors              │
│  - Kernel build failure (exit 1 after retries exhausted)      │
│  - Stock defconfig copy/rule replace failure                  │
│  - Re-Kernel KPM config symbol not found when requested       │
│                                                                │
│ NON-FATAL (|| true, continue):                                 │
│  - SUSFS main patch (patch -p1 || true)                       │
│    → Some hunks may already exist from KSU integration        │
│  - KSU SUSFS patch for Official variant (|| true)             │
│  - Unicode bypass patch (|| true)                             │
│  - LZ4KD/lz4k_oplus patches (warning emitted)                 │
│  - Droidspaces SYSVIPC/POSIX_MQUEUE patches (warning)         │
│  - Stock config spoof (exit 0 if source not found)            │
│  - glibc fix: sed 2>/dev/null || true (tools may not exist)   │
│                                                                │
│ RETRY LOGIC (nick-fields/retry@v4):                            │
│  - Build step only                                             │
│  - timeout_minutes: 30                                         │
│  - max_attempts: 3                                             │
│  - retry_on: timeout                                           │
│  → Handles transient OOM/timeout on GitHub runners             │
│  → Does NOT retry on compilation errors (bail immediately)     │
└───────────────────────────────────────────────────────────────┘
```

---

## COMPLETE CONDITIONAL FIX MATRIX

Every compatibility fix in the pipeline, mapped by android×kernel×sublevel×patchlevel:

### GLIBC 2.38 FIXES

| Android | Kernel | Sub ≤ | Fix |
|---------|--------|-------|-----|
| 13 | 5.10 | 186 | resolve_btfids Makefile + parse-options.c C99 |
| 13 | 5.15 | 119 | resolve_btfids Makefile + parse-options.c C99 |
| 14 | 6.1  | 43  | resolve_btfids Makefile only (no C99 issue) |

### SUSFS PRE-PATCH CONTEXT ADJUSTMENTS

| Android | Kernel | Sub Condition | File | Operation |
|---------|--------|---------------|------|-----------|
| 12 | 5.10 | ≤43 | fs/proc/base.c | Normalize this_len type |
| 12 | 5.10 | ≤117 | fs/notify/fdinfo.c | Remove comment block, replace mask pattern |
| 13 | 5.10 | ≤107 | fs/notify/fdinfo.c | Same fdinfo fix |
| 13 | 5.15 | ≤41 | fs/namespace.c | Add mnt_idmapping.h include |
| 13 | 5.15 | ≤41 | fs/open.c | Add mnt_idmapping.h include |
| 13 | 5.15 | ≤41 | fs/notify/fdinfo.c | Same fdinfo fix |
| 14 | 6.1  | ≤25 | fs/proc/base.c | Add trace/hooks/sched.h |
| 14 | 6.1  | ≤141 | fs/proc/base.c | Add dma-buf.h |
| 14 | 6.1  | ≥157 | fs/namespace.c | Remove trace/hooks/blk.h |
| 15 | 6.6  | ≤30 | fs/proc/task_mmu.c | Add last_vma_end assignment |
| 15 | 6.6  | ≤92 | fs/proc/base.c | Add dma-buf.h |
| 15 | 6.6  | ≤57 | mm/memory.c | Add zswap.h |
| 16 | 6.12 | ≥58 | fs/exec.c | Remove dma-buf.h |

### SUSFS POST-PATCH FIXES

| Android | Kernel | Condition | Fix |
|---------|--------|-----------|-----|
| 12 | 5.10 | 2024-11 patch | vm_flags_clear → inline bit clear |
| 12 | 5.10 | sub≤209 | goto show_pad → return 0 |
| 13 | 5.15 | 2024-11 patch | vm_flags_clear → inline bit clear |
| 13 | 5.15 | sub≤148, ≠2024-05 | goto show_pad → return 0 |
| 13 | 5.15 | SUSFS symbols present, no include | Inject susfs_def.h into task_mmu.c |
| 14 | 6.1  | SUSFS symbols present, no include | Inject susfs_def.h into base.c |
| 14 | 6.1  | sub≤75, ≠2024-05 | goto show_pad → return 0 |
| 14 | 6.1  | DEFAULT_KSU_MNT_ID undeclared | Inject susfs_def.h + externs into namespace.c |
| 15 | 6.6  | SUSFS symbols but no susfs_def.h | Inject into base.c + add dma-buf.h |
| 15 | 6.6  | SUSFS symbols but no susfs_def.h | Inject into memory.c |
| 16 | 6.12 | KSU_MANUAL_HOOK + KSU_SUSFS conflict | Exclude MANUAL_HOOK when SUSFS active |
| 16 | 6.12 | susfs functions used, no include | Inject susfs_def.h into exec.c |

### KERNELSU POST-INTEGRATION FIXES

| Android | Kernel | Condition | Fix |
|---------|--------|-----------|-----|
| 13 | 5.15 | sub 74-137 (ReSukiSU) | Unwrap kallsyms_on_each_symbol from LIVEPATCH guard |

---

## KEY ARCHITECTURAL DECISIONS

### 1. ccache Cache Key Design
**Key:** `{android}-{kernel}-{sublevel}-ccache-{sha}`
**Why:** The git SHA changes on every commit, giving exact cache hits for rebuilds of the same source. The fallback (`restore-keys`) matches the same android×kernel×sublevel combo from any previous build — most files don't change between sublevels within the same branch, so ccache can reuse >90% of objects.

### 2. Toolchain Caching Separately
**Key:** `toolchain-{runner.os}-v1`
**Why:** kernel-build-tools (AOSP prebuilts including clang, avbtool) is ~2GB and changes rarely. A separate cache avoids invalidating it when kernel source or ccache changes.

### 3. SUSFS Patch Strategy: Pre-Context → Apply → Restore → Post-Fix
**Why:** The SUSFS patch is generated against one specific sublevel. Instead of maintaining 50+ patches for every sublevel variant:
- **Pre-context:** Rewrite source to match what the patch expects
- **Apply:** Single patch file applies cleanly
- **Restore:** Undo the context rewrites so the final tree is original source + SUSFS changes, not mangled source
- **Post-fix:** Handle edge cases the patch missed (missing includes, symbol name changes between kernel versions)

### 4. Two Build Systems (build.sh vs Bazel)
**Why:** AOSP migrated GKI kernel builds from shell-script-based (`build/build.sh`) to Bazel (Kleaf) starting with android14-6.1. The pipeline must handle both because android12/13 still use 5.x kernels with the old system.

The Bazel path requires the defconfig fragment trick: Bazel validates that defconfig is a strict subset of gki_defconfig. Modified configs must be passed as fragments, not direct edits.

### 5. Bazel disk_cache vs ccache
Build step uses `--disk_cache=/home/runner/.cache/bazel` (Bazel's built-in cache) rather than wrapping Bazel with ccache. ccache is only used for the traditional 5.x build path.

### 6. Deprecated Branch Auto-Detection
Google moves old kernel branches under `deprecated/` prefix in the manifest. Without this detection + sed fix, `repo init` fails for old android12/13 branches. The workflow handles this transparently by checking `git ls-remote` output for "deprecated" keyword.

### 7. LTO: thin vs none
- **5.10/5.15/6.1/6.6:** `--lto=thin` (faster builds, smaller binaries)
- **6.12:** `--lto=none` — Rust kernel modules are incompatible with LTO. This is a known limitation of 6.12+ GKI with Rust modules enabled.

### 8. All Patches Are Idempotent
Every sed operation checks before modifying (`grep -qF` before sed, `--forward` for patches, `ensure_line_once()` pattern). This allows the workflow to be re-run on the same checkout without corruption — critical for debugging and retries.

---

## WHY THE PIPELINE NEVER FAILS

1. **Iterative hardening over time:** Each conditional fix was added because a real build failed at that exact android×kernel×sublevel combination. Nothing is speculative.

2. **Tolerance for partial patch application:** SUSFS patches use `|| true`, meaning partial hunk failures don't abort the pipeline. Combined with .rej collection, the operator can see what failed and fix it post-hoc.

3. **Retry on transient failures:** Build step retries 3 times on timeout (GitHub runner OOM, network blips during Bazel download). Compilation errors are NOT retried — they're deterministic.

4. **Separated caches:** ccache, toolchain, and Bazel cache are independent. A cache eviction in one doesn't affect the others.

5. **Version-specific build paths:** 5.x uses traditional build.sh + ccache. 6.x uses Bazel + disk_cache. Each path is optimized for its era.

6. **Defensive idempotency:** Every file modification is conditional. Re-running any step produces the same result. No state corruption from retries.

7. **Explicit environment control:** `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true` (GH Actions compatibility), explicit repo version pin (`--repo-rev=v2.16`), glibc version detection before applying version-specific fixes.

8. **Sublevel awareness:** The pipeline doesn't assume a static sublevel. It reads the actual SUBLEVEL from Makefile and uses it in all compatibility checks.
