#!/usr/bin/bash
set -euo pipefail

readonly arch=$(uname -m)
readonly os=$(uname -s)

if [[ "$EUID" -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

if [[ "$os" != "Darwin" ]]; then
  echo "This script is only supported on macOS."
  exit 1
fi

if [[ -z "$tmp_directory" ]]; then
  tmp_directory=$(mktemp -d) || {
    echo "ERROR" "Failed to create temporary directory"
    exit 1
  }
  echo "INFO" "Created directory ${tmp_directory}"
fi

# Clone directory to tmp_directory
readonly repository="https://github.com/SapphSky/mac.refurb.sh/archive/refs/heads/main.zip"

echo "INFO" "Downloading ${repository} to ${tmp_directory}/mac.refurb.sh.zip"
if ! curl -L --connect-timeout 30 --retry 2 --retry-delay 3 \
      --progress-bar "${repository}" -o "${tmp_directory}/mac.refurb.sh.zip"; then
  echo "ERROR" "Failed to download repository"
  exit 1
fi

echo "INFO" "Extracting..."
if ! tar -xzf "${tmp_directory}/mac.refurb.sh.zip" -C "${tmp_directory}"; then
  echo "ERROR" "Couldn't extract repository."
  exit 1
fi

cd "${tmp_directory}/mac.refurb.sh-main"

source ./fetch_dependencies.sh
source ./menu.sh
