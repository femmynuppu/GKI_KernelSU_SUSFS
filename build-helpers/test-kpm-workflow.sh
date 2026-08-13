#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CUSTOM="$ROOT/.github/workflows/kernel-custom.yml"
BUILD="$ROOT/.github/workflows/build.yml"
MANAGER="$ROOT/.github/workflows/get-manager.yml"
PINS="$ROOT/config/kpm.config"
VALIDATOR="$ROOT/build-helpers/validate-kpm-recipe.sh"

HELPER="$ROOT/build-helpers/apply-resukisu-kpm.sh"
PATCH="$ROOT/patches/resukisu-kpm-current.patch"

BRIDGE="$ROOT/patches/kernelpatch-0.13.3-resukisu.patch"
KP_HELPER="$ROOT/build-helpers/build-kernelpatch.sh"
KPM_CONFIG_VERIFIER="$ROOT/build-helpers/verify-kpm-config.sh"
KPM_ARTIFACT_VERIFIER="$ROOT/build-helpers/verify-kpm-artifacts.sh"
KPM_PROVENANCE_WRITER="$ROOT/build-helpers/write-kpm-provenance.sh"

for required in "$BRIDGE" "$KP_HELPER"; do
  [ -f "$required" ] || {
    echo "missing required KernelPatch bridge file: $required" >&2
    exit 1
  }
done

for symbol in \
  sukisu_load_module_path \
  sukisu_unload_module \
  sukisu_kpm_num \
  sukisu_kpm_list \
  sukisu_kpm_info \
  sukisu_kpm_control \
  sukisu_kpm_version; do
  grep -Fq "$symbol" "$BRIDGE" || {
    echo "KernelPatch bridge is missing hook: $symbol" >&2
    exit 1
  }
done

for wrapper in \
  'hook_wrap4((void *)addr, before_sukisu_load_module_path' \
  'hook_wrap3((void *)addr, before_sukisu_unload_module' \
  'hook_wrap1((void *)addr, before_sukisu_kpm_num' \
  'hook_wrap3((void *)addr, before_sukisu_kpm_list' \
  'hook_wrap4((void *)addr, before_sukisu_kpm_info' \
  'hook_wrap4((void *)addr, before_sukisu_kpm_control' \
  'hook_wrap2((void *)addr, before_sukisu_kpm_version'; do
  grep -Fq "$wrapper" "$BRIDGE" || {
    echo "KernelPatch bridge has a missing or wrong-arity wrapper: $wrapper" >&2
    exit 1
  }
done

grep -Fq 'arg_len <= 0 || arg_len >= KPM_ARGS_LEN' "$BRIDGE" || {
  echo "KernelPatch control bridge must reject unterminated KPM arguments" >&2
  exit 1
}

for bound in \
  'name_len <= 0 || name_len >= sizeof(kpm_name)' \
  'arg_len <= 0 || arg_len >= sizeof(kpm_args)'; do
  grep -Fq "$bound" "$PATCH" || {
    echo "ReSukiSU KPM control handler is missing string bound: $bound" >&2
    exit 1
  }
done

kp_work=$(mktemp -d)
trap 'rm -rf "$kp_work"' EXIT
mkdir -p "$kp_work/KernelPatch/input" "$kp_work/bin"
printf 'immutable-input\n' > "$kp_work/KernelPatch/input/Image"
cat > "$kp_work/bin/git" <<'SH'
#!/usr/bin/env bash
exit 99
SH
chmod +x "$kp_work/bin/git"
input_hash=$(sha256sum "$kp_work/KernelPatch/input/Image" | cut -d' ' -f1)
set +e
PATH="$kp_work/bin:$PATH" TARGET_COMPILE=unused \
  bash "$KP_HELPER" \
    "$kp_work/KernelPatch/input/Image" \
    "$kp_work/output/Image" \
    "$kp_work" >/dev/null 2>&1
