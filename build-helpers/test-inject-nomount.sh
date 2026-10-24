#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/kernel/fs" "$TMP/incomplete"
printf 'menu "Filesystems"\nendmenu\n' > "$TMP/kernel/fs/Kconfig"
printf '# Filesystems\n' > "$TMP/kernel/fs/Makefile"
printf 'untouched d_path source\n' > "$TMP/kernel/fs/d_path.c"
(
  cd "$TMP/kernel"
  bash "$ROOT/build-helpers/inject-nomount.sh" "$ROOT/src/nomount"
  bash "$ROOT/build-helpers/inject-nomount.sh" "$ROOT/src/nomount"
  for file in nomount.c nomount.h Kconfig Makefile; do
    cmp "$ROOT/src/nomount/$file" "fs/nomount/$file"
  done
  [ "$(grep -cF 'source "fs/nomount/Kconfig"' fs/Kconfig)" = 1 ]
  [ "$(grep -cF 'obj-$(CONFIG_NOMOUNT) += nomount/' fs/Makefile)" = 1 ]
  grep -qx 'untouched d_path source' fs/d_path.c
  before=$(sha256sum fs/Kconfig fs/Makefile fs/nomount/*)
  if bash "$ROOT/build-helpers/inject-nomount.sh" "$TMP/incomplete"; then
    echo 'Incomplete source bundle was accepted' >&2
    exit 1
  fi
  [ "$before" = "$(sha256sum fs/Kconfig fs/Makefile fs/nomount/*)" ]
)
echo 'NoMount source identity, idempotence and incomplete-input checks passed'
