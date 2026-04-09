# N60PRO OpenWrt/ImmortalWrt GitHub Actions 自动构建

本仓库用于 **磊科 Netcore N60 Pro** 的 OpenWrt/ImmortalWrt 固件自动化编译（GitHub Actions）。

## 目标

- 使用 237/ImmortalWrt（mt798x）源码进行编译
- 提供 **日常版**（保证日常体验 + 常用好用插件）
- 日常版默认集成 **iStore（luci-app-store）**，刷机后无需手动敲 `opkg` 即可在后台使用商店
- 支持 attendedsysupgrade 在线升级（保留配置）工作流与设备端默认配置
- 提供 DNS/SQM 策略模板：dnsmasq-full（HTTPS/SVCB + ECS 策略）与 CAKE（100M/300M/1G）
- 产物以 Actions Artifact（可选 Release）形式提供下载

## 文档

- `docs/plugins-and-istore.md`：常用插件推荐（中英文对照）+ iStore 商店是否支持中英文与切换说明

## 目录结构

- `.github/workflows/build-n60pro.yml`：主工作流
- `configs/`：构建配置片段（fragments）
  - `nx60pro-512m.override`：512M 闪存改版的目标/设备选择覆盖片段（可选）
- `configs/fragments/`：**日常版（daily）**所用的配置片段组合
- `scripts/`：构建过程中的自定义脚本
  - `diy-part1.sh`：公共自定义（feeds、通用改动）
  - `diy-part-n60pro.sh`：N60PRO 相关定制（可选插件、默认值等）
  - `post-build.sh`：编译后处理（重命名、整理输出）

## 使用方式（高层）

1. 将本仓库推送到你的 GitHub 账号下
2. 进入 GitHub 仓库的 `Actions`，运行 `构建 N60PRO 固件`
3. 在构建完成页面下载 `Artifacts` 中固件

> 注意：编译 OpenWrt 需要大量时间和磁盘。首次编译可能 1~2 小时或更久，后续启用缓存会快很多。

## 新增构建输入（在线升级 + DNS/SQM）

- `attendedsysupgrade`：`true/false`，控制是否生成 ASU 元数据并在固件中预装在线升级客户端默认项
- `dns_policy`：
  - `adguard`：保持 daily 默认 AdGuardHome DNS 方案
  - `dnsmasq-balanced`：dnsmasq-full 平衡策略（默认仅提示 ECS 白名单）
  - `dnsmasq-unlock`：dnsmasq-full 解锁优先（更积极 ECS）
  - `dnsmasq-privacy`：dnsmasq-full 隐私优先（关闭 ECS 侧信道）
- `sqm_tier`：`none/100m/300m/1g`，按带宽档位注入 CAKE 参数模板

## 在线保配置升级（attendedsysupgrade）

- CI 侧：
  - 在 `out/asu/metadata.json` 产出 sysupgrade 镜像清单、sha256、大小与构建参数
  - 与 `manifest.txt`、`sha256sums` 一起随 Artifact/Release 发布
- 设备侧：
  - 首启脚本会在存在 `/etc/config/attendedsysupgrade` 时写入安全默认项（保留配置/保留软件包、关闭危险强制升级）
  - 若未包含对应包，脚本会自动跳过，不影响首启流程

## feeds 锁定（feeds_lock）：推荐组合与回滚方法

工作流输入 `feeds_lock` 支持把指定 feed 锁定到某个 commit/tag（形如 `name=<sha>`，多个用逗号分隔）。

### 推荐锁定组合（模板）

> 说明：哪些 feed 存在取决于你的 `feeds.conf.default`（本仓库默认在 `scripts/diy-part1.sh` 里追加了 iStore/OpenClash/PassWall2 相关 feeds）。

- iStore 生态（建议一起锁定，避免 API/依赖不一致）：
  - `istore=<sha>,nas=<sha>,nas_luci=<sha>`
- 代理生态（按你使用的生态锁定其一或两套）：
  - Clash：`openclash=<sha>`
  - PassWall2：`passwall_packages=<sha>,passwall2=<sha>`

### 如何回滚/取消锁定

- **取消锁定**：重新运行工作流，`feeds_lock` 留空（默认跟随各 feed 的分支 HEAD）。
- **回滚到旧版本**：把 `<sha>` 替换为你想回退到的 commit/tag，再运行一次即可。

