#!/bin/bash

set -euo pipefail

echo "================================================"
echo " iStoreOS 25.12 / 360T7"
echo " Daed + PassWall + MosDNS"
echo "================================================"

echo
echo ">>> Source tree:"
pwd

echo
echo ">>> Git:"
git log -1 --oneline || true


#################################################
# 1. 检查 360T7 target
#################################################

echo
echo "================================================"
echo ">>> Checking 360T7 target"
echo "================================================"

if [ ! -d "target/linux/mediatek" ]; then
    echo "ERROR: target/linux/mediatek not found."
    exit 1
fi

if ! grep -Rqs "qihoo_360t7" target/linux/mediatek; then
    echo "ERROR: qihoo_360t7 target not found."
    exit 1
fi

echo "OK: qihoo_360t7 target found."


#################################################
# 2. 修改默认 LAN IP
#################################################

echo
echo "================================================"
echo ">>> Setting LAN IP"
echo "================================================"

CONFIG_GENERATE="package/base-files/files/bin/config_generate"

if [ ! -f "$CONFIG_GENERATE" ]; then
    echo "ERROR: $CONFIG_GENERATE not found."
    exit 1
fi

if grep -q "192\.168\.1\.1" "$CONFIG_GENERATE"; then
    sed -i \
        's/192\.168\.1\.1/192.168.6.1/g' \
        "$CONFIG_GENERATE"
fi

if grep -q "192\.168\.6\.1" "$CONFIG_GENERATE"; then
    echo "OK: LAN IP = 192.168.6.1"
else
    echo "ERROR: Failed to set LAN IP to 192.168.6.1"
    exit 1
fi


#################################################
# 3. Root password
#################################################

echo
echo "================================================"
echo ">>> Root password"
echo "================================================"

echo "No hard-coded root password will be installed."
echo "User should initialize the password after first boot."


#################################################
# 4. 清理第三方源码及 feed 冲突
#################################################

echo
echo "================================================"
echo ">>> Cleaning third-party package trees"
echo "================================================"

rm -rf \
    package/passwall \
    package/passwall-packages \
    package/mosdns \
    package/daed \
    package/dae

#
# iStoreOS 25.12 feeds may already provide dae/daed.
# Remove the feed package links/directories before
# installing the pinned QiuSimons version.
#

rm -rf \
    package/feeds/base/dae \
    package/feeds/packages/dae \
    package/feeds/packages/sing-box \
    package/feeds/packages/xray-core \
    package/feeds/packages/mosdns \
    package/feeds/packages/v2dat \
    package/feeds/packages/v2ray-geodata

rm -rf \
    feeds/packages/net/sing-box \
    feeds/packages/net/xray-core \
    feeds/packages/net/mosdns \
    feeds/packages/net/v2dat

echo "OK: conflicting package trees removed."


#################################################
# 5. Install PassWall
#################################################

echo
echo "================================================"
echo ">>> Installing PassWall"
echo "================================================"

git clone \
    --depth=1 \
    --single-branch \
    https://github.com/Openwrt-Passwall/openwrt-passwall.git \
    package/passwall

git clone \
    --depth=1 \
    --single-branch \
    https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git \
    package/passwall-packages

if [ ! -d "package/passwall" ]; then
    echo "ERROR: PassWall source not found."
    exit 1
fi

if [ ! -d "package/passwall-packages" ]; then
    echo "ERROR: PassWall packages source not found."
    exit 1
fi

echo "OK: PassWall source installed."


#################################################
# 6. Install MosDNS v5
#################################################

echo
echo "================================================"
echo ">>> Installing MosDNS v5"
echo "================================================"

rm -rf \
    package/mosdns \
    package/luci-app-mosdns \
    /tmp/luci-app-mosdns

git clone \
    --depth=1 \
    --single-branch \
    --branch=v5 \
    https://github.com/sbwml/luci-app-mosdns.git \
    /tmp/luci-app-mosdns

mkdir -p \
    package/mosdns \
    package/luci-app-mosdns

cp -a /tmp/luci-app-mosdns/mosdns/. \
    package/mosdns/

cp -a /tmp/luci-app-mosdns/luci-app-mosdns/. \
    package/luci-app-mosdns/

rm -rf /tmp/luci-app-mosdns

if [ ! -f "package/mosdns/Makefile" ]; then
    echo "ERROR: package/mosdns/Makefile not found."
    exit 1
fi

