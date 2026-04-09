#!/usr/bin/env bash
set -euo pipefail

# N60PRO specific customization hook.
# This script runs inside the OpenWrt/ImmortalWrt source tree (WORKDIR).

echo "[diy-part-n60pro] start"

# Use this script for device-specific overlays/patches.
# Default value changes should be done via uci-defaults (more robust vs upstream changes).

# Apply files/ overlay (e.g. /etc/uci-defaults)
if [ -n "${GITHUB_WORKSPACE:-}" ] && [ -d "${GITHUB_WORKSPACE}/files" ]; then
  mkdir -p files
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "${GITHUB_WORKSPACE}/files/" "./files/"
  else
    cp -a "${GITHUB_WORKSPACE}/files/." "./files/"
  fi

  if [ -f "files/etc/uci-defaults/99-n60pro-defaults" ]; then
    chmod 0755 "files/etc/uci-defaults/99-n60pro-defaults" || true
  fi
fi

echo "[diy-part-n60pro] done"

