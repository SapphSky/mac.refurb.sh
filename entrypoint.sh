#!/usr/bin/env bash
set -o errexit -o pipefail

readonly script_name="mac.refurb.sh Launcher"
readonly version="2025.09.18"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script is only supported on macOS"
  exit 1
fi

source ./bootstrap.sh

main_menu () {
  "${gum}" style \
  --align center \
  --bold \
  --border rounded \
  --padding 1 \
  --width 40 \
  "mac.refurb.sh" \

  local choices=( \
  "Install macOS:install" \
  "Manage Disk Images:manage_images" \
  "Reset NVRAM:reset_nvram" \
  "View Device Info:device_info" \
  "Exit:exit"
  )
  choices=$(printf "%s\n" "${choices[@]}")

  local choice=$(echo "${choices}" | "${gum}" choose --header "Main Menu" --label-delimiter ":")

  case "$choice" in
    "install")
      sh ./restore_disk_image.sh && main_menu
      ;;
    "manage_images")
      sh ./disk_image_manager.sh && main_menu
      ;;
    "reset_nvram")
      sh ./reset_nvram.sh && main_menu
      ;;
    "device_info")
      sh ./view_device_info.sh && main_menu
      ;;
    "exit")
      echo "INFO" "Exiting program, goodbye!" && exit 0
      ;;
  esac
}

_main () {
  main_menu
}

_main