if [ ! -f "package/luci-app-mosdns/Makefile" ]; then
    echo "ERROR: package/luci-app-mosdns/Makefile not found."
    exit 1
fi

echo "OK: MosDNS source installed."


#################################################
# 7. Install Daed
#################################################

echo
echo "================================================"
echo ">>> Installing Daed"
echo "================================================"

DAED_TAG="daed_2026.07.31-r1"

git clone \
    --depth=1 \
    --single-branch \
    --branch="$DAED_TAG" \
    https://github.com/QiuSimons/luci-app-daed.git \
    package/dae

if [ ! -d "package/dae" ]; then
    echo "ERROR: Daed source not found."
    exit 1
fi

if [ ! -f "package/dae/daed/Makefile" ]; then
    echo "ERROR: package/dae/daed/Makefile not found."
    exit 1
fi

if [ ! -f "package/dae/luci-app-daed/Makefile" ]; then
    echo "ERROR: package/dae/luci-app-daed/Makefile not found."
    exit 1
fi

echo "OK: Daed source installed."
echo "Daed version: $DAED_TAG"


#################################################
# 8. Remove duplicate packages
#################################################

echo
echo "================================================"
echo ">>> Removing duplicate PassWall packages"
echo "================================================"

rm -rf \
    package/passwall-packages/mosdns \
    package/passwall-packages/v2dat \
    package/passwall-packages/xray-core \
    package/passwall-packages/v2ray-geodata

rm -rf \
    package/passwall/sing-box \
    package/passwall/xray-core

echo "OK: duplicate packages removed."


#################################################
# 9. Verify Daed package tree
#################################################

echo
echo "================================================"
echo ">>> Verifying Daed package tree"
echo "================================================"

echo
echo "[Daed Makefiles]"

find package/dae \
    -maxdepth 3 \
    -type f \
    -name Makefile \
    -print

if [ ! -f "package/dae/daed/Makefile" ]; then
    echo "ERROR: Daed backend Makefile not found."
    exit 1
fi

if [ ! -f "package/dae/luci-app-daed/Makefile" ]; then
    echo "ERROR: Daed LuCI Makefile not found."
    exit 1
fi

echo "OK: Daed backend Makefile found."
echo "OK: Daed LuCI Makefile found."


#################################################
# 10. Verify PassWall
#################################################

echo
echo "================================================"
echo ">>> Verifying PassWall"
echo "================================================"

if ! find package/passwall \
    -type f \
    -name Makefile \
    -print -quit |
    grep -q .; then

    echo "ERROR: PassWall Makefile not found."
    exit 1
fi

if ! find package/passwall-packages \
    -type f \
    -name Makefile \
    -print -quit |
    grep -q .; then

    echo "ERROR: PassWall packages Makefile not found."
    exit 1
fi

echo "OK: PassWall Makefile found."
echo "OK: PassWall packages Makefile found."


#################################################
# 11. Verify MosDNS
#################################################

echo
echo "================================================"
echo ">>> Verifying MosDNS"
echo "================================================"

if ! find package/mosdns \
    -type f \
    -name Makefile \
    -print -quit |
    grep -q .; then

    echo "ERROR: MosDNS Makefile not found."
    exit 1
fi

echo "OK: MosDNS Makefile found."


#################################################
# 12. Check old feed Daed
#################################################

echo
echo "================================================"
echo ">>> Checking old Daed feed"
echo "================================================"

if [ -e "package/feeds/base/dae" ]; then
    echo "ERROR: old package/feeds/base/dae still exists."
    echo "The iStoreOS feed Daed package may conflict with"
    echo "the pinned QiuSimons Daed package."
    exit 1
fi

echo "OK: old feed Daed removed."


#################################################
# 13. Check 360T7 image definition
#################################################

echo
echo "================================================"
echo ">>> Checking 360T7 image definition"
echo "================================================"

IMAGE_DEF="target/linux/mediatek/image/filogic.mk"

if [ ! -f "$IMAGE_DEF" ]; then
    echo "ERROR: $IMAGE_DEF not found."
    exit 1
fi

if ! grep -q "Device/qihoo_360t7" "$IMAGE_DEF"; then
    echo "ERROR: qihoo_360t7 image definition not found."
    exit 1
fi

echo "OK: 360T7 image definition found."


#################################################
# 14. Check target configuration
#################################################

echo
echo "================================================"
echo ">>> Checking target configuration"
echo "================================================"

