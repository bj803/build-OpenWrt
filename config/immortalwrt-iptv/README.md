# immortalwrt-iptv —— HomeIPTV（192.168.10.77）固件配置

这套配置用来编译 **10.77 那台「IPTV / Docker / xteve」业务机**的固件。
2026-09-15 按现网实机逐项核对后重写（原来那份 7436 行的完整 `.config` dump 已替换为可维护的写法）。

## 这台机器要干什么

| 项目 | 现网实况（采集自 192.168.10.77） |
|---|---|
| 平台 | ImmortalWrt x86/64，ESXi 虚拟机（J4125） |
| 网卡 | `eth0` = 192.168.10.77/24（内网，网关 192.168.10.1）<br>`eth1` = 192.168.100.103/24（运营商 IPTV 侧，网关 192.168.100.1） |
| IPTV | **msd_lite** 把 IGMP 组播转成 HTTP：`192.168.10.77:23234`（`udpxy` 装了但默认关） |
| 容器 | **docker + dockerman**，数据根 `/opt/docker`（`/opt` = 独立数据盘 `sdb1`，ext4，现有 622 MB）<br>容器：`IPTV` = `alturismo/xteve_guide2go:latest`，另跑宿主机 `xteve -port=34400` |
| 磁盘 | `sda1` 128M vfat `/boot`、`sda2` 1G squashfs `/rom` + f2fs `/overlay`（与 `.config` 里的 128/1024 一致） |
| 其它 | `ttyd` 网页终端（`/bin/login`）、`lm-sensors`、`autocore`、argon 主题、`default-settings-chn` |

## 文件清单

| 文件 | 作用 |
|---|---|
| `config` | 目标平台 + 镜像选项 + 要装的包（117 行，含注释；其余交给 `make defconfig`） |
| `feeds.conf.default` | feeds 来源，分支钉在 `openwrt-25.12`（必须与 workflow 的 `REPO_BRANCH` 一致） |
| `diy-part1.sh` | feeds 更新前执行：**打开内核 BBR + fq**（改 `target/linux/**/config-<版本>` 片段） |
| `diy-part2.sh` | feeds 更新后执行：root 口令、默认 IP/主机名、argon 主题、BBR 运行时默认值、合并 `files/` |
| `files/etc/uci-defaults/99-homeiptv` | **首次启动脚本**：自动配好 IPTV 网卡、msd_lite、docker、dnsmasq、LuCI 中文等 |
| `.github/workflows/Build_Imm_IPTV_2512.yml` | 编译流水线（原仓库里没有任何 workflow 引用本目录，这次补上） |

## 怎么构建

**方式一（推荐）**：GitHub → Actions → **Build Imm IPTV 2512** → `Run workflow`。
日志里搜 `[BBR]` 和 `[IPTV]` 可以看到自检输出：

```
==> [BBR] target/linux/generic/config-6.12 -> BBR=1 行, FQ=1 行
==> [BBR] target/linux/x86/config-6.12 -> BBR=1 行, FQ=1 行
==> [BBR] 已写入 package/base-files/files/etc/sysctl.conf
==> [IPTV] 已合并 files/ 覆盖层：
      files/etc/uci-defaults/99-homeiptv
```

**方式二**：本地 Linux 构建

```sh
git clone https://github.com/immortalwrt/immortalwrt -b openwrt-25.12 --depth=1 openwrt
cd openwrt
cp ../build-OpenWrt-main/config/immortalwrt-iptv/feeds.conf.default feeds.conf.default
./scripts/feeds update -a
../build-OpenWrt-main/config/immortalwrt-iptv/diy-part1.sh   # 注意 cwd 必须是 openwrt/
../build-OpenWrt-main/config/immortalwrt-iptv/diy-part2.sh
./scripts/feeds install -a
cp ../build-OpenWrt-main/config/immortalwrt-iptv/config .config
make defconfig && make -j$(nproc)
```

产物：`bin/targets/x86/64/*-squashfs-combined-efi.img.gz`（EFI 整盘镜像，直接写盘/写虚拟磁盘）。

## 固件开机后会自动变成什么样

首次启动时 `/etc/uci-defaults/99-homeiptv` 会执行一次（之后自动删除），把下面这些落到位：

