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

#========================================================================================================================
# 默认启用 BBR + fq 队列  —— 2026-09-15 追加
# 内核已内建 BBR/fq（见 diy-part1.sh），这里把运行时默认值也写进固件。
#
# 写 /etc/sysctl.conf 而不是 /etc/sysctl.d/*：base-files 自带的那个文件里就写着
#   "User defined entries should be added to this file not to /etc/sysctl.d/* as
#    that directory is not backed-up by default and will not survive a reimage"
# 而且实机 /etc/init.d/sysctl 的 start() 确实是：
#   for CONF in /etc/sysctl.d/*.conf /etc/sysctl.conf; do sysctl -e -p "$CONF"; done
# 两个位置都会生效，但 /etc/sysctl.conf 会被 sysupgrade 保留。
# 如果将来不想默认启用 BBR，删掉本段即可（内核里仍然有 bbr，随时可 sysctl 打开）。
#========================================================================================================================
SYSCTL_CONF="package/base-files/files/etc/sysctl.conf"
if [ -f "$SYSCTL_CONF" ]; then
	if grep -q '^net.ipv4.tcp_congestion_control=bbr' "$SYSCTL_CONF"; then
		echo "==> [BBR] $SYSCTL_CONF 已含 BBR 配置，跳过"
	else
		{
			echo ''
			echo '# BBR 拥塞控制 + fq 队列（由 diy 脚本写入）'
			echo 'net.core.default_qdisc=fq'
			echo 'net.ipv4.tcp_congestion_control=bbr'
		} >> "$SYSCTL_CONF"
		echo "==> [BBR] 已写入 $SYSCTL_CONF"
	fi
	echo "==> [BBR] 末尾 4 行:"; tail -n 4 "$SYSCTL_CONF"
else
	echo "==> [BBR] 警告：$SYSCTL_CONF 不存在，跳过"
fi

# ------------------------------- 5. 合并 files/ 覆盖层 -------------------------------
# files/ 是 OpenWrt 官方的"自定义文件"机制：<buildroot>/files/ 会被原样覆盖进固件根文件系统。
# 本套配置里放的是自建的 BBR 页面 luci-app-bbr（菜单 / ACL / rpcd 后端 / 前端 JS），
# 以及首页诊断等辅助文件。
REPO_CONFIG_DIR="../config/imm-Nikki-2512"
if [ -d "$REPO_CONFIG_DIR/files" ]; then
	mkdir -p files
	cp -a "$REPO_CONFIG_DIR/files/." files/
	# Windows 检出/手工复制过来的文件没有可执行位，而这几类文件必须是 +x 才能工作：
	#   etc/uci-defaults/*  只执行 +x 的脚本
	#   etc/init.d/*        init 脚本
	#   usr/libexec/rpcd/*  rpcd 插件（我们的 BBR 后端就是它）
	find files/etc/uci-defaults files/etc/init.d files/usr/libexec/rpcd \
		-type f -exec chmod 0755 {} + 2>/dev/null || true
	echo "==> [Nikki] 已合并 files/ 覆盖层："
	find files -type f | sed 's/^/      /'
else
	echo "==> [Nikki] 警告：$REPO_CONFIG_DIR/files 不存在，BBR 页面不会被带上"
fi

echo "==> [Nikki] diy-part2 完成"