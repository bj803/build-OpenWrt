#!/bin/bash
#========================================================================================================================
# Description: Diy script (After Update feeds, Before Install feeds)
# Source code repository: https://github.com/immortalwrt/immortalwrt / Branch: openwrt-25.12
#========================================================================================================================

# ------------------------------- 删除与 PassWall feeds 冲突的官方包 -------------------------------
# 25.12 官方 feeds/packages 内含这些包的旧版本，必须删除让 PassWall 自己的版本胜出
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
# 25.12 新增冲突包（nikki/mihomo 在新版 packages feed 中已加入）
rm -rf feeds/packages/net/nikki
rm -rf feeds/packages/net/mihomo

# 删除 luci feed 里可能存在的旧版 passwall luci（passwall_luci feed 提供正确版本）
rm -rf feeds/luci/applications/luci-app-passwall

# ------------------------------- 主源码定制 -------------------------------

# 设置 root 默认密码（qwe**789 的 md5crypt 哈希）
sed -i 's/root:::0:99999:7:::/root:$1$qTM.tEk0$J0I9VtO1JT99G4R2iZKaA.::0:99999:7:::/g' package/base-files/files/etc/shadow

# 修改默认主题为 argon
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true

# 修改默认 IP（旁路由地址）
sed -i 's/192.168.1.1/192.168.111.5/g' package/base-files/files/bin/config_generate

# 修改机器名称
sed -i "s/ImmortalWrt/HomeImm111/g" package/base-files/files/bin/config_generate

# ------------------------------- 25.12 特有：wifi-scripts 已从 shell 改为 ucode -------------------------------
# 旁路由通常不用 wifi，无需处理；若有自定义 wifi 脚本请在此更新路径
