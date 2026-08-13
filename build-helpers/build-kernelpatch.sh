#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: build-kernelpatch.sh <unpatched-image> <output-image> <work-dir>" >&2
  exit 2
}

[ "$#" -eq 3 ] || usage

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
INPUT=$1
OUTPUT=$2
WORK_DIR=$3

# shellcheck source=../config/kpm.config
source "$ROOT/config/kpm.config"

[ -f "$INPUT" ] || {
  echo "unpatched kernel image not found: $INPUT" >&2
  exit 1
}

input_real=$(realpath "$INPUT")
output_real=$(realpath -m "$OUTPUT")
[ "$input_real" != "$output_real" ] || {
  echo "input and output kernel image paths must differ" >&2
  exit 1
}

KP_DIR=$(realpath -m "$WORK_DIR/KernelPatch")
for image_path in "$input_real" "$output_real"; do
  case "$image_path" in
    "$KP_DIR"|"$KP_DIR"/*)
      echo "kernel image path must not be inside disposable KernelPatch clone: $image_path" >&2
      exit 1
      ;;
  esac
done
rm -rf "$KP_DIR"
git clone --filter=blob:none --no-checkout https://github.com/bmax121/KernelPatch.git "$KP_DIR"
git -C "$KP_DIR" checkout "$KERNELPATCH_COMMIT"

actual_head=$(git -C "$KP_DIR" rev-parse HEAD)
[ "$actual_head" = "$KERNELPATCH_COMMIT" ] || {
  echo "KernelPatch revision mismatch: expected $KERNELPATCH_COMMIT, got $actual_head" >&2
  exit 1
}

BRIDGE="$ROOT/patches/kernelpatch-0.13.3-resukisu.patch"
git -C "$KP_DIR" apply --check "$BRIDGE"
git -C "$KP_DIR" apply "$BRIDGE"

: "${TARGET_COMPILE:?TARGET_COMPILE must be the aarch64-none-elf tool prefix}"
(
  cd "$KP_DIR/kernel"
  export ANDROID=1
  make hdr kpimg
)

cmake -S "$KP_DIR/tools" -B "$KP_DIR/tools/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$KP_DIR/tools/build"

KPIMG="$KP_DIR/kernel/kpimg"
KPTOOLS="$KP_DIR/tools/build/kptools"
[ -s "$KPIMG" ] || {
  echo "KernelPatch kpimg was not built: $KPIMG" >&2
  exit 1
}
[ -x "$KPTOOLS" ] || {
  echo "KernelPatch kptools was not built: $KPTOOLS" >&2
  exit 1
}

input_sha256=$(sha256sum "$INPUT" | cut -d' ' -f1)
mkdir -p "$(dirname "$OUTPUT")"
cp "$INPUT" "$OUTPUT"
"$KPTOOLS" -p -i "$OUTPUT" -k "$KPIMG" -s "${KPM_SUPERKEY:?KPM_SUPERKEY is required}" -o "$OUTPUT.patched"
mv "$OUTPUT.patched" "$OUTPUT"
"$KPTOOLS" -l -i "$OUTPUT" >/dev/null
post_patch_input_sha256=$(sha256sum "$INPUT" | cut -d' ' -f1)
[ "$post_patch_input_sha256" = "$input_sha256" ] || {
  echo "unpatched input image changed during KernelPatch build" >&2
  exit 1
}

if [ -n "${GITHUB_ENV:-}" ]; then
  {
    echo "KERNELPATCH_RESOLVED_COMMIT=$actual_head"
    echo "KERNELPATCH_KPIMG=$KPIMG"
    echo "KERNELPATCH_KPTOOLS=$KPTOOLS"
    echo "KPM_UNPATCHED_SHA256=$input_sha256"
  } >> "$GITHUB_ENV"
fi
