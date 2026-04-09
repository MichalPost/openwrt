# N60PRO OpenWrt/ImmortalWrt GitHub Actions Build

本仓库用于 **磊科 Netcore N60 Pro** 的 OpenWrt/ImmortalWrt 固件自动化编译（GitHub Actions）。

## 目标

- 使用 237/ImmortalWrt（mt798x）源码进行编译
- 支持多套配置（基础版 / 重度插件版）
- 产物以 Actions Artifact（可选 Release）形式提供下载

## 目录结构

- `.github/workflows/build-n60pro.yml`：主工作流
- `configs/`：保存不同的构建 `.config`
  - `nx60pro-high-power.base.config`：基础 profile（**config fragment**，用于叠加到 defconfig）
  - `nx60pro-heavy.config`：重度插件 profile（**config fragment**）
  - `nx60pro-512m.override`：512M 闪存改版的目标/设备选择覆盖片段（可选）
- `scripts/`：构建过程中的自定义脚本
  - `diy-part1.sh`：公共自定义（feeds、通用改动）
  - `diy-part-n60pro.sh`：N60PRO 相关定制（可选插件、默认值等）
  - `post-build.sh`：编译后处理（重命名、整理输出）

## 使用方式（高层）

1. 将本仓库推送到你的 GitHub 账号下
2. 进入 GitHub 仓库的 `Actions`，运行 `Build N60PRO firmware`
3. 在构建完成页面下载 `Artifacts` 中固件

> 注意：编译 OpenWrt 需要大量时间和磁盘。首次编译可能 1~2 小时或更久，后续启用缓存会快很多。

## 配置模型（重要）

工作流会按以下顺序生成最终 `.config`：

1. `cp defconfig/nx60pro-ipailna-high-power.config .config`（高功率 defconfig 作为基底）
2. 追加 `configs/<profile>.config`（profile **片段**，不覆盖基底）
3. 若选择 `mod-512m`，再追加 `configs/nx60pro-512m.override`
4. `make defconfig` 让 Kconfig 补齐依赖与默认值

