"""Regression checks for real Image banners, including the printk format string."""

import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "verify_kernel", Path(__file__).with_name("verify-built-kernel.py"))
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)

RELEASE = "5.10.236-android12-9-00020-gf997514b333d-ab13743839"
TIMESTAMP = "Mon Jul 7 16:32:37 UTC 2025"
BANNER = f"Linux version {RELEASE} (build-user@build-host) (clang 12) #1 SMP PREEMPT {TIMESTAMP}"
BASE_CONFIG = ["CONFIG_ARM64=y", "CONFIG_KSU=y", "CONFIG_TCP_CONG_BBR=y",
               "CONFIG_DEFAULT_BBR=y", 'CONFIG_DEFAULT_TCP_CONG="bbr"', "CONFIG_NET_SCH_FQ=y"]


class VerificationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.out = self.root / "evidence"
        self.image = self.root / "Image"
        self.config = self.root / "out/android12-5.10/common/.config"
        self.config.parent.mkdir(parents=True)
        self.config.write_text("\n".join(BASE_CONFIG) + "\n")
        self.header = self.config.parent / "include/generated/utsrelease.h"
        self.header.parent.mkdir(parents=True)
        self.header.write_text(f'#define UTS_RELEASE "{RELEASE}"\n')
        (self.root / "common").mkdir()
        (self.root / "common/Makefile").write_text("VERSION = 5\nPATCHLEVEL = 10\nSUBLEVEL = 236\n")
        self.image.write_bytes(b"ARM64\0Linux version %s (%s)\0" + BANNER.encode() + b"\0")
        self.environment = patch.dict(os.environ, {"REQUESTED_RELEASE": RELEASE,
                                                 "REQUESTED_BUILD_TIME": TIMESTAMP}, clear=True)
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.revision = patch.object(verifier.subprocess, "check_output", return_value="a" * 40 + "\n")
        self.revision.start()
        self.addCleanup(self.revision.stop)

    def test_format_string_before_actual_banner_is_ignored(self):
        verifier.verify(self.root, self.image, self.out)
        self.assertEqual(json.loads((self.out / "build.json").read_text())["banner"], BANNER)

    def test_wrong_release_is_rejected_before_evidence_is_written(self):
        self.image.write_bytes(BANNER.replace(RELEASE, "5.10.235-wrong").encode() + b"\0")
        with self.assertRaisesRegex(ValueError, "banner.*UTS_RELEASE"):
            verifier.verify(self.root, self.image, self.out)
        self.assertFalse(self.out.exists())

    def test_wrong_timestamp_is_rejected(self):
        self.image.write_bytes(BANNER.replace(TIMESTAMP, "Thu Jan 1 00:00:00 UTC 1970").encode() + b"\0")
        with self.assertRaisesRegex(ValueError, "timestamp"):
            verifier.verify(self.root, self.image, self.out)

    def test_requested_feature_must_be_built_in(self):
        os.environ["VERIFY_NOMOUNT"] = "true"
        self.config.write_text(self.config.read_text() + "CONFIG_NOMOUNT=m\n")
        with self.assertRaisesRegex(ValueError, "CONFIG_NOMOUNT=y"):
            verifier.verify(self.root, self.image, self.out)

    def test_only_format_string_is_rejected(self):
        self.image.write_bytes(b"Linux version %s (%s)\0")
        with self.assertRaisesRegex(ValueError, "banner.*UTS_RELEASE"):
            verifier.verify(self.root, self.image, self.out)

    def test_conflicting_actual_banners_are_rejected(self):
        self.image.write_bytes(self.image.read_bytes() + BANNER.replace(TIMESTAMP, "another build").encode() + b"\0")
        with self.assertRaisesRegex(ValueError, "conflicting banners"):
            verifier.verify(self.root, self.image, self.out)

    def test_malformed_release_header_is_rejected(self):
        self.header.write_text("/* missing UTS_RELEASE */\n")
        with self.assertRaisesRegex(ValueError, "header is malformed"):
            verifier.verify(self.root, self.image, self.out)


if __name__ == "__main__":
    unittest.main()
