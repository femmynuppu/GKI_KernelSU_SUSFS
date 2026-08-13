#!/usr/bin/env bash
set -euo pipefail

KERNEL_DIR=${1:?usage: spoof-kernel-version.sh <kernel-dir> <release>}
REQUESTED_RELEASE=${2:?usage: spoof-kernel-version.sh <kernel-dir> <release>}
MAKEFILE="$KERNEL_DIR/Makefile"

[ -f "$MAKEFILE" ] || {
  echo "kernel version spoof failed: missing $MAKEFILE" >&2
  exit 1
}

if [[ ! "$REQUESTED_RELEASE" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
  echo "kernel version spoof failed: release has no numeric prefix: $REQUESTED_RELEASE" >&2
  exit 1
fi

requested_major=${BASH_REMATCH[1]}
requested_minor=${BASH_REMATCH[2]}
requested_sublevel=${BASH_REMATCH[3]}
source_major=$(awk '$1 == "VERSION" && $2 == "=" { print $3; exit }' "$MAKEFILE")
source_minor=$(awk '$1 == "PATCHLEVEL" && $2 == "=" { print $3; exit }' "$MAKEFILE")

if [ "$requested_major.$requested_minor" != "$source_major.$source_minor" ]; then
  echo "kernel version spoof failed: requested $requested_major.$requested_minor does not match source $source_major.$source_minor" >&2
  exit 1
fi

sed -i -E "s/^(SUBLEVEL[[:space:]]*=[[:space:]]*).*/\1${requested_sublevel}/" "$MAKEFILE"
grep -qxE "SUBLEVEL[[:space:]]*=[[:space:]]*${requested_sublevel}" "$MAKEFILE" || {
  echo "kernel version spoof failed: SUBLEVEL was not updated to $requested_sublevel" >&2
  exit 1
}