if [ -f ".config" ]; then

    echo
    echo "[Target]"
    grep '^CONFIG_TARGET_mediatek' .config || true

    if ! grep -q \
        '^CONFIG_TARGET_mediatek_filogic_DEVICE_qihoo_360t7=y' \
        .config; then

        echo "ERROR: 360T7 target is not enabled."
        exit 1
    fi

    echo "OK: 360T7 target enabled."

else

    echo "WARNING: .config does not exist yet."
    echo "make defconfig will generate it later."
fi


#################################################
# 15. Check eBPF / BTF configuration
#################################################

echo
echo "================================================"
echo ">>> Checking eBPF / BTF configuration"
echo "================================================"

if [ -f ".config" ]; then

    grep -E \
        '^(CONFIG_DEVEL|CONFIG_BPF_TOOLCHAIN_HOST|CONFIG_KERNEL_DEBUG_INFO|CONFIG_KERNEL_DEBUG_INFO_BTF|CONFIG_KERNEL_CGROUPS|CONFIG_KERNEL_CGROUP_BPF|CONFIG_KERNEL_BPF_EVENTS|CONFIG_KERNEL_XDP_SOCKETS|CONFIG_PACKAGE_kmod-xdp-sockets-diag)' \
        .config \
        || true

fi


#################################################
# 16. Check Daed package version
#################################################

echo
echo "================================================"
echo ">>> Checking Daed package version"
echo "================================================"

DAED_MAKEFILE="package/dae/daed/Makefile"

DAED_PKG_NAME="$(
    sed -n 's/^PKG_NAME:=//p' "$DAED_MAKEFILE" | head -n 1
)"

DAED_PKG_VERSION="$(
    sed -n 's/^PKG_VERSION:=//p' "$DAED_MAKEFILE" | head -n 1
)"

DAED_PKG_RELEASE="$(
    sed -n 's/^PKG_RELEASE:=//p' "$DAED_MAKEFILE" | head -n 1
)"

echo "PKG_NAME:    $DAED_PKG_NAME"
echo "PKG_VERSION: $DAED_PKG_VERSION"
echo "PKG_RELEASE: $DAED_PKG_RELEASE"

if [ "$DAED_PKG_NAME" != "daed" ]; then
    echo "ERROR: Unexpected Daed PKG_NAME."
    exit 1
fi

if [ -z "$DAED_PKG_VERSION" ]; then
    echo "ERROR: Daed PKG_VERSION is empty."
    exit 1
fi

if [ -z "$DAED_PKG_RELEASE" ]; then
    echo "ERROR: Daed PKG_RELEASE is empty."
    exit 1
fi

echo "OK: Daed package metadata found."


#################################################
# 17. Third-party revisions
#################################################

echo
echo "================================================"
echo ">>> Third-party package revisions"
echo "================================================"

echo
echo "[Daed]"
git -C package/dae describe --tags --always || true
git -C package/dae log -1 --oneline || true

echo
echo "[PassWall]"
git -C package/passwall log -1 --oneline || true

echo
echo "[PassWall packages]"
git -C package/passwall-packages log -1 --oneline || true

echo
echo "[MosDNS]"
git -C package/mosdns log -1 --oneline || true


#################################################
# 18. Final package tree
#################################################

echo
echo "================================================"
echo ">>> Final package tree"
echo "================================================"

echo
echo "[Daed]"

find package/dae \
    -maxdepth 3 \
    -type f \
    -name Makefile \
    -print


echo
echo "[PassWall]"

find package/passwall \
    -maxdepth 2 \
    -type f \
    -name Makefile \
    -print \
    | head -50


echo
echo "[PassWall packages]"

find package/passwall-packages \
    -maxdepth 3 \
    -type f \
    -name Makefile \
    -print \
    | head -100


echo
echo "[MosDNS]"

find package/mosdns \
    -maxdepth 3 \
    -type f \
    -name Makefile \
    -print \
    | head -50


#################################################
# 19. Final summary
#################################################

echo
echo "================================================"
echo ">>> Final configuration summary"
echo "================================================"

echo
echo "Target:"
echo "  MediaTek Filogic"
echo "  MT7981"
echo "  Qihoo 360T7"

echo
echo "LAN:"
echo "  192.168.6.1"

echo
echo "Packages:"
echo "  Daed"
echo "  PassWall"
echo "  MosDNS"

echo
echo "Daed:"
echo "  $DAED_TAG"

echo
echo "eBPF / BTF:"
echo "  Enabled"

echo
echo "================================================"
echo ">>> DIY Part 2 completed successfully"
echo "================================================"
