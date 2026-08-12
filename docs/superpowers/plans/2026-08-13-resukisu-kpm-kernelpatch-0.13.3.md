# ReSukiSU KPM + KernelPatch 0.13.3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an isolated Android 12 GKI 5.10.236 ReSukiSU artifact with restored KPM kernel/userspace/Manager support, KernelPatch 0.13.3, SUSFS, NoMount, BBR, BBG, and LZ4K/LZ4KD ZRAM.

**Architecture:** Keep the established kernel feature pipeline and add a gated KPM path. Generate a deterministic compatibility patch from pinned ReSukiSU donor/current revisions, build KernelPatch plus the adapted bridge from pinned source, preserve the unpatched kernel, and patch only a copy. Build the matching Manager from the same patched ReSukiSU tree and upload hashes/provenance with both recovery and experimental artifacts.

**Tech Stack:** GitHub Actions YAML, Bash, Android GKI/Kbuild, ReSukiSU C/Rust/Kotlin, KernelPatch ARM64 freestanding C/assembly, Gradle/Android SDK, `kptools`, SHA-256 provenance.

---

## File structure

**Create**

- `config/kpm.config` — immutable ReSukiSU donor/current and KernelPatch revision pins.
- `build-helpers/apply-resukisu-kpm.sh` — fetches donor KPM files, applies the maintained compatibility patch, and validates required ReSukiSU symbols.
- `build-helpers/build-kernelpatch.sh` — builds pinned KernelPatch 0.13.3 plus the ReSukiSU bridge and patches a copy of `Image`.
- `build-helpers/verify-kpm-config.sh` — validates final kernel KPM/KALLSYMS and existing feature configuration.
- `build-helpers/verify-kpm-artifacts.sh` — validates distinct images, bridge/tool outputs, metadata, and hashes.
- `build-helpers/write-kpm-provenance.sh` — creates `build-provenance.json` from resolved commits, workflow inputs, files, and hashes.
- `build-helpers/test-kpm-workflow.sh` — deterministic local tests for input propagation, scope gates, pins, and artifact rules.
- `patches/resukisu-kpm-current.patch` — maintained selective port from the legacy KPM donor to pinned current ReSukiSU.
- `patches/kernelpatch-0.13.3-resukisu.patch` — bridge adaptation against pinned upstream KernelPatch 0.13.3.

**Modify**

- `.github/workflows/kernel-custom.yml` — expose `use_kpm`, force supported KPM recipe, pass KPM inputs to build and Manager jobs.
- `.github/workflows/build.yml` — declare KPM input, pin sources, apply/verify port, build and package KernelPatch artifacts.
- `.github/workflows/get-manager.yml` — accept KPM mode and ReSukiSU pin, build the matching Manager instead of downloading an unrelated latest artifact.
- `config/config` — retain the approved SUSFS pin; no mutable KPM pins are stored here.

## Task 1: Add deterministic KPM pins and workflow contract

**Files:**
- Create: `config/kpm.config`
- Create: `build-helpers/test-kpm-workflow.sh`
- Modify: `.github/workflows/kernel-custom.yml:53-59,72-128,129-157`
- Modify: `.github/workflows/build.yml:18-98,1434-1442`
- Modify: `.github/workflows/get-manager.yml:11-30`

- [ ] **Step 1: Write the failing workflow contract test**

Create a Bash test that checks:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CUSTOM="$ROOT/.github/workflows/kernel-custom.yml"
BUILD="$ROOT/.github/workflows/build.yml"
MANAGER="$ROOT/.github/workflows/get-manager.yml"
PINS="$ROOT/config/kpm.config"

for file in "$CUSTOM" "$BUILD" "$MANAGER"; do
  grep -q 'use_kpm:' "$file" || { echo "missing use_kpm contract: $file" >&2; exit 1; }
