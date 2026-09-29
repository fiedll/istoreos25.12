#!/bin/bash

set -euo pipefail

echo "================================================"
echo " iStoreOS 25.12 / 360T7"
echo " Daed + MosDNS + Tailscale"
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
    echo "OK: LAN IP in config_generate verified as 192.168.6.1"
else
    echo "WARNING: 192.168.6.1 not explicitly found in config_generate, relying on uci-defaults."
fi


#################################################
# 2b. 注入 360T7 首次开机网络修复 (解决无法获取 IP)
#################################################

echo
echo "================================================"
echo ">>> Injecting 360T7 network defaults"
echo "================================================"

UCI_DEF_DIR="package/base-files/files/etc/uci-defaults"
mkdir -p "$UCI_DEF_DIR"
NETWORK_FIX="$UCI_DEF_DIR/99-360t7-network"

cat > "$NETWORK_FIX" <<'EOF'
#!/bin/sh
uci -q batch <<MAKER
set network.lan=interface
set network.lan.proto='static'
set network.lan.ipaddr='192.168.6.1'
set network.lan.netmask='255.255.255.0'
set network.lan.device='br-lan'

delete network.@device[0] 2>/dev/null || true
set network.br_lan=device
set network.br_lan.name='br-lan'
set network.br_lan.type='bridge'
add_list network.br_lan.ports='lan1'
add_list network.br_lan.ports='lan2'
add_list network.br_lan.ports='lan3'

set network.wan=interface
set network.wan.device='wan'
set network.wan.proto='dhcp'

set network.wan6=interface
set network.wan6.device='wan'
set network.wan6.proto='dhcpv6'
MAKER
uci commit network
exit 0
EOF
chmod +x "$NETWORK_FIX"

echo "OK: 360T7 first-boot network repair configured."
echo "  LAN: br-lan = lan1 lan2 lan3"
echo "  LAN IP: 192.168.6.1/24"
echo "  DHCP: dnsmasq-full"
echo "  WAN: wan / DHCP"


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
    package/luci-app-mosdns \
    package/geo2txt

cp -a /tmp/luci-app-mosdns/mosdns/. package/mosdns/
cp -a /tmp/luci-app-mosdns/luci-app-mosdns/. package/luci-app-mosdns/

if [ -d /tmp/luci-app-mosdns/geo2txt ]; then
    cp -a /tmp/luci-app-mosdns/geo2txt/. package/geo2txt/
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

if [ ! -f "package/geo2txt/Makefile" ]; then
    echo "ERROR: package/geo2txt/Makefile not found."
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

git clone --depth=1 --single-branch \
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

# 去掉对外部 vmlinux-btf 软件包的硬依赖
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

./scripts/feeds install tailscale luci-app-tailscale-community luci-i18n-tailscale-community-zh-cn || true

if [ ! -f "feeds/packages/net/tailscale/Makefile" ]; then
    echo "ERROR: Tailscale package not found in feeds."
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
# 10. Check 360T7 image definition
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
# 11. Final summary
#################################################

echo
echo "================================================"
echo ">>> Final configuration summary"
echo "================================================"

echo
echo "Target:"
echo "  MediaTek Filogic MT7981 (Qihoo 360T7)"

echo
echo "LAN:"
echo "  192.168.6.1 (Ports: lan1 lan2 lan3)"

echo
echo "Packages:"
echo "  Daed"
echo "  MosDNS"
echo "  Tailscale"

echo
echo "eBPF / BTF:"
echo "  Enabled"

echo
echo "================================================"
echo ">>> DIY Part 2 completed successfully"
echo "================================================"
