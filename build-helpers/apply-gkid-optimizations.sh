#!/usr/bin/env bash
# ==============================================================================
# Apply GKID Performance, Battery & Network Optimizations
# Ports patches from GKID-Kernels (common optimizations, scheduler, I/O, network)
# ==============================================================================
set -u

KERNEL_DIR="${1:?usage: apply-gkid-optimizations.sh <kernel_root> <defconfig_path>}"
DEFCONFIG="${2:?usage: apply-gkid-optimizations.sh <kernel_root> <defconfig_path>}"
PATCH_DIR="$(cd "$(dirname "$0")/../patches/gkid" && pwd)"

echo "=== Applying GKID Optimizations ==="
echo "Kernel Directory: $KERNEL_DIR"
echo "Patch Directory : $PATCH_DIR"
echo "Defconfig       : $DEFCONFIG"

cd "$KERNEL_DIR"

applied_count=0
skipped_count=0
skipped_list=""

# 1. Apply common optimization patches
if [ -d "$PATCH_DIR" ]; then
    for patch_file in "$PATCH_DIR"/*.patch; do
        [ -f "$patch_file" ] || continue
        patch_name=$(basename "$patch_file")

        # Test dry-run first
        if patch -p1 -N -s --dry-run < "$patch_file" >/dev/null 2>&1; then
            if patch -p1 -N --forward < "$patch_file" >/dev/null 2>&1; then
                echo "  [+] Applied: $patch_name"
                applied_count=$((applied_count + 1))
            else
                echo "  [-] Failed to apply: $patch_name (reverted)"
                skipped_count=$((skipped_count + 1))
                skipped_list="$skipped_list $patch_name"
            fi
        else
            echo "  [-] Skipped: $patch_name (context mismatch or already present)"
            skipped_count=$((skipped_count + 1))
            skipped_list="$skipped_list $patch_name"
        fi
    done

    # 2. Try BBRv3 patch if present
    if [ -f "$PATCH_DIR/bbrv3/bbrv3.patch" ]; then
        if patch -p1 -N -s --dry-run < "$PATCH_DIR/bbrv3/bbrv3.patch" >/dev/null 2>&1; then
            if patch -p1 -N --forward < "$PATCH_DIR/bbrv3/bbrv3.patch" >/dev/null 2>&1; then
                echo "  [+] Applied: BBRv3 patch"
                applied_count=$((applied_count + 1))
            fi
        else
            echo "  [-] Skipped: BBRv3 patch (using verified stock BBR stack)"
        fi
    fi
fi

echo "Summary: $applied_count applied, $skipped_count skipped."
if [ -n "$skipped_list" ]; then
    echo "::warning::GKID patches not present in this kernel build (not supported on this kernel baseline or context drift):$skipped_list"
    echo "GKID SKIP LIST:$skipped_list"
fi
if find . -maxdepth 4 -type f -name '*.rej' 2>/dev/null | head -n 1 | grep -q .; then
    echo "::warning::GKID left .rej files behind — inspect before trusting the build:"
    find . -maxdepth 4 -type f -name '*.rej' 2>/dev/null | head -n 10
fi

# 3. Apply GKID Performance & Network Kernel Configs
echo "=== Injecting GKID Performance & Network Configs ==="

cat >> "$DEFCONFIG" << 'EOF'
# --- GKID Performance & I/O Tuning ---
CONFIG_FRAME_WARN=0
CONFIG_MQ_IOSCHED_DEADLINE=y
CONFIG_F2FS_FS_XATTR=y
CONFIG_F2FS_FS_POSIX_ACL=y
CONFIG_F2FS_FS_COMPRESSION=y

# --- GKID Network & Firewall Enhancements ---
CONFIG_IP_NF_TARGET_TTL=y
CONFIG_IP6_NF_NAT=y
CONFIG_IP6_NF_TARGET_MASQUERADE=y
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y
CONFIG_IP6_NF_TARGET_HL=y
CONFIG_IP_SET=y
CONFIG_IP_SET_MAX=65534
CONFIG_IP_SET_BITMAP_IP=y
CONFIG_IP_SET_BITMAP_IPMAC=y
CONFIG_IP_SET_BITMAP_PORT=y
CONFIG_IP_SET_HASH_IP=y
CONFIG_IP_SET_HASH_IPMARK=y
CONFIG_IP_SET_HASH_IPPORT=y
CONFIG_IP_SET_HASH_IPPORTIP=y
CONFIG_IP_SET_HASH_IPPORTNET=y
CONFIG_IP_SET_HASH_IPMAC=y
CONFIG_IP_SET_HASH_MAC=y
CONFIG_IP_SET_HASH_NETPORTNET=y
CONFIG_IP_SET_HASH_NET=y
CONFIG_IP_SET_HASH_NETNET=y
CONFIG_IP_SET_HASH_NETPORT=y
CONFIG_IP_SET_HASH_NETIFACE=y
CONFIG_IP_SET_LIST_SET=y
CONFIG_NETFILTER_XT_SET=y
EOF

echo "✓ GKID configs appended to $DEFCONFIG"
echo "=== GKID Optimization injection complete ==="
