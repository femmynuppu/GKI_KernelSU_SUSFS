#!/usr/bin/env bash
# Fetch only the reviewed commit; fail rather than falling back to a branch tip.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
COMPONENT=${1:?component required}
DEST=${2:?destination required}
metadata=$(python3 - "$ROOT/config/upstream-lock.json" "$COMPONENT" <<'PY'
import json, re, sys
entry = json.load(open(sys.argv[1]))[sys.argv[2]]
assert re.fullmatch(r'[0-9a-f]{40}', entry['commit'])
assert entry['url'].startswith(('https://github.com/', 'https://gitlab.com/'))
print(entry['url'])
print(entry['commit'])
PY
)
mapfile -t fields <<< "$metadata"
[ "${#fields[@]}" = 2 ]
git init "$DEST"
git -C "$DEST" remote add origin "${fields[0]}"
git -C "$DEST" fetch --depth 1 origin "${fields[1]}"
git -C "$DEST" checkout --detach FETCH_HEAD
[ "$(git -C "$DEST" rev-parse HEAD)" = "${fields[1]}" ]
echo "$COMPONENT checked out at ${fields[1]}"
