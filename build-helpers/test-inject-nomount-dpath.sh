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

case "${1:-5.x}" in
  5.x)
    cat > "$TMP/kernel/fs/d_path.c" <<'EOF'
struct path { int unused; };
#define unlikely(value) (value)

char *d_path(const struct path *path, char *buf, int buflen)
{
	char *res = buf + buflen;
	struct path root;
	int error;

	/*
	 * We have various synthetic filesystems that never get mounted.
	 */
	(void)path;
	(void)root;
	(void)error;
	return res;
}
EOF
    ;;
  6.x)
    cat > "$TMP/kernel/fs/d_path.c" <<'EOF'
struct path { int unused; };
#define unlikely(value) (value)
#define DECLARE_BUFFER(name, buffer, length) char *name = (buffer) + (length)

char *d_path(const struct path *path, char *buf, int buflen)
{
	DECLARE_BUFFER(b, buf, buflen);
	struct path root;

	/*
	 * We have various synthetic filesystems that never get mounted.
	 */
	(void)path;
	(void)root;
	return b;
}
EOF
    ;;
  *)
    echo "usage: $0 [5.x|6.x]" >&2
    exit 2
    ;;
esac

(
  cd "$TMP/kernel"
  bash "$SCRIPT_DIR/inject-nomount.sh" "$TMP/source" >/dev/null 2>&1 || true
)

grep -q 'nm_path = nomount_handle_dpath(path, buf, buflen);' "$TMP/kernel/fs/d_path.c"
cc -std=gnu89 -DCONFIG_NOMOUNT -Wdeclaration-after-statement -Werror \
  -fsyntax-only "$TMP/kernel/fs/d_path.c"
