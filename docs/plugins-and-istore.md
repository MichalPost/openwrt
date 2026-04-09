# OpenWrt 常用插件推荐与中英文对照（含 iStore 说明）

本文面向日常家用/旁路由/小型办公室场景，整理：

- **常用 LuCI 插件（包名）**的中英文/中文说明对照与适用场景
- **推荐搭配与避坑**（哪些二选一、哪些对存储/内存要求高）
- **iStore（`luci-app-store`）是否有中英文对照**以及语言切换逻辑

> 说明：OpenWrt 的“插件”通常指 LuCI 应用（`luci-app-*`）或其依赖服务包。不同发行版/第三方 feeds 的“菜单显示名”可能略有差异，但**包名（opkg 名称）**基本一致。

## iStore 商店是否有中英文对照？怎么切换语言？

### 结论

- **有**。iStore（`luci-app-store`）内置多语言，至少包含：
  - English（`en`）
  - 简体中文（`zh-cn`）
  - 繁体中文（`zh-tw`）
- iStore 前端会根据 LuCI 当前语言加载语言包 JSON，路径形如：
  - `/luci-static/istore/i18n/<lang>.json`
- 因此你在 LuCI 里切换语言后，iStore 页面也会跟随变更。

### 证据（上游实现）

- iStore 前端在页面注入 `window.vue_lang_data` 指向 `/luci-static/istore/i18n/<lang>.json`，并设置 `window.vue_lang` 为当前语言代码（来自上游 `linkease/istore` 的 `main.htm`）。
- iStore 的 i18n 体系（PO 文件、支持语言、分类翻译等）在 `linkease/istore` 的国际化文档中有明确说明（DeepWiki 索引）。

### 实操：在 LuCI 切换语言

- LuCI：`系统 → 系统 → 语言和界面`（不同主题/版本菜单名略有差异）
- 常见情况：
  - **英文固件想要中文**：安装 `luci-i18n-base-zh-cn`（以及你用到的插件的 `luci-i18n-*-zh-cn` 语言包，如果有）
  - **中文固件想要英文**：多数情况下英文是默认内置；若固件裁剪过语言资源，则需要安装对应 `luci-i18n-*` 的 `en` 语言包（是否存在取决于发行版打包方式）

## 常用插件（LuCI App）推荐清单（带对照与说明）

下面按“最常见、最好用”的思路挑选，优先列出 iStore/feeds 中最常见的包名。对照来源主要来自社区对照表整理（可用于快速搜索包名）。

### 1) 网络与基础服务（建议优先）

|用途|LuCI 包名（opkg）|中文常见叫法 / 说明|英文常见叫法|
|---|---|---|---|
|UPnP 端口转发|`luci-app-upnp`|UPnP（端口自动转发）|UPnP|
|动态域名|`luci-app-ddns`|动态 DNS（DDNS）|Dynamic DNS|
|网络唤醒|`luci-app-wol` / `luci-app-wolplus`|网络唤醒（WOL）|Wake on LAN|
|计划任务/定时重启|`luci-app-autoreboot`|计划重启|Scheduled Reboot|
|网页终端|`luci-app-ttyd`|TTYD 终端|Terminal (ttyd)|

### 2) DNS/去广告/隐私（非常常用）

> 建议只选一套“主 DNS 方案”，避免多套同时接管导致解析链条混乱。

|用途|LuCI 包名（opkg）|中文常见叫法 / 说明|英文常见叫法|
|---|---|---|---|
|广告拦截 DNS|`luci-app-adguardhome`|AdGuard Home 广告过滤|AdGuard Home|
|智能 DNS 加速|`luci-app-smartdns`|SmartDNS（多上游测速选优）|SmartDNS|
|DNS 过滤/规则|`luci-app-dnsfilter`|DNS 过滤器|DNS Filter|

#### DNS 方案（可切换 fragments）与冲突说明

本仓库的构建模型支持用 `configs/fragments/*.config` 组合出不同“DNS 体系”。为了避免冲突，建议遵循下面的选择逻辑：

- **daily 默认**：仅内置 AdGuard Home（`configs/fragments/adguard.config`），保持开箱即用的去广告体验。
- **可选 fragments（按需启用）**：
  - SmartDNS：`configs/fragments/dns-smartdns.config`
  - dnsmasq-full：`configs/fragments/dns-dnsmasq-full.config`
  - Unbound：`configs/fragments/dns-unbound.config`
- **常见冲突来源**：
  - 多个服务同时监听/接管 DNS（53 端口）或在 DHCP/DNS 劫持链路里互相覆盖
  - 同时启用多套“DNS 重写/广告过滤/递归解析”，导致上游/下游关系不清晰、排障困难

#### dnsmasq-full 策略模板（HTTPS/SVCB + ECS）

当工作流输入 `dns_policy` 选择 `dnsmasq-*` 时，会启用 `configs/fragments/dns-dnsmasq-full.config` 并在首启执行 `files/etc/uci-defaults/98-dns-policy`：

- `dnsmasq-balanced`（默认推荐）：启用现代 DNS 参数，ECS 仅做“提示式白名单”
- `dnsmasq-unlock`：解锁优先，更积极携带 ECS
- `dnsmasq-privacy`：隐私优先，关闭 ECS 侧信道

如果系统检测到 AdGuardHome/SmartDNS/Unbound 同时存在多套主 DNS 栈，脚本会自动跳过强制改写，避免链路冲突。

#### 允许的组合（示例：AdGuard Home 上游接 SmartDNS）

如果你确实想组合（例如 AdGuard 负责过滤，SmartDNS 负责上游测速选优），建议明确一条固定链路：

