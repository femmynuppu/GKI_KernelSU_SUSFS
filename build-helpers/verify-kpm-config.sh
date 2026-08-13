#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONFIG_FILE=${1:?usage: verify-kpm-config.sh <kernel-config>}

[ -f "$CONFIG_FILE" ] || {
  echo "KPM config verification failed: file not found: $CONFIG_FILE" >&2
  exit 1
}

missing=()
for expected in \
  'CONFIG_KSU=y' \
  'CONFIG_KSU_SUSFS=y' \
  'CONFIG_KSU_SUSFS_SUS_PATH=y' \
  'CONFIG_KSU_SUSFS_SUS_MOUNT=y' \
  'CONFIG_KSU_SUSFS_SUS_KSTAT=y' \
  'CONFIG_KSU_SUSFS_SPOOF_UNAME=y' \
  'CONFIG_KSU_SUSFS_ENABLE_LOG=y' \
  'CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y' \
  'CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y' \
  'CONFIG_KSU_SUSFS_OPEN_REDIRECT=y' \
  'CONFIG_KSU_SUSFS_SUS_MAP=y' \
  'CONFIG_KPM=y' \
  'CONFIG_KALLSYMS=y' \
  'CONFIG_KALLSYMS_ALL=y' \
  'CONFIG_NOMOUNT=y' \
  'CONFIG_BBG=y' \
  'CONFIG_ZRAM=y' \
  'CONFIG_ZRAM_DEF_COMP_LZ4KD=y' \
  'CONFIG_CRYPTO_LZ4K=y' \
  'CONFIG_CRYPTO_LZ4KD=y'
do
  grep -qxF "$expected" "$CONFIG_FILE" || missing+=("$expected")
done

if [ "${#missing[@]}" -ne 0 ]; then
  printf 'KPM config verification failed: missing %s\n' "${missing[@]}" >&2
  exit 1
fi

bash "$ROOT/build-helpers/verify-bbr-config.sh" "$CONFIG_FILE"
echo "KPM final config verified"
