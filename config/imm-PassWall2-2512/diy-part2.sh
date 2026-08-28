#!/bin/bash
#========================================================================================================================
# passwall2 diy‑part2.sh ImmortalWrt openwrt‑25.12
# runs after feeds update, before feeds install
#========================================================================================================================

# 删除官方feeds冲突包，不存在目录不会报错
rm -rf feeds/packages/net/xray-core
rm -rf feeds/packages/net/v2ray-geodata
rm -rf feeds/packages/net/sing-box
rm -rf feeds/packages/net/chinadns-ng
rm -rf feeds/packages/net/dns2socks
rm -rf feeds/packages/net/hysteria
rm -rf feeds/packages/net/ipt2socks
rm -rf feeds/packages/net/microsocks
rm -rf feeds/packages/net/naiveproxy
rm -rf feeds/packages/net/shadowsocks-libev
rm -rf feeds/packages/net/shadowsocks-rust
rm -rf feeds/packages/net/shadowsocksr-libev
rm -rf feeds/packages/net/simple-obfs
rm -rf feeds/packages/net/tcping
rm -rf feeds/packages/net/trojan-plus
rm -rf feeds/packages/net/tuic-client
rm -rf feeds/packages/net/v2ray-plugin
rm -rf feeds/packages/net/xray-plugin
rm -rf feeds/packages/net/geoview
rm -rf feeds/packages/net/shadow-tls
rm -rf feeds/packages/net/nikki
rm -rf feeds/packages/net/mihomo

# 存在才删除旧passwall v1 luci，避免CI报错
if [ -d "feeds/luci/applications/luci-app-passwall" ];then
    rm -rf feeds/luci/applications/luci-app-passwall
fi

# root密码 md5crypt
sed -i 's/root:::0:99999:7:::/root:$1$qTM.tEk0$J0I9VtO1JT99G4R2iZKaA.::0:99999:7:::/g' package/base-files/files/etc/shadow

# 修改默认IP、主机名、主题
sed -i 's/192.168.1.1/192.168.111.5/g' package/base-files/files/bin/config_generate
sed -i "s/ImmortalWrt/HomeImm‑PW2/g" package/base-files/files/bin/config_generate
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
