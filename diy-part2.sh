#!/bin/bash

echo "===== Add Packages ====="

# PassWall
git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall-packages.git package/passwall-packages

git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall.git package/passwall

# Daed
git clone --depth=1 https://github.com/QiuSimons/luci-app-daed.git package/luci-app-daed

# MosDNS
git clone --depth=1 https://github.com/sbwml/luci-app-mosdns.git package/luci-app-mosdns

# Tailscale
git clone --depth=1 https://github.com/asvow/luci-app-tailscale.git package/luci-app-tailscale

echo "===== Modify Default IP ====="

sed -i 's/192.168.1.1/192.168.6.1/g' \
package/base-files/files/bin/config_generate

echo "===== Enable BTF ====="

grep -q "CONFIG_DEBUG_INFO_BTF=y" \
target/linux/mediatek/filogic/config-default || cat >> \
target/linux/mediatek/filogic/config-default <<'EOF'

CONFIG_DEBUG_INFO=y
CONFIG_DEBUG_INFO_BTF=y
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_NET_CLS_ACT=y
CONFIG_NET_SCH_INGRESS=y

EOF

mkdir -p package/base-files/files/etc/uci-defaults

cat > package/base-files/files/etc/uci-defaults/99-custom-settings <<'EOF'
#!/bin/sh

echo "root:password" | chpasswd

uci set dropbear.@dropbear[0].RootPasswordAuth='1'
uci set dropbear.@dropbear[0].PasswordAuth='1'
uci commit dropbear

uci set uhttpd.main.redirect_https='0'
uci commit uhttpd

/etc/init.d/dropbear enable
/etc/init.d/uhttpd enable

rm -f /etc/uci-defaults/99-custom-settings

exit 0
EOF

chmod +x \
package/base-files/files/etc/uci-defaults/99-custom-settings

echo "===== DIY2 Complete ====="
``
