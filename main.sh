#!/usr/bin/bash
set -euo pipefail

readonly arch="$(uname -m || echo 'x86_64')"
readonly os="$(uname -s || echo 'Darwin')"

if [[ "$EUID" -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

if [[ "$os" != "Darwin" ]]; then
  echo "This script is only supported on macOS."
  exit 1
fi

tmp_directory="$(mktemp -d)" || {
  echo "ERROR: Failed to create temporary directory"
  exit 1
}
echo "INFO: Created directory ${tmp_directory}"

# Download repository zip to tmp_directory
readonly repository_url="https://github.com/SapphSky/mac.refurb.sh/archive/refs/heads/main.zip"
readonly zip_file="${tmp_directory}/mac.refurb.sh.zip"

echo "INFO: Downloading mac.refurb.sh..."
if ! curl -L --connect-timeout 30 --retry 2 --retry-delay 3 \
    --progress-bar "$repository_url" -o "$zip_file"; then
  echo "ERROR: Failed to download repository"
  exit 1
fi

echo "INFO: Extracting repository archive..."
if ! unzip -q "$zip_file" -d "$tmp_directory"; then
  echo "ERROR: Couldn't extract repository."
  exit 1
fi

cd "${tmp_directory}/mac.refurb.sh-main"

source ./check_dependencies.sh
source ./menu.sh
