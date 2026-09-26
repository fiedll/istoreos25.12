#!/bin/bash

# 修改默认IP为 192.168.6.1
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# 首次启动脚本
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-custom-settings <<'EOF'
#!/bin/sh

# 设置默认密码
echo "root:password" | chpasswd

# 开启SSH密码登录
if uci show dropbear.@dropbear[0] >/dev/null 2>&1; then
    uci set dropbear.@dropbear[0].RootPasswordAuth='1'
    uci set dropbear.@dropbear[0].PasswordAuth='1'
    uci commit dropbear
fi

# 启动SSH
[ -f /etc/init.d/dropbear ] && {
    /etc/init.d/dropbear enable
    /etc/init.d/dropbear restart
}

# 启动Web并关闭强制HTTPS跳转
[ -f /etc/init.d/uhttpd ] && {
    uci set uhttpd.main.redirect_https='0'
    uci commit uhttpd

    /etc/init.d/uhttpd enable
    /etc/init.d/uhttpd restart
}

# ttyd支持
if uci show ttyd.@ttyd[0] >/dev/null 2>&1; then
    uci set ttyd.@ttyd[0].command='/bin/login'
    uci commit ttyd
fi

rm -f /etc/uci-defaults/99-custom-settings

exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-custom-settings

# 完整 eBPF 与 BTF 内核支持（daed 运行必需）
grep -q "^CONFIG_BPF=y" target/linux/mediatek/filogic/config-default || cat >> target/linux/mediatek/filogic/config-default <<'EOF'
CONFIG_DEBUG_INFO=y
CONFIG_DEBUG_INFO_BTF=y
CONFIG_DEBUG_INFO_DWARF4=y
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_NET_CLS_ACT=y
CONFIG_NET_SCH_INGRESS=y
EOF

# 拉取 daed 源码
rm -rf package/daed
git clone --depth=1 https://github.com/QiuSimons/luci-app-daed package/daed
