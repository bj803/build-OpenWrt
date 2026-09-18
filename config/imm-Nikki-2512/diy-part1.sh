#!/bin/bash
#========================================================================================================================
# ImmortalWrt x86/64 —— Nikki（Mihomo/sing-box 透明代理）编译前置脚本（feeds 更新之前执行）
# 运行目录：clone 下来的 openwrt/ 源码树（workflow「Load custom feeds」步骤里 cd openwrt 后调用本文件）
#
# 2026-09-18 修正版：第一次加 BBR 的构建（run 35293926108）在 target/linux 阶段失败，
# 根因与修法写在下面 BBR 段的 ★ 注释里（务必连注释一起看，别再只加一行 TCP_CONG_BBR=y）。
#========================================================================================================================

#========================================================================================================================
# 开启 BBR 拥塞控制 + fq 队列（内核内建 =y）
#
# 背景：现网固件 sysctl net.ipv4.tcp_available_congestion_control = "reno cubic"，
#       modprobe tcp_bbr 返回 255，/lib/modules 下没有 tcp_bbr 模块 —— 内核没编译 BBR，
#       sysctl / uci 都打不开，只能重编固件。
#
# 为什么改 target/linux/**/config-<版本> 片段、而不是写进 .config：
#       内核选项来自这些片段文件（include/kernel-defaults.mk:114 的 $(LINUX_CONF_CMD)、
#       include/kernel-build.mk:128 依赖的 $(LINUX_KCONFIG_LIST)）；
#       而 config/Config-kernel.in 里没有 KERNEL_TCP_CONG_* / KERNEL_NET_SCH_FQ 的定义，
#       写进 .config 会被 make defconfig（实为 scripts/config/conf --defconfig，其 confdata.c 对
#       未知符号 conf_warning + continue、不写回）静默丢掉。
#
# ★ 关键坑（2026-09-18 那次构建就是死在这里；只改 TCP_CONG_BBR 一行会整轮白跑）：
#       net/ipv4/Kconfig 里 "Default TCP congestion control" 是个 choice，成员 DEFAULT_BBR 的可见性写作
#       `bool "BBR" if TCP_CONG_BBR=y` —— 只有 TCP_CONG_BBR=y 时它才出现。片段里当时只有
#       `CONFIG_DEFAULT_CUBIC=y`，**没有** DEFAULT_BBR 的任何保存值（那会儿它不可见）。
#       于是打开 BBR 之后，DEFAULT_BBR 在 kconfig 眼里是"新符号"，syncconfig 会走
#       "* Restart config... / Default TCP congestion control / choice[1-3?]:" 交互提问；
#       CI 里没有 stdin → EOF → scripts/kconfig/Makefile:85 syncconfig Error 1 →
#       include/config/auto.conf.cmd 生成失败 → target/linux failed to build（world Error 2）。
#       对照组（就是解法本身）：同样新暴露出来的 DEFAULT_FQ 没被标成 (NEW)，因为片段里本来就有
#       `# CONFIG_DEFAULT_FQ is not set`（第 1384 行）—— 说明"给新成员一个显式值"就能避开交互提问。
#       因此这里补 `# CONFIG_DEFAULT_BBR is not set`：内核默认仍是 cubic，
#       运行时的 bbr 交给 diy-part2.sh 写进 /etc/sysctl.conf（net.ipv4.tcp_congestion_control=bbr）。
#       顺便把 DEFAULT_FQ 也用同样方式定死一遍（片段里已有该行，属幂等覆盖，防上游改动）。
#========================================================================================================================
for f in target/linux/generic/config-[0-9]* target/linux/x86/config-[0-9]*; do
	[ -f "$f" ] || continue

	# 1) 打开 BBR 与 fq（=y 内建；=m 的模块没有对应 kmod 包，不会进镜像）
	sed -i -e '/^CONFIG_TCP_CONG_BBR=/d' -e '/^CONFIG_NET_SCH_FQ=/d' \
	       -e 's/^# CONFIG_TCP_CONG_BBR is not set$/CONFIG_TCP_CONG_BBR=y/' \
	       -e 's/^# CONFIG_NET_SCH_FQ is not set$/CONFIG_NET_SCH_FQ=y/' "$f"
	grep -q '^CONFIG_TCP_CONG_BBR=y' "$f" || echo 'CONFIG_TCP_CONG_BBR=y' >> "$f"
	grep -q '^CONFIG_NET_SCH_FQ=y' "$f" || echo 'CONFIG_NET_SCH_FQ=y' >> "$f"

	# 2) 给"因为上面两行而新出现的 choice 成员"显式定值，避免 kconfig 交互提问（见 ★）
	for sym in DEFAULT_BBR DEFAULT_FQ; do
		sed -i -e "/^CONFIG_${sym}=/d" -e "/^# CONFIG_${sym} is not set\$/d" "$f"
		echo "# CONFIG_${sym} is not set" >> "$f"
	done

	echo "==> [BBR] $f -> BBR=$(grep -c '^CONFIG_TCP_CONG_BBR=y' "$f") 行, FQ=$(grep -c '^CONFIG_NET_SCH_FQ=y' "$f") 行, 新成员显式定值: $(( $(grep -c '^# CONFIG_DEFAULT_BBR is not set$' "$f") + $(grep -c '^# CONFIG_DEFAULT_FQ is not set$' "$f") )) 行"
	echo "==> [BBR] 内核默认拥塞控制仍为: $(grep -m1 '^CONFIG_DEFAULT_TCP_CONG=' "$f")（$(grep -m1 '^CONFIG_DEFAULT_CUBIC=y' "$f" || echo '注意：没找到 CONFIG_DEFAULT_CUBIC=y')）"
done
