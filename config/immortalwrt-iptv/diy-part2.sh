#!/bin/bash
#========================================================================================================================
# ImmortalWrt x86/64 —— HomeIPTV（192.168.10.77）编译后置脚本（feeds 更新之后执行）
# 运行目录：clone 下来的 openwrt/ 源码树
#
# 2026-09-15 重写。做了 5 件事：
#   1) root 默认口令（与两台旁路由同一套 md5crypt，三台一致便于维护）
#   2) 默认 IP → 192.168.10.77、主机名 → HomeIPTV
#   3) 默认主题 → argon（两种 collections 路径都兼容）
#   4) BBR + fq 的运行时默认值 → 写进 /etc/sysctl.conf
#   5) 把本套配置的 files/ 覆盖层塞进源码树（里面有首次启动脚本，负责 IPTV/msd_lite/docker 的全部默认设置）
#========================================================================================================================

# 本套配置所在目录。DIY 脚本的 cwd 是 openwrt/（clone 出来的源码树），所以 ../config 就是仓库里的 config 目录
REPO_CONFIG_DIR="../config/immortalwrt-iptv"

# ------------------------------- 1. root 默认口令 -------------------------------
# 现网三台口令哈希一致（$1$qTM.tEk0$…），这里保持同一套，避免"这台和那台不一样"
sed -i 's/root:::0:99999:7:::/root:$1$qTM.tEk0$J0I9VtO1JT99G4R2iZKaA.::0:99999:7:::/g' package/base-files/files/etc/shadow

# ------------------------------- 2. 默认 IP 与主机名 -------------------------------
# config_generate 负责首次启动生成 /etc/config/network，改它的默认值最稳（不会被 board.d 覆盖）
sed -i 's/192.168.1.1/192.168.10.77/g' package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt/HomeIPTV/g' package/base-files/files/bin/config_generate

# ------------------------------- 3. 默认主题 argon -------------------------------
# 25.12 的 luci 集合在 collections/luci-light，老分支在 collections/luci，两处都改，缺了就跳过
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci-light/Makefile 2>/dev/null || true

# ------------------------------- 4. BBR + fq 运行时默认值 -------------------------------
# 内核已内建（见 diy-part1.sh），这里把运行时默认值写进固件默认的 /etc/sysctl.conf。
# 写这个文件而不是 /etc/sysctl.d/*：base-files 自带的那个文件里就写着
#   "User defined entries should be added to this file not to /etc/sysctl.d/* as
#    that directory is not backed-up by default and will not survive a reimage"
# 而且实机 /etc/init.d/sysctl 的 start() 确实会遍历 /etc/sysctl.d/*.conf 和 /etc/sysctl.conf。
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
	echo "==> [IPTV] 警告：$SYSCTL_CONF 不存在，跳过 BBR 默认值"
fi

# ------------------------------- 5. 合并 files/ 覆盖层 -------------------------------
# files/ 是 OpenWrt 官方的"自定义文件"机制：<buildroot>/files/ 会被原样覆盖进固件根文件系统。
# 本套配置里的 files/etc/uci-defaults/99-homeiptv 就是首次启动脚本（配 IPTV 网卡 / msd_lite / docker 等）。
if [ -d "$REPO_CONFIG_DIR/files" ]; then
	mkdir -p files
	cp -a "$REPO_CONFIG_DIR/files/." files/
	# Windows 检出/手工复制过来的文件可能没有可执行位，而这几类文件必须是 +x 才能工作：
	#   etc/uci-defaults/*（只执行 +x 的脚本）、etc/init.d/*（init 脚本）、usr/libexec/rpcd/*（rpcd 插件）
	find files/etc/uci-defaults files/etc/init.d files/usr/libexec/rpcd \
		-type f -exec chmod 0755 {} + 2>/dev/null || true
	echo "==> [IPTV] 已合并 files/ 覆盖层："
	find files -type f | sed 's/^/      /'
else
	echo "==> [IPTV] 警告：$REPO_CONFIG_DIR/files 不存在，首次启动脚本不会被带上"
fi

echo "==> [IPTV] diy-part2 完成"
