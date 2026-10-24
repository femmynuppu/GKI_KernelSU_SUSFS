#!/usr/bin/env python3
"""Set the emitted release without changing LINUX_VERSION_CODE or source APIs."""

import re
import sys
from pathlib import Path


def configure(kernel: Path, release: str) -> None:
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:[-+.][A-Za-z0-9_.+-]+)?", release):
        raise ValueError("invalid kernel release")
    if len(release) > 64:
        raise ValueError("kernel release exceeds UTS_RELEASE's 64 character limit")
    makefile = kernel / "Makefile"
    text = makefile.read_text()
    major = re.search(r"^VERSION\s*=\s*(\d+)$", text, re.M)
    minor = re.search(r"^PATCHLEVEL\s*=\s*(\d+)$", text, re.M)
    if not major or not minor or not release.startswith(f"{major[1]}.{minor[1]}."):
        raise ValueError("requested kernel family does not match the source")

    # Android 5.x appends BUILD_NUMBER to UTS_RELEASE separately. The complete
    # requested release already owns its build suffix, so append nothing else.
    text = text.replace("UTS_RELEASE=$(KERNELRELEASE)-ab$(BUILD_NUMBER)",
                        "UTS_RELEASE=$(KERNELRELEASE)")
    text, generated = re.subn(
        r"^filechk_kernel\.release\s*=[^\n]*(?:\n\t[^\n]*)*",
        f'filechk_kernel.release = echo "{release}"', text, flags=re.M,
    )
    text, command = re.subn(
        r"^(kernelrelease:[^\n]*\n)(?:\t[^\n]*\n)+",
        rf'\g<1>\t@echo "{release}"\n', text, flags=re.M,
    )
    if generated != 1 or command != 1:
        raise ValueError("unsupported Makefile release rules; no file was written")
    makefile.write_text(text)
    print(f"Emitted kernel release: {release}; source VERSION/PATCHLEVEL/SUBLEVEL preserved")


if __name__ == "__main__":
    try:
        configure(Path(sys.argv[1]), sys.argv[2])
    except (OSError, ValueError) as error:
        sys.exit(f"kernel version spoof failed: {error}")