kp_status=$?
set -e
[ "$kp_status" -ne 0 ] || {
  echo "KernelPatch helper must reject input nested below its disposable clone" >&2
  exit 1
}
[ -f "$kp_work/KernelPatch/input/Image" ] || {
  echo "KernelPatch helper deleted its nested input" >&2
  exit 1
}
[ "$(sha256sum "$kp_work/KernelPatch/input/Image" | cut -d' ' -f1)" = "$input_hash" ] || {
  echo "KernelPatch helper modified its nested input" >&2
  exit 1
}
grep -Fq '"$KPTOOLS" -l -i "$OUTPUT" >/dev/null' "$KP_HELPER" || {
  echo "KernelPatch helper must suppress superkeys from inspection output" >&2
  exit 1
}
for required in "$HELPER" "$PATCH"; do
  [ -f "$required" ] || {
    echo "missing required KPM source port file: $required" >&2
    exit 1
  }
done

[ -x "$HELPER" ] || {
  echo "KPM source port helper must be executable: $HELPER" >&2
  exit 1
}

for symbol in \
  "config KPM" \
  "sukisu_handle_kpm" \
  "SUKISU_KPM_LOAD" \
  "sukisu_load_module_path" \
  "sukisu_kpm_version"; do
  grep -Fq "$symbol" "$PATCH" || {
    echo "KPM source port patch is missing required symbol: $symbol" >&2
    exit 1
  }
  grep -Fq "$symbol" "$HELPER" || {
    echo "KPM source port helper does not verify required symbol: $symbol" >&2
    exit 1
  }
done

grep -Fq 'if (!ksu_access_ok(arg1, len))' "$PATCH" || {
  echo "KPM LIST must validate its arg1 output pointer" >&2
  exit 1
}
if grep -Fq 'if (!ksu_access_ok(arg2, len))' "$PATCH"; then
  echo "KPM LIST must not treat arg2 length as a pointer" >&2
  exit 1
fi
grep -Fq 'len <= 0 || len > sizeof(buf)' "$PATCH" || {
  echo "KPM LIST must bound its requested copy length to its stack buffer" >&2
  exit 1
}

for resource in \
  kpm_title \
  kpm_empty \
  kpm_version \
  kpm_author \
  kpm_uninstall \
  kpm_uninstall_success \
  kpm_uninstall_failed \
  kpm_install_success \
  kpm_install_failed \
  kpm_args \
  kpm_control \
  close_notice \
  kernel_module_notice \
  kpm_control_success \
  kpm_control_failed \
  kpm_install_mode \
  kpm_install_mode_load \
  kpm_install_mode_embed \
  kpm_install_mode_description \
  snackbar_failed_to_check_module_file \
  invalid_file_type \
  confirm_uninstall_title_with_filename \
  confirm_uninstall_content \
  search_modules; do
  entry="<string name=\"$resource\""
  grep -Fq "$entry" "$PATCH" || {
    echo "KPM source port patch is missing Manager resource: $resource" >&2
    exit 1
  }
  grep -Fq "  $resource" "$HELPER" || {
    echo "KPM source port helper does not verify Manager resource: $resource" >&2
    exit 1
  }
done

if grep -Eq '^(GIT binary patch|Binary files .*manager/app/src/main/assets/(kpimg|kptools))' "$PATCH"; then
  echo "KPM source port patch must not contain binary assets" >&2
  exit 1
fi

if grep -Eq '^diff --git a/manager/app/src/main/assets/(kpimg|kptools) ' "$PATCH"; then
  echo "KPM source port patch must not restore kpimg or kptools" >&2
  exit 1
fi
expect_success() {
  local name=$1
  shift
  local output
  if ! output=$(bash "$VALIDATOR" "$@" 2>&1); then
    echo "$name: expected success, got: $output" >&2
    exit 1
  fi
}

expect_failure() {
  local name=$1
  local expected=$2
  shift 2
  local output status
  set +e
  output=$(bash "$VALIDATOR" "$@" 2>&1)
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    echo "$name: expected failure" >&2
    exit 1
  fi
  if [ "$output" != "$expected" ]; then
    echo "$name: expected '$expected', got '$output'" >&2
    exit 1
  fi
}
expected_release='5.10.236-android12-9-00085-g226a9632f13d-ab11136126'
expected_timestamp='Wed Nov 22 14:16:37 UTC 2023'

expect_success "disabled KPM ignores target tuple" \
  false android99 0.0 arbitrary false true arbitrary arbitrary
expect_success "supported KPM recipe" \
  true android12 5.10 236 true false "$expected_release" "$expected_timestamp"

