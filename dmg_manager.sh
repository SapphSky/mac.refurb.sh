#!/usr/bin/bash
set -euo pipefail

echo "INFO" "Running Disk Image Manager..."

readonly disk_image_repository="https://dl.refurb.sh/assets/disk_images/"
readonly disk_image_manifest="${disk_image_repository}manifest.json"

# Source shared disk image utilities
source "$(dirname "$0")/disk_image_utils.sh"

fetch_remote_disk_images () {
  local manifest=$(curl -s "$disk_image_manifest")
  echo "$manifest" | jq -r '.disk_images[] | select(.available == true) | .display_name + " " + .version + ":" + .filename'
  return 0
}

pick_remote_disk_image () {
  local choice=$(fetch_remote_disk_images | gum choose --header "Select a disk image to download:" --label-delimiter ":")
  download_disk_image "$choice"
  return 0
}

pick_local_disk_image () {
  local choice=$(select_local_disk_image "Select a disk image:")
  echo "$choice"
  return 0
}

scan_disk_image () {
  asr imagescan --source "$1"
  return 0
}

download_disk_image () {
  local filename="$1"
  local download_url="${disk_image_repository}${filename}"
  local destination="$(gum file /Volumes --directory --header "Select a directory to save ${filename} to:" --padding="1 0 0 0")"
  gum spin --spinner globe --title "Downloading ${filename} to ${destination}/${filename}" --show-output -- \
  curl "$download_url" --connect-timeout 30 --progress-bar --retry 5 --output "${destination}/${filename}"
  scan_disk_image "${destination}/${filename}"
  return 0
}

disk_images_menu () {
  local choices=$(cat <<EOF
    View available disk images:list
    Download disk images:download
    Scan images (Checksum):scan
EOF
)
  choices=$(printf "%s\n" "${choices[@]}")

  local choice=$(echo "${choices}" | gum choose --header 'Disk Image Manager' --label-delimiter ":")

  case "$choice" in
    "list")
    fetch_local_disk_images && disk_images_menu
    ;;

    "download")
    pick_remote_disk_image && disk_images_menu
    ;;

    "scan")
    scan_disk_image "$(pick_local_disk_image)" && disk_images_menu
    ;;
  esac
}

disk_images_menu
return 0