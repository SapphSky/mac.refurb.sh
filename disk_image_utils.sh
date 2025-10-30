#!/bin/bash
set -euo pipefail

scan_local_disk_images () {
  local disk_images=$(find / \
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
    return 1
  fi
  
  echo "$disk_images"
  return 0
}

select_local_disk_image () {
  local header="$1"
  if [[ -z "$header" ]]; then
    header="Select a disk image:"
  fi
  
  local disk_images
  if ! disk_images=$(scan_local_disk_images); then
    return 1
  fi
  
  echo "$disk_images" | gum choose --header "$header"
}
