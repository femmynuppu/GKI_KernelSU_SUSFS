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
filechk_kernel.release = \
	echo "$(KERNELVERSION)$$(false)"
kernelrelease:
	@echo "$(KERNELVERSION)$$(false)"
generated:
	@$(filechk_kernel.release)
EOF
release='5.10.198-android12-9-00085-g226a9632f13d-ab11136126'
bash "$ROOT/build-helpers/spoof-kernel-version.sh" "$TMP" "$release"
[ "$(make -s -C "$TMP" kernelrelease)" = "$release" ]
[ "$(make -s -C "$TMP" generated)" = "$release" ]
grep -qx 'SUBLEVEL = 236' "$TMP/Makefile"
before=$(sha256sum "$TMP/Makefile")
for invalid in '5.15.236-invalid' '5.10.236-$(id)'; do
  if bash "$ROOT/build-helpers/spoof-kernel-version.sh" "$TMP" "$invalid"; then
    echo "Invalid release accepted: $invalid" >&2
    exit 1
  fi
  [ "$before" = "$(sha256sum "$TMP/Makefile")" ]
done
echo 'Exact emitted release, preserved source version and invalid-input checks passed'
