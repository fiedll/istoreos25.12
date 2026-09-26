#!/bin/bash

set -e

echo "================================================"
echo " iStoreOS 25.12 / 360T7"
echo " Daed + eBPF + BTF build configuration"
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
echo ">>> Setting LAN IP to 192.168.6.1"

CONFIG_GENERATE="package/base-files/files/bin/config_generate"

if [ -f "$CONFIG_GENERATE" ]; then

    sed -i \
        's/192\.168\.1\.1/192.168.6.1/g' \
        "$CONFIG_GENERATE"

    echo "OK: LAN IP = 192.168.6.1"

else

    echo "WARNING:"
    echo "$CONFIG_GENERATE not found."

fi


#################################################
# 3. 不设置固定 root 密码
#################################################

echo
echo ">>> Root password"
echo
echo "No hard-coded root password will be installed."
echo "User should initialize the password after first boot."


#################################################
# 4. 清理第三方包目录
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
# 9. 检查 Daed
#################################################

echo
echo ">>> Checking Daed source"

if [ ! -d "package/daed" ]; then
    echo "ERROR: Daed source was not cloned."
    exit 1
fi

if [ ! -f "package/daed/Makefile" ]; then
    echo "ERROR: Daed Makefile not found."
    exit 1
fi

echo "Daed source: OK"


#################################################
# 10. 检查 Daed kernel configuration
#################################################

echo
echo "================================================"
echo ">>> Checking Daed kernel configuration"
echo "================================================"

check_config()
{
    SYMBOL="$1"

    if grep -q "^${SYMBOL}=y" .config; then
        echo "OK   ${SYMBOL}=y"
    else
        echo "FAIL ${SYMBOL} is not enabled"
        return 1
    fi
}

check_config CONFIG_KERNEL_DEBUG_INFO
check_config CONFIG_KERNEL_DEBUG_INFO_BTF
check_config CONFIG_KERNEL_CGROUPS
check_config CONFIG_KERNEL_CGROUP_BPF
check_config CONFIG_KERNEL_BPF_EVENTS
check_config CONFIG_BPF_TOOLCHAIN_HOST
check_config CONFIG_KERNEL_XDP_SOCKETS


#################################################
# 11. BTF 不能使用 reduced debug info
#################################################

echo
echo ">>> Checking reduced debug information"

if grep -q "^CONFIG_KERNEL_DEBUG_INFO_REDUCED=y" .config; then

    echo "ERROR:"
    echo "CONFIG_KERNEL_DEBUG_INFO_REDUCED=y"
    echo
    echo "Daed requires full debug information for BTF."
    exit 1

fi

echo "OK: reduced debug information disabled."


#################################################
# 12. 检查 XDP sockets module
#################################################

echo
echo ">>> Checking XDP sockets module"

if grep -q "^CONFIG_PACKAGE_kmod-xdp-sockets-diag=y" .config; then
    echo "OK: kmod-xdp-sockets-diag"
else
    echo "ERROR: kmod-xdp-sockets-diag is missing."
    exit 1
fi


#################################################
# 13. 检查 360T7 image definition
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
# 14. 打印第三方仓库版本
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
# 15. 完成
#################################################

echo
echo "================================================"
echo ">>> DIY Part 2 completed successfully"
echo "================================================"

echo
echo "Target:"
echo "  MediaTek Filogic"
echo "  MT7981"
echo "  Qihoo 360T7"

echo
echo "Daed:"
echo "  enabled"

echo
echo "BTF:"
echo "  enabled"

echo
echo "eBPF:"
echo "  enabled"

echo
