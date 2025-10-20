#!/usr/bin/env bash
set -o errexit -o pipefail

echo "INFO" "Running ASR Wizard..."

device_info () {
  json=$(diskutil info -plist "$1" | plutil -convert json -o - -)
  name=$(echo "$json" | jq '.MediaName')
  size=$(echo "$json" | jq '.TotalSize' | human_readable_size)
  echo "$name - $size ($1)//$1"
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

# Fetch local disk images
echo "INFO" "Scanning for local disk images... This may take a while."
# "${gum}" spin --spinner minidot --title "Scanning for local disk images... This may take a while." -- \
disk_images=$(find / \
  -path "/Volumes/Macintosh HD" -prune -o \
  -path "/Applications" -prune -o \
  -path "/Library" -prune -o \
  -path "/System" -prune -o \
  -path "/Users" -prune -o \
  -type f -name '*.dmg' -print0 \
  2>/dev/null | tr '\0' '\n' || true)
disk_images=$(printf '%s\n' "$disk_images")

if [[ -z "$disk_images" ]]; then
  echo "INFO" "No disk images found."
  exit 0
fi

# Select source disk image
source_image=$(echo "$disk_images" | "${gum}" choose --header "Select a source disk image to restore:")

# Fetch local disk drives
echo "INFO" "Scanning for local disk drives..."
device_disks=($(for disk in $(diskutil list internal physical | grep -E "^/dev/disk[0-9]+" | cut -d' ' -f1); do device_info "$disk"; done | tr '\n' '\0'))
device_disks=($(printf '%s\0' "${device_disks[@]}" | tr '\0' '\n'))

# Select target disk drive
target_disk=$(echo "${device_disks[@]}" | "${gum}" choose --header "Select a target disk to:" --label-delimiter "//")

# Choose post-restore options
post_restore_options=$("${gum}" choose --header "Choose post-restore options:" --no-limit --selected="*" \
  "Clear NVRAM and SMC" \
  "Reboot after installation" \
)

# Confirm choices
"${gum}" style --bold --padding 1 "Confirm disk restoration operation"
"${gum}" style "I am about to run \"asr restore\" with the following parameters:"
"${gum}" style "Source Disk Image: $source_image"
"${gum}" style "Restore Target Disk: $target_disk"
"${gum}" style "Post-restore options: $post_restore_options"

if ! "${gum}" confirm \
"Are you sure you want to proceed? This action cannot be undone." \
--default="false" \
--affirmative="Confirm" \
--negative="Cancel"; then
  echo "INFO" "User cancelled disk restoration."
  exit 0
fi

# Restore disk image
echo "INFO" "Starting disk restoration..."
diskutil eraseDisk APFS "Target Restore Volume" "$target_disk"
asr restore --source "$source_image" --target "${target_disk}s2" --erase --noprompt

# Perform post-restore options
case $post_restore_options in
  "Clear NVRAM and SMC")
    sh ./reset_nvram.sh
    ;;
  "Reboot after installation")
    reboot
    ;;
esac

exit 0