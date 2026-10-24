#!/usr/bin/env python3
"""Check the compiled legacy GKI output, then preserve its real configuration."""

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


def verify(root: Path, image: Path, output: Path) -> None:
    candidates = [p for p in (root / "out").rglob(".config")
                  if (p.parent / "include/generated/utsrelease.h").is_file()
                  and "CONFIG_ARM64=y" in p.read_text().splitlines()]
    if len(candidates) != 1:
        raise ValueError(f"expected one compiled ARM64 config, found {len(candidates)}")
    config = candidates[0]
    lines = set(config.read_text().splitlines())
    required = ["CONFIG_KSU=y", "CONFIG_TCP_CONG_BBR=y", "CONFIG_DEFAULT_BBR=y",
                'CONFIG_DEFAULT_TCP_CONG="bbr"', "CONFIG_NET_SCH_FQ=y"]
    features = {
        "SUSFS": ["CONFIG_KSU_SUSFS=y"],
        "NOMOUNT": ["CONFIG_NOMOUNT=y"],
        "VPNHIDE": ["CONFIG_VPNHIDE=y", "CONFIG_VPNHIDE_FS_HIDING=y"],
        "BBG": ["CONFIG_BBG=y"],
        "ZRAM": ["CONFIG_ZRAM=y", "CONFIG_ZSMALLOC=y", "CONFIG_CRYPTO_LZ4=y",
                 "CONFIG_CRYPTO_LZ4HC=y", "CONFIG_CRYPTO_LZ4K=y",
                 "CONFIG_CRYPTO_LZ4KD=y", "CONFIG_CRYPTO_LZ4K_OPLUS=y", "CONFIG_CRYPTO_842=y"],
        "DROIDSPACES": ["CONFIG_SYSVIPC=y", "CONFIG_POSIX_MQUEUE=y", "CONFIG_IPC_NS=y",
                       "CONFIG_PID_NS=y", "CONFIG_DEVTMPFS=y"],
    }
    for name, entries in features.items():
        if os.environ.get(f"VERIFY_{name}") == "true":
            required.extend(entries)
    missing = sorted(set(required) - lines)
    if missing:
        raise ValueError("compiled configuration is missing: " + ", ".join(missing))
    header = (config.parent / "include/generated/utsrelease.h").read_text()
    release_match = re.search(r'^#define UTS_RELEASE "([^"]+)"$', header, re.M)
    if not release_match:
        raise ValueError("generated UTS_RELEASE header is malformed")
    release = release_match[1]
    requested = os.environ.get("REQUESTED_RELEASE", "")
    if requested and release != requested:
        raise ValueError(f"compiled release {release!r} differs from {requested!r}")
    # Image also contains the printk template "Linux version %s (%s)".
    # Match the actual release-bearing banner rather than the first occurrence.
    image_bytes = image.read_bytes()
    candidates = re.findall(rb"Linux version [^\x00\n]{1,2048}", image_bytes)
    if not candidates:
        raise ValueError("compiled image has no Linux version banner")
    prefix = f"Linux version {release} (".encode()
    banners = {candidate for candidate in candidates if candidate.startswith(prefix)}
    if not banners:
        raise ValueError("image banner and generated UTS_RELEASE disagree")
    if len(banners) != 1:
        raise ValueError("image contains conflicting banners for generated UTS_RELEASE")
    banner = banners.pop().decode(errors="replace")
    timestamp = os.environ.get("REQUESTED_BUILD_TIME", "")
    if timestamp and timestamp.lower() != "n" and timestamp not in banner:
        raise ValueError("requested build timestamp is absent from the image banner")
    source = (root / "common/Makefile").read_text()
    source_version = ".".join(re.search(rf"^{key}\s*=\s*(\d+)$", source, re.M)[1]
                              for key in ["VERSION", "PATCHLEVEL", "SUBLEVEL"])
    source_commit = subprocess.check_output(
        ["git", "-C", str(root / "common"), "rev-parse", "HEAD"], text=True).strip()
    output.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(config, output / "kernel.config")
    shutil.copyfile(Path(__file__).resolve().parent.parent / "config/upstream-lock.json",
                    output / "upstream-lock.json")
    result = {"source_version": source_version, "source_commit": source_commit,
              "image_sha256": hashlib.sha256(image_bytes).hexdigest(),
              "release": release, "banner": banner, "required_config": required}
    (output / "build.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    try:
        verify(*map(Path, sys.argv[1:4]))
    except (OSError, ValueError, TypeError) as error:
        sys.exit(f"kernel artifact verification failed: {error}")
