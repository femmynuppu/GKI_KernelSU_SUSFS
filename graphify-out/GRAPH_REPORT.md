# Graph Report - C:\PROJECT\GKI_KernelSU_SUSFS  (2026-06-09)

## Corpus Check
- 614 files · ~0 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 614 nodes · 1103 edges · 52 communities (35 shown, 17 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 51 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]

## God Nodes (most connected - your core abstractions)
1. `LZ4_compress_generic()` - 22 edges
2. `LZ4_compress_generic_validated()` - 21 edges
3. `LZ4_FORCE_INLINE` - 19 edges
4. `LZ4HC_CCtx_internal` - 19 edges
5. `LZ4HC_InsertAndGetWiderMatch()` - 19 edges
6. `tableType_t` - 13 edges
7. `LZ4_stream_t` - 13 edges
8. `BYTE` - 13 edges
9. `LZ4_streamHC_t` - 13 edges
10. `zeromount_should_skip()` - 12 edges

## Surprising Connections (you probably didn't know these)
- `__read_mostly section mismatch on ksu_selinux_hide_enabled` --DOCUMENTED_IN--> `Softbrick Root Cause - __read_mostly section mismatch`  [EXTRACTED]
  src/susfs/susfs_selinux.h → C:/PROJECT/remote_kernel_server/SOFTBRICK_ROOT_CAUSE.md
- `zeromount_should_skip()` --calls--> `zm_is_recursive()`  [INFERRED]
  src/zeromount/zeromount.c → src/zeromount/zeromount.h
- `LZ4_isAligned()` --calls--> `LZ4_initStreamHC()`  [INFERRED]
  zram/lz4/lz4.c → zram/lz4/lz4hc.c
- `LZ4_isLittleEndian()` --calls--> `LZ4HC_countPattern()`  [INFERRED]
  zram/lz4/lz4.c → zram/lz4/lz4hc.c
- `LZ4_isLittleEndian()` --calls--> `LZ4HC_NbCommonBytes32()`  [INFERRED]
  zram/lz4/lz4.c → zram/lz4/lz4hc.c

## Import Cycles
- None detected.

## Communities (52 total, 17 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.06
Nodes (95): dict_directive, dictIssue_directive, earlyEnd_directive, LoadDict_mode_e, LZ4_FORCE_O2, LZ4_arm64_decompress_safe(), LZ4_arm64_decompress_safe_partial(), LZ4_attach_dictionary() (+87 more)

### Community 1 - "Community 1"
Cohesion: 0.05
Nodes (54): zeromount.h, dev_t, loff_t, u32, uid_t, zeromount_build_absolute_path(), zeromount_get_virtual_path_for_inode(), zeromount_getname_hook() (+46 more)

### Community 2 - "Community 2"
Cohesion: 0.10
Nodes (63): cParams_t, dictCtx_directive, HCfavor_e, LZ4_read32(), isStateCompatible(), LZ4_attach_HC_dictionary(), LZ4_compress_HC(), LZ4_compress_HC_continue_destSize() (+55 more)

### Community 3 - "Community 3"
Cohesion: 0.03
Nodes (64): build.yml, SUSFS_commit_pinning, setuid_hook.c fix, kallsyms_on_each_symbol fix, Droidspaces SYSVIPC kABI fix, actions/cache@v5 (toolchain), mm/memory.c, mm/mmap.c (+56 more)

### Community 4 - "Community 4"
Cohesion: 0.05
Nodes (41): CONFIG_KSU_SUSFS_SUS_PATH, CONFIG_KSU_SUSFS_SUS_MOUNT, CONFIG_KSU_SUSFS_OPEN_REDIRECT, CONFIG_KSU_SUSFS_SUS_MAP, CONFIG_KSU_SUSFS_SPOOF_UNAME, CONFIG_KSU_SUSFS_SUS_KSTAT, fs/susfs.c, fs/d_path.c (+33 more)

