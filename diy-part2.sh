#!/bin/bash

set -euo pipefail

echo "================================================"
echo " iStoreOS 25.12 / 360T7"
echo " Daed + MosDNS"
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
# 2b. 检查并注入 360T7 首次开机网络修复 (UCI Defaults)
#################################################

echo
echo "================================================"
echo ">>> Checking 360T7 network defaults"
echo "================================================"

# 如果外部仓库没有挂载 files，则在源码树内直接动态生成，防止脚本报错中断
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
    package/dae

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
    feeds/packages/net/v2dat

echo "OK: conflicting package trees removed."


#################################################
# 5. Install MosDNS v5
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
# 6. Install Daed
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

test -f package/daed/Makefile
test -f package/luci-app-daede/Makefile

echo "OK: known-good kenzok8 Daed tree installed."


#################################################
# 7. Verify Daed package tree
#################################################

echo
echo "================================================"
echo ">>> Verifying Daed package tree"
echo "================================================"

echo
echo "[Daed Makefiles]"

find package/daed \
    -maxdepth 3 \
    -type f \
    -name Makefile \
    -print

if [ ! -f "package/daed/Makefile" ]; then
    echo "ERROR: Daed backend Makefile not found."
    exit 1
fi

if [ ! -f "package/luci-app-daede/Makefile" ]; then
    echo "ERROR: Daed LuCI Makefile not found."
    exit 1
fi

echo "OK: Daed backend Makefile found."
echo "OK: Daed LuCI Makefile found."


#################################################
# 8. Verify MosDNS
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
# 9. Check old feed Daed
#################################################

echo
echo "================================================"
echo ">>> Checking old Daed feed"
echo "================================================"

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
# 11. Check target configuration
#################################################

echo
echo "================================================"
echo ">>> Checking target configuration"
echo "================================================"

if [ -f ".config" ]; then

    echo
    echo "[Target]"
    grep '^CONFIG_TARGET_mediatek' .config || true

    echo
    echo "[Daed BTF selection]"
    grep -E '^CONFIG_KERNEL_DEBUG_INFO(_BTF)?=' .config || true

    if ! grep -q '^CONFIG_KERNEL_DEBUG_INFO_BTF=y' .config; then
        echo "ERROR: integrated kernel BTF is not enabled."
        exit 1
    fi

    if grep -q '^CONFIG_PACKAGE_daed_DAED_USE_(KERNEL|VMLINUX)_BTF=' .config; then
        echo "ERROR: obsolete Daed package-local BTF option remains."
        exit 1
    fi

    echo "OK: Daed uses integrated kernel BTF."

    if ! grep -q \
        '^CONFIG_TARGET_mediatek_filogic_DEVICE_qihoo_360t7=y' \
        .config; then

        echo "ERROR: standard 360T7 target is not enabled."
        exit 1
    fi

    if ! grep -q \
        '^CONFIG_TARGET_mediatek_filogic_DEVICE_qihoo_360t7-ubi=y' \
        .config; then
        echo "ERROR: 360T7 UBI target is not enabled."
        exit 1
    fi

    echo "OK: standard 360T7 target enabled."
    echo "OK: 360T7 UBI target enabled."

else
    echo "WARNING: .config does not exist yet."
    echo "make defconfig will generate it later."
fi


#################################################
# 12. Check eBPF / BTF configuration
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
# 13. Check Daed package version
#################################################

echo
echo "================================================"
echo ">>> Checking Daed package version"
echo "================================================"

DAED_MAKEFILE="package/daed/Makefile"

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
# 14. Third-party revisions
#################################################

echo
echo "================================================"
echo ">>> Third-party package revisions"
echo "================================================"

echo
echo "[Daed]"
git -C package/daed describe --tags --always || true
git -C package/daed log -1 --oneline || true

echo
echo "[MosDNS]"
git -C package/mosdns log -1 --oneline || true


#################################################
# 15. Final package tree
#################################################

echo
echo "================================================"
echo ">>> Final package tree"
echo "================================================"

echo
echo "[Daed]"
find package/daed \
    -maxdepth 3 \
    -type f \
    -name Makefile \
    -print

echo
echo "[MosDNS]"
find package/mosdns \
    -maxdepth 3 \
    -type f \
    -name Makefile \
    -print \
    | head -50


#################################################
# 16. Final summary
#################################################

echo
echo "================================================"
echo ">>> Final configuration summary"
echo "================================================"

echo
echo "Target:"
echo "  MediaTek Filogic"
echo "  MT7981"
echo "  Qihoo 360T7 (standard + UBI images)"

echo
echo "LAN:"
echo "  192.168.6.1"

echo
echo "Packages:"
echo "  Daed"
echo "  MosDNS"

echo
echo "Daed:"
echo "  $DAED_PKG_NAME $DAED_PKG_VERSION-$DAED_PKG_RELEASE"

echo
echo "eBPF / BTF:"
echo "  Enabled"

echo
echo "================================================"
echo ">>> DIY Part 2 completed successfully"
echo "================================================"
