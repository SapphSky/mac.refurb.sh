#!/usr/bin/bash
set -euo pipefail

echo "INFO" "Running ASR Wizard..."

device_info () {
  json=$(diskutil info -plist "$1" | plutil -convert json -o - -)
  name=$(echo "$json" | jq -r '.MediaName')
  size=$(echo "$json" | jq '.TotalSize' | human_readable_size)
  echo "$name - $size ($1):$1"
}

human_readable_size () {
  awk '
    function human(x) {
        if (x<1000) {return x} else {x/=1024}
        s="kMGTEPZY";
        while (x>=1000 && length(s)>1)
            {x/=1024; s=substr(s,2)}
        return int(x+0.5) substr(s,1,1)
    }
    {sub(/^[0-9]+/, human($1)); print}'
}

echo "INFO" "Checking OS compatibility..."
ioreg_output=$(ioreg -l 2>/dev/null || true)
model=$(echo "$ioreg_output" | (grep ModelNumber -m 1 2>/dev/null || true) | awk -F'"' '{print $4}' || echo "")

if [[ -f "compatibility.csv" ]] && [[ -n "$model" ]]; then
  compatibility=$(grep -s "\"$model\"" compatibility.csv 2>/dev/null | awk -F',' '{print $2, $3}' || true)
  
  if [[ -z "$compatibility" ]]; then
    echo "WARNING" "No compatibility data found for ${model}."
    echo "Please be aware of the compatible OS versions for this model."
  else
    max_version=$(echo "$compatibility" | awk '{print $1}')
    min_version=$(echo "$compatibility" | awk '{print $2}')
    echo "INFO" "Minimum OS version: ${min_version}"
    echo "INFO" "Maximum OS version: ${max_version}"
  fi
else
  echo "WARNING" "Could not determine model or compatibility.csv not found."
fi

# Source shared disk image utilities
source "$(dirname "$0")/disk_image_utils.sh"

# Select source disk image
source_image=$(select_local_disk_image "Select a source disk image to restore:")

if [[ -z "$source_image" ]]; then
  echo "INFO" "User cancelled disk image selection."
  return 0
fi

# Fetch local disk drives
echo "INFO" "Scanning for local disk drives..."
device_disks=$(for disk in $(diskutil list physical | grep -E "^/dev/disk[0-9]+" | cut -d' ' -f1); do device_info "$disk"; done)

# Select target disk drive
target_disk=$(echo "$device_disks" | gum choose --header "Select a target disk to restore:" --label-delimiter ":")

if [[ -z "$target_disk" ]]; then
  echo "INFO" "User cancelled target disk selection."
  return 0
fi

# Choose post-restore options
post_restore_options=$(printf "%s\n" \
  "Clear NVRAM and SMC:clear_nvram" \
  "Reboot after installation:reboot" \
  "View Device Info:view_device_info" \
| gum choose --header "Choose post-restore options:" --no-limit --label-delimiter ":" --selected="clear_nvram,reboot") || true

if [[ -z "$post_restore_options" ]]; then
  echo "INFO" "No post-restore options selected."
fi

# Confirm choices
gum style --bold --padding 1 "Confirm disk restoration operation"
gum style "I am about to run \"asr restore\" with the following parameters:"
gum style "Source Disk Image: $source_image"
gum style "Restore Target Disk: $target_disk"
gum style "Post-restore options: $(echo "$post_restore_options" | tr '\n' ', ')"

if ! gum confirm \
"Are you sure you want to proceed? This action cannot be undone." \
--default="false" \
--affirmative="Confirm" \
--negative="Cancel"; then
  echo "INFO" "User cancelled disk restoration."
  return 0
fi

# Restore disk image
echo "INFO" "Starting disk restoration..."
echo "INFO" "ASR Restore  |  Source: $source_image  |  Target: $target_disk (/Volumes/Macintosh HD)"

if ! diskutil eraseDisk APFS "Macintosh HD" "$target_disk"; then
  echo "ERROR" "Failed to erase disk."
  return 1
fi

if ! diskutil mountDisk "$target_disk"; then
  echo "ERROR" "Failed to mount disk."
  return 1
fi

if ! asr restore --source "$source_image" --target "/Volumes/Macintosh HD" --erase --noprompt; then
  echo "ERROR" "ASR restore failed."
  return 1
fi

if [[ -n "$post_restore_options" ]]; then
  while IFS= read -r option; do
    [[ -z "$option" ]] && continue
    case "$option" in
      "Clear NVRAM and SMC")
        sh ./reset_nvram.sh
        ;;
      "View Device Info")
        sh ./view_device_info.sh
        ;;
      "Reboot after installation")
        reboot
        ;;
    esac
  done <<< "$post_restore_options"
fi

return 0
