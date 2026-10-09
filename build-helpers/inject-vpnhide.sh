#!/usr/bin/env bash
# ==============================================================================
# Inject VPNHide In-Tree VPN Interface Concealment Backend
# Supports Android GKI (5.10, 5.15, 6.1, 6.6, 6.12)
# ==============================================================================
set -u

KERNEL_DIR="${1:?usage: inject-vpnhide.sh <kernel_root> <kmi> <defconfig_path>}"
KMI="${2:?usage: inject-vpnhide.sh <kernel_root> <kmi> <defconfig_path>}"
DEFCONFIG="${3:?usage: inject-vpnhide.sh <kernel_root> <kmi> <defconfig_path>}"
SRC_DIR="$(cd "$(dirname "$0")/../src/vpnhide" && pwd)"
PATCH_DIR="$SRC_DIR/builtin/versions/$KMI"

echo "=== Injecting VPNHide In-Tree Backend ==="
echo "Kernel Directory: $KERNEL_DIR"
echo "KMI Target      : $KMI"
echo "Defconfig       : $DEFCONFIG"
echo "VPNHide Source  : $SRC_DIR"

cd "$KERNEL_DIR"

PYTHON_BIN="python3"
command -v python3 >/dev/null 2>&1 || PYTHON_BIN="python"

BUNDLE_DIR="/tmp/vpnhide_bundle_$$"
applied_via_script=false

if [ -f "$SRC_DIR/builtin/scripts/integrate.py" ]; then
    echo "  [>] Attempting integration via integrate.py..."
    if $PYTHON_BIN "$SRC_DIR/builtin/scripts/integrate.py" apply \
        --kernel "$KERNEL_DIR" \
        --kmi "$KMI" \
        --output "$BUNDLE_DIR" 2>/dev/null; then
        echo "  [+] VPNHide applied cleanly via integrate.py"
        applied_via_script=true
    else
        echo "  [-] integrate.py anchor mismatch, falling back to manual driver setup & patch application..."
    fi
    rm -rf "$BUNDLE_DIR"
fi

if [ "$applied_via_script" = false ]; then
    echo "  [>] Performing fallback integration..."
    # 1. Copy driver files
    mkdir -p security/vpnhide
    cp -rf "$SRC_DIR/builtin/security/vpnhide/"* security/vpnhide/
    mkdir -p security/vpnhide/shared security/vpnhide/generated
    cp -f "$SRC_DIR/kmod/shared/vpnhide_logic.h" security/vpnhide/shared/
    cp -f "$SRC_DIR/kmod/generated/iface_lists.h" security/vpnhide/generated/
    cp -f "$SRC_DIR/kmod/generated/hook_ids.h" security/vpnhide/generated/
    echo "  [+] Driver files and vendored headers copied to security/vpnhide"

    # 2. Copy public header
    mkdir -p include/linux
    cp -f "$SRC_DIR/builtin/include/linux/vpnhide.h" include/linux/
    echo "  [+] Header copied to include/linux/vpnhide.h"

    # 3. Wire security/Kconfig & security/Makefile
    if ! grep -q 'security/vpnhide/Kconfig' security/Kconfig; then
        if grep -q '^endmenu' security/Kconfig; then
            sed -i '/^endmenu/i source "security/vpnhide/Kconfig"' security/Kconfig
        else
            echo 'source "security/vpnhide/Kconfig"' >> security/Kconfig
        fi
        echo "  [+] security/Kconfig wired"
    fi
    if ! grep -q 'CONFIG_VPNHIDE' security/Makefile; then
        printf '\nobj-$(CONFIG_VPNHIDE) += vpnhide/\n' >> security/Makefile
        echo "  [+] security/Makefile wired"
    fi

    # 4. Apply version patches
    if [ -d "$PATCH_DIR" ]; then
        echo "  [>] Applying call-site patches from $PATCH_DIR..."
        for p in "$PATCH_DIR"/*.patch; do
            [ -f "$p" ] || continue
            pname=$(basename "$p")
            if patch -p1 -N --forward < "$p" >/dev/null 2>&1; then
                echo "    [+] Applied: $pname"
            else
                echo "    [-] Skipped: $pname (already present or fuzzy)"
            fi
        done
    fi
fi

# 5. Verify call-site coverage (self-adapting: expectations come from the patch files)
#    Fails loudly instead of shipping a partially patched (falsely "hidden") kernel.
echo "=== Verifying VPNHide call-site coverage ==="
if [ ! -d "$PATCH_DIR" ]; then
    echo "::error::VPNHide: no patch set for KMI $KMI at $PATCH_DIR"
    exit 1
fi

verify_fail=0
verified_files=0
for p in "$PATCH_DIR"/*.patch; do
    [ -f "$p" ] || continue
    pname=$(basename "$p")
    target=$(sed -n 's|^+++ b/||p' "$p" | head -n 1)
    if [ -z "$target" ]; then
        echo "::error::VPNHide: no target path header in $pname"
        verify_fail=1
        continue
    fi
    if [ ! -f "$target" ]; then
        echo "::error::VPNHide: patched file missing: $target (from $pname)"
        verify_fail=1
        continue
    fi
    expected=$(grep '^+' "$p" | grep -v '^+++' | grep -oE 'vpnhide_[a-z0-9_]+' | wc -l | tr -d ' ')
    actual=$(grep -oE 'vpnhide_[a-z0-9_]+' "$target" | wc -l | tr -d ' ')
    if [ "$actual" -lt "$expected" ]; then
        echo "::error::VPNHide: $target has $actual vpnhide_ references, expected >= $expected from $pname — call-site not patched"
        verify_fail=1
    fi
    verified_files=$((verified_files + 1))
done

if [ "$verified_files" -eq 0 ]; then
    echo "::error::VPNHide: no .patch files found in $PATCH_DIR"
    verify_fail=1
fi

if [ -n "$(find . -maxdepth 6 \( -path ./out -o -path ./bazel-\* \) -prune -o -type f -name '*.rej' -print 2>/dev/null | head -n 1)" ]; then
    echo "::error::VPNHide: leftover .rej files detected — some hunks were rejected"
    find . -maxdepth 6 \( -path ./out -o -path ./bazel-\* \) -prune -o -type f -name '*.rej' -print 2>/dev/null | head -n 10
    verify_fail=1
fi

if [ "$verify_fail" -ne 0 ]; then
    echo "::error::VPNHide verification failed — refusing to build a partially hidden kernel"
    exit 1
fi
echo "✓ All $verified_files call-site files carry the required VPNHide hooks"

# 6. Inject defconfig
echo "=== Configuring VPNHide in defconfig ==="
grep -q '^CONFIG_VPNHIDE=y$' "$DEFCONFIG" || echo "CONFIG_VPNHIDE=y" >> "$DEFCONFIG"
grep -q '^CONFIG_VPNHIDE_FS_HIDING=y$' "$DEFCONFIG" || echo "CONFIG_VPNHIDE_FS_HIDING=y" >> "$DEFCONFIG"
echo "✓ CONFIG_VPNHIDE=y & CONFIG_VPNHIDE_FS_HIDING=y appended to $DEFCONFIG"
echo "=== VPNHide injection complete ==="
