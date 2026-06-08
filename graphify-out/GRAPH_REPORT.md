# Graph Report - .  (2026-06-09)

## Corpus Check
- 48 files · ~75,428 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 610 nodes · 1109 edges · 50 communities (34 shown, 16 thin omitted)
- Extraction: 95% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 48 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_LZ4 Compression Internals|LZ4 Compression Internals]]
- [[_COMMUNITY_LZ4HC Compression|LZ4HC Compression]]
- [[_COMMUNITY_Build Workflow Structure|Build Workflow Structure]]
- [[_COMMUNITY_ZeroMount C Types|ZeroMount C Types]]
- [[_COMMUNITY_Kernel Config Options|Kernel Config Options]]
- [[_COMMUNITY_Build Phases & Gaps|Build Phases & Gaps]]
- [[_COMMUNITY_Script Orchestration|Script Orchestration]]
- [[_COMMUNITY_ZeroMount Header API|ZeroMount Header API]]
- [[_COMMUNITY_SUSFS Patch Files|SUSFS Patch Files]]
- [[_COMMUNITY_Contributors & Features|Contributors & Features]]
- [[_COMMUNITY_GitHub Actions CI|GitHub Actions CI]]
- [[_COMMUNITY_Telegram Notifications|Telegram Notifications]]
- [[_COMMUNITY_Android Kernel Targets|Android Kernel Targets]]
- [[_COMMUNITY_External Repository Dependencies|External Repository Dependencies]]
- [[_COMMUNITY_KernelSU Variants|KernelSU Variants]]
- [[_COMMUNITY_Device Support|Device Support]]
- [[_COMMUNITY_Droidspaces Integration|Droidspaces Integration]]
- [[_COMMUNITY_AnyKernel3 Packaging|AnyKernel3 Packaging]]
- [[_COMMUNITY_Build Tools & Dependencies|Build Tools & Dependencies]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 24|Community 24]]
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
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]

## God Nodes (most connected - your core abstractions)
1. `LZ4_compress_generic_validated()` - 21 edges
2. `LZ4_FORCE_INLINE` - 20 edges
3. `LZ4HC_CCtx_internal` - 20 edges
4. `LZ4HC_InsertAndGetWiderMatch()` - 19 edges
5. `LZ4_decompress_generic()` - 14 edges
6. `LZ4_FORCE_O2` - 14 edges
7. `U32` - 14 edges
8. `tableType_t` - 13 edges
9. `LZ4_compress_generic()` - 13 edges
10. `LZ4_stream_t` - 13 edges

## Surprising Connections (you probably didn't know these)
- `zeromount_should_skip()` --calls--> `zm_is_recursive()`  [INFERRED]
  src/zeromount/zeromount.c → src/zeromount/zeromount.h
- `LZ4_readLE64()` --calls--> `LZ4_isLittleEndian()`  [INFERRED]
  zram/lz4/lz4hc.c → zram/lz4/lz4.c
- `LZ4HC_countPattern()` --calls--> `LZ4_isLittleEndian()`  [INFERRED]
  zram/lz4/lz4hc.c → zram/lz4/lz4.c
- `LZ4HC_NbCommonBytes32()` --calls--> `LZ4_isLittleEndian()`  [INFERRED]
  zram/lz4/lz4hc.c → zram/lz4/lz4.c
- `LZ4HC_InsertAndGetWiderMatch()` --calls--> `LZ4_read16()`  [INFERRED]
  zram/lz4/lz4hc.c → zram/lz4/lz4.c

## Import Cycles
- None detected.

## Communities (50 total, 16 thin omitted)

### Community 0 - "LZ4 Compression Internals"
Cohesion: 0.05
Nodes (98): dict_directive, dictIssue_directive, earlyEnd_directive, LoadDict_mode_e, LZ4_FORCE_O2, LZ4_arm64_decompress_safe(), LZ4_arm64_decompress_safe_partial(), LZ4_attach_dictionary() (+90 more)

### Community 1 - "LZ4HC Compression"
Cohesion: 0.09
Nodes (74): cParams_t, dictCtx_directive, HCfavor_e, LZ4_isAligned(), isStateCompatible(), LZ4_attach_HC_dictionary(), LZ4_compress_HC(), LZ4_compress_HC_continue() (+66 more)

### Community 2 - "Build Workflow Structure"
Cohesion: 0.03
Nodes (65): build.yml, SUSFS_commit_pinning, setuid_hook.c fix, kallsyms_on_each_symbol fix, Droidspaces SYSVIPC kABI fix, actions/cache@v5 (toolchain), mm/memory.c, mm/mmap.c (+57 more)

