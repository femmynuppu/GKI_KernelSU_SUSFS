#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: apply-resukisu-kpm.sh <KernelSU-dir> [patch]" >&2
  exit 2
}

[ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
KSU_DIR=$1
PATCH=${2:-"$ROOT/patches/resukisu-kpm-current.patch"}

[ -d "$KSU_DIR/.git" ] || {
  echo "ReSukiSU target is not a git checkout: $KSU_DIR" >&2
  exit 1
}
[ -f "$PATCH" ] || {
  echo "KPM source patch not found: $PATCH" >&2
  exit 1
}

# shellcheck source=../config/kpm.config
source "$ROOT/config/kpm.config"
actual_head=$(git -C "$KSU_DIR" rev-parse HEAD)
[ "$actual_head" = "$RESUKISU_CURRENT" ] || {
  echo "ReSukiSU revision mismatch in $KSU_DIR: expected $RESUKISU_CURRENT, got $actual_head" >&2
  exit 1
}

if grep -Eq '^(GIT binary patch|diff --git a/manager/app/src/main/assets/(kpimg|kptools) )' "$PATCH"; then
  echo "KPM source patch contains forbidden Manager binary assets: $PATCH" >&2
  exit 1
fi

git -C "$KSU_DIR" apply --check "$PATCH" || {
  echo "KPM source patch does not apply cleanly to $KSU_DIR at $actual_head: $PATCH" >&2
  exit 1
}
git -C "$KSU_DIR" apply "$PATCH"

require_literal() {
  local path=$1
  local symbol=$2
  local file="$KSU_DIR/$path"
  [ -f "$file" ] || {
    echo "KPM source requirement file is missing: $path" >&2
    exit 1
  }
  grep -Fq "$symbol" "$file" || {
    echo "KPM source requirement '$symbol' is missing from $path" >&2
    exit 1
  }
}

require_literal kernel/Kconfig "config KPM"
require_literal kernel/Kbuild "kpm/kpm.o"
require_literal kernel/kpm/kpm.c "sukisu_handle_kpm"
require_literal kernel/kpm/kpm.c "sukisu_load_module_path"
require_literal kernel/kpm/kpm.c "sukisu_unload_module"
require_literal kernel/kpm/kpm.c "sukisu_kpm_num"
require_literal kernel/kpm/kpm.c "sukisu_kpm_list"
require_literal kernel/kpm/kpm.c "sukisu_kpm_info"
require_literal kernel/kpm/kpm.c "sukisu_kpm_control"
require_literal kernel/kpm/kpm.c "sukisu_kpm_version"
require_literal uapi/supercall.h "SUKISU_KPM_LOAD"
require_literal uapi/supercall.h "SUKISU_KPM_VERSION"
require_literal uapi/supercall.h "KSU_IOCTL_KPM"
require_literal kernel/supercall/dispatch.c "do_kpm"
require_literal userspace/ksud/src/android/mod.rs "mod kpm;"
require_literal userspace/ksud/src/android/kpm.rs "pub fn load_module"
require_literal userspace/ksud/src/android/kpm.rs "pub fn unload_module"
require_literal userspace/ksud/src/android/kpm.rs "pub fn list"
require_literal userspace/ksud/src/android/kpm.rs "pub fn info"
require_literal userspace/ksud/src/android/kpm.rs "pub fn control"
require_literal userspace/ksud/src/android/kpm.rs "pub fn num"
require_literal userspace/ksud/src/android/kpm.rs "pub fn version"
require_literal userspace/ksud/src/android/cli.rs "Commands::Kpm"
require_literal userspace/ksud/src/android/init_event.rs "kpm::booted_load()"
require_literal manager/app/src/main/cpp/jni.c "isKPMEnabled"
require_literal manager/app/src/main/cpp/ksu.c "is_KPM_enable"
require_literal manager/app/src/main/java/com/resukisu/resukisu/Natives.kt "external fun isKPMEnabled"
require_literal manager/app/src/main/java/com/resukisu/resukisu/ui/screen/main/KpmPage.kt "fun KpmPage"
require_literal manager/app/src/main/java/com/resukisu/resukisu/ui/viewmodel/KpmViewModel.kt "class KpmViewModel"
require_literal manager/app/src/main/java/com/resukisu/resukisu/ui/screen/BottomBarDestination.kt "KpmPage(bottomPadding)"
require_literal manager/app/src/main/java/com/resukisu/resukisu/ui/navigation/Routes.kt "data object Kpm : Route"
require_literal manager/app/src/main/java/com/resukisu/resukisu/ui/util/KsuCli.kt "fun getKpmVersion"
require_literal manager/app/src/main/java/com/resukisu/resukisu/ui/webui/WebViewInterface.kt "fun listAllKpm"
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
  require_literal manager/app/src/main/res/values/strings.xml "<string name=\"$resource\""
done

require_literal kernel/kpm/kpm.c "if (!ksu_access_ok(arg1, len))"
require_literal kernel/kpm/kpm.c "len <= 0 || len > sizeof(buf)"
if grep -Fq "if (!ksu_access_ok(arg2, len))" "$KSU_DIR/kernel/kpm/kpm.c"; then
  echo "KPM LIST validates its length argument instead of its output pointer" >&2
  exit 1
fi

for asset in \
  manager/app/src/main/assets/kpimg \
  manager/app/src/main/assets/kptools; do
  [ ! -e "$KSU_DIR/$asset" ] || {
    echo "forbidden legacy Manager binary asset was restored: $asset" >&2
    exit 1
  }
done

echo "Applied and verified ReSukiSU KPM source port at $actual_head"
