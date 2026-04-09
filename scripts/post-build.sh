#!/usr/bin/env bash
set -euo pipefail

echo "[post-build] start"

OUTDIR="${OUTDIR:-${GITHUB_WORKSPACE:-}/out}"
PROFILE="${PROFILE:-${INPUT_PROFILE:-}}"
FLASH_LAYOUT="${FLASH_LAYOUT:-${INPUT_FLASH_LAYOUT:-}}"
SOURCE_FLAVOR="${SOURCE_FLAVOR:-${INPUT_SOURCE_FLAVOR:-}}"

mkdir -p "${OUTDIR}"

manifest="${OUTDIR}/manifest.txt"
sha_file="${OUTDIR}/sha256sums"

get_git_head() {
  local dir="$1"
  if [ -d "${dir}/.git" ]; then
    git -C "${dir}" rev-parse HEAD 2>/dev/null || true
  fi
}

now_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

append_kv() {
  local k="$1"
  local v="$2"
  printf "%s=%s\n" "${k}" "${v}" >> "${manifest}"
}

extract_pkg_version() {
  local pkg="$1"
  local found=""

  shopt -s nullglob globstar
  for f in "${OUTDIR}"/**/Packages "${OUTDIR}"/**/Packages.gz; do
    if [[ "${f}" == *.gz ]]; then
      found="$(gzip -cd "${f}" 2>/dev/null | awk -v p="${pkg}" '
        $1=="Package:" && $2==p {inpkg=1; next}
        inpkg && $1=="Version:" {print $2; exit}
        $0=="" {inpkg=0}
      ' || true)"
    else
      found="$(awk -v p="${pkg}" '
        $1=="Package:" && $2==p {inpkg=1; next}
        inpkg && $1=="Version:" {print $2; exit}
        $0=="" {inpkg=0}
      ' "${f}" || true)"
    fi

    if [ -n "${found}" ]; then
      echo "${found}"
      return 0
    fi
  done
  echo "NOT_FOUND"
}

write_manifest() {
  : > "${manifest}"
  append_kv "generated_at_utc" "$(now_utc)"

  append_kv "build_repo" "${GITHUB_REPOSITORY:-}"
  append_kv "build_repo_commit" "${GITHUB_SHA:-}"
  append_kv "run_id" "${GITHUB_RUN_ID:-}"
  append_kv "run_number" "${GITHUB_RUN_NUMBER:-}"
  append_kv "workflow" "${GITHUB_WORKFLOW:-}"

  append_kv "profile" "${PROFILE}"
  append_kv "flash_layout" "${FLASH_LAYOUT}"
  append_kv "source_flavor" "${SOURCE_FLAVOR}"

  append_kv "source_repo_url" "$(git remote get-url origin 2>/dev/null || true)"
  append_kv "source_repo_commit" "$(get_git_head ".")"

  append_kv "default_lan_ip" "192.168.6.1"
  append_kv "default_timezone" "CST-8"
  append_kv "default_zonename" "Asia/Shanghai"

  echo "" >> "${manifest}"
  echo "[feeds]" >> "${manifest}"
  if [ -d "feeds" ]; then
    for d in feeds/*; do
      [ -d "${d}" ] || continue
      name="$(basename "${d}")"
      head="$(get_git_head "${d}")"
      if [ -n "${head}" ]; then
        printf "%s=%s\n" "${name}" "${head}" >> "${manifest}"
      fi
    done
  fi

  echo "" >> "${manifest}"
  echo "[key_packages]" >> "${manifest}"
  KEY_PACKAGES="${KEY_PACKAGES:-luci luci-ssl adguardhome mwan3 luci-app-mwan3 zerotier luci-app-zerotier cloudflared}"
  for p in ${KEY_PACKAGES}; do
    printf "%s=%s\n" "${p}" "$(extract_pkg_version "${p}")" >> "${manifest}"
  done
}

write_sha256sums() {
  : > "${sha_file}"
  (
    cd "${OUTDIR}"
    # Generate stable checksums for all files under out/
    # Exclude the checksum file itself during generation.
    while IFS= read -r -d '' f; do
      rel="${f#./}"
      [ "${rel}" = "$(basename "${sha_file}")" ] && continue
      sha256sum "${rel}"
    done < <(find . -type f -print0 | LC_ALL=C sort -z)
  ) > "${sha_file}"
}

write_manifest
write_sha256sums

echo "[post-build] done"

