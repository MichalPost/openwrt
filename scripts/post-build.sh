#!/usr/bin/env bash
set -euo pipefail

echo "[post-build] start"

OUTDIR="${OUTDIR:-${GITHUB_WORKSPACE:-}/out}"
PROFILE="${PROFILE:-${INPUT_PROFILE:-}}"
FLASH_LAYOUT="${FLASH_LAYOUT:-${INPUT_FLASH_LAYOUT:-}}"
SOURCE_FLAVOR="${SOURCE_FLAVOR:-${INPUT_SOURCE_FLAVOR:-}}"
FEEDS_LOCK_REQUESTED="${FEEDS_LOCK_REQUESTED:-${INPUT_FEEDS_LOCK:-}}"
DNS_POLICY="${DNS_POLICY:-${INPUT_DNS_POLICY:-}}"
SQM_TIER="${SQM_TIER:-${INPUT_SQM_TIER:-}}"
ATTENDEDSYSUPGRADE="${ATTENDEDSYSUPGRADE:-${INPUT_ATTENDEDSYSUPGRADE:-}}"

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
	printf "%s=%s\n" "${k}" "${v}" >>"${manifest}"
}

append_section_line() {
	local section="$1"
	local line="$2"
	echo "" >>"${manifest}"
	echo "[${section}]" >>"${manifest}"
	printf "%s\n" "${line}" >>"${manifest}"
}

append_section_header() {
	local section="$1"
	echo "" >>"${manifest}"
	echo "[${section}]" >>"${manifest}"
}

get_feed_head_or_error() {
	local name="$1"
	local d="feeds/${name}"
	if [ ! -d "${d}" ]; then
		echo "ERROR:NOT_FOUND"
		return 0
	fi
	if [ ! -d "${d}/.git" ]; then
		echo "ERROR:NOT_GIT"
		return 0
	fi
	local head
	head="$(get_git_head "${d}")"
	if [ -z "${head}" ]; then
		echo "ERROR:NO_HEAD"
		return 0
	fi
	echo "${head}"
}

write_feeds_lock_sections() {
	append_section_header "feeds_lock_requested"
	printf "%s\n" "${FEEDS_LOCK_REQUESTED}" >>"${manifest}"

	append_section_header "feeds_lock_effective"
	if [ -z "${FEEDS_LOCK_REQUESTED}" ]; then
		echo "(none)" >>"${manifest}"
		return 0
	fi

	# Accept comma-separated name=ref pairs (ref kept for trace, but effective is always HEAD after checkout)
	local locks="${FEEDS_LOCK_REQUESTED}"
	local IFS=','
	local kv
	for kv in ${locks}; do
		[ -n "${kv}" ] || continue
		local name="${kv%%=*}"
		local ref="${kv#*=}"
		if [ -z "${name}" ] || [ -z "${ref}" ] || [ "${name}" = "${ref}" ]; then
			printf "%s=%s\n" "${name:-INVALID}" "ERROR:INVALID_ENTRY(${kv})" >>"${manifest}"
			continue
		fi
		printf "%s=%s (requested_ref=%s)\n" "${name}" "$(get_feed_head_or_error "${name}")" "${ref}" >>"${manifest}"
	done
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
	: >"${manifest}"
	append_kv "generated_at_utc" "$(now_utc)"

	append_kv "build_repo" "${GITHUB_REPOSITORY:-}"
	append_kv "build_repo_commit" "${GITHUB_SHA:-}"
	append_kv "run_id" "${GITHUB_RUN_ID:-}"
	append_kv "run_number" "${GITHUB_RUN_NUMBER:-}"
	append_kv "workflow" "${GITHUB_WORKFLOW:-}"

	append_kv "profile" "${PROFILE}"
	append_kv "flash_layout" "${FLASH_LAYOUT}"
	append_kv "source_flavor" "${SOURCE_FLAVOR}"
	append_kv "dns_policy" "${DNS_POLICY}"
	append_kv "sqm_tier" "${SQM_TIER}"
	append_kv "attendedsysupgrade" "${ATTENDEDSYSUPGRADE}"

	append_kv "source_repo_url" "$(git remote get-url origin 2>/dev/null || true)"
	append_kv "source_repo_commit" "$(get_git_head ".")"

	append_kv "default_lan_ip" "192.168.6.1"
	append_kv "default_timezone" "CST-8"
	append_kv "default_zonename" "Asia/Shanghai"

	write_feeds_lock_sections

	echo "" >>"${manifest}"
	echo "[feeds]" >>"${manifest}"
	if [ -d "feeds" ]; then
		for d in feeds/*; do
			[ -d "${d}" ] || continue
			name="$(basename "${d}")"
			head="$(get_git_head "${d}")"
			if [ -n "${head}" ]; then
				printf "%s=%s\n" "${name}" "${head}" >>"${manifest}"
			fi
		done
	fi

	echo "" >>"${manifest}"
	echo "[key_packages]" >>"${manifest}"
	KEY_PACKAGES="${KEY_PACKAGES:-luci luci-ssl adguardhome luci-app-adguardhome luci-app-openclash luci-app-passwall2}"
	for p in ${KEY_PACKAGES}; do
		printf "%s=%s\n" "${p}" "$(extract_pkg_version "${p}")" >>"${manifest}"
	done
}

write_sha256sums() {
	: >"${sha_file}"
	(
		cd "${OUTDIR}"
		# 为 out/ 下的所有文件生成稳定的校验和
		# 生成时排除校验和文件本身
		while IFS= read -r -d '' f; do
			rel="${f#./}"
			[ "${rel}" = "$(basename "${sha_file}")" ] && continue
			sha256sum "${rel}"
		done < <(find . -type f -print0 | LC_ALL=C sort -z)
	) >"${sha_file}"
}

write_manifest
write_sha256sums

echo "[post-build] done"