scope_message="KPM is supported only for android12-5.10.236"
expect_failure "wrong Android version" "$scope_message" \
  true android13 5.10 236 true false "$expected_release" "$expected_timestamp"
expect_failure "wrong kernel version" "$scope_message" \
  true android12 5.15 236 true false "$expected_release" "$expected_timestamp"
expect_failure "wrong kernel sublevel" "$scope_message" \
  true android12 5.10 237 true false "$expected_release" "$expected_timestamp"
expect_failure "NoMount disabled" "KPM recipe requires add_nomount=true" \
  true android12 5.10 236 false false "$expected_release" "$expected_timestamp"
expect_failure "ZeroMount enabled" "KPM recipe requires add_zeromount=false" \
  true android12 5.10 236 true true "$expected_release" "$expected_timestamp"
expect_failure "wrong spoof release" \
  "KPM recipe requires version=$expected_release" \
  true android12 5.10 236 true false wrong "$expected_timestamp"
expect_failure "wrong spoof timestamp" \
  "KPM recipe requires build_time=$expected_timestamp" \
  true android12 5.10 236 true false "$expected_release" wrong
expect_failure "wrong argument count" \
  "Usage: validate-kpm-recipe.sh <use_kpm> <android_version> <kernel_version> <sub_level> <add_nomount> <add_zeromount> <version> <build_time>" \
  true android12 5.10 236 true false "$expected_release"

python - "$CUSTOM" "$BUILD" "$MANAGER" <<'PY'
import shlex
import sys

import yaml


def load(path):
    with open(path, encoding="utf-8") as stream:
        return yaml.safe_load(stream)


def on(document):
    if "on" in document:
        return document["on"]
    return document[True]


def assert_false_boolean_input(document, event, path):
    value = on(document)[event]["inputs"]["use_kpm"]
    assert value["required"] is False, f"{path}: use_kpm.required must be false"
    assert value["type"] == "boolean", f"{path}: use_kpm.type must be boolean"
    assert value["default"] is False, f"{path}: use_kpm.default must be false"


custom_path, build_path, manager_path = sys.argv[1:]
custom = load(custom_path)
build = load(build_path)
manager = load(manager_path)

assert_false_boolean_input(custom, "workflow_dispatch", custom_path)
assert_false_boolean_input(build, "workflow_call", build_path)
assert_false_boolean_input(manager, "workflow_call", manager_path)

jobs = custom["jobs"]
expression = "${{ inputs.use_kpm }}"
assert jobs["build-custom-kernel"]["with"]["use_kpm"] == expression
manager_with = jobs["get-ksu-manager"]["with"]
assert manager_with["use_kpm"] == expression
assert manager_with["resukisu_commit"] == "3ef06b0fcb0960dc9563256fe26a58e892663387"

manager_commit = on(manager)["workflow_call"]["inputs"]["resukisu_commit"]
assert manager_commit["required"] is False
assert manager_commit["type"] == "string"

steps = build["jobs"]["build-kernel"]["steps"]
checkout_index = next(
    (
        index
        for index, step in enumerate(steps)
        if str(step.get("uses", "")).startswith("actions/checkout@")
    ),
    None,
)
assert checkout_index is not None, "build-kernel must check out the repository"

expected_command = [
    "bash",
    "build-helpers/validate-kpm-recipe.sh",
    "${{ inputs.use_kpm }}",
    "${{ inputs.android_version }}",
    "${{ inputs.kernel_version }}",
    "${{ inputs.sub_level }}",
    "${{ inputs.add_nomount }}",
    "${{ inputs.add_zeromount }}",
    "${{ inputs.version }}",
    "${{ inputs.build_time }}",
]
validator_index = None
validator_command = None
for index, step in enumerate(steps):
    for line in str(step.get("run", "")).splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if "build-helpers/validate-kpm-recipe.sh" not in line:
            continue
        command = shlex.split(line)
        if command[:2] == expected_command[:2]:
            assert validator_index is None, "build-kernel must invoke the KPM validator exactly once"
            validator_index = index
            validator_command = command

