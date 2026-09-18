#!/bin/bash
#========================================================================================================================
# ImmortalWrt x86/64 —— HomeIPTV（192.168.10.77）编译前置脚本（feeds 更新之前执行）
# 运行目录：clone 下来的 openwrt/ 源码树（workflow「Load custom feeds」步骤里 cd openwrt 之后调用本文件）
#
# 2026-09-18 修正：BBR 改用 immortalwrt **官方 kmod-tcp-bbr 包**（.config 里已选
#   CONFIG_PACKAGE_kmod-tcp-bbr=y），不再靠改内核片段；与 Nikki 那份脚本同一套逻辑。
#
# 为什么不改内核片段（Nikki 第一次构建就是这么挂的）：
#   net/ipv4/Kconfig 里 "Default TCP congestion control" 是 choice，成员 DEFAULT_BBR 可见性写作
#   `bool "BBR" if TCP_CONG_BBR=y`（只有 =y 才可见）。片段里只有 CONFIG_DEFAULT_CUBIC=y，
#   把它写成 =y 会让 DEFAULT_BBR 变成"新符号" → syncconfig 交互提问 → CI 无 stdin → EOF →
#   scripts/kconfig/Makefile:85 syncconfig Error 1 → target/linux failed to build。
#   走 **模块（=m）** 不会让 DEFAULT_BBR 变可见 —— 官方 kmod 包天然避开这个坑。
#
# 官方 kmod 包的证据（package/kernel/linux/modules/netsupport.mk 的 KernelPackage/tcp-bbr）：
#   KCONFIG:=CONFIG_TCP_CONG_BBR、FILES:=net/ipv4/tcp_bbr.ko、AUTOLOAD 自动加载，
#   并且包里自带 /etc/sysctl.d/12-tcp-bbr.conf（内容 net.ipv4.tcp_congestion_control=bbr）。
#
# 本脚本：① 检查有没有 kmod-tcp-bbr（没有就退回"内核片段 =y + choice 显式定值"的兜底写法）；
#        ② 打开 fq 队列（=y 内建），让 net.core.default_qdisc=fq 可用，并保证 DEFAULT_FQ 有显式值。
#========================================================================================================================
KMOD_OK=0
if grep -qs 'KernelPackage/tcp-bbr' package/kernel/linux/modules/netsupport.mk; then
	KMOD_OK=1
	echo "==> [BBR] 走官方 kmod 路径：kmod-tcp-bbr 存在（=m 模块 + AUTOLOAD 自动加载 + 自带 sysctl.d 设 bbr）"
else
	echo "==> [BBR] 警告：源码树里没有 kmod-tcp-bbr，退回内核片段补丁（CONFIG_TCP_CONG_BBR=y 内建）"
fi

for f in target/linux/generic/config-[0-9]* target/linux/x86/config-[0-9]*; do
	[ -f "$f" ] || continue

	if [ "$KMOD_OK" = "0" ]; then
		sed -i -e '/^CONFIG_TCP_CONG_BBR=/d' \
		       -e 's/^# CONFIG_TCP_CONG_BBR is not set$/CONFIG_TCP_CONG_BBR=y/' "$f"
		grep -q '^CONFIG_TCP_CONG_BBR=y' "$f" || echo 'CONFIG_TCP_CONG_BBR=y' >> "$f"
	fi

	sed -i -e '/^CONFIG_NET_SCH_FQ=/d' \
	       -e 's/^# CONFIG_NET_SCH_FQ is not set$/CONFIG_NET_SCH_FQ=y/' "$f"
	grep -q '^CONFIG_NET_SCH_FQ=y' "$f" || echo 'CONFIG_NET_SCH_FQ=y' >> "$f"

	for sym in DEFAULT_FQ DEFAULT_BBR; do
		sed -i -e "/^CONFIG_${sym}=/d" -e "/^# CONFIG_${sym} is not set\$/d" "$f"
		echo "# CONFIG_${sym} is not set" >> "$f"
	done

	echo "==> [BBR] $f -> BBR(片段)=$(grep -c '^CONFIG_TCP_CONG_BBR=y' "$f") 行, FQ=$(grep -c '^CONFIG_NET_SCH_FQ=y' "$f") 行, choice 显式定值: DEFAULT_FQ=$(grep -c '^# CONFIG_DEFAULT_FQ is not set$' "$f") / DEFAULT_BBR=$(grep -c '^# CONFIG_DEFAULT_BBR is not set$' "$f")"
done