| 项 | 值 |
|---|---|
| 主机名 / 时区 | `HomeIPTV` / `Asia/Shanghai`（NTP 用 tencent + aliyun + ntsc + cn.ntp.org.cn） |
| `eth0` | `192.168.10.77/24`，网关 `192.168.10.1`，**不做 DHCP 服务器**（本机是固定 IP 客户端） |
| `eth1` | `192.168.100.103/24`，网关 `192.168.100.1`（只有检测到 `eth1` 才创建） |
| dnsmasq | 上游 `223.5.5.5` / `1.1.1.1`、`cachesize 8000`、`min_cache_ttl 3600`、`use_stale_cache 3600`、`rebind_protection 1`、`localservice 1`、`dns_redirect 1`（与两台旁路由对齐） |
| msd_lite | 启用，`network=iptv`，监听 `192.168.10.77:23234` 与 `[::]:23234` |
| udpxy / ttyd | udpxy 默认 `disabled=1`；ttyd 只听 `@lan`，命令 `/bin/login` |
| docker | 数据根 `/opt/docker/`、`iptables=0`、镜像加速 `hub-mirror.c.163.com`、**`auto_start=1`**（改用官方开关，不再用 `rc.local` 里 `sleep 60` 的竞态 hack） |
| `/opt` 挂载 | 按 UUID `bcf51219-…-7a5d6c50bb42` 自动挂载（没这块盘就跳过，交给 automount） |
| LuCI | 默认中文 + argon 主题 |
| 内核 | **BBR + fq**：`net.ipv4.tcp_congestion_control=bbr`、`net.core.default_qdisc=fq`（由 `diy-part1/2` 带上） |

## 刷完机怎么验

```sh
# 1) BBR 真的在（刷机前这里是 reno cubic / cubic / fq_codel）
sysctl net.ipv4.tcp_available_congestion_control   # 期望 reno cubic bbr
sysctl net.ipv4.tcp_congestion_control             # 期望 bbr
sysctl net.core.default_qdisc                      # 期望 fq
grep -i bbr /lib/modules/$(uname -r)/modules.builtin

# 2) 网络与 IPTV
ip -4 addr show | grep inet                        # eth0=10.77  eth1=100.103
uci show msd_lite | grep -E 'enabled|address|network'
/etc/init.d/msd_lite status                        # 期望 running
wget -qO- http://192.168.10.77:23234/status | head  # msd_lite 状态页

# 3) 拉一路组播试试（把 <组播地址:端口> 换成你的频道，例如 rtp://239.x.x.x:xxxx）
#    cd 到支持 msd_lite 的播放器，源填：http://192.168.10.77:23234/rtp/<239.x.x.x>:<port>

# 4) Docker
/usr/local/bin/docker ps -a     # 或 docker ps -a；期望看到 IPTV 容器，数据在 /opt/docker
df -h /opt                       # 期望挂到独立数据盘
```

## 注意事项 / 已知取舍

1. **`/opt` 的 UUID 是这台机器数据盘的**。换盘或换机器要改 `files/etc/uci-defaults/99-homeiptv` 里的 `OPT_UUID`，否则 `/opt` 不会自动挂载、docker 数据会落到 overlay（overlay 只有 ~950 MB，装不下几个镜像）。
2. **IPTV 侧的 `192.168.100.103` 是静态写死的**（与现网一致）。如果运营商换了网段/地址，改同一个脚本里的四行即可。
3. **`eth1` 必须是第二块网卡**：脚本用 `[ -e /sys/class/net/eth1 ]` 判断，单网卡时不会创建 iptv 接口，机器照常可管理。
4. **msd_lite 仍然监听 `[::]:23234`（全接口）**，包括运营商那侧 —— 与现网一致。想收紧就删掉那一行 `list address`，只留 `192.168.10.77:23234`（这就是核查报告里 P3 提到的加固点）。
5. **uhttpd 只开 HTTP 80**，不配 443：现网是「配了 443 但没证书、实际没监听」，属于配置与实现不一致；要用 HTTPS 就在 LuCI「系统 → 管理权 → HTTP(S) 访问」生成证书。
6. **默认口令**沿用你们三台一致的那套哈希（写在 `diy-part2.sh`）。release 页面里**没有**写明文口令（与另几个 workflow 不同，是有意改的）。
7. 这份固件**不做透明代理**，不需要 nikki/passwall feed。
8. **docker 的桥与防火墙规则是自动的**：25.12 的 `dockerd` init 首次启动会执行 `uciadd`，自动往 `/etc/config/network` 加 `docker` 接口 + `docker0` 网桥、往 `/etc/config/firewall` 加 `docker` zone（input/output/forward 均 ACCEPT）。所以看到这两个 zone 属正常现象，不用手工加。
9. **不需要 `rc.local`**：现网那份 `/etc/rc.local` 里的 `sleep 60 && /etc/init.d/dockerd restart` 是竞态规避的临时手段，新固件靠 init 自身启动 + fstab 先挂 `/opt`（`S11fstab` 早于 `S99dockerd`）来保证顺序。

## 想改用 openwrt-24.10（内核 6.6 / opkg）？

只改两处，其余不用动（`.config` 特意写成不依赖内核版本 / 包管理器）：

1. `feeds.conf.default` 里 5 行的 `;openwrt-25.12` → `;openwrt-24.10`
2. workflow 里 `REPO_BRANCH: openwrt-25.12` → `openwrt-24.10`

`diy-part1.sh` 的内核片段补丁用的是 `config-[0-9]*` 通配符，对 `config-6.6` 一样生效。