assert validator_index is not None, "build-kernel must invoke the KPM validator"
assert validator_index == checkout_index + 1, "KPM validator must run immediately after checkout"
assert validator_command == expected_command, "KPM validator must receive exactly the eight recipe inputs"
cleanup_index = next(
    (
        index
        for index, step in enumerate(steps)
        if str(step.get("uses", "")).startswith("endersonmenezes/free-disk-space@")
    ),
    None,
)
setup_index = next(
    (
        index
        for index, step in enumerate(steps)
        if step.get("name") == "初始化构建环境"
    ),
    None,
)
assert cleanup_index is not None, "build-kernel must retain the disk cleanup step"
assert setup_index is not None, "build-kernel must retain the environment setup step"
assert validator_index < cleanup_index, "KPM validator must run before disk cleanup"
assert validator_index < setup_index, "KPM validator must run before environment setup"
ksu_step = next(
    (step for step in steps if step.get("name") == "添加 KernelSU"),
    None,
)
assert ksu_step is not None, "build-kernel must retain the KernelSU setup step"
ksu_setup = str(ksu_step.get("run", ""))
source_config = 'source "${{ github.workspace }}/config/kpm.config"'
kpm_condition = 'if [ "${{ inputs.use_kpm }}" = "true" ]; then'
pinned_fetch = '"https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/$RESUKISU_CURRENT/kernel/setup.sh"'
pinned_setup = 'bash -s "$RESUKISU_CURRENT"'
apply_helper = 'bash "${{ github.workspace }}/build-helpers/apply-resukisu-kpm.sh" "$KERNEL_ROOT/KernelSU"'
normal_fetch = '"https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh"'
normal_setup = "bash $BRANCH"


for required in (
    source_config,
    kpm_condition,
    pinned_fetch,
    pinned_setup,
    apply_helper,
    normal_fetch,
    normal_setup,
):
    assert required in ksu_setup, f"KernelSU setup is missing: {required}"

assert ksu_setup.index(source_config) < ksu_setup.index(kpm_condition)
assert ksu_setup.index(kpm_condition) < ksu_setup.index(pinned_fetch)
assert ksu_setup.index(pinned_fetch) < ksu_setup.index(pinned_setup)
assert ksu_setup.index(pinned_setup) < ksu_setup.index(apply_helper)
assert ksu_setup.index(apply_helper) < ksu_setup.index(normal_fetch)
assert ksu_setup.index(normal_fetch) < ksu_setup.index(normal_setup)

compile_step = next(
    (
        step
        for step in steps
        if str(step.get("uses", "")).startswith("nick-fields/retry@")
    ),
    None,
)
assert compile_step is not None, "build-kernel must retain its retry-wrapped compile step"
compile_command = str(compile_step.get("with", {}).get("command", ""))
bbr_verify = 'bash "$GITHUB_WORKSPACE/build-helpers/verify-bbr-config.sh" /tmp/final-kernel.config'
kpm_verify = 'bash "$GITHUB_WORKSPACE/build-helpers/verify-kpm-config.sh" /tmp/final-kernel.config'
assert bbr_verify in compile_command, "compile step must run the BBR final-config verifier"
assert kpm_condition in compile_command, "compile step must guard KPM-only verification"
assert kpm_verify in compile_command, "compile step must run the KPM final-config verifier"
assert compile_command.index(bbr_verify) < compile_command.index(kpm_verify)

manager_steps = manager["jobs"]["get_ksu_manager"]["steps"]
kpm_checkout = next(
    (
        step
        for step in manager_steps
        if str(step.get("uses", "")).startswith("actions/checkout@")
    ),
    None,
)
assert kpm_checkout is not None, "KPM Manager job must check out workflow helpers"
assert "inputs.use_kpm" in str(kpm_checkout.get("if", ""))

manager_build = next(
    (step for step in manager_steps if step.get("name") == "构建匹配 KPM Manager"),
    None,
)
assert manager_build is not None, "KPM Manager source-build step is missing"
assert "inputs.use_kpm" in str(manager_build.get("if", ""))
manager_build_run = str(manager_build.get("run", ""))
for required in (
    "RESUKISU_CURRENT",
    "apply-resukisu-kpm.sh",
    "submodule update --init --recursive",
    "gradlew assembleRelease",
    "sha256sum",
):
    assert required in manager_build_run, f"KPM Manager build is missing: {required}"