done
grep -q 'use_kpm: \${{ inputs.use_kpm }}' "$CUSTOM"
grep -q '^RESUKISU_CURRENT=' "$PINS"
grep -q '^RESUKISU_KPM_DONOR=' "$PINS"
grep -q '^KERNELPATCH_VERSION=0.13.3$' "$PINS"
grep -q '^KERNELPATCH_COMMIT=' "$PINS"
grep -q '^SUKISU_BRIDGE_DONOR=' "$PINS"
```

- [ ] **Step 2: Run the contract test and verify RED**

Run:

```bash
bash build-helpers/test-kpm-workflow.sh
```

Expected: failure reporting missing `use_kpm` or `config/kpm.config`.

- [ ] **Step 3: Add immutable source pins**

Create `config/kpm.config` with these initial verified revisions:

```bash
RESUKISU_CURRENT=3ef06b0fcb0960dc9563256fe26a58e892663387
RESUKISU_KPM_DONOR=a13d71f699093f0c1da7ba442881eccaa8e4321a
KERNELPATCH_VERSION=0.13.3
KERNELPATCH_COMMIT=043c0c3bae68ddc6f2894b4e483d8f54cb85d112
SUKISU_BRIDGE_DONOR=762e6fb446f58020691b83509873268f6af634f2
```

- [ ] **Step 4: Declare and forward the KPM input**

Add boolean `use_kpm`, default `false`, to `kernel-custom.yml`, `build.yml`, and `get-manager.yml`. Forward it to both called workflows. Pass the pinned ReSukiSU revision to the Manager workflow when KPM is enabled.

Add this exact early build guard:

```bash
if [ "${{ inputs.use_kpm }}" = "true" ]; then
  [ "${{ inputs.android_version }}" = android12 ] &&
  [ "${{ inputs.kernel_version }}" = 5.10 ] &&
  [ "${{ inputs.sub_level }}" = 236 ] || {
    echo "KPM is supported only for android12-5.10.236" >&2
    exit 1
  }
  [ "${{ inputs.add_nomount }}" = true ] || {
    echo "KPM recipe requires add_nomount=true" >&2
    exit 1
  }
  [ "${{ inputs.add_zeromount }}" = false ] || {
    echo "KPM recipe requires add_zeromount=false" >&2
    exit 1
  }
fi
```

- [ ] **Step 5: Run the contract test and verify GREEN**

Run:

```bash
bash build-helpers/test-kpm-workflow.sh
```

Expected: exit 0.

- [ ] **Step 6: Commit the workflow contract**

```bash
git add config/kpm.config build-helpers/test-kpm-workflow.sh .github/workflows/kernel-custom.yml .github/workflows/build.yml .github/workflows/get-manager.yml
git commit -m "feat(kpm): add pinned workflow contract"
```

## Task 2: Generate and validate the selective ReSukiSU KPM port

**Files:**
- Create: `patches/resukisu-kpm-current.patch`
- Create: `build-helpers/apply-resukisu-kpm.sh`
- Modify: `.github/workflows/build.yml:427-460`
- Test: `build-helpers/test-kpm-workflow.sh`

- [ ] **Step 1: Extend the failing test for the ReSukiSU port helper**

Append checks that require the helper to validate these strings after application:

```bash
for symbol in \
  'config KPM' \
  'sukisu_handle_kpm' \
  'SUKISU_KPM_LOAD' \
  'sukisu_load_module_path' \
  'sukisu_kpm_version'; do
  grep -q "$symbol" "$ROOT/build-helpers/apply-resukisu-kpm.sh" || exit 1
