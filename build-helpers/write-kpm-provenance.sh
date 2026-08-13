#!/usr/bin/env bash
set -euo pipefail

OUTPUT=${1:?usage: write-kpm-provenance.sh <output-json>}

for variable in \
  WORKFLOW_COMMIT \
  KERNEL_SOURCE_COMMIT \
  RESUKISU_COMMIT \
  RESUKISU_KPM_DONOR \
  SUSFS_COMMIT \
  KERNELPATCH_COMMIT \
  KERNELPATCH_VERSION \
  MANAGER_SOURCE_COMMIT \
  KPM_KPIMG_PATH \
  KPM_KPTOOLS_PATH \
  KPM_UNPATCHED_IMAGE \
  KPM_PATCHED_IMAGE \
  KPM_INPUTS_JSON
do
  [ -n "${!variable:-}" ] || {
    echo "KPM provenance failed: missing $variable" >&2
    exit 1
  }
done

for artifact in \
  "$KPM_KPIMG_PATH" \
  "$KPM_KPTOOLS_PATH" \
  "$KPM_UNPATCHED_IMAGE" \
  "$KPM_PATCHED_IMAGE"
do
  [ -s "$artifact" ] || {
    echo "KPM provenance failed: missing or empty artifact: $artifact" >&2
    exit 1
  }
done


kpimg_sha256=$(sha256sum "$KPM_KPIMG_PATH" | cut -d' ' -f1)
kptools_sha256=$(sha256sum "$KPM_KPTOOLS_PATH" | cut -d' ' -f1)
unpatched_image_sha256=$(sha256sum "$KPM_UNPATCHED_IMAGE" | cut -d' ' -f1)
patched_image_sha256=$(sha256sum "$KPM_PATCHED_IMAGE" | cut -d' ' -f1)

mkdir -p "$(dirname "$OUTPUT")"
temporary="$OUTPUT.tmp"
trap 'rm -f "$temporary"' EXIT
if command -v jq >/dev/null 2>&1; then
  jq -e . >/dev/null <<< "$KPM_INPUTS_JSON" || {
    echo "KPM provenance failed: KPM_INPUTS_JSON is not valid JSON" >&2
    exit 1
  }
  jq -n \
    --arg workflow_commit "$WORKFLOW_COMMIT" \
    --arg kernel_source_commit "$KERNEL_SOURCE_COMMIT" \
    --arg resukisu_commit "$RESUKISU_COMMIT" \
    --arg resukisu_kpm_donor "$RESUKISU_KPM_DONOR" \
    --arg susfs_commit "$SUSFS_COMMIT" \
    --arg kernelpatch_commit "$KERNELPATCH_COMMIT" \
    --arg kernelpatch_version "$KERNELPATCH_VERSION" \
    --arg kpimg_sha256 "$kpimg_sha256" \
    --arg kptools_sha256 "$kptools_sha256" \
    --arg unpatched_image_sha256 "$unpatched_image_sha256" \
    --arg patched_image_sha256 "$patched_image_sha256" \
    --arg manager_source_commit "$MANAGER_SOURCE_COMMIT" \
    --argjson inputs "$KPM_INPUTS_JSON" \
    '{
      workflow_commit: $workflow_commit,
      kernel_source_commit: $kernel_source_commit,
      resukisu_commit: $resukisu_commit,
      resukisu_kpm_donor: $resukisu_kpm_donor,
      susfs_commit: $susfs_commit,
      kernelpatch_commit: $kernelpatch_commit,
      kernelpatch_version: $kernelpatch_version,
      kpimg_sha256: $kpimg_sha256,
      kptools_sha256: $kptools_sha256,
      unpatched_image_sha256: $unpatched_image_sha256,
      patched_image_sha256: $patched_image_sha256,
      manager_source_commit: $manager_source_commit,
      inputs: $inputs
    }' > "$temporary"
else
  python3 - "$temporary" \
    "$kpimg_sha256" "$kptools_sha256" \
    "$unpatched_image_sha256" "$patched_image_sha256" <<'PY'
import json
import os
import sys

output, kpimg_hash, kptools_hash, unpatched_hash, patched_hash = sys.argv[1:]
try:
    inputs = json.loads(os.environ["KPM_INPUTS_JSON"])
except json.JSONDecodeError as error:
    raise SystemExit(f"KPM provenance failed: KPM_INPUTS_JSON is not valid JSON: {error}")

data = {
    "workflow_commit": os.environ["WORKFLOW_COMMIT"],
    "kernel_source_commit": os.environ["KERNEL_SOURCE_COMMIT"],
    "resukisu_commit": os.environ["RESUKISU_COMMIT"],
    "resukisu_kpm_donor": os.environ["RESUKISU_KPM_DONOR"],
    "susfs_commit": os.environ["SUSFS_COMMIT"],
    "kernelpatch_commit": os.environ["KERNELPATCH_COMMIT"],
    "kernelpatch_version": os.environ["KERNELPATCH_VERSION"],
    "kpimg_sha256": kpimg_hash,
    "kptools_sha256": kptools_hash,
    "unpatched_image_sha256": unpatched_hash,
    "patched_image_sha256": patched_hash,
    "manager_source_commit": os.environ["MANAGER_SOURCE_COMMIT"],
    "inputs": inputs,
}
with open(output, "w", encoding="utf-8", newline="\n") as stream:
    json.dump(data, stream, indent=2)
    stream.write("\n")
PY
fi
mv "$temporary" "$OUTPUT"
trap - EXIT
