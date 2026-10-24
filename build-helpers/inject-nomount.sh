#!/usr/bin/env bash
# Integration of the vendored NoMount v2.2.0 into a GKI kernel tree.
# NoMount v2.x operates via dynamic VFS structure hijacking (i_op, f_op, s_op, d_op)
# and lives self-contained under fs/nomount/, eliminating intrusive kernel patches.
#
# Usage: inject-nomount.sh <SRC_DIR containing Kconfig, Makefile, nomount.c, nomount.h>
# Run from the kernel source root (the dir that contains fs/).
set -euo pipefail

SRC="${1:?usage: inject-nomount.sh <vendored-source-dir>}"

echo "=== NoMount v2.2.0 VFS Integration ==="

# Validate before changing the kernel tree. CI must never silently fetch a
# different upstream revision when the reviewed source bundle is incomplete.
for file in nomount.c nomount.h Kconfig Makefile; do
  [ -s "$SRC/$file" ] || { echo "Missing NoMount source: $SRC/$file" >&2; exit 1; }
done
[ -f fs/Makefile ] && [ -f fs/Kconfig ] || {
  echo "Run this helper from the kernel source root" >&2
  exit 1
}

# 1. Clean up legacy v1.1.0 files if present
rm -f fs/nomount.c fs/nomount.h
if grep -q 'config NOMOUNT' fs/Kconfig; then
  sed -i '/config NOMOUNT/,/help/d' fs/Kconfig 2>/dev/null || true
fi
if grep -q 'obj-$(CONFIG_NOMOUNT) += nomount.o' fs/Makefile; then
  sed -i '/obj-\$(CONFIG_NOMOUNT) += nomount\.o/d' fs/Makefile 2>/dev/null || true
fi

# 2. Setup fs/nomount directory
mkdir -p fs/nomount

echo "  + Copying reviewed NoMount source: $SRC"
for file in nomount.c nomount.h Kconfig Makefile; do
  cp -f "$SRC/$file" fs/nomount/
done

# 3. Add to fs/Makefile (idempotent)
if ! grep -q 'nomount/' fs/Makefile; then
  printf '\nobj-$(CONFIG_NOMOUNT) += nomount/\n' >> fs/Makefile
  echo "  ✓ fs/Makefile updated"
else
  echo "  ✓ fs/Makefile already configured"
fi

# 4. Add to fs/Kconfig (idempotent)
if ! grep -q 'source "fs/nomount/Kconfig"' fs/Kconfig; then
  if grep -q '^endmenu' fs/Kconfig; then
    awk '
      /^endmenu/ { last_match = NR }
      { lines[NR] = $0 }
      END {
        for (i = 1; i <= NR; i++) {
          if (i == last_match) print "source \"fs/nomount/Kconfig\""
          print lines[i]
        }
      }
    ' fs/Kconfig > fs/Kconfig.tmp && mv fs/Kconfig.tmp fs/Kconfig
  else
    printf '\nsource "fs/nomount/Kconfig"\n' >> fs/Kconfig
  fi
  echo "  ✓ fs/Kconfig updated"
else
  echo "  ✓ fs/Kconfig already configured"
fi

echo "=== NoMount v2.2.0 successfully integrated ==="
