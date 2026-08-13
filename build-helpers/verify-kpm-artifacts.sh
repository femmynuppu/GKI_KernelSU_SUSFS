#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: verify-kpm-artifacts.sh <unpatched-image> <patched-image> <kpimg> <kptools>" >&2
  exit 2
}

[ "$#" -eq 4 ] || usage

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
UNPATCHED=$1
PATCHED=$2
KPIMG=$3
KPTOOLS=$4

# shellcheck source=../config/kpm.config
source "$ROOT/config/kpm.config"
: "${KPM_UNPATCHED_SHA256:?KPM_UNPATCHED_SHA256 is required}"
: "${EXPECTED_KERNEL_RELEASE:?EXPECTED_KERNEL_RELEASE is required}"
: "${EXPECTED_BUILD_TIMESTAMP:?EXPECTED_BUILD_TIMESTAMP is required}"

for artifact in "$UNPATCHED" "$PATCHED" "$KPIMG" "$KPTOOLS"; do
  [ -s "$artifact" ] || {
    echo "KPM artifact verification failed: missing or empty file: $artifact" >&2
    exit 1
  }
done
[ -x "$KPTOOLS" ] || {
  echo "KPM artifact verification failed: kptools is not executable: $KPTOOLS" >&2
  exit 1
}

unpatched_sha256=$(sha256sum "$UNPATCHED" | cut -d' ' -f1)
patched_sha256=$(sha256sum "$PATCHED" | cut -d' ' -f1)
[ "$unpatched_sha256" = "$KPM_UNPATCHED_SHA256" ] || {
  echo "KPM artifact verification failed: unpatched image hash changed" >&2
  exit 1
}
[ "$unpatched_sha256" != "$patched_sha256" ] || {
  echo "KPM artifact verification failed: patched image is byte-identical to unpatched image" >&2
  exit 1
}

inspection=$("$KPTOOLS" -l -i "$PATCHED" 2>&1) || {
  echo "KPM artifact verification failed: kptools inspection failed" >&2
  exit 1
}
IFS=. read -r kp_major kp_minor kp_patch <<< "$KERNELPATCH_VERSION"
printf -v expected_kpimg_version '%x' "$(((10#$kp_major << 16) | (10#$kp_minor << 8) | 10#$kp_patch))"
grep -Fxq "patched=true" <<< "$inspection" || {
  echo "KPM artifact verification failed: kptools did not mark the image patched" >&2
  exit 1
}
grep -Fxq "version=0x$expected_kpimg_version" <<< "$inspection" || {
  echo "KPM artifact verification failed: expected KernelPatch $KERNELPATCH_VERSION metadata" >&2
  exit 1
}
kpimg_version=$("$KPTOOLS" -v -k "$KPIMG" 2>&1) || {
  echo "KPM artifact verification failed: kpimg version inspection failed" >&2
  exit 1
}
[ "$kpimg_version" = "$expected_kpimg_version" ] || {
  echo "KPM artifact verification failed: kpimg is not KernelPatch $KERNELPATCH_VERSION" >&2
  exit 1
}

mapfile -t banners < <(grep '^banner=' <<< "$inspection")
[ "${#banners[@]}" -eq 1 ] || {
  echo "KPM artifact verification failed: expected exactly one parsed kernel banner" >&2
  exit 1
}
case "${banners[0]}" in
  "banner=Linux version $EXPECTED_KERNEL_RELEASE "*"$EXPECTED_BUILD_TIMESTAMP"*) ;;
  *)
    echo "KPM artifact verification failed: Linux release or build timestamp mismatch" >&2
    exit 1
    ;;
esac

echo "KPM artifacts verified: unpatched=$unpatched_sha256 patched=$patched_sha256"
