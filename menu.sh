#!/usr/bin/bash
set -euo pipefail

gum style \
--align center \
--bold \
--border rounded \
--padding 1 \
--width 40 \
"mac.refurb.sh" \

choices=$(cat <<EOF
Install macOS:install
Manage Disk Images:manage_images
Reset NVRAM:reset_nvram
View Device Info:device_info
Exit:exit
EOF
)

choice=$(echo "$choices" | gum choose --header "Main Menu" --label-delimiter ":")

case "$choice" in
  "install")
    if ! source ./restore.sh; then
      echo "ERROR" "Failed to run restore script"
      exit 1
    fi
    ;;
  "manage_images")
    if ! source ./dmg_manager.sh; then
      echo "ERROR" "Failed to run disk image manager"
      exit 1
    fi
    ;;
  "reset_nvram")
    if ! source ./reset_nvram.sh; then
      echo "ERROR" "Failed to reset NVRAM"
      exit 1
    fi
    ;;
  "device_info")
    if ! source ./view_device_info.sh; then
      echo "ERROR" "Failed to view device info"
      exit 1
    fi
    ;;
  "exit")
    echo "INFO" "Exiting program, goodbye!" && exit 0
    ;;
esac

source ./menu.sh
