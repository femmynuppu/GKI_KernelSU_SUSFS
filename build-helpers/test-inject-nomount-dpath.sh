#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/kernel/fs" "$TMP/source"
: > "$TMP/kernel/fs/Kconfig"
: > "$TMP/kernel/fs/Makefile"
: > "$TMP/source/nomount.c"
: > "$TMP/source/nomount.h"

cat > "$TMP/kernel/fs/Kconfig" <<'EOF'
menu "File systems"
endmenu
EOF

cat > "$TMP/kernel/fs/Makefile" <<'EOF'
# fs Makefile
obj-y += open.o
EOF

# Seed legacy v1.1.0 files to ensure cleanup contract works
touch "$TMP/kernel/fs/nomount.c" "$TMP/kernel/fs/nomount.h"
echo 'config NOMOUNT' >> "$TMP/kernel/fs/Kconfig"
echo 'obj-$(CONFIG_NOMOUNT) += nomount.o' >> "$TMP/kernel/fs/Makefile"

# Create mock v2.1 source files
echo '/* nomount c */' > "$TMP/source/nomount.c"
echo '/* nomount h */' > "$TMP/source/nomount.h"
echo 'config NOMOUNT' > "$TMP/source/Kconfig"
echo 'obj-$(CONFIG_NOMOUNT) += nomount.o' > "$TMP/source/Makefile"

(
  cd "$TMP/kernel"
  bash "$SCRIPT_DIR/inject-nomount.sh" "$TMP/source" >/dev/null
  # Test idempotency on second run
  bash "$SCRIPT_DIR/inject-nomount.sh" "$TMP/source" >/dev/null
)

# Verify v2.1 directory and files
[ -f "$TMP/kernel/fs/nomount/nomount.c" ] || { echo "FAIL: fs/nomount/nomount.c missing"; exit 1; }
[ -f "$TMP/kernel/fs/nomount/nomount.h" ] || { echo "FAIL: fs/nomount/nomount.h missing"; exit 1; }
[ -f "$TMP/kernel/fs/nomount/Kconfig" ] || { echo "FAIL: fs/nomount/Kconfig missing"; exit 1; }
[ -f "$TMP/kernel/fs/nomount/Makefile" ] || { echo "FAIL: fs/nomount/Makefile missing"; exit 1; }

# Verify legacy cleanup
[ ! -f "$TMP/kernel/fs/nomount.c" ] || { echo "FAIL: legacy fs/nomount.c was not cleaned up"; exit 1; }
[ ! -f "$TMP/kernel/fs/nomount.h" ] || { echo "FAIL: legacy fs/nomount.h was not cleaned up"; exit 1; }

# Verify Makefile wiring (idempotent, exactly 1 occurrence)
mk_count=$(grep -c 'obj-\$(CONFIG_NOMOUNT) += nomount/' "$TMP/kernel/fs/Makefile" || true)
[ "$mk_count" -eq 1 ] || { echo "FAIL: fs/Makefile has $mk_count entries, expected 1"; exit 1; }

# Verify Kconfig wiring (idempotent, exactly 1 occurrence)
kc_count=$(grep -c 'source "fs/nomount/Kconfig"' "$TMP/kernel/fs/Kconfig" || true)
[ "$kc_count" -eq 1 ] || { echo "FAIL: fs/Kconfig has $kc_count entries, expected 1"; exit 1; }

echo "NoMount v2.1 integration contract passed"
