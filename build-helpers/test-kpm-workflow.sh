#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CUSTOM="$ROOT/.github/workflows/kernel-custom.yml"
BUILD="$ROOT/.github/workflows/build.yml"
MANAGER="$ROOT/.github/workflows/get-manager.yml"
PINS="$ROOT/config/kpm.config"
VALIDATOR="$ROOT/build-helpers/validate-kpm-recipe.sh"

expect_success() {
  local name=$1
  shift
  local output
  if ! output=$(bash "$VALIDATOR" "$@" 2>&1); then
    echo "$name: expected success, got: $output" >&2
    exit 1
  fi
}

expect_failure() {
  local name=$1
  local expected=$2
  shift 2
  local output status
  set +e
  output=$(bash "$VALIDATOR" "$@" 2>&1)
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    echo "$name: expected failure" >&2
    exit 1
  fi
  if [ "$output" != "$expected" ]; then
    echo "$name: expected '$expected', got '$output'" >&2
    exit 1
  fi
}

expect_success "disabled KPM ignores target tuple" \
  false android99 0.0 arbitrary false true
expect_success "supported KPM recipe" \
  true android12 5.10 236 true false

scope_message="KPM is supported only for android12-5.10.236"
expect_failure "wrong Android version" "$scope_message" \
  true android13 5.10 236 true false
expect_failure "wrong kernel version" "$scope_message" \
  true android12 5.15 236 true false
expect_failure "wrong kernel sublevel" "$scope_message" \
  true android12 5.10 237 true false
expect_failure "NoMount disabled" "KPM recipe requires add_nomount=true" \
  true android12 5.10 236 false false
expect_failure "ZeroMount enabled" "KPM recipe requires add_zeromount=false" \
  true android12 5.10 236 true true
expect_failure "wrong argument count" \
  "Usage: validate-kpm-recipe.sh <use_kpm> <android_version> <kernel_version> <sub_level> <add_nomount> <add_zeromount>" \
  true android12 5.10 236 true

python - "$CUSTOM" "$BUILD" "$MANAGER" <<'PY'
import shlex
import sys

import yaml


def load(path):
    with open(path, encoding="utf-8") as stream:
        return yaml.safe_load(stream)


def on(document):
    if "on" in document:
        return document["on"]
    return document[True]


def assert_false_boolean_input(document, event, path):
    value = on(document)[event]["inputs"]["use_kpm"]
    assert value["required"] is False, f"{path}: use_kpm.required must be false"
    assert value["type"] == "boolean", f"{path}: use_kpm.type must be boolean"
    assert value["default"] is False, f"{path}: use_kpm.default must be false"


custom_path, build_path, manager_path = sys.argv[1:]
custom = load(custom_path)
build = load(build_path)
manager = load(manager_path)

assert_false_boolean_input(custom, "workflow_dispatch", custom_path)
assert_false_boolean_input(build, "workflow_call", build_path)
assert_false_boolean_input(manager, "workflow_call", manager_path)

jobs = custom["jobs"]
expression = "${{ inputs.use_kpm }}"
assert jobs["build-custom-kernel"]["with"]["use_kpm"] == expression
manager_with = jobs["get-ksu-manager"]["with"]
assert manager_with["use_kpm"] == expression
assert manager_with["resukisu_commit"] == "3ef06b0fcb0960dc9563256fe26a58e892663387"

manager_commit = on(manager)["workflow_call"]["inputs"]["resukisu_commit"]
assert manager_commit["required"] is False
assert manager_commit["type"] == "string"

steps = build["jobs"]["build-kernel"]["steps"]
checkout_index = next(
    (
        index
        for index, step in enumerate(steps)
        if str(step.get("uses", "")).startswith("actions/checkout@")
    ),
    None,
)
assert checkout_index is not None, "build-kernel must check out the repository"

expected_command = [
    "bash",
    "build-helpers/validate-kpm-recipe.sh",
    "${{ inputs.use_kpm }}",
    "${{ inputs.android_version }}",
    "${{ inputs.kernel_version }}",
    "${{ inputs.sub_level }}",
    "${{ inputs.add_nomount }}",
    "${{ inputs.add_zeromount }}",
]
validator_index = None
validator_command = None
for index, step in enumerate(steps):
    for line in str(step.get("run", "")).splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if "build-helpers/validate-kpm-recipe.sh" not in line:
            continue
        command = shlex.split(line)
        if command[:2] == expected_command[:2]:
            assert validator_index is None, "build-kernel must invoke the KPM validator exactly once"
            validator_index = index
            validator_command = command

assert validator_index is not None, "build-kernel must invoke the KPM validator"
assert validator_index == checkout_index + 1, "KPM validator must run immediately after checkout"
assert validator_command == expected_command, "KPM validator must receive exactly the six recipe inputs"
cleanup_index = next(
    (
        index
        for index, step in enumerate(steps)
        if str(step.get("uses", "")).startswith("endersonmenezes/free-disk-space@")
    ),
    None,
)
setup_index = next(
    (
        index
        for index, step in enumerate(steps)
        if step.get("name") == "初始化构建环境"
    ),
    None,
)
assert cleanup_index is not None, "build-kernel must retain the disk cleanup step"
assert setup_index is not None, "build-kernel must retain the environment setup step"
assert validator_index < cleanup_index, "KPM validator must run before disk cleanup"
assert validator_index < setup_index, "KPM validator must run before environment setup"
PY

env -i PATH="$PATH" bash --noprofile --norc -s -- "$PINS" <<'BASH'
set -euo pipefail
pins=$1
before=
after=
before=$(compgen -A variable | LC_ALL=C sort)
source "$pins"
after=$(comm -13 <(printf '%s\n' "$before") <(compgen -A variable | LC_ALL=C sort))

expected_names='KERNELPATCH_COMMIT
KERNELPATCH_VERSION
RESUKISU_CURRENT
RESUKISU_KPM_DONOR
SUKISU_BRIDGE_DONOR'
[ "$after" = "$expected_names" ] || {
  echo "kpm.config declares unexpected variables: $after" >&2
  exit 1
}

[ "$RESUKISU_CURRENT" = 3ef06b0fcb0960dc9563256fe26a58e892663387 ]
[ "$RESUKISU_KPM_DONOR" = a13d71f699093f0c1da7ba442881eccaa8e4321a ]
[ "$KERNELPATCH_VERSION" = 0.13.3 ]
[ "$KERNELPATCH_COMMIT" = 043c0c3bae68ddc6f2894b4e483d8f54cb85d112 ]
[ "$SUKISU_BRIDGE_DONOR" = 762e6fb446f58020691b83509873268f6af634f2 ]
BASH

echo "KPM workflow contract tests passed"