kpm_upload = next(
    (
        step
        for step in manager_steps
        if step.get("uses") == "actions/upload-artifact@v6"
        and step.get("with", {}).get("name") == "ReSukiSU-Manager-KPM"
    ),
    None,
)
assert kpm_upload is not None, "matching KPM Manager artifact upload is missing"
assert "inputs.use_kpm" in str(kpm_upload.get("if", ""))

normal_manager = next(
    (step for step in manager_steps if step.get("id") == "add_KSU"),
    None,
)
assert normal_manager is not None
assert "!inputs.use_kpm" in str(normal_manager.get("if", ""))

kpm_package_step = next(
    (step for step in steps if step.get("name") == "构建并验证 KPM 恢复产物"),
    None,
)
assert kpm_package_step is not None, "KPM recovery packaging step is missing"
kpm_package_run = str(kpm_package_step.get("run", ""))
for required in (
    "artifacts/unpatched/Image",
    "artifacts/kpm/Image",
    "build-kernelpatch.sh",
    "verify-kpm-artifacts.sh",
    "write-kpm-provenance.sh",
    "ReSukiSU-5.10.236-unpatched.zip",
    "ReSukiSU-5.10.236-KernelPatch-0.13.3-KPM.zip",
):
    assert required in kpm_package_run, f"KPM recovery packaging is missing: {required}"

kpm_kernel_upload = next(
    (
        step
        for step in steps
        if step.get("uses") == "actions/upload-artifact@v6"
        and step.get("with", {}).get("name") == "ReSukiSU-KernelPatch-KPM-${{ env.CONFIG }}"
    ),
    None,
)
assert kpm_kernel_upload is not None, "KPM recovery artifact upload is missing"
assert "inputs.use_kpm" in str(kpm_kernel_upload.get("if", ""))
upload_paths = str(kpm_kernel_upload.get("with", {}).get("path", ""))
assert "artifacts/" in upload_paths
assert "ReSukiSU-*.zip" in upload_paths
PY
for verifier in "$KPM_CONFIG_VERIFIER" "$KPM_ARTIFACT_VERIFIER"; do
  [ -x "$verifier" ] || {
    echo "missing executable KPM verifier: $verifier" >&2
    exit 1
  }
done

verify_tmp=$(mktemp -d)
trap 'rm -rf "$kp_work" "$verify_tmp"' EXIT
valid_config="$verify_tmp/valid.config"
cat > "$valid_config" <<'EOF'
CONFIG_KSU=y
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
CONFIG_KPM=y
CONFIG_KALLSYMS=y
CONFIG_KALLSYMS_ALL=y
CONFIG_NOMOUNT=y
CONFIG_BBG=y
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_NET_SCH_FQ=y
CONFIG_ZRAM=y
CONFIG_ZRAM_DEF_COMP_LZ4KD=y
CONFIG_CRYPTO_LZ4K=y
CONFIG_CRYPTO_LZ4KD=y
EOF
bash "$KPM_CONFIG_VERIFIER" "$valid_config"

while IFS= read -r missing_symbol; do
  missing_config="$verify_tmp/missing.config"
  grep -vxF "$missing_symbol" "$valid_config" > "$missing_config"
  set +e
  missing_output=$(bash "$KPM_CONFIG_VERIFIER" "$missing_config" 2>&1)
  missing_status=$?
  set -e
  [ "$missing_status" -ne 0 ] || {
    echo "KPM config verifier accepted a config without $missing_symbol" >&2
    exit 1
  }
  case "$missing_output" in
    *"$missing_symbol"*) ;;
    *)
      echo "KPM config verifier did not name the missing $missing_symbol symbol" >&2
      exit 1
      ;;
  esac
done < "$valid_config"

unpatched="$verify_tmp/unpatched-Image"
patched="$verify_tmp/patched-Image"
kpimg="$verify_tmp/kpimg"
kptools="$verify_tmp/kptools"
release='5.10.236-android12-9-00085-g226a9632f13d-ab11136126'
timestamp='Wed Nov 22 14:16:37 UTC 2023'
printf 'Linux version %s #1 SMP PREEMPT %s\nunpatched\n' "$release" "$timestamp" > "$unpatched"
printf 'Linux version %s #1 SMP PREEMPT %s\npatched\n' "$release" "$timestamp" > "$patched"
printf 'kpimg\n' > "$kpimg"
cat > "$kptools" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-} ${2:-}" in
  "-l -i")
    [ "$#" -eq 3 ]
    [ -s "$3" ]
    echo "[Kernel Image]"
    if [ -n "${FAKE_BANNER:-}" ]; then
      echo "banner=$FAKE_BANNER"
    else
      printf 'banner='
      sed -n '1p' "$3"
    fi
    echo "patched=${FAKE_PATCHED:-true}"
    echo "[KernelPatch Image]"
    echo "version=0x${FAKE_PATCH_VERSION:-d03}"
    ;;
  "-v -k")
    [ "$#" -eq 3 ]
    [ -s "$3" ]
    echo "${FAKE_KPIMG_VERSION:-d03}"
    ;;
  *)
    exit 2
    ;;
