#!/usr/bin/env bash
set -euo pipefail

prev="${1:-}"
cur="${2:-}"
if [ -z "${prev}" ] || [ -z "${cur}" ]; then
  echo "usage: config-drift.sh <prev_final.config> <current_final.config>"
  exit 2
fi

if [ ! -f "${cur}" ]; then
  echo "[config-drift] current config not found: ${cur}"
  exit 1
fi

if [ ! -f "${prev}" ]; then
  echo "[config-drift] no previous config found; skipping drift report"
  exit 0
fi

extract_watchlist() {
  local f="$1"
  {
    # Target / device selection
    grep -E '^CONFIG_TARGET_.*=y$' "${f}" || true

    # Core UI + daily expectations
    grep -E '^CONFIG_PACKAGE_(luci|luci-ssl|luci-app-store|adguardhome|luci-app-adguardhome|luci-app-openclash|luci-app-passwall2)=y$' "${f}" || true

    # DNS / SQM related (coarse but stable signals)
    grep -E '^CONFIG_PACKAGE_(dnsmasq-full|smartdns|unbound|sqm-scripts|kmod-sched-cake|kmod-ifb)=y$' "${f}" || true
  } | LC_ALL=C sort -u
}

tmp_prev="$(mktemp)"
tmp_cur="$(mktemp)"
trap 'rm -f "${tmp_prev}" "${tmp_cur}"' EXIT

extract_watchlist "${prev}" > "${tmp_prev}"
extract_watchlist "${cur}" > "${tmp_cur}"

echo "[config-drift] watchlist diff (prev -> current):"
if diff -u "${tmp_prev}" "${tmp_cur}"; then
  echo "[config-drift] no drift in watched keys"
else
  echo "[config-drift] drift detected above"
fi

