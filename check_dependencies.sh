#!/usr/bin/bash
set -euo pipefail

### Gum ###
readonly gum_version="0.17.0"
readonly gum_package="gum_${gum_version}_Darwin_${arch}.tar.gz"
readonly gum_url="https://github.com/charmbracelet/gum/releases/download/v${gum_version}/${gum_package}"
readonly gum_dir="${tmp_directory}/gum_${gum_version}_Darwin_${arch}"

if ! command -v gum >/dev/null 2>&1; then
  echo "INFO" "Downloading dependency: gum..."
  if ! curl -L --connect-timeout 30 --retry 2 --retry-delay 3 --progress-bar "${gum_url}" -o "${tmp_directory}/${gum_package}"; then
    echo "ERROR" "Couldn't download gum binary."
    exit 1
  fi

  if ! tar -xzf "${tmp_directory}/${gum_package}" -C "${tmp_directory}"; then
    echo "ERROR" "Couldn't extract gum binary."
    exit 1
  fi

  export PATH="${gum_dir}:${PATH}"
fi

### Binaries ###
arch_alt () {
  if [[ "$arch" == "x86_64" ]]; then
    echo "amd64"
  else
    echo "arm64"
  fi
}

if ! command -v jq >/dev/null 2>&1; then
  echo "INFO" "Downloading missing dependency: jq..."
  jq_url="https://github.com/jqlang/jq/releases/download/jq-1.8.1/jq-macos-$(arch_alt)"
  mkdir -p "${tmp_directory}/bin"
  if ! curl -L --connect-timeout 30 --retry 2 --retry-delay 3 --progress-bar "$jq_url" -o "${tmp_directory}/bin/jq"; then
    echo "ERROR" "Couldn't download jq binary."
    exit 1
  fi

  chmod +x "${tmp_directory}/bin/jq"
  export PATH="${tmp_directory}/bin:${PATH}"
fi