esac
SH
chmod +x "$kptools"

KPM_UNPATCHED_SHA256=$(sha256sum "$unpatched" | cut -d' ' -f1) \
EXPECTED_KERNEL_RELEASE="$release" \
EXPECTED_BUILD_TIMESTAMP="$timestamp" \
  bash "$KPM_ARTIFACT_VERIFIER" "$unpatched" "$patched" "$kpimg" "$kptools"

expected_unpatched_sha256=$(sha256sum "$unpatched" | cut -d' ' -f1)
expect_artifact_failure() {
  local name=$1
  local expected=$2
  shift 2
  local output status

  set +e
  output=$(
    KPM_UNPATCHED_SHA256="$expected_unpatched_sha256" \
    EXPECTED_KERNEL_RELEASE="$release" \
    EXPECTED_BUILD_TIMESTAMP="$timestamp" \
      "$@" 2>&1
  )
  status=$?
  set -e
  [ "$status" -ne 0 ] || {
    echo "$name: expected artifact verification failure" >&2
    exit 1
  }
  case "$output" in
    *"$expected"*) ;;
    *)
      echo "$name: expected '$expected', got '$output'" >&2
      exit 1
      ;;
  esac
}

expect_artifact_failure \
  "modified unpatched image" \
  "unpatched image hash changed" \
  env KPM_UNPATCHED_SHA256=0000000000000000000000000000000000000000000000000000000000000000 \
  bash "$KPM_ARTIFACT_VERIFIER" "$unpatched" "$patched" "$kpimg" "$kptools"
expect_artifact_failure \
  "identical patched image" \
  "patched image is byte-identical" \
  bash "$KPM_ARTIFACT_VERIFIER" "$unpatched" "$unpatched" "$kpimg" "$kptools"
expect_artifact_failure \
  "wrong kpimg version" \
  "kpimg is not KernelPatch" \
  env FAKE_KPIMG_VERSION=d02 \
  bash "$KPM_ARTIFACT_VERIFIER" "$unpatched" "$patched" "$kpimg" "$kptools"
expect_artifact_failure \
  "wrong parsed banner" \
  "Linux release or build timestamp mismatch" \
  env FAKE_BANNER="Linux version wrong #1 SMP PREEMPT $timestamp" \
  bash "$KPM_ARTIFACT_VERIFIER" "$unpatched" "$patched" "$kpimg" "$kptools"
expect_artifact_failure \
  "unpatched image not marked patched" \
  "did not mark the image patched" \
  env FAKE_PATCHED=false \
  bash "$KPM_ARTIFACT_VERIFIER" "$unpatched" "$patched" "$kpimg" "$kptools"
expect_artifact_failure \
  "wrong embedded KernelPatch version" \
  "expected KernelPatch" \
  env FAKE_PATCH_VERSION=d02 \
  bash "$KPM_ARTIFACT_VERIFIER" "$unpatched" "$patched" "$kpimg" "$kptools"

empty_artifact="$verify_tmp/empty"
: > "$empty_artifact"
for empty_index in 0 1 2 3; do
  artifact_args=("$unpatched" "$patched" "$kpimg" "$kptools")
  artifact_args[$empty_index]="$empty_artifact"
  expect_artifact_failure \
    "empty artifact index $empty_index" \
    "missing or empty file" \
    bash "$KPM_ARTIFACT_VERIFIER" "${artifact_args[@]}"
done