### 如何确认“最终生效的锁定结果”

构建产物 `out/manifest.txt` 会包含：

- `[feeds_lock_requested]`：你在工作流里输入的原始 `feeds_lock` 字符串
- `[feeds_lock_effective]`：对每个 requested feed 写出最终 HEAD（即本次构建实际使用的 commit）
- `[feeds]`：所有 feeds 的 HEAD（全量清单，用于排查非锁定项的漂移）

## 配置模型（重要）

工作流会按以下顺序生成最终 `.config`：

1. `cp defconfig/nx60pro-ipailna-high-power.config .config`（高功率 defconfig 作为基底）
2. 追加 `configs/fragments/*.config`（日常版由多个 **片段** 组合，不覆盖基底）
3. 若选择 `mod-512m`，再追加 `configs/nx60pro-512m.override`
4. `make defconfig` 让 Kconfig 补齐依赖与默认值

## 可选 fragments（按需启用）

默认 daily 只选择一套“稳态日常体验”的 fragments；下面这些属于 **按需启用**：

- **MultiWAN（mwan3）**：`configs/fragments/multiwan-mwan3.config`（双 WAN/多出口策略路由与故障切换）
- **DNS 可选方案**：`configs/fragments/dns-*.config`（SmartDNS / dnsmasq-full / unbound 等，详见 `docs/plugins-and-istore.md` 的 DNS 章节）
- **SQM CAKE 档位模板**：
  - `configs/fragments/sqm-cake-100m.config`
  - `configs/fragments/sqm-cake-300m.config`
  - `configs/fragments/sqm-cake-1g.config`
  - 配合首启脚本 `files/etc/uci-defaults/97-sqm-tier` 自动写入 `/etc/config/sqm`
- **Wi‑Fi tuning**：`configs/fragments/wifi-tuning.config`（配合 `files/etc/uci-defaults/98-wifi-tuning` 的首启默认值）
- **PassWall2 后端预装（可选）**：
  - `configs/fragments/passwall2-backend-sing-box.config`
  - `configs/fragments/passwall2-backend-xray.config`
  - 通过工作流输入 `passwall2_backend` 选择 `none` / `sing-box` / `xray` / `dual`
- **PassWall2 开箱预设（可选）**：
  - `configs/fragments/passwall2-backend-minimal.config`（常用 geo/诊断工具）
  - 通过工作流输入 `passwall2_preset` 选择 `base` / `minimal`

## 128M 闪存 + U 盘扩容（extroot 到 /overlay）

适用场景：你保持 **stock-128m（原厂 128M 闪存）**，但希望安装更多插件，把 overlay 扩展到 U 盘（extroot）。

### 推荐做法（最省事）

- **把 U 盘做成 1 个 ext4 分区**，并设置分区卷标为 **`OWRT_OVERLAY`**。
  - Windows 可用 DiskGenius：分区表 GPT，分区 ext4，卷标 `OWRT_OVERLAY`。
- 把 U 盘插到路由器 USB 口，开机后首次进入系统。
- 本仓库内置的 `/etc/uci-defaults/99-n60pro-defaults` 会在首启时尝试：
  - 找到卷标为 `OWRT_OVERLAY` 的 ext4 分区
  - 自动写入 `/etc/config/fstab`，将该分区设置为外置 `/overlay`
  - 若已有插件/配置，会尽量把当前 `/overlay` 内容迁移到 U 盘
  - **提示重启后生效**
  - （增强）若 U 盘上还有其它分区，会尽量自动写入挂载点到 `/mnt/sdXN`（例如 `/mnt/sda1`）
  - （可选）若检测到 swap 分区，会尽量自动写入并启用；也支持在 zram 相关 init 脚本存在时按需启用 zram（见脚本内环境变量）

### 如果你已经装了一堆插件（手动迁移要点）

如果自动迁移没覆盖你的情况，可按社区常见方法手动迁移（SSH）：先把 U 盘分区挂到 `/mnt`，再把 `/overlay` 内容拷过去，最后在 `挂载点` 里把该分区设为「作为外部 /overlay 使用」，重启即可。

### 验证是否生效

- 重启后 SSH 执行 `mount`，应看到 `/overlay` 来自 `/dev/sdX1`（或对应 UUID 的设备）。
- LuCI：`系统 → 挂载点` 里能看到 `/overlay` 的挂载项。

