# NetConsole 独立管理台 — Pencil 设计交付说明

## 源文件与导出

- **Pencil 源稿**：设计已通过 MCP 写入 **当前 Cursor 内的 Pencil 会话**（编辑器标题多为 `pencil-new.pen`）。请在本机 Pencil 画板中执行 **另存为 / Save As**，保存到仓库路径 **`e:\Code\openwrt\design\admin-ui.pen`**，便于纳入 Git 与协作。勿用文本编辑器直接编辑 `.pen`。
- **PNG 导出**（2x）：[`exports/`](exports/)
  - `OemNP.png` — 登录
  - `kvfmB.png` — 桌面总览（App Shell + 仪表盘）
  - `whX5S.png` — 设置表单（WAN/PPPoE 示例）
  - `StaoI.png` — DHCP 客户端表格
  - `kC0Er.png` — 小屏：抽屉打开 + 堆叠 KPI + 横滑表格示意 + 客户端卡片
  - `LIHxn.png` — 组件库画板（按钮、输入、导航项、标签）

## 画板结构（顶层 Frame 名称）

| 名称 | 用途 |
|------|------|
| `01_Login` | 品牌侧栏 + 登录卡片（含错误态、2FA 占位、记住本机） |
| `_DesignSystem` | 可复用组件：`DS_ButtonPrimary`、`DS_ButtonOutline`、`DS_Input`、`DS_NavItem`、`DS_TagSuccess` / `Warning` / `Error` |
| `02_Dashboard_Desktop` | 侧栏导航 + KPI + 流量示意 + 事件列表 + 快捷操作 |
| `03_Settings_Form` | 分组表单 + 校验错误 + 开关 + 底部操作条 |
| `04_DHCP_Clients_Table` | 工具栏 + 表头/数据行 + 分页 + 空状态示意 |
| `05_Mobile_DrawerOpen` | 抽屉导航 + 窄区「主内容」预览（420×780，避免过窄裁切） |

美学基准：**Soft Bento · Carbon Frost**（`get_guidelines`），并叠加网络管理场景语义色（成功/告警/错误/信息）。

## 设计变量 → 前端（`:root` / Tailwind v4）

从 Pencil `get_variables` 同步到 CSS 时，建议如下命名（单值放 `:root`，字体栈放在 `@layer base` 工具类，见 Pencil Tailwind 指南）：

| Pencil 变量 | 建议 CSS 自定义属性 | 用途 |
|-------------|---------------------|------|
| `background` | `--color-background` | 页面底 `#F7F8FA` |
| `card` | `--color-card` | 卡片/面板白底 |
| `foreground` | `--color-foreground` | 主文案 |
| `mutedForeground` | `--color-muted-foreground` | 次要说明 |
| `border` | `--color-border` | 描边/分割线 |
| `primary` | `--color-primary` | 主按钮、强调、侧栏激活态 |
| `destructive` | `--color-destructive` | 错误描边、危险操作 |
| `success` | `--color-success` | 正向趋势、成功标签 |
| `warning` | `--color-warning` | 告警标签、staging 胶囊 |
| `info` | `--color-info` | 链接色、IPv4 等数据强调 |

**圆角节奏（稿面示意）**：卡片/大容器约 **12–16px**，输入/按钮约 **8–10px**，胶囊 **full**。

**字体**：稿面以 **Inter** 渲染为主；实现时可用 **Geist** + **Geist Mono**（数据列）贴近 Soft Bento 配置。

## 实现时注意

- 表格小屏：稿中同时给了 **横向滚动宽表** 与 **客户端卡片**，实现时可按断点二选一或并存。
- 桌面仪表盘 KPI 第三张卡片在自动布局下可能出现轻微裁切；若像素级对齐，可为 KPI 行指定略大的 `min-height` 或改为纵向 `fit_content`。
