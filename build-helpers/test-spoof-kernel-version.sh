#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/Makefile" <<'EOF'
VERSION = 5
PATCHLEVEL = 10
SUBLEVEL = 236
EXTRAVERSION =
EOF

bash "$ROOT/build-helpers/spoof-kernel-version.sh" \
  "$TMP" \
  "5.10.198-android12-9-00085-g226a9632f13d-ab11136126"

actual=$(sed -n 's/^SUBLEVEL = //p' "$TMP/Makefile")
[ "$actual" = "198" ] || {
  echo "expected SUBLEVEL 198, got $actual" >&2
  exit 1
}

echo "kernel version spoof contract passed"
