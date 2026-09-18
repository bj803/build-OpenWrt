#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt
# Function: Diy script (Before Update feeds, Modify the default IP, hostname, theme, add/remove software packages, etc.)
# Source code repository: https://github.com/immortalwrt/immortalwrt / Branch: master
#========================================================================================================================

# Add a feed source
# sed -i '$a src-git lienol https://github.com/Lienol/openwrt-package' feeds.conf.default

# other
# rm -rf package/emortal/{autosamba,ipv6-helper}
# rm -rf package/emortal/{autosamba}

#========================================================================================================================
# 开启 BBR 拥塞控制 + fq 队列（内核内建）  —— 2026-09-15 追加
#
# 背景：现网固件的 sysctl net.ipv4.tcp_available_congestion_control = "reno cubic"，
#       modprobe tcp_bbr 返回 255 且 /lib/modules 下没有该模块 —— 说明这个内核**没有编译 BBR**。
#       所以 BBR 不是 sysctl / uci 能打开的，必须在编译期打开内核选项后重编固件。
#
# 为什么改内核 config 片段、而不是写进 .config：
#       OpenWrt 的内核选项来自 target/linux/**/config-<版本> 这些片段文件；
#       include/kernel-defaults.mk 虽然支持把 .config 里的 CONFIG_KERNEL_xxx 映射成内核选项，
#       但 config/Config-kernel.in 里**没有** KERNEL_TCP_CONG_* / KERNEL_NET_SCH_FQ 的符号定义，
#       写在 .config 里会被 make defconfig 丢掉，因此必须直接改片段文件。
#
# 加两项（都用 =y 内建；=m 的模块只有被 kmod 包声明才会进镜像，这里没有对应包）：
#       CONFIG_TCP_CONG_BBR=y   拥塞控制算法本体
#       CONFIG_NET_SCH_FQ=y     BBR 官方配套的 fq 排队/整流（本固件原本只有 fq_codel）
# 幂等：重复执行不会产生重复行。
#========================================================================================================================
for f in target/linux/generic/config-[0-9]* target/linux/x86/config-[0-9]*; do
	[ -f "$f" ] || continue
	sed -i -e '/^CONFIG_TCP_CONG_BBR=/d' -e '/^CONFIG_NET_SCH_FQ=/d' \
	       -e 's/^# CONFIG_TCP_CONG_BBR is not set$/CONFIG_TCP_CONG_BBR=y/' \
	       -e 's/^# CONFIG_NET_SCH_FQ is not set$/CONFIG_NET_SCH_FQ=y/' "$f"
	grep -q '^CONFIG_TCP_CONG_BBR=y' "$f" || echo 'CONFIG_TCP_CONG_BBR=y' >> "$f"
	grep -q '^CONFIG_NET_SCH_FQ=y' "$f" || echo 'CONFIG_NET_SCH_FQ=y' >> "$f"
	echo "==> [BBR] $f -> BBR=$(grep -c '^CONFIG_TCP_CONG_BBR=y' "$f") 行, FQ=$(grep -c '^CONFIG_NET_SCH_FQ=y' "$f") 行"
done
