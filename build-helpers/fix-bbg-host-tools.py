#!/usr/bin/env python3
"""Honor Kbuild's host compiler/linker settings in the pinned BBG generator."""

import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()
before = "$(shell $(HOSTCC) -I$(srctree)/scripts/selinux/genheaders"
after = "$(shell $(HOSTCC) $(KBUILD_HOSTCFLAGS) $(KBUILD_HOSTLDFLAGS) -I$(srctree)/scripts/selinux/genheaders"
if text.count(before) == 1:
    text = text.replace(before, after)
elif text.count(after) != 1:
    sys.exit("BBG host-tool fix failed: unsupported generator command")
path.write_text(text)
print("BBG genheaders inherits KBUILD_HOSTCFLAGS and KBUILD_HOSTLDFLAGS")