### Community 3 - "ZeroMount C Types"
Cohesion: 0.07
Nodes (48): dev_t, loff_t, u32, uid_t, zeromount_build_absolute_path(), zeromount_get_virtual_path_for_inode(), zeromount_getname_hook(), zeromount_inject_dents() (+40 more)

### Community 4 - "Kernel Config Options"
Cohesion: 0.05
Nodes (42): CONFIG_KSU_SUSFS_SUS_PATH, CONFIG_KSU_SUSFS_SUS_MOUNT, CONFIG_KSU_SUSFS_OPEN_REDIRECT, CONFIG_KSU_SUSFS_SUS_MAP, CONFIG_KSU_SUSFS_SPOOF_UNAME, CONFIG_KSU_SUSFS_SUS_KSTAT, fs/susfs.c, fs/d_path.c (+34 more)

### Community 5 - "Build Phases & Gaps"
Cohesion: 0.05
Nodes (40): Gap: TCP BBR missing (no CONFIG_TCP_CONG_BBR, CONFIG_DEFAULT_BBR), GitHub Actions workflow run screenshot (action.png), PHASE 0: Pre-flight (summary, disk cleanup, checkout), PHASE 1: Environment Bootstrap (repo, deps, ccache, toolchain, signing), PHASE 10: ZRAM LZ4 Stack (LZ4 1.10.0 upgrade, LZ4KD, LZ4K_OPLUS), PHASE 11: WiFi/BT Compatibility (Samsung KDP, Xiaomi symbols for 6.6), PHASE 12: ZRAM Config (CONFIG_ZRAM=y, module→built-in, fragment append), PHASE 13: BBG Baseband Guard (optional, wget setup.sh | bash) (+32 more)

### Community 6 - "Script Orchestration"
Cohesion: 0.18
Nodes (16): fetch_all(), fetch_lts(), fetch_makefile(), get_end_date(), json_path(), make_date_range(), parse_version(), 返回结束日期：如果为 None 则使用当前月份 (+8 more)

### Community 7 - "ZeroMount Header API"
Cohesion: 0.12
Nodes (8): dev_t, loff_t, uid_t, zeromount_inject_dents(), zeromount_inject_dents64(), zeromount_inject_dents_common(), zeromount_is_uid_blocked(), zeromount_spoof_mmap_metadata()

### Community 8 - "SUSFS Patch Files"
Cohesion: 0.13
Nodes (15): emergency-cleanup.yml, kernel-a16-6-12.yml, main.yml, collect-rejects, emergency_cleanup_job, bug_report.yml, release_body.md, feature_request.yml (+7 more)

### Community 9 - "Contributors & Features"
Cohesion: 0.16
Nodes (14): Commit c17aae5 (removed multi-KSU variant support, ReSukiSU-only), Gaokao 2026 Archive (repo frozen during Chinese college entrance exam), Multi-manager mode (ReSukiSU driver, KowSU/SukiSU-Ultra managers supported), AlexLiuDev233 (workflow fix contributor), cctv18 (workflow fix contributor, 6.12 kernel support), coolzyd9107 (repo creator/owner), YC酱luyancib (Telegram Bot developer), TanakaLun (contributor, fixes and modifications) (+6 more)

### Community 10 - "GitHub Actions CI"
Cohesion: 0.14
Nodes (14): Telegram Channel @ReSukiSUKernelBuilds (release notifications), Gap: Enhanced SUSFS 51_ patch absent (only in Super-Builders), Gap: ZeroMount VFS missing (60_ patch, exists only in Super-Builders), GitHub Release page screenshot (release.png), GKI_KernelSU_SUSFS, Super-Builders (GKI kernel builder, comparison project), update_data.py (JSON data generator for GitHub Pages), Enhanced SUSFS 51_ patch (kstat redirect, unicode filter, AS_FLAGS guards) (+6 more)

### Community 11 - "Telegram Notifications"
Cohesion: 0.17
Nodes (13): Android 12, Android 13, Android 14, Android 15, Android 16, OnePlus ColorOS 14/15 incompatibility warning, SUSFS pre-context→apply→restore→post-fix 4-stage patch strategy, Linux Kernel 5.10 (GKI LTS) (+5 more)

### Community 12 - "Android Kernel Targets"
Cohesion: 0.21
Nodes (13): android12/5.10.json (sublevel tracking, ~150 lines, ~40 entries), android13/5.15.json, android14/6.1.json, android15/6.6.json, android16/6.12.json, gki_fetch.py (scrapes Google kernel/common for sublevels), kernel-a12-5-10.yml (per-version sublevel matrix), kernel-a13-5-15.yml (+5 more)

