#!/usr/bin/env bash
set -euo pipefail

# Output a stable sha256 of feeds/* git HEADs (name=sha), sorted by feed name.
#
# This hash is intended for caching keys (dl/tmp/host-staging) so that:
# - changing upstream source HEAD does NOT always break the cache
# - changing feed locks DOES invalidate the cache (as it should)

root="${1:-.}"
if [ ! -d "${root}/feeds" ]; then
  echo "no-feeds"
  exit 0
fi

tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT

for d in "${root}"/feeds/*; do
  [ -d "${d}" ] || continue
  [ -d "${d}/.git" ] || continue
  name="$(basename "${d}")"
  head="$(git -C "${d}" rev-parse HEAD 2>/dev/null || true)"
  [ -n "${head}" ] || continue
  printf "%s=%s\n" "${name}" "${head}" >> "${tmp}"
done

if [ ! -s "${tmp}" ]; then
  echo "no-git-feeds"
  exit 0
fi

LC_ALL=C sort -o "${tmp}" "${tmp}"
sha256sum "${tmp}" | awk '{print $1}'

