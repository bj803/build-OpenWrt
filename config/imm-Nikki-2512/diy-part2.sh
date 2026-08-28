#!/bin/bash
#========================================================================================================================
# Nikki (Mihomo/sing-box) diy-part2.sh  ImmortalWrt openwrt-25.12
# 已核实：Nikki 的包名（nikki / mihomo-meta / mihomo-alpha / luci-app-nikki）
# 在官方 immortalwrt/packages、immortalwrt/luci（openwrt-25.12）中均无同名冲突，
# 因此不需要像 PassWall2 那样手工 rm -rf 清理官方 feeds 里的旧包。
#========================================================================================================================

# 设置root密码 md5crypt（已比对官方 package/base-files/files/etc/shadow 默认内容，
# 匹配的原始字符串 root:::0:99999:7::: 是正确的）
sed -i 's/root:::0:99999:7:::/root:$1$qTM.tEk0$J0I9VtO1JT99G4R2iZKaA.::0:99999:7:::/g' package/base-files/files/etc/shadow

# 修改默认IP、主机名
sed -i 's/192.168.1.1/192.168.111.5/g' package/base-files/files/bin/config_generate
sed -i "s/ImmortalWrt/HomeImm-Nikki/g" package/base-files/files/bin/config_generate

# 修改默认主题为 argon
# 已核实：luci-theme-bootstrap 依赖实际写在 feeds/luci/collections/luci-light/Makefile 里
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci-light/Makefile 2>/dev/null || true