### Community 5 - "Community 5"
Cohesion: 0.05
Nodes (40): Gap: TCP BBR missing (no CONFIG_TCP_CONG_BBR, CONFIG_DEFAULT_BBR), GitHub Actions workflow run screenshot (action.png), PHASE 0: Pre-flight (summary, disk cleanup, checkout), PHASE 1: Environment Bootstrap (repo, deps, ccache, toolchain, signing), PHASE 10: ZRAM LZ4 Stack (LZ4 1.10.0 upgrade, LZ4KD, LZ4K_OPLUS), PHASE 11: WiFi/BT Compatibility (Samsung KDP, Xiaomi symbols for 6.6), PHASE 12: ZRAM Config (CONFIG_ZRAM=y, module→built-in, fragment append), PHASE 13: BBG Baseband Guard (optional, wget setup.sh | bash) (+32 more)

### Community 6 - "Community 6"
Cohesion: 0.18
Nodes (16): fetch_all(), fetch_lts(), fetch_makefile(), get_end_date(), json_path(), make_date_range(), parse_version(), 返回结束日期：如果为 None 则使用当前月份 (+8 more)

### Community 7 - "Community 7"
Cohesion: 0.17
Nodes (15): loff_t, susfs_selinux_hook_avc_audit(), susfs_selinux_hook_check_context(), susfs_selinux_hook_read_policy(), susfs_selinux_is_hidden_context(), u16, u32, loff_t (+7 more)

### Community 8 - "Community 8"
Cohesion: 0.13
Nodes (15): emergency-cleanup.yml, kernel-a16-6-12.yml, main.yml, collect-rejects, emergency_cleanup_job, bug_report.yml, release_body.md, feature_request.yml (+7 more)

### Community 9 - "Community 9"
Cohesion: 0.16
Nodes (14): Commit c17aae5 (removed multi-KSU variant support, ReSukiSU-only), Gaokao 2026 Archive (repo frozen during Chinese college entrance exam), Multi-manager mode (ReSukiSU driver, KowSU/SukiSU-Ultra managers supported), AlexLiuDev233 (workflow fix contributor), cctv18 (workflow fix contributor, 6.12 kernel support), coolzyd9107 (repo creator/owner), YC酱luyancib (Telegram Bot developer), TanakaLun (contributor, fixes and modifications) (+6 more)

### Community 10 - "Community 10"
Cohesion: 0.14
Nodes (14): Telegram Channel @ReSukiSUKernelBuilds (release notifications), Gap: Enhanced SUSFS 51_ patch absent (only in Super-Builders), Gap: ZeroMount VFS missing (60_ patch, exists only in Super-Builders), GitHub Release page screenshot (release.png), GKI_KernelSU_SUSFS, Super-Builders (GKI kernel builder, comparison project), update_data.py (JSON data generator for GitHub Pages), Enhanced SUSFS 51_ patch (kstat redirect, unicode filter, AS_FLAGS guards) (+6 more)

### Community 11 - "Community 11"
Cohesion: 0.17
Nodes (13): Android 12, Android 13, Android 14, Android 15, Android 16, OnePlus ColorOS 14/15 incompatibility warning, SUSFS pre-context→apply→restore→post-fix 4-stage patch strategy, Linux Kernel 5.10 (GKI LTS) (+5 more)

### Community 12 - "Community 12"
Cohesion: 0.21
Nodes (13): android12/5.10.json (sublevel tracking, ~150 lines, ~40 entries), android13/5.15.json, android14/6.1.json, android15/6.6.json, android16/6.12.json, gki_fetch.py (scrapes Google kernel/common for sublevels), kernel-a12-5-10.yml (per-version sublevel matrix), kernel-a13-5-15.yml (+5 more)

### Community 13 - "Community 13"
Cohesion: 0.17
Nodes (12): get-manager.yml, kernel-a12-5-10.yml, kernel-a14-6-1.yml, kernel-custom.yml, build-manager.yml, sidex15/susfs4ksu-module, Android 12, Android 14 (+4 more)