[ -x "$KPM_PROVENANCE_WRITER" ] || {
  echo "missing executable KPM provenance writer: $KPM_PROVENANCE_WRITER" >&2
  exit 1
}
provenance="$verify_tmp/build-provenance.json"
WORKFLOW_COMMIT=1111111111111111111111111111111111111111 \
KERNEL_SOURCE_COMMIT=2222222222222222222222222222222222222222 \
RESUKISU_COMMIT=3ef06b0fcb0960dc9563256fe26a58e892663387 \
RESUKISU_KPM_DONOR=a13d71f699093f0c1da7ba442881eccaa8e4321a \
SUSFS_COMMIT=3c14ad549f826b1f53878ec8c12253efebeed75a \
KERNELPATCH_COMMIT=043c0c3bae68ddc6f2894b4e483d8f54cb85d112 \
KERNELPATCH_VERSION=0.13.3 \
MANAGER_SOURCE_COMMIT=3ef06b0fcb0960dc9563256fe26a58e892663387 \
KPM_KPIMG_PATH="$kpimg" \
KPM_KPTOOLS_PATH="$kptools" \
KPM_UNPATCHED_IMAGE="$unpatched" \
KPM_PATCHED_IMAGE="$patched" \
KPM_INPUTS_JSON='{"android_version":"android12","kernel_version":"5.10","sub_level":"236","use_kpm":true}' \
  bash "$KPM_PROVENANCE_WRITER" "$provenance"

python3 - "$provenance" \
  "$(sha256sum "$kpimg" | cut -d' ' -f1)" \
  "$(sha256sum "$kptools" | cut -d' ' -f1)" \
  "$(sha256sum "$unpatched" | cut -d' ' -f1)" \
  "$(sha256sum "$patched" | cut -d' ' -f1)" <<'PY'
import json
import sys

path, kpimg_hash, kptools_hash, unpatched_hash, patched_hash = sys.argv[1:]
with open(path, encoding="utf-8") as stream:
    provenance = json.load(stream)

assert provenance["workflow_commit"] == "1111111111111111111111111111111111111111"
assert provenance["kernel_source_commit"] == "2222222222222222222222222222222222222222"
assert provenance["resukisu_commit"] == "3ef06b0fcb0960dc9563256fe26a58e892663387"
assert provenance["resukisu_kpm_donor"] == "a13d71f699093f0c1da7ba442881eccaa8e4321a"
assert provenance["susfs_commit"] == "3c14ad549f826b1f53878ec8c12253efebeed75a"
assert provenance["kernelpatch_commit"] == "043c0c3bae68ddc6f2894b4e483d8f54cb85d112"
assert provenance["kernelpatch_version"] == "0.13.3"
assert provenance["manager_source_commit"] == "3ef06b0fcb0960dc9563256fe26a58e892663387"
assert provenance["kpimg_sha256"] == kpimg_hash
assert provenance["kptools_sha256"] == kptools_hash
assert provenance["unpatched_image_sha256"] == unpatched_hash
assert provenance["patched_image_sha256"] == patched_hash
assert provenance["inputs"]["android_version"] == "android12"
assert provenance["inputs"]["use_kpm"] is True
PY

env -i PATH="$PATH" bash --noprofile --norc -s -- "$PINS" <<'BASH'
set -euo pipefail
pins=$1
before=
after=
before=$(compgen -A variable | LC_ALL=C sort)
source "$pins"
after=$(comm -13 <(printf '%s\n' "$before") <(compgen -A variable | LC_ALL=C sort))

expected_names='KERNELPATCH_COMMIT
KERNELPATCH_VERSION
RESUKISU_CURRENT
RESUKISU_KPM_DONOR
SUKISU_BRIDGE_DONOR'
[ "$after" = "$expected_names" ] || {
  echo "kpm.config declares unexpected variables: $after" >&2
  exit 1
}

[ "$RESUKISU_CURRENT" = 3ef06b0fcb0960dc9563256fe26a58e892663387 ]
[ "$RESUKISU_KPM_DONOR" = a13d71f699093f0c1da7ba442881eccaa8e4321a ]
[ "$KERNELPATCH_VERSION" = 0.13.3 ]
[ "$KERNELPATCH_COMMIT" = 043c0c3bae68ddc6f2894b4e483d8f54cb85d112 ]
[ "$SUKISU_BRIDGE_DONOR" = 762e6fb446f58020691b83509873268f6af634f2 ]
BASH

echo "KPM workflow contract tests passed"