- **SmartDNS**：只作为上游解析器运行（监听本机端口），不要再额外接管 DHCP/劫持链路
- **AdGuard Home**：把上游 DNS 指向 SmartDNS（本机地址 + 端口），并确保“谁是最终对 LAN 提供的 DNS”这一点只有一个

### 3) 科学上网 / 代理分流（按生态二选一）

> 这类插件对 CPU/内存/存储较敏感，规则订阅也会带来额外开销。  
> 同一固件里不建议同时装太多“代理大套件”，优先**确定你要用 Clash 生态还是 Xray/V2Ray 生态**。

|用途|LuCI 包名（opkg）|中文常见叫法 / 说明|英文常见叫法|
|---|---|---|---|
|Clash 分流|`luci-app-openclash`|OpenClash|OpenClash|
|多协议代理（Xray 等）|`luci-app-passwall` / `luci-app-passwall2`|PassWall / PassWall2|PassWall|
|传统生态集合|`luci-app-ssr-plus`|SSR Plus+|ShadowsocksR Plus+|
|旁路/分流工具|`luci-app-bypass`|Bypass|Bypass|

### 4) 存储/NAS/下载（按需求选装）

|用途|LuCI 包名（opkg）|中文常见叫法 / 说明|英文常见叫法|
|---|---|---|---|
|磁盘管理|`luci-app-diskman`|磁盘管理（分区/挂载）|DiskMan|
|SMB 共享|`luci-app-samba4`|网络共享（Samba4）|Samba4|
|FTP|`luci-app-vsftpd`|FTP 服务器|FTP Server|
|DLNA|`luci-app-minidlna`|miniDLNA|miniDLNA|
|Aria2 下载|`luci-app-aria2`|Aria2 下载工具|Aria2|
|Transmission|`luci-app-transmission`|BT 下载（Transmission）|Transmission|
|qBittorrent|`luci-app-qbittorrent`|BT 下载（qBittorrent）|qBittorrent|

### 5) Docker（只装一个面板）

|用途|LuCI 包名（opkg）|中文常见叫法 / 说明|英文常见叫法|
|---|---|---|---|
|Docker 面板（推荐）|`luci-app-dockerman`|带控制面板的 Docker|Dockerman|
|Docker（无面板/简化）|`luci-app-docker`|不带控制面板的 Docker|Docker|

建议：`luci-app-dockerman` 与 `luci-app-docker` **通常二选一**；并且 Docker 更适合有足够存储空间（extroot/大闪存/硬盘）的机型。

### 6) 监控与统计（轻重分级）

|用途|LuCI 包名（opkg）|中文常见叫法 / 说明|英文常见叫法|
|---|---|---|---|
|带宽统计|`luci-app-nlbwmon`|网络带宽监视器|NLBWMon|
|实时流量|`luci-app-wrtbwmon`|实时流量监测|WRTBWMon|
|系统监控（重）|`luci-app-netdata`|实时监控（Netdata）|Netdata|

## SQM CAKE 模板（100M/300M/1G）

工作流输入 `sqm_tier` 会联动：

- 构建期：注入 `configs/fragments/sqm-cake-*.config`（确保 `sqm-scripts`、`kmod-sched-cake` 等依赖）
- 首启：`files/etc/uci-defaults/97-sqm-tier` 自动写入 `/etc/config/sqm`

默认参数（可在 LuCI 的 SQM 页面继续微调）：

|档位|下载(kbit/s)|上传(kbit/s)|qdisc|script|
|---|---:|---:|---|---|
|100M|95000|30000|cake|layer_cake.qos|
|300M|285000|80000|cake|layer_cake.qos|
|1G|850000|100000|cake|layer_cake.qos|

## 推荐的“最好用”搭配（按场景给组合）

### 家用基础（稳定优先）

- **基础**：`luci-app-upnp`、`luci-app-ddns`、`luci-app-autoreboot`、`luci-app-ttyd`
- **DNS 二选一**：
  - 轻量：`luci-app-smartdns`
  - 去广告：`luci-app-adguardhome`（再按需要叠加 SmartDNS，但务必理清上游/下游关系）

### 旁路由/分流（功能优先）

- **Clash 生态**：`luci-app-openclash`
- **Xray 生态**：`luci-app-passwall` 或 `luci-app-passwall2`
- **避坑**：不要同时把多个插件都设为“主透明代理/主 DNS 劫持”，否则很难定位问题。

### NAS/下载（存储优先）

- `luci-app-diskman` +（按需）`luci-app-samba4` / `luci-app-aria2` / `luci-app-qbittorrent`
- 若你的设备是 **128M 闪存**，强烈建议先做 extroot（你仓库 `docs/README.md` 已有说明），再安装重型服务。

## 快速检索技巧（中英文对照怎么用）

- **找包名**：看到“中文插件名/功能名”时，优先在对照表里找对应的 `luci-app-xxx` 包名
- **找菜单**：不同固件菜单翻译不同，**以包名为准**（iStore/软件包页面也以包名检索更稳）

## 参考与来源

- iStore 多语言/国际化说明（DeepWiki 索引 `linkease/istore`）：`https://deepwiki.com/linkease/istore/8-internationalization`
- iStore 前端加载语言 JSON 的实现（上游源码 `main.htm` raw）：`https://raw.githubusercontent.com/linkease/istore/7be7658d/luci/luci-app-store/luasrc/view/store/main.htm`
- OpenWrt LuCI 插件中英文对照表（社区整理）：`https://blog.wwang.pw/post/OpenWrt_LuCI`
- 插件中英文对照表（另一份快查版本）：`https://juejin.cn/post/7280436307914965032`