### Community 14 - "Community 14"
Cohesion: 0.22
Nodes (9): config/config (custom SUSFS/SukiSU commit override), Gap: SUSFS v2.1.0 version uncertain (may need upstream tag verification), SUSFS branch selection interface screenshot (susfs_branch.png), SUSFS commit selection interface screenshot (susfs_commit.png), SUSFS feature demonstration example screenshot (susfs_eg1.png), simonpunk (SUSFS author), simonpunk/susfs4ksu (GitLab upstream SUSFS patches), SUSFS (kernel file-system hiding/redirection for root) (+1 more)

### Community 15 - "Community 15"
Cohesion: 0.33
Nodes (6): MRPCS SELinux Detection Catalog, __read_mostly section mismatch on ksu_selinux_hide_enabled, SELinux Complete Flow Trace, SELinux Red Team Simulation, Softbrick Red Team Analysis, Softbrick Root Cause - __read_mostly section mismatch

### Community 16 - "Community 16"
Cohesion: 0.33
Nodes (6): CONFIG_ZSMALLOC, CONFIG_ZRAM, apply_lz4_neon.sh, ZRAM_LZ4, lz4kd.patch, lz4k_oplus.patch

### Community 17 - "Community 17"
Cohesion: 0.33
Nodes (6): Droidspaces, NTSync, CONFIG_NTSYNC, CONFIG_ANDROID_PARANOID_NETWORK, ravindu644/Droidspaces-OSS, Goldzxcbug/Droidspaces_Kernel_patch

### Community 18 - "Community 18"
Cohesion: 0.40
Nodes (4): android_version, entries, kernel_version, lts

### Community 19 - "Community 19"
Cohesion: 0.40
Nodes (4): android_version, entries, kernel_version, lts

### Community 20 - "Community 20"
Cohesion: 0.40
Nodes (4): android_version, entries, kernel_version, lts

### Community 21 - "Community 21"
Cohesion: 0.40
Nodes (4): android_version, entries, kernel_version, lts

### Community 22 - "Community 22"
Cohesion: 0.40
Nodes (4): android_version, entries, kernel_version, lts

### Community 23 - "Community 23"
Cohesion: 0.50
Nodes (4): SukiSU/ReSukiSU kernel manager example screenshot (sukisu_eg1.png), KernelSU (kernel-based root solution for Android GKI), ReSukiSU (KernelSU variant, primary for this project), SukiSU (KernelSU variant, slower updates than ReSukiSU)

### Community 25 - "Community 25"
Cohesion: 0.67
Nodes (3): Bazel defconfig fragment trick (config additions via --defconfig_fragment for 6.x), LTO thin vs none (thin for 5.10-6.6, none for 6.12 with Rust modules), PHASE 19: Compilation (5.x build.sh vs 6.x Bazel fork, LTO=thin/none)

### Community 27 - "Community 27"
Cohesion: 0.67
Nodes (3): config/zram.config (ZRAM kernel config fragment), apply_lz4_neon.sh (injects ARM64 NEON calls into crypto/fs modules), ZRAM LZ4 v1.10.0 with ARM64 NEON acceleration

### Community 28 - "Community 28"
Cohesion: 0.67
Nodes (3): kernel-a13-5-15.yml, Android 13, kernel 5.15

### Community 29 - "Community 29"
Cohesion: 0.67
Nodes (3): kernel-a15-6-6.yml, Android 15, kernel 6.6

### Community 30 - "Community 30"
Cohesion: 0.67
Nodes (3): BBG, CONFIG_BBG, vc-teahouse/Baseband-guard

### Community 31 - "Community 31"
Cohesion: 0.67
Nodes (3): Re-Kernel, CONFIG_REKERNEL, Sakion-Team/Re-Kernel

## Knowledge Gaps
- **40 isolated node(s):** `fix-susfs-compat.sh script`, `android_version`, `kernel_version`, `lts`, `entries` (+35 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.