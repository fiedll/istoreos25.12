#!/bin/bash

set -e

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

if [ -f "$CONFIG_GENERATE" ]; then

    sed -i \
        's/192\.168\.1\.1/192.168.6.1/g' \
        "$CONFIG_GENERATE"

    echo "OK: LAN IP = 192.168.6.1"

else

    echo "WARNING: $CONFIG_GENERATE not found."

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
# 4. 清理旧第三方源码
#################################################

echo
echo "================================================"
echo ">>> Cleaning third-party package trees"
echo "================================================"

rm -rf package/passwall
rm -rf package/passwall-packages
rm -rf package/mosdns
rm -rf package/daed


#################################################
# 5. PassWall
#################################################

echo
echo "================================================"
echo ">>> Installing PassWall"
echo "================================================"

git clone \
    --depth=1 \
    https://github.com/Openwrt-Passwall/openwrt-passwall.git \
    package/passwall

git clone \
    --depth=1 \
    https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git \
    package/passwall-packages

echo "OK: PassWall source installed."


#################################################
# 6. MosDNS
#################################################

echo
echo "================================================"
echo ">>> Installing MosDNS v5"
echo "================================================"

git clone \
    --depth=1 \
    --branch=v5 \
    https://github.com/sbwml/luci-app-mosdns.git \
    package/mosdns

echo "OK: MosDNS source installed."


#################################################
# 7. Daed
#################################################

echo
echo "================================================"
echo ">>> Installing Daed"
echo "================================================"

git clone \
    --depth=1 \
    https://github.com/QiuSimons/luci-app-daed.git \
    package/daed

echo "OK: Daed source installed."


#################################################
# 8. 清理重复包
#################################################

echo
echo "================================================"
echo ">>> Removing duplicate MosDNS / v2dat"
echo "================================================"

rm -rf package/passwall-packages/mosdns
rm -rf package/passwall-packages/v2dat

rm -rf feeds/packages/net/mosdns
rm -rf feeds/packages/net/v2dat

rm -rf package/feeds/packages/mosdns
rm -rf package/feeds/packages/v2dat


#################################################
# 9. 检查第三方源码
#################################################

echo
echo "================================================"
echo ">>> Checking third-party sources"
echo "================================================"

if [ ! -d "package/passwall" ]; then
    echo "ERROR: PassWall source not found."
    exit 1
fi

if [ ! -d "package/passwall-packages" ]; then
    echo "ERROR: PassWall packages source not found."
    exit 1
fi

if [ ! -d "package/mosdns" ]; then
    echo "ERROR: MosDNS source not found."
    exit 1
fi

if [ ! -d "package/daed" ]; then
    echo "ERROR: Daed source not found."
    exit 1
fi

if [ ! -f "package/daed/Makefile" ]; then
    echo "ERROR: Daed Makefile not found."
    exit 1
fi

echo "OK: PassWall source"
echo "OK: PassWall packages source"
echo "OK: MosDNS source"
echo "OK: Daed source"


#################################################
# 10. 检查 360T7 image definition
#################################################

echo
echo "================================================"
echo ">>> Checking 360T7 image definition"
echo "================================================"

IMAGE_DEF="target/linux/mediatek/image/filogic.mk"

if [ ! -f "$IMAGE_DEF" ]; then
    echo "ERROR: filogic.mk not found."
    exit 1
fi

if ! grep -q "Device/qihoo_360t7" "$IMAGE_DEF"; then
    echo "ERROR: qihoo_360t7 image definition not found."
    exit 1
fi

echo "OK: 360T7 image definition found."


#################################################
# 11. 第三方仓库版本
#################################################

echo
echo "================================================"
echo ">>> Third-party package revisions"
echo "================================================"

echo
echo "[PassWall]"
git -C package/passwall log -1 --oneline || true

echo
echo "[PassWall packages]"
git -C package/passwall-packages log -1 --oneline || true

echo
echo "[MosDNS]"
git -C package/mosdns log -1 --oneline || true

echo
echo "[Daed]"
git -C package/daed log -1 --oneline || true


#################################################
# 12. 完成
#################################################

echo
echo "================================================"
echo ">>> DIY Part 1 completed successfully"
echo "================================================"

echo
echo "Target:"
echo "  MediaTek Filogic"
echo "  MT7981"
echo "  Qihoo 360T7"

echo
echo "Packages:"
echo "  PassWall"
echo "  MosDNS"
echo "  Daed"

echo
echo "Kernel/eBPF/BTF configuration will be handled"
echo "by diy-part2.sh and make defconfig."

echo
