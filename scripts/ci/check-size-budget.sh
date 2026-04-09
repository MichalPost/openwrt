#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${1:-out}"
if [ ! -d "${OUTDIR}" ]; then
  echo "[size-budget] out dir not found: ${OUTDIR}"
  exit 1
fi

# Strict defaults for 128M flash devices (bytes). Override via env if needed.
: "${BUDGET_SYSUPGRADE_MAX_BYTES:=73400320}" # 70 MiB
: "${BUDGET_ROOTFS_MAX_BYTES:=62914560}"    # 60 MiB
: "${BUDGET_KERNEL_MAX_BYTES:=10485760}"    # 10 MiB

max_size_of_glob() {
  local dir="$1"
  local pattern="$2"
  local max=0
  local found=0

  shopt -s nullglob globstar
  local f
  for f in "${dir}"/**/${pattern}; do
    [ -f "${f}" ] || continue
    found=1
    sz="$(stat -c '%s' "${f}")"
    if [ "${sz}" -gt "${max}" ]; then
      max="${sz}"
      max_file="${f}"
    fi
  done

  if [ "${found}" -eq 0 ]; then
    echo "0|"
    return 0
  fi

  echo "${max}|${max_file}"
}

human_mib() {
  python3 - <<'PY'
import os, sys
v=int(sys.argv[1])
print(f"{v/1024/1024:.2f} MiB")
PY
}

check_one() {
  local label="$1"
  local glob="$2"
  local budget="$3"

  r="$(max_size_of_glob "${OUTDIR}" "${glob}")"
  max="${r%%|*}"
  file="${r#*|}"

  if [ "${max}" -eq 0 ]; then
    echo "[size-budget] WARN: ${label} not found (glob: ${glob})"
    return 0
  fi

  max_mib="$(python3 - <<PY
v=${max}
print(f"{v/1024/1024:.2f}")
PY
)"
  budget_mib="$(python3 - <<PY
v=${budget}
print(f"{v/1024/1024:.2f}")
PY
)"

  echo "[size-budget] ${label}: ${max} bytes (${max_mib} MiB), budget ${budget} bytes (${budget_mib} MiB)"
  echo "[size-budget] ${label} file: ${file}"

  if [ "${max}" -gt "${budget}" ]; then
    echo "[size-budget] ERROR: ${label} exceeds budget"
    exit 1
  fi
}

echo "[size-budget] checking under: ${OUTDIR}"
check_one "sysupgrade" "*sysupgrade*.bin" "${BUDGET_SYSUPGRADE_MAX_BYTES}"
check_one "rootfs" "*rootfs*.*" "${BUDGET_ROOTFS_MAX_BYTES}"
check_one "kernel" "*kernel*.*" "${BUDGET_KERNEL_MAX_BYTES}"

echo "[size-budget] OK"

