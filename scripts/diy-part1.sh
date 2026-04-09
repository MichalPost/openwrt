#!/usr/bin/env bash
set -euo pipefail

# 通用自定义钩子。
# 该脚本在 OpenWrt/ImmortalWrt 源码树（WORKDIR）内执行。

echo "[diy-part1] start"

# 添加可选的第三方 feeds（幂等追加，重复执行也安全）。
# 保持这些项为“可选”：即使你后续移除，也不应影响构建主流程。

add_feed() {
  local line="$1"
  local file="feeds.conf.default"
  if ! grep -qF -- "$line" "$file"; then
    echo "$line" >> "$file"
  fi
}

# iStore（可选）。如果你不使用 iStore，可以删除这些行。
add_feed "src-git istore https://github.com/linkease/istore;main"
add_feed "src-git nas https://github.com/linkease/nas-packages.git;master"
add_feed "src-git nas_luci https://github.com/linkease/nas-packages-luci.git;main"

# OpenClash（Clash 生态）。提供 luci-app-openclash。
add_feed "src-git openclash https://github.com/vernesong/OpenClash.git;master"

# PassWall2（多协议代理面板，Xray/sing-box 等生态）
# 说明：PassWall2 由两个 feeds 组成：
# - passwall_packages：后端依赖包集合（xray-core/sing-box/naiveproxy 等）
# - passwall2：LuCI 面板与规则
add_feed "src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main"
add_feed "src-git passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git;main"

echo "[diy-part1] done"

