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
    PATCH_DIR="$SRC_DIR/builtin/versions/$KMI"
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

# 5. Verify call-site coverage (fail loudly instead of shipping a partially patched kernel)
echo "=== Verifying VPNHide call-site coverage ==="
verify_fail=0
count_sym() {
    c=$(grep -c "$1" "$2" 2>/dev/null || true)
    if [ "$c" -lt "$3" ]; then
        echo "::error::VPNHide: $2 is missing $1 (found $c, need $3) — call-site not patched"
        verify_fail=1
    fi
}
count_sym vpnhide_should_hide_ifname net/core/dev_ioctl.c 3
count_sym vpnhide_should_hide_dev    net/core/dev_ioctl.c 1
count_sym vpnhide_should_hide_dev    net/core/rtnetlink.c 1
count_sym vpnhide_should_hide_dev    net/ipv4/devinet.c 1
count_sym vpnhide_should_hide_ifname net/ipv4/devinet.c 1
count_sym vpnhide_should_hide_dev    net/ipv6/addrconf.c 1
count_sym vpnhide_setsockopt_bind    net/socket.c 1
count_sym vpnhide_hide_fib_route     net/ipv4/fib_trie.c 1
count_sym vpnhide_hide_fib6_route    net/ipv6/ip6_fib.c 1
count_sym vpnhide_hide_fib_dump      net/ipv4/fib_semantics.c 1
count_sym vpnhide_hide_rt6           net/ipv6/route.c 1
count_sym vpnhide_hide_fib_rule      net/core/fib_rules.c 1
count_sym vpnhide_should_hide_dentry fs/namei.c 2
count_sym vpnhide_should_hide_dentry fs/stat.c 1
count_sym vpnhide_readdir_begin      fs/readdir.c 1

if [ -n "$(find . -maxdepth 6 \( -path ./out -o -path ./bazel-\* \) -prune -o -type f -name '*.rej' -print 2>/dev/null | head -n 1)" ]; then
    echo "::error::VPNHide: leftover .rej files detected — some hunks were rejected"
    find . -maxdepth 6 \( -path ./out -o -path ./bazel-\* \) -prune -o -type f -name '*.rej' -print 2>/dev/null | head -n 10
    verify_fail=1
fi

if [ "$verify_fail" -ne 0 ]; then
    echo "::error::VPNHide verification failed — refusing to build a partially hidden kernel"
    exit 1
fi
echo "✓ All 13 call-site files carry the required VPNHide hooks"

# 6. Inject defconfig
echo "=== Configuring VPNHide in defconfig ==="
grep -q '^CONFIG_VPNHIDE=y$' "$DEFCONFIG" || echo "CONFIG_VPNHIDE=y" >> "$DEFCONFIG"
grep -q '^CONFIG_VPNHIDE_FS_HIDING=y$' "$DEFCONFIG" || echo "CONFIG_VPNHIDE_FS_HIDING=y" >> "$DEFCONFIG"
echo "✓ CONFIG_VPNHIDE=y & CONFIG_VPNHIDE_FS_HIDING=y appended to $DEFCONFIG"
echo "=== VPNHide injection complete ==="
