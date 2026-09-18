#!/bin/bash
#========================================================================================================================
# ImmortalWrt x86/64 —— Nikki（Mihomo/sing-box 透明代理）编译前置脚本（feeds 更新之前执行）
# 运行目录：clone 下来的 openwrt/ 源码树（workflow「Load custom feeds」步骤里 cd openwrt 后调用本文件）
#
# 2026-09-18 第二次修正：BBR 改用 immortalwrt **官方 kmod-tcp-bbr 包**（.config 里已选
#   CONFIG_PACKAGE_kmod-tcp-bbr=y），不再靠改内核片段；本脚本只做「检查 + 打开 fq + 兜底」。
#
# 为什么不改内核片段（第一次就是这么挂的）：
#   net/ipv4/Kconfig 里 "Default TCP congestion control" 是 choice，成员 DEFAULT_BBR 的可见性写作
#   `bool "BBR" if TCP_CONG_BBR=y` —— 只有 **=y** 才可见。片段里本来只有 CONFIG_DEFAULT_CUBIC=y，
#   没有 DEFAULT_BBR 的保存值；一旦把它写成 =y，它就变成 kconfig 眼里的"新符号"，
#   syncconfig 走 "* Restart config... / choice[1-3?]:" 交互提问 → CI 无 stdin → EOF →
#   scripts/kconfig/Makefile:85 syncconfig Error 1 → target/linux failed to build（整轮白跑）。
#   走 **模块（=m）** 则不会让 DEFAULT_BBR 变可见 —— 这就是官方 kmod 包的天然优势。
#
# 官方 kmod 包的证据（package/kernel/linux/modules/netsupport.mk）：
#     define KernelPackage/tcp-bbr
#       KCONFIG:=CONFIG_TCP_CONG_BBR
#       FILES:=$(LINUX_DIR)/net/ipv4/tcp_bbr.ko
#       AUTOLOAD:=$(call AutoProbe,tcp_bbr)              # 开机自动加载，无需手工 modprobe
#     /etc/sysctl.d/12-tcp-bbr.conf                      # 包自带，内容是 net.ipv4.tcp_congestion_control=bbr
#
# 本脚本做两件事：
#   1) 检查源码树里还有没有 kmod-tcp-bbr：有 → 走包（正常路径）；没有 → 退回内核片段 =y 的老写法
#      （老写法已补上 choice 成员显式定值，本地用真实片段验证过）。
#   2) 打开 fq 队列（=y 内建），让 net.core.default_qdisc=fq 真的可用（BBR 官方推荐的配套队列）；
#      fq 的 choice 成员 DEFAULT_FQ 的守卫是 `if NET_SCH_FQ`（不带 =y，模块也算），
#      所以必须保证片段里有显式的 `# CONFIG_DEFAULT_FQ is not set`（片段本来就有一行，这里幂等覆盖）。
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

	# 只有缺少 kmod 时才把 BBR 写进内核片段（=y 内建）
	if [ "$KMOD_OK" = "0" ]; then
		sed -i -e '/^CONFIG_TCP_CONG_BBR=/d' \
		       -e 's/^# CONFIG_TCP_CONG_BBR is not set$/CONFIG_TCP_CONG_BBR=y/' "$f"
		grep -q '^CONFIG_TCP_CONG_BBR=y' "$f" || echo 'CONFIG_TCP_CONG_BBR=y' >> "$f"
	fi

	# fq 队列（BBR 的配套 pacing 队列）
	sed -i -e '/^CONFIG_NET_SCH_FQ=/d' \
	       -e 's/^# CONFIG_NET_SCH_FQ is not set$/CONFIG_NET_SCH_FQ=y/' "$f"
	grep -q '^CONFIG_NET_SCH_FQ=y' "$f" || echo 'CONFIG_NET_SCH_FQ=y' >> "$f"

	# 给"可能新出现的 choice 成员"显式定值，杜绝 kconfig 交互提问（幂等；kmod 路径下也无害）
	for sym in DEFAULT_FQ DEFAULT_BBR; do
		sed -i -e "/^CONFIG_${sym}=/d" -e "/^# CONFIG_${sym} is not set\$/d" "$f"
		echo "# CONFIG_${sym} is not set" >> "$f"
	done

	echo "==> [BBR] $f -> BBR(片段)=$(grep -c '^CONFIG_TCP_CONG_BBR=y' "$f") 行, FQ=$(grep -c '^CONFIG_NET_SCH_FQ=y' "$f") 行, choice 显式定值: DEFAULT_FQ=$(grep -c '^# CONFIG_DEFAULT_FQ is not set$' "$f") / DEFAULT_BBR=$(grep -c '^# CONFIG_DEFAULT_BBR is not set$' "$f")"
done
