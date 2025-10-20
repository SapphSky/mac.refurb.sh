#!/usr/bin/env bash
set -o errexit -o pipefail

repository="https://github.com/SapphSky/mac.refurb.sh/archive/refs/heads/main.zip"

if [[ -z "$tmpdir" ]]; then
  tmpdir=$(mktemp -d) || {
    echo "ERROR" "Failed to create temporary directory"
    exit 1
  }
  echo "INFO" "Created temporary directory: ${tmpdir}"
fi

echo "INFO" "Downloading ${repository} to ${tmpdir}/mac.refurb.sh.zip"
if ! curl -L --connect-timeout 30 --retry 2 --retry-delay 3 \
      --progress-bar "${repository}" -o "${tmpdir}/mac.refurb.sh.zip"; then
  echo "ERROR" "Failed to download repository"
  exit 1
fi

echo "INFO" "Extracting..."
if ! tar -xzf "${tmpdir}/mac.refurb.sh.zip" -C "${tmpdir}"; then
  echo "ERROR" "Failed to extract repository"
  exit 1
fi

cd "${tmpdir}/mac.refurb.sh-main"
sh ./entrypoint.sh
exit 0