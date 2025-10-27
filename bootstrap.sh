#!/usr/bin/env bash
set -o errexit -o pipefail

readonly gum_version="0.17.0"
readonly arch=$(uname -m)
readonly gum_package="gum_${gum_version}_Darwin_${arch}.tar.gz"
readonly gum_url="https://github.com/charmbracelet/gum/releases/download/v${gum_version}/${gum_package}"
readonly miau_dmg_url="https://dl.refurb.sh/assets/miau.dmg"

if [[ -z "$tmpdir" ]]; then
  tmpdir=$(mktemp -d) || {
    echo "ERROR" "Failed to create temporary directory"
    exit 1
  }
  echo "INFO" "Created temporary directory: ${tmpdir}"
fi

echo "INFO" "Downloading dependency" "gum ${gum_version}..."
if ! curl -L --connect-timeout 30 --retry 2 --retry-delay 3 \
      --progress-bar "${gum_url}" -o "${tmpdir}/${gum_package}"; then
  echo "ERROR" "Failed to download gum binary"
  exit 1
fi

echo "INFO" "Extracting to ${tmpdir}/${gum_package}..."
if ! tar -xzf "${tmpdir}/${gum_package}" -C "${tmpdir}"; then
  echo "ERROR" "Failed to extract gum archive"
  exit 1
fi

export gum="${tmpdir}/gum_${gum_version}_Darwin_${arch}/gum"

chmod +x "${gum}" || {
  echo "ERROR" "Failed to make gum binary executable"
  exit 1
}

echo "INFO" "gum installed successfully"

# Skip if miau volume is already mounted
if [[ -d "/Volumes/miau" ]]; then
  echo "INFO" "miau volume is already mounted"
  export miau="/Volumes/miau"
  return 0
fi

echo "INFO" "Downloading miau.dmg..."
if ! curl -L --connect-timeout 30 --retry 2 --retry-delay 3 \
      --progress-bar "${miau_dmg_url}" -o "${tmpdir}/miau.dmg"; then
  echo "ERROR" "Failed to download miau.dmg"
  exit 1
fi

# Mount miau.dmg
echo "INFO" "Mounting miau.dmg..."
hdiutil attach "${tmpdir}/miau.dmg" -quiet
export miau="/Volumes/miau"
echo "INFO" "miau.dmg mounted successfully"

return