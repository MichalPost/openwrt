#!/usr/bin/env bash
set -euo pipefail

# N60PRO 专用自定义钩子。
# 该脚本在 OpenWrt/ImmortalWrt 源码树（WORKDIR）内执行。

echo "[diy-part-n60pro] start"

# 用于设备相关的 overlay/补丁处理。
# 默认值类改动建议通过 uci-defaults 完成（相对上游变更更稳健）。

# 应用 files/ overlay（例如 /etc/uci-defaults）
if [ -n "${GITHUB_WORKSPACE:-}" ] && [ -d "${GITHUB_WORKSPACE}/files" ]; then
  mkdir -p files
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "${GITHUB_WORKSPACE}/files/" "./files/"
  else
    cp -a "${GITHUB_WORKSPACE}/files/." "./files/"
  fi

  if [ -d "files/etc/uci-defaults" ]; then
    for f in files/etc/uci-defaults/*; do
      [ -f "${f}" ] || continue
      chmod 0755 "${f}" || true
    done
  fi
fi

echo "[diy-part-n60pro] done"