### Community 13 - "External Repository Dependencies"
Cohesion: 0.17
Nodes (12): get-manager.yml, kernel-a12-5-10.yml, kernel-a15-6-6.yml, kernel-custom.yml, build-manager.yml, sidex15/susfs4ksu-module, Android 12, Android 15 (+4 more)

### Community 14 - "KernelSU Variants"
Cohesion: 0.22
Nodes (9): config/config (custom SUSFS/SukiSU commit override), Gap: SUSFS v2.1.0 version uncertain (may need upstream tag verification), SUSFS branch selection interface screenshot (susfs_branch.png), SUSFS commit selection interface screenshot (susfs_commit.png), SUSFS feature demonstration example screenshot (susfs_eg1.png), simonpunk (SUSFS author), simonpunk/susfs4ksu (GitLab upstream SUSFS patches), SUSFS (kernel file-system hiding/redirection for root) (+1 more)

### Community 15 - "Device Support"
Cohesion: 0.33
Nodes (6): CONFIG_ZSMALLOC, CONFIG_ZRAM, apply_lz4_neon.sh, ZRAM_LZ4, lz4kd.patch, lz4k_oplus.patch

### Community 16 - "Droidspaces Integration"
Cohesion: 0.33
Nodes (6): Droidspaces, NTSync, CONFIG_NTSYNC, CONFIG_ANDROID_PARANOID_NETWORK, ravindu644/Droidspaces-OSS, Goldzxcbug/Droidspaces_Kernel_patch

### Community 17 - "AnyKernel3 Packaging"
Cohesion: 0.40
Nodes (4): android_version, entries, kernel_version, lts

### Community 18 - "Build Tools & Dependencies"
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
Cohesion: 0.50
Nodes (4): SukiSU/ReSukiSU kernel manager example screenshot (sukisu_eg1.png), KernelSU (kernel-based root solution for Android GKI), ReSukiSU (KernelSU variant, primary for this project), SukiSU (KernelSU variant, slower updates than ReSukiSU)

### Community 24 - "Community 24"
Cohesion: 0.67
Nodes (3): Bazel defconfig fragment trick (config additions via --defconfig_fragment for 6.x), LTO thin vs none (thin for 5.10-6.6, none for 6.12 with Rust modules), PHASE 19: Compilation (5.x build.sh vs 6.x Bazel fork, LTO=thin/none)

### Community 26 - "Community 26"
Cohesion: 0.67
Nodes (3): config/zram.config (ZRAM kernel config fragment), apply_lz4_neon.sh (injects ARM64 NEON calls into crypto/fs modules), ZRAM LZ4 v1.10.0 with ARM64 NEON acceleration

### Community 27 - "Community 27"
Cohesion: 0.67
Nodes (3): kernel-a13-5-15.yml, Android 13, kernel 5.15

### Community 28 - "Community 28"
Cohesion: 0.67
Nodes (3): kernel-a14-6-1.yml, Android 14, kernel 6.1

### Community 29 - "Community 29"
Cohesion: 0.67
Nodes (3): BBG, CONFIG_BBG, vc-teahouse/Baseband-guard

### Community 30 - "Community 30"
Cohesion: 0.67
Nodes (3): Re-Kernel, CONFIG_REKERNEL, Sakion-Team/Re-Kernel

## Knowledge Gaps
- **32 isolated node(s):** `fix-susfs-compat.sh script`, `android_version`, `kernel_version`, `lts`, `entries` (+27 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **16 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `LZ4_read32()` connect `LZ4 Compression Internals` to `LZ4HC Compression`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **Why does `LZ4_count()` connect `LZ4 Compression Internals` to `LZ4HC Compression`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **Why does `LZ4HC_InsertAndGetWiderMatch()` connect `LZ4HC Compression` to `LZ4 Compression Internals`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **What connects `fix-susfs-compat.sh script`, `android_version`, `kernel_version` to the rest of the system?**
  _37 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `LZ4 Compression Internals` be split into smaller, more focused modules?**
  _Cohesion score 0.05408805031446541 - nodes in this community are weakly interconnected._
- **Should `LZ4HC Compression` be split into smaller, more focused modules?**
  _Cohesion score 0.08544087491455912 - nodes in this community are weakly interconnected._
- **Should `Build Workflow Structure` be split into smaller, more focused modules?**
  _Cohesion score 0.03076923076923077 - nodes in this community are weakly interconnected._