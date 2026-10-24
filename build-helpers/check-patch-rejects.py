#!/usr/bin/env python3
"""Reject incomplete patch stacks before compiling or publishing an artifact."""

import json
import os
import sys
from pathlib import Path


def check(root: Path, output: Path, stage: str) -> None:
    if not root.is_dir():
        raise ValueError(f"kernel tree is missing: {root}")
    rejects = []

    def fail(error):
        raise error

    for directory, _, files in os.walk(root, onerror=fail, followlinks=False):
        rejects.extend(str((Path(directory) / name).relative_to(root))
                       for name in files if name.endswith(".rej"))
    result = {"stage": stage, "reject_count": len(rejects), "rejects": sorted(rejects)}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(f"Patch reject gate ({stage}): {len(rejects)} .rej files")
    if rejects:
        raise ValueError("refusing to build/publish with patch rejects: " + ", ".join(sorted(rejects)))


if __name__ == "__main__":
    try:
        check(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3])
    except (OSError, ValueError) as error:
        sys.exit(f"patch reject check failed: {error}")
