#!/bin/bash
set -euo pipefail

echo "================================================"
echo " iStoreOS 25.12 / 360T7"
echo " Daed + MosDNS + Tailscale + WiFi"
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
# 2. 保持上游原始 LAN IP
#################################################
echo
echo "================================================"
echo ">>> Checking upstream LAN IP"
echo "================================================"

CONFIG_GENERATE="package/base-files/files/bin/config_generate"

if [ ! -f "$CONFIG_GENERATE" ]; then
    echo "ERROR: $CONFIG_GENERATE not found."
    exit 1
fi

if grep -q "192\.168\.1\.1" "$CONFIG_GENERATE"; then
    echo "OK: upstream LAN IP remains 192.168.1.1"
else
    echo "ERROR: upstream 192.168.1.1 LAN default was not found."
    exit 1
fi

#################################################
# 2b. 去掉强制 network/dhcp，改由 board.d 生成
#################################################
echo
echo "================================================"
echo ">>> Removing forced network/dhcp overlays"
echo "================================================"

rm -f \
    "${GITHUB_WORKSPACE:-}/files/etc/config/network" \
    "${GITHUB_WORKSPACE:-}/files/etc/config/dhcp" \
    files/etc/config/network \
    files/etc/config/dhcp \
    2>/dev/null || true

echo "OK: forced network/dhcp removed; board.d will generate defaults."
echo "  Expected: LAN=lan1/lan2/lan3 @ 192.168.1.1, WAN=wan (DHCP)"

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
    package/dae \
    package/v2ray-geodata

rm -rf \
    package/feeds/base/dae \
    package/feeds/packages/dae \
    package/feeds/packages/sing-box \
    package/feeds/packages/mosdns \
    package/feeds/packages/v2dat \
    package/feeds/packages/v2ray-geodata

rm -rf \
    feeds/packages/net/sing-box \
    feeds/packages/net/mosdns \
    feeds/packages/net/v2dat \
    feeds/packages/net/v2ray-geodata

echo "OK: conflicting package trees removed."

#################################################
# 5. 克隆 v2ray-geodata 依赖
#################################################
echo
echo "================================================"
echo ">>> Cloning v2ray-geodata"
echo "================================================"

git clone --depth=1 https://github.com/sbwml/v2ray-geodata package/v2ray-geodata

#################################################
# 6. Install MosDNS v5
#################################################
echo
echo "================================================"
echo ">>> Installing MosDNS v5"
echo "================================================"

rm -rf package/mosdns package/luci-app-mosdns package/geo2txt /tmp/luci-app-mosdns

git clone \
    --depth=1 \
    --single-branch \
    --branch=v5 \
    https://github.com/sbwml/luci-app-mosdns.git \
    /tmp/luci-app-mosdns

mkdir -p package/mosdns package/luci-app-mosdns

cp -a /tmp/luci-app-mosdns/mosdns/. package/mosdns/
cp -a /tmp/luci-app-mosdns/luci-app-mosdns/. package/luci-app-mosdns/

# geo2txt 为可选组件
if [ -d /tmp/luci-app-mosdns/geo2txt ]; then
    mkdir -p package/geo2txt
    cp -a /tmp/luci-app-mosdns/geo2txt/. package/geo2txt/
    echo "OK: geo2txt included."
else
    echo "WARN: geo2txt directory not found in upstream, skipped."
fi

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
# 7. Install Daed & 修复依赖
#################################################
echo
echo "================================================"
echo ">>> Installing Daed"
echo "================================================"

rm -rf package/daed package/luci-app-daede package/dae /tmp/openwrt-daede

git clone \
    --depth=1 \
    --single-branch \
    https://github.com/kenzok8/openwrt-daede.git \
    /tmp/openwrt-daede

for pkg in daed luci-app-daede dae; do
    if [ ! -d "/tmp/openwrt-daede/$pkg" ]; then
        echo "ERROR: missing $pkg in kenzok8/openwrt-daede"
        exit 1
    fi
done

cp -a /tmp/openwrt-daede/daed package/daed
cp -a /tmp/openwrt-daede/luci-app-daede package/luci-app-daede
cp -a /tmp/openwrt-daede/dae package/dae
rm -rf package/daed/vmlinux-btf /tmp/openwrt-daede

# 移除对独立 vmlinux-btf 包的依赖（使用内核内置 BTF）
sed -i 's/+vmlinux-btf//g' package/daed/Makefile 2>/dev/null || true
sed -i 's/+vmlinux-btf//g' package/dae/Makefile 2>/dev/null || true

test -f package/daed/Makefile
test -f package/luci-app-daede/Makefile

echo "OK: known-good kenzok8 Daed tree installed."

#################################################
# 8. Install & Check Tailscale
#################################################
echo
echo "================================================"
echo ">>> Installing Tailscale from feeds"
echo "================================================"

# 去掉 || true，让安装失败直接暴露
./scripts/feeds install \
    tailscale \
    luci-app-tailscale-community \
    luci-i18n-tailscale-community-zh-cn

if [ ! -f "feeds/packages/net/tailscale/Makefile" ] && \
   [ ! -f "package/feeds/packages/tailscale/Makefile" ]; then
    echo "ERROR: Tailscale package not found after feeds install."
    exit 1
fi

echo "OK: Tailscale installed from feeds."

#################################################
# 9. Verify Package Trees
#################################################
echo
echo "================================================"
echo ">>> Verifying Package Trees"
echo "================================================"

test -f package/daed/Makefile
test -f package/luci-app-daede/Makefile
echo "OK: Daed backend & LuCI found."

if ! find package/mosdns -type f -name Makefile -print -quit | grep -q .; then
    echo "ERROR: MosDNS Makefile not found."
    exit 1
fi
echo "OK: MosDNS found."

if [ -e "package/feeds/base/dae" ]; then
    echo "ERROR: old package/feeds/base/dae still exists."
    exit 1
fi
echo "OK: old feed Daed removed."

#################################################
# 10. MTK Ethernet IRQ backport — 临时禁用
#################################################
echo
echo "================================================"
echo ">>> Skipping MTK Ethernet IRQ backport"
echo "================================================"
echo "SKIP: 739-net-ethernet-mtk_eth_soc-rework-irq-handling.patch"
echo "      disabled to unblock toolchain/kernel-headers build."

#################################################
# 11. Check 360T7 image definition
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
# 12. Final summary
#################################################
echo
echo "================================================"
echo ">>> Final configuration summary"
echo "================================================"
echo
echo "Target:"
echo "  MediaTek Filogic MT7981 (Qihoo 360T7)"
echo
echo "Network:"
echo "  board.d auto: LAN=lan1/2/3 @ 192.168.1.1, WAN=wan"
echo
echo "Packages:"
echo "  Daed / MosDNS / Tailscale / WiFi (mt7915e)"
echo
echo "eBPF / BTF:"
echo "  Enabled"
echo
echo "MTK IRQ backport:"
echo "  Disabled (temporary)"
echo
echo "================================================"
echo ">>> DIY Part 2 completed successfully"
echo "================================================"
