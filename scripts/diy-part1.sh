#!/usr/bin/env bash
set -euo pipefail

# Common customization hook.
# This script runs inside the OpenWrt/ImmortalWrt source tree (WORKDIR).

echo "[diy-part1] start"

# Add optional third-party feeds (safe idempotent append).
# Keep these optional: builds should still work even if you later remove them.

add_feed() {
  local line="$1"
  local file="feeds.conf.default"
  if ! grep -qF -- "$line" "$file"; then
    echo "$line" >> "$file"
  fi
}

# iStore (optional). If you don't use iStore, you can delete these lines.
add_feed "src-git istore https://github.com/linkease/istore;main"
add_feed "src-git nas https://github.com/linkease/nas-packages.git;master"
add_feed "src-git nas_luci https://github.com/linkease/nas-packages-luci.git;main"

echo "[diy-part1] done"

