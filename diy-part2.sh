#!/bin/bash

set -e

echo "=============================================="
echo " iStoreOS 25.12 / 360T7 DIY Part 2"
echo "=============================================="

echo
echo ">>> Build directory:"
pwd

echo
echo ">>> Git information:"
git rev-parse --short HEAD || true


#################################################
# 1. 检查目标设备
#################################################

echo
echo ">>> Checking 360T7 target..."

if [ ! -d "target/linux/mediatek" ]; then
    echo "ERROR: MediaTek target directory not found."
    exit 1
fi

if ! grep -Rqs "qihoo_360t7" target/linux/mediatek; then
    echo "ERROR: qihoo_360t7 target was not found."
    echo "This does NOT look like a valid iStoreOS/OpenWrt 360T7 source tree."
    exit 1
fi

echo "OK: qihoo_360t7 target found."


#################################################
# 2. 设置默认 LAN IP
#################################################

echo
echo ">>> Setting default LAN IP to 192.168.6.1..."

CONFIG_GENERATE="package/base-files/files/bin/config_generate"

if [ -f "$CONFIG_GENERATE" ]; then
    sed -i \
        's/192\.168\.1\.1/192.168.6.1/g' \
        "$CONFIG_GENERATE"

    echo "LAN IP configured: 192.168.6.1"
else
    echo "WARNING: $CONFIG_GENERATE not found."
fi


#################################################
# 3. 不修改 root 默认密码
#
# iStoreOS/OpenWrt 25.12 第一次启动时，
# 用户自行设置 root 密码。
#
# 不在固件里写死：
# root:password
#################################################

echo
echo ">>> Keeping default password initialization."
echo "No hard-coded root password will be injected."


#################################################
# 4. 清理旧的第三方插件目录
#################################################

echo
echo ">>> Cleaning old third-party package trees..."

rm -rf package/passwall
rm -rf package/passwall-packages

rm -rf package/mosdns


#################################################
# 5. 加入 PassWall
#################################################

echo
echo "=============================================="
echo ">>> Installing PassWall source"
echo "=============================================="

git clone \
    --depth=1 \
    https://github.com/Openwrt-Passwall/openwrt-passwall.git \
    package/passwall

git clone \
    --depth=1 \
    https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git \
    package/passwall-packages


#################################################
# 6. 加入 MosDNS
#################################################

echo
echo "=============================================="
echo ">>> Installing MosDNS v5"
echo "=============================================="

git clone \
    --depth=1 \
    --branch=v5 \
    https://github.com/sbwml/luci-app-mosdns.git \
    package/mosdns


#################################################
# 7. 删除第三方仓库中的重复 MosDNS / v2dat
#
# 避免：
#
# official feed
#       +
# passwall-packages
#       +
# mosdns feed
#
# 同时提供同名 package。
#################################################

echo
echo ">>> Removing duplicate MosDNS / v2dat packages..."

rm -rf package/passwall-packages/mosdns
rm -rf package/passwall-packages/v2dat

rm -rf feeds/packages/net/mosdns
rm -rf feeds/packages/net/v2dat

rm -rf package/feeds/packages/mosdns
rm -rf package/feeds/packages/v2dat


#################################################
# 8. 检查第三方 package 是否存在
#################################################

echo
echo ">>> Checking package sources..."

if [ ! -d "package/passwall" ]; then
    echo "ERROR: PassWall source missing."
    exit 1
fi

if [ ! -d "package/passwall-packages" ]; then
    echo "ERROR: PassWall packages source missing."
    exit 1
fi

if [ ! -d "package/mosdns" ]; then
    echo "ERROR: MosDNS source missing."
    exit 1
fi

echo "PassWall: OK"
echo "PassWall packages: OK"
echo "MosDNS: OK"


#################################################
# 9. 打印版本信息
#################################################

echo
echo "=============================================="
echo ">>> Third-party source revisions"
echo "=============================================="

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
# 10. 检查 360T7 image definition
#################################################

echo
echo ">>> Checking 360T7 image definition..."

IMAGE_DEF="target/linux/mediatek/image/filogic.mk"

if [ ! -f "$IMAGE_DEF" ]; then
    echo "ERROR: $IMAGE_DEF not found."
    exit 1
fi

if ! grep -q "Device/qihoo_360t7" "$IMAGE_DEF"; then
    echo "ERROR: qihoo_360t7 image definition not found."
    exit 1
fi

echo "OK: qihoo_360t7 image definition found."


#################################################
# 11. 最终检查
#################################################

echo
echo "=============================================="
echo ">>> DIY Part 2 completed"
echo "=============================================="

echo
echo "Target:"
grep -R "CONFIG_TARGET_mediatek_filogic_DEVICE_qihoo_360t7" \
    .config || true

echo
echo "Expected firmware:"
echo "  qihoo_360t7-squashfs-sysupgrade.itb"
echo "  qihoo_360t7-initramfs-recovery.itb"
echo "  qihoo_360t7-preloader.bin"
echo "  qihoo_360t7-bl31-uboot.fip"

echo
