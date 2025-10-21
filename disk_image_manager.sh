#!/usr/bin/env bash
set -o errexit -o pipefail

echo "INFO" "Running Disk Image Manager..."

readonly disk_image_repository="https://dl.refurb.sh/assets/disk_images/"
readonly disk_image_manifest="${disk_image_repository}manifest.json"

fetch_local_disk_images () {
  # echo "INFO" "Scanning for local disk images... This may take a while."
  # "${gum}" spin --spinner minidot --title "Scanning for local disk images... This may take a while." -- \
  disk_images=$(find / \
    -path "/Volumes/Macintosh HD" -prune -o \
    -path "/Applications" -prune -o \
    -path "/Library" -prune -o \
    -path "/System" -prune -o \
    -path "/macOS Base System" -prune -o \
    -path "/tmp" -prune -o \
    -path "/bin" -prune -o \
    -path "/cores" -prune -o \
    -path "/etc" -prune -o \
    -path "/opt" -prune -o \
    -path "/private" -prune -o \
    -path "/sbin" -prune -o \
    -path "/usr" -prune -o \
    -path "/var" -prune -o \
    -path "/Users" -prune -o \
    -type f -name '*.dmg' -print0 \
    2>/dev/null | tr '\0' '\n' || true)
  disk_images=$(printf '%s\n' "$disk_images")

  if [[ -z "$disk_images" ]]; then
    echo "INFO" "No disk images found."
    return 0
  fi

  echo "$disk_images"
}

fetch_remote_disk_images () {
  local manifest=$(curl -s "$disk_image_manifest")
  echo "$manifest" | jq -r '.disk_images[] | select(.available == true) | .display_name + " " + .version + ":" + .filename'
  return 0
}

pick_remote_disk_image () {
  local choice=$(fetch_remote_disk_images | "${gum}" choose --header "Select a disk image to download:" --label-delimiter ":")
  download_disk_image "$choice"
  return 0
}

pick_local_disk_image () {
  local choice=$(fetch_local_disk_images | "${gum}" choose --header "Select a disk image:")
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
  local destination="$("${gum}" file /Volumes --directory --header "Select a directory to save ${filename} to:" --padding="1 0 0 0")"
  "${gum}" spin --spinner globe --title "Downloading ${filename} to ${destination}/${filename}" --show-output -- \
  curl "$download_url" --connect-timeout 30 --progress-bar --retry 5 --output "${destination}/${filename}"
  scan_disk_image "${destination}/${filename}"
  return 0
}

disk_images_menu () {
  local choices=( \
  "View available disk images:list" \
  "Download disk images:download" \
  "Scan images (Checksum):scan" \
  )
  choices=$(printf "%s\n" "${choices[@]}")

  local choice=$(echo "${choices}" | "${gum}" choose --header 'Disk Image Manager' --label-delimiter ":")

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
exit 0