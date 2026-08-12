# ReSukiSU KPM + KernelPatch 0.13.3 Design

## Goal

Create an experimental branch, isolated from `main`, that builds Android 12 GKI 5.10.236 with current ReSukiSU, KernelPatch 0.13.3 KPM support, current pinned SUSFS, NoMount, BBR, BBG, and LZ4K/LZ4KD ZRAM. Restore the matching ReSukiSU Manager KPM UI and preserve recovery artifacts.

## Fixed scope

- Branch: `feat/resukisu-kpm-kernelpatch-0.13.3`
- Base: `08eb7b0`
- Android: `android12`
- Kernel: `5.10.236`
- OS patch branch: `2025-05`
- Revision: `r11`
- ReSukiSU: current `main`, pinned to the resolved implementation commit
- Legacy KPM donor: ReSukiSU `a13d71f699093f0c1da7ba442881eccaa8e4321a`
- KernelPatch: upstream `0.13.3`, with an adapted ReSukiSU bridge
- SUSFS: `3c14ad549f826b1f53878ec8c12253efebeed75a`
- NoMount: enabled
- ZeroMount: disabled
- BBR: enabled
- BBG: enabled
- ZRAM: LZ4K and LZ4KD enabled
- Manager KPM UI: restored and built from the same source snapshot as the kernel/userspace ABI

Other kernel versions remain unsupported by the KPM option until this target passes all gates.

## Architecture

The build composes four independently verifiable layers:

1. GKI 5.10.236 receives SUSFS, then NoMount, BBR, BBG, and ZRAM changes through the existing workflow.
2. Current ReSukiSU receives a selective KPM port from the last pre-removal commit. The port covers kernel KPM handlers, UAPI, supercall dispatch, ksud operations, and Manager UI.
3. KernelPatch 0.13.3 is built from pinned source. The old Suki bridge is adapted to the 0.13.3 API rather than mixing 0.13.0 binaries with 0.13.3.
4. The compiled kernel `Image` is preserved unchanged. KernelPatch patches a copy, producing a second recoverable artifact.

## ReSukiSU port

Do not revert current ReSukiSU. Restore and adapt only KPM-related changes from the donor commit:

- `kernel/kpm/*`
- `kernel/Kbuild`
- `kernel/Kconfig`
- `kernel/supercall/dispatch.c`
- `uapi/supercall.h`
- KPM commands under `userspace/ksud`
- Manager KPM state, navigation, UI, JNI/native calls, and required assets

Current ReSukiSU behavior outside KPM remains authoritative. Conflicts are resolved against current interfaces, not by restoring obsolete callers.

The runtime ABI must support:

- version
- module count
- load
- unload
- list
- info
- control

## KernelPatch integration

Use upstream KernelPatch tag `0.13.3`. Build `kpimg` and `kptools` from one pinned source revision. Port the ReSukiSU bridge so it resolves and hooks:

- `sukisu_load_module_path`
- `sukisu_unload_module`
- `sukisu_kpm_list`
- `sukisu_kpm_info`
- `sukisu_kpm_control`
- `sukisu_kpm_version`

The workflow must fail if a required bridge symbol or hook cannot be verified. It must not silently create a patched artifact without a working control path.

## Workflow interface

Add an explicit boolean `use_kpm` input to `kernel-custom.yml` and reusable `build.yml`, and forward it through the workflow call.

When `use_kpm=true`, reject any target except:

```text
android_version=android12
kernel_version=5.10
sub_level=236
```

KPM mode also enforces `add_nomount=true` and `add_zeromount=false` for this branch's supported recipe. Existing non-KPM behavior remains unchanged.

## Build order

1. Resolve and pin all source revisions.
2. Fetch current ReSukiSU and apply the KPM compatibility port.
3. Apply current pinned SUSFS.
4. Inject NoMount after SUSFS and verify every expected call site.
5. Apply BBR, BBG, and ZRAM support.
6. Compile GKI and extract its final configuration.
7. Preserve the unpatched `Image`.
8. Build KernelPatch 0.13.3 and its ReSukiSU bridge.
9. Patch a copy of the `Image`.
10. Inspect the patched image using the matching toolchain.
11. Build the matching ReSukiSU Manager with KPM UI.
12. Package separate recovery and experimental artifacts with provenance.

## Artifacts

Produce:

- `ReSukiSU-5.10.236-unpatched.zip`
- `ReSukiSU-5.10.236-KernelPatch-0.13.3-KPM.zip`
- `ReSukiSU-Manager-KPM.apk`
- `build-provenance.json`

The provenance record contains source commits, tool hashes, image hashes, manager hash, workflow commit, and effective workflow inputs.

## Build verification

Extract configuration from the final kernel image. Verify the actual symbols used by the fetched source, including equivalents if source names differ:

- KSU enabled
- ReSukiSU SUSFS inline-hook mode enabled
- KPM enabled
- KALLSYMS and KALLSYMS_ALL enabled
- NoMount enabled
- BBG enabled
- BBR enabled and selected correctly
- ZRAM enabled
- LZ4K and LZ4KD enabled

Verify zero patch rejects, all NoMount hook call sites, bridge symbols, successful KernelPatch inspection, and distinct hashes for patched and unpatched images.

Verify spoofed kernel metadata remains:

```text
5.10.236-android12-9-00085-g226a9632f13d-ab11136126
Wed Nov 22 14:16:37 UTC 2023
```

## Device verification

Use staged rollout:

1. Boot the unpatched artifact.
2. Boot the KPM artifact with `/data/adb/kpm` empty.
3. Verify boot completion, storage, Wi-Fi, Bluetooth, and mobile data.
4. Verify SUSFS, NoMount behavior, BBR, BBG, and active ZRAM algorithms.
5. Verify KPM version and a zero module count.
6. Manually load a benign demo KPM.
7. Verify list, info, control, unload, and post-unload stability.
8. Reboot without persistent modules.
9. Test persistent autoload only after manual lifecycle tests pass.

A successful compile or boot alone does not satisfy acceptance.

## Failure handling

Always retain the unpatched artifact and stock boot recovery path. On failure, classify it as source port, compile, image patch, early KernelPatch initialization, ReSukiSU bridge, ioctl/manager, KPM load, or persistent autoload. Fix one layer per iteration and preserve logs and provenance for every run.

## Non-goals

- KPM support for 5.15, 6.1, 6.6, or 6.12
- replacing the stable ReSukiSU artifact
- supporting ZeroMount together with NoMount
- accepting mutable `main` or `latest` binaries without resolved commits and hashes
- loading third-party persistent KPM modules during initial validation