done
```

Run the test and expect failure because the helper does not exist.

- [ ] **Step 2: Build the selective patch from exact revisions**

In temporary clones, compare current ReSukiSU with donor KPM paths. Restore donor KPM files and adapt them to current `kernel/Kbuild`, `kernel/Kconfig`, `kernel/supercall/dispatch.c`, `uapi/supercall.h`, ksud, JNI, and Manager sources. Do not revert unrelated files. Export the resulting diff as `patches/resukisu-kpm-current.patch`.

The patch must restore the seven runtime operations and Manager screens without undoing current manager signing, supercall, or SUSFS behavior.

- [ ] **Step 3: Implement the idempotent port helper**

`apply-resukisu-kpm.sh <KernelSU-dir>` must:

```bash
set -euo pipefail
KSU_DIR=${1:?usage: apply-resukisu-kpm.sh <KernelSU-dir>}
PATCH=${2:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/patches/resukisu-kpm-current.patch"}
git -C "$KSU_DIR" apply --check "$PATCH"
git -C "$KSU_DIR" apply "$PATCH"
```

Then verify Kconfig, kernel handler, UAPI commands, ksud operations, JNI/native bridge, and Manager navigation. A missing requirement exits nonzero with the missing symbol and path.

- [ ] **Step 4: Test the helper against pinned ReSukiSU**

Run:

```bash
TMP=$(mktemp -d)
git clone --filter=blob:none https://github.com/ReSukiSU/ReSukiSU.git "$TMP/KernelSU"
git -C "$TMP/KernelSU" checkout 3ef06b0fcb0960dc9563256fe26a58e892663387
bash build-helpers/apply-resukisu-kpm.sh "$TMP/KernelSU"
git -C "$TMP/KernelSU" diff --check
rm -rf "$TMP"
```

Expected: helper exits 0; `git diff --check` exits 0.

- [ ] **Step 5: Wire the helper after ReSukiSU setup**

Change the setup URL to the pinned `RESUKISU_CURRENT` value in KPM mode. Run the helper immediately after setup and before SUSFS compatibility edits. Keep current branch behavior when `use_kpm=false`.

- [ ] **Step 6: Run workflow and helper tests**

Run:

```bash
bash build-helpers/test-kpm-workflow.sh
```

Expected: exit 0.

- [ ] **Step 7: Commit the ReSukiSU port**

```bash
git add patches/resukisu-kpm-current.patch build-helpers/apply-resukisu-kpm.sh build-helpers/test-kpm-workflow.sh .github/workflows/build.yml
git commit -m "feat(kpm): port KPM to current ReSukiSU"
```

## Task 3: Port the ReSukiSU bridge to KernelPatch 0.13.3

**Files:**
- Create: `patches/kernelpatch-0.13.3-resukisu.patch`
- Create: `build-helpers/build-kernelpatch.sh`
- Test: `build-helpers/test-kpm-workflow.sh`

- [ ] **Step 1: Add failing bridge requirements**

Extend the test to require the KernelPatch helper and all bridge hook names:

```bash
for symbol in sukisu_load_module_path sukisu_unload_module sukisu_kpm_list sukisu_kpm_info sukisu_kpm_control sukisu_kpm_version; do
  grep -q "$symbol" "$ROOT/patches/kernelpatch-0.13.3-resukisu.patch" || exit 1
done
```

Run the test and expect failure.

- [ ] **Step 2: Create the KernelPatch bridge patch**

Start from pinned upstream KernelPatch `043c0c3...`. Compare the Suki bridge donor `762e6fb...`, then port only the bridge and its build wiring to the 0.13.3 hook/preset APIs. Preserve 0.13.3 map selection, kallsyms resolution, boot flow, memory layout, and KPM loader.

Every hook must use the callback arity matching the current ReSukiSU function signature. Treat any unresolved symbol as fatal.

- [ ] **Step 3: Implement KernelPatch build and image-copy patching**

`build-kernelpatch.sh` accepts:

```text
build-kernelpatch.sh <unpatched-image> <output-image> <work-dir>
```

It must:

1. source `config/kpm.config`;
2. clone and checkout `KERNELPATCH_COMMIT`;
3. apply `kernelpatch-0.13.3-resukisu.patch` with `git apply --check`;
4. build Android `kpimg` with `export TARGET_COMPILE=<aarch64-none-elf-prefix>; cd kernel; export ANDROID=1; make hdr kpimg`, then build Linux `kptools` with `cd tools; cmake -S . -B build -DCMAKE_BUILD_TYPE=Release; cmake --build build`;
5. copy the input image to the output path;
6. patch only the output image;
7. run `kptools` inspection on the output;
8. write resolved commit and tool paths to `$GITHUB_ENV` when available.

The helper must reject identical input/output paths before doing work.

- [ ] **Step 4: Test KernelPatch source application and tool build**

Run the helper's source-only/test mode against the pinned revision. Expected: bridge patch applies, toolchain build exits 0, and `kpimg` plus `kptools` are non-empty.

- [ ] **Step 5: Run the contract test**

```bash
bash build-helpers/test-kpm-workflow.sh
```

Expected: exit 0.

- [ ] **Step 6: Commit the KernelPatch bridge**

```bash
git add patches/kernelpatch-0.13.3-resukisu.patch build-helpers/build-kernelpatch.sh build-helpers/test-kpm-workflow.sh
git commit -m "feat(kpm): bridge KernelPatch 0.13.3"
```

## Task 4: Add final configuration and artifact verification

**Files:**
- Create: `build-helpers/verify-kpm-config.sh`
- Create: `build-helpers/verify-kpm-artifacts.sh`
- Modify: `.github/workflows/build.yml:1423-1464,1645-1652`
- Test: `build-helpers/test-kpm-workflow.sh`

- [ ] **Step 1: Write failing verifier tests with fixtures**

The test creates a valid config fixture containing:

```text
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
CONFIG_KPM=y
CONFIG_KALLSYMS=y
CONFIG_KALLSYMS_ALL=y
CONFIG_NOMOUNT=y
CONFIG_BBG=y
CONFIG_TCP_CONG_BBR=y
CONFIG_ZRAM=y
CONFIG_CRYPTO_LZ4K=y
CONFIG_CRYPTO_LZ4KD=y
```

Run `verify-kpm-config.sh` against it and expect RED because the verifier does not exist. Add negative fixtures missing one symbol and require nonzero exit.

- [ ] **Step 2: Implement final config verification**

`verify-kpm-config.sh <config>` validates exact required symbols and delegates BBR checks to `verify-bbr-config.sh`. Before locking the two LZ4K names, inspect the fetched ZRAM patch source and update the required names to its real Kconfig symbols. Error output names every missing symbol.

- [ ] **Step 3: Implement artifact verification**

`verify-kpm-artifacts.sh <unpatched> <patched> <kpimg> <kptools>` validates:

- all files exist and are non-empty;
- unpatched and patched image hashes differ;
- input image remains unchanged across patching;
- `kptools` inspection succeeds;
- patched image contains expected KernelPatch version metadata;
- final Linux version contains the requested release and build timestamp.

- [ ] **Step 4: Wire KPM config selection and verification**

Replace the dead string-prefix gate at `build.yml:1434-1442` with the boolean `use_kpm`. Add `CONFIG_KPM=y`, `CONFIG_KALLSYMS=y`, and `CONFIG_KALLSYMS_ALL=y` only in KPM mode. After `extract-ikconfig`, run both BBR and KPM config verifiers.

- [ ] **Step 5: Run local verifier tests**

```bash
bash build-helpers/test-kpm-workflow.sh
```

Expected: positive fixture passes; each negative fixture fails; overall test exits 0.

- [ ] **Step 6: Commit verification gates**

```bash
git add build-helpers/verify-kpm-config.sh build-helpers/verify-kpm-artifacts.sh build-helpers/test-kpm-workflow.sh .github/workflows/build.yml
git commit -m "test(kpm): verify config and patched image"
```

## Task 5: Build and package matching Manager UI

**Files:**
- Modify: `.github/workflows/get-manager.yml:11-30,65-146,188-199`
- Test: `build-helpers/test-kpm-workflow.sh`

- [ ] **Step 1: Add a failing Manager-source-build contract**

Require KPM mode in `get-manager.yml` to contain:

```text
RESUKISU_CURRENT
apply-resukisu-kpm.sh
gradlew
assembleRelease
ReSukiSU-Manager-KPM
```

Run the test and expect failure.

- [ ] **Step 2: Replace unrelated artifact download in KPM mode**

When `use_kpm=true`:

1. checkout this repository so helpers/patches are available;
2. clone ReSukiSU at `RESUKISU_CURRENT`;
3. run `apply-resukisu-kpm.sh`;
4. initialize required submodules;
5. run the repository's release Manager Gradle task;
6. locate the release APK;
7. compute SHA-256;
8. upload as `ReSukiSU-Manager-KPM`.

Retain the existing latest-artifact download only when `use_kpm=false`.

- [ ] **Step 3: Verify the patched Manager source compiles**

Run the same Gradle command in a clean Linux/CI environment. Expected: release APK exists and is non-empty. If signing requires unavailable secrets, use the repository's supported unsigned release artifact and record that status; do not fabricate signing.

- [ ] **Step 4: Run the contract test**

```bash
bash build-helpers/test-kpm-workflow.sh
```

Expected: exit 0.

- [ ] **Step 5: Commit Manager integration**

```bash
git add .github/workflows/get-manager.yml build-helpers/test-kpm-workflow.sh
git commit -m "feat(kpm): build matching ReSukiSU Manager"
```

## Task 6: Package recovery, KPM, and provenance artifacts

**Files:**
- Create: `build-helpers/write-kpm-provenance.sh`
- Modify: `.github/workflows/build.yml:1660-1791`
- Test: `build-helpers/test-kpm-workflow.sh`

- [ ] **Step 1: Add failing provenance requirements**

Require `write-kpm-provenance.sh` to emit these JSON keys:

```text
workflow_commit
kernel_source_commit
resukisu_commit
resukisu_kpm_donor
susfs_commit
kernelpatch_commit
kernelpatch_version
kpimg_sha256
kptools_sha256
unpatched_image_sha256
patched_image_sha256
manager_source_commit
inputs
```

Run the test and expect failure.

- [ ] **Step 2: Implement provenance writer**

Use `jq -n` with values passed through environment variables. Fail if a required value is empty. Hash with `sha256sum`; never parse human-formatted hash output. Write deterministic JSON to the requested path.

- [ ] **Step 3: Produce separate AnyKernel packages**

In KPM mode:

1. copy final `Image` to `artifacts/unpatched/Image`;
2. invoke `build-kernelpatch.sh` to create `artifacts/kpm/Image`;
3. build one AnyKernel zip from each image;
4. give explicit names containing `unpatched` and `KernelPatch-0.13.3-KPM`;
5. run artifact verification;
6. write `build-provenance.json`;
7. upload both zips, images, KernelPatch tools/hashes, and provenance.

The normal non-KPM artifact path remains unchanged.

- [ ] **Step 4: Test provenance and overwrite prevention**

Use temporary fake files and verify:

```bash
bash build-helpers/write-kpm-provenance.sh "$TMP/build-provenance.json"
jq -e '.kernelpatch_version == "0.13.3"' "$TMP/build-provenance.json"
```

Also call `build-kernelpatch.sh image image work` and require nonzero exit before the file changes.

- [ ] **Step 5: Run all helper tests**

```bash
bash build-helpers/test-kpm-workflow.sh
bash build-helpers/test-inject-nomount-dpath.sh 5.x
bash build-helpers/test-inject-nomount-dpath.sh 6.x
```

Expected: all exit 0.

- [ ] **Step 6: Commit artifact packaging**

```bash
git add build-helpers/write-kpm-provenance.sh build-helpers/test-kpm-workflow.sh .github/workflows/build.yml
git commit -m "feat(kpm): package recovery and provenance"
```

## Task 7: Dispatch Android 12 5.10.236 integration build

**Files:**
- Verify: GitHub Actions run and uploaded artifacts

- [ ] **Step 1: Push the experimental branch**

```bash
git push -u origin feat/resukisu-kpm-kernelpatch-0.13.3
```

Expected: branch is created on the remote with no change to `main`.

- [ ] **Step 2: Run all local validations once**

```bash
bash build-helpers/test-kpm-workflow.sh
bash build-helpers/test-inject-nomount-dpath.sh 5.x
bash build-helpers/test-inject-nomount-dpath.sh 6.x
TMP_CONFIG=$(mktemp)
cat > \"$TMP_CONFIG\" <<'EOF'
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_BBR=y
CONFIG_DEFAULT_TCP_CONG=\"bbr\"
CONFIG_NET_SCH_FQ=y
EOF
bash build-helpers/verify-bbr-config.sh \"$TMP_CONFIG\"
rm -f \"$TMP_CONFIG\"
```

Expected: all exit 0.

- [ ] **Step 3: Dispatch the supported recipe**

```bash
gh workflow run kernel-custom.yml \
  -R femmynuppu/GKI_KernelSU_SUSFS \
  --ref feat/resukisu-kpm-kernelpatch-0.13.3 \
  -f android_version=android12 \
  -f kernel_version=5.10 \
  -f sub_level=236 \
  -f os_patch_level=2025-05 \
  -f revision=r11 \
  -f version=5.10.236-android12-9-00085-g226a9632f13d-ab11136126 \
  -f build_time='Wed Nov 22 14:16:37 UTC 2023' \
  -f use_zram=true \
  -f use_bbg=true \
  -f use_rekernel=false \
  -f cancel_susfs=false \
  -f supp_op=false \
  -f droidspaces=off \
  -f droidspaces_ntsync=false \
  -f add_zeromount=false \
  -f add_selinux_evasion=false \
  -f add_nomount=true \
  -f use_kpm=true
```

- [ ] **Step 4: Watch the run to completion**

```bash
gh run watch <run-id> -R femmynuppu/GKI_KernelSU_SUSFS --exit-status
```

Expected: kernel and matching Manager jobs succeed.

- [ ] **Step 5: Diagnose the first real failure, not the final aggregate**

If failed:

```bash
gh run view <run-id> -R femmynuppu/GKI_KernelSU_SUSFS --log-failed
```

Locate the earliest compiler/patch/tool error. Add a failing local regression test for that exact layer, fix one root cause, commit, push, and dispatch again. Do not remove KPM, NoMount, BBG, ZRAM, BBR, or SUSFS to make the matrix easier.

- [ ] **Step 6: Capture and verify provenance**

Use the ReSukiSU kernel MCP provenance capture for the successful run. Verify artifact hash, source commit, config hash, artifact size, and run ID form a valid chain.

- [ ] **Step 7: Record successful build evidence**

Record run URL, artifact names, SHA-256 hashes, final extracted config results, KernelPatch inspection result, and manager artifact in the final delivery. Do not claim device runtime behavior until the device gates are executed.

## Task 8: Device rollout and runtime KPM validation

**Files:**
- Verify: device state and captured logs; no repository change unless a runtime defect requires one

- [ ] **Step 1: Preserve recovery prerequisites**

Keep stock boot and the unpatched artifact locally. Confirm the Xiaomi 13T is visible using:

```text
D:\XIAOMI13T\ADB FASTBOOT\adb.exe devices
```

- [ ] **Step 2: Boot/flash the unpatched artifact first**

Verify Android boot completion and baseline network/storage behavior. Capture `uname -a`, `/proc/version`, active congestion control, ZRAM algorithms, and final kernel config where available.

- [ ] **Step 3: Empty persistent KPM directory before first patched boot**

Ensure `/data/adb/kpm` contains no `.kpm` files. Boot the KernelPatch artifact.

- [ ] **Step 4: Verify base runtime gates**

Verify boot completion, storage, Wi-Fi association, Bluetooth enablement, mobile data, SUSFS, a real NoMount redirect rule, BBR, BBG presence, ZRAM LZ4K/LZ4KD availability, uname spoof, and build timestamp.

- [ ] **Step 5: Verify KPM lifecycle manually**

Using the matching Manager or ksud interface:

1. read KPM version;
2. confirm module count zero;
3. load one benign demo KPM;
4. list it;
5. read info;
6. send a benign control message;
7. unload it;
8. confirm module count zero.

- [ ] **Step 6: Reboot before enabling persistence**

Confirm a clean reboot with no module in `/data/adb/kpm`. Only then copy the benign module to the persistent directory and test one autoload reboot.

- [ ] **Step 7: Classify any runtime failure**

Collect `dmesg`, pstore/ramoops, Manager logs, and boot state. Classify the failure as KernelPatch early init, ReSuki bridge, ioctl/Manager, module load, NoMount/SUSFS interaction, or persistent autoload. Add a regression gate and fix only that layer.
