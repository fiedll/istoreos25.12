#!/bin/bash

echo "===== DIY PART2 START ====="

# 修改默认IP
sed -i 's/192.168.1.1/192.168.6.1/g' \
package/base-files/files/bin/config_generate

# 首次启动脚本
mkdir -p package/base-files/files/etc/uci-defaults

cat > package/base-files/files/etc/uci-defaults/99-custom-settings <<'EOF'
#!/bin/sh

echo "root:password" | chpasswd

uci -q set dropbear.@dropbear[0].RootPasswordAuth='1'
uci -q set dropbear.@dropbear[0].PasswordAuth='1'
uci commit dropbear

uci -q set uhttpd.main.redirect_https='0'
uci commit uhttpd

/etc/init.d/dropbear enable
/etc/init.d/uhttpd enable

if uci show ttyd.@ttyd[0] >/dev/null 2>&1; then
    uci set ttyd.@ttyd[0].command='/bin/login'
    uci commit ttyd
fi

rm -f /etc/uci-defaults/99-custom-settings

exit 0
EOF

chmod +x \
package/base-files/files/etc/uci-defaults/99-custom-settings

echo "===== DIY PART2 END ====="
