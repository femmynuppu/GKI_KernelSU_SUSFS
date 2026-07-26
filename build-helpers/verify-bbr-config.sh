#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=${1:?usage: verify-bbr-config.sh <kernel-config>}

for expected in \
  'CONFIG_TCP_CONG_ADVANCED=y' \
  'CONFIG_TCP_CONG_BBR=y' \
  'CONFIG_DEFAULT_BBR=y' \
  'CONFIG_DEFAULT_TCP_CONG="bbr"' \
  'CONFIG_NET_SCH_FQ=y'
do
  grep -qxF "$expected" "$CONFIG_FILE" || {
    echo "BBR verification failed: missing $expected" >&2
    exit 1
  }
done

echo "BBR final config verified"
