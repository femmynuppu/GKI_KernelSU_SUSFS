#!/usr/bin/env python3
"""Exercise AK3 partition selection in a fake filesystem, without flashing.

Use the checked-out upstream core and our actual anykernel.sh. Device paths
are redirected into a temporary directory. Boot read/write functions are
replaced after core setup, so these tests never read or write real partitions.
The host Bash simulation does not replace an Android/BusyBox/device test.
"""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


AK3 = Path(sys.argv.pop(1)).resolve() if len(sys.argv) > 1 else Path("AnyKernel3").resolve()
INSTALLER = (AK3 / "anykernel.sh").read_text()
CORE = (AK3 / "tools/ak3-core.sh").read_text()


class InstallerTests(unittest.TestCase):
    def simulate(self, suffix="", slot="", init_boot=False, missing=False):
        with tempfile.TemporaryDirectory(prefix="ak3-installer-") as temp:
            root = Path(temp)
            (root / "tools").mkdir()
            devices = root / "dev/block/by-name"
            devices.mkdir(parents=True)
            (root / "dev/null").touch()
            (root / "proc").mkdir()
            (root / "proc/cmdline").write_text("")
            (root / "proc/mtd").write_text("")
            (root / "proc/version").write_text("Linux version 5.10.236-test (host)\n")
            target_suffix = suffix or ("_" + slot if slot else "")
            if not missing:
                name = "boot" + target_suffix
                (devices.parent / name).touch()
                (devices / name).symlink_to("../" + name)
            if init_boot:
                for name in ("init_boot_a", "init_boot_b"):
                    (devices.parent / name).touch()
                    (devices / name).symlink_to("../" + name)

            def virtualize(text):
                text = text.replace("/dev/", str(root / "dev") + "/")
                for name in ("cmdline", "mtd", "version"):
                    text = text.replace("/proc/" + name, str(root / "proc" / name))
                return text

            # setup_ak executes on source. The replacement functions below
            # take over before anykernel.sh reaches its installation calls.
            core = virtualize(CORE) + """
dump_boot() { printf 'TEST_DUMP:%s\\n' "$BLOCK"; }
write_boot() { printf 'TEST_WRITE:%s\\n' "$BLOCK"; exit 0; }
split_boot() { printf 'TEST_SPLIT:%s\\n' "$BLOCK"; }
flash_boot() { printf 'TEST_FLASH:%s\\n' "$BLOCK"; exit 0; }
"""
            (root / "tools/ak3-core.sh").write_text(core)
            (root / "anykernel.sh").write_text(virtualize(INSTALLER))
            runner = """
getprop() {
  case "$1" in
    ro.boot.slot_suffix) printf '%s' "$TEST_SLOT_SUFFIX" ;;
    ro.boot.slot) printf '%s' "$TEST_SLOT" ;;
  esac
}
. ./anykernel.sh
"""
            env = os.environ.copy()
            for key in ("BLOCK", "IS_SLOT_DEVICE", "SLOT", "SLOT_SELECT", "AKHOME",
                        "RAMDISK_COMPRESSION", "PATCH_VBMETA_FLAG", "NO_MAGISK_CHECK"):
                env.pop(key, None)
            env.update(OUTFD="1", TEST_SLOT_SUFFIX=suffix, TEST_SLOT=slot)
            result = subprocess.run(["bash", "-c", runner], cwd=root, env=env,
                                    capture_output=True, text=True, timeout=15)
            return result, str(devices / ("boot" + target_suffix))

    def assert_boot_selected(self, result, target, split=False):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        first, last = ("SPLIT", "FLASH") if split else ("DUMP", "WRITE")
        self.assertIn(f"TEST_{first}:{target}", result.stdout)
        self.assertIn(f"TEST_{last}:{target}", result.stdout)
        self.assertNotIn("Unable to determine", result.stdout)

    def test_active_slot_a(self):
        self.assert_boot_selected(*self.simulate(suffix="_a"))

    def test_active_slot_b(self):
        self.assert_boot_selected(*self.simulate(suffix="_b"))

    def test_slot_property_fallback(self):
        self.assert_boot_selected(*self.simulate(slot="b"))

    def test_non_slot_boot(self):
        self.assert_boot_selected(*self.simulate())

    def test_init_boot_layout_still_targets_boot(self):
        self.assert_boot_selected(*self.simulate(suffix="_b", init_boot=True), split=True)

    def test_missing_partition_aborts_before_installation(self):
        result, _ = self.simulate(suffix="_a", missing=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unable to determine boot partition. Aborting...", result.stdout)
        self.assertNotIn("TEST_", result.stdout)


if __name__ == "__main__":
    unittest.main()
