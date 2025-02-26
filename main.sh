#!/bin/bash

# Parse command line arguments
DRY_RUN=false
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -dry|--dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
done

BACK_OPTION="Back"
EXIT_OPTION="Exit"

# gnu bash doesn't have a clear function, so we need to define our own
function clear() {
  printf "\033c"
}

function is_running_as_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root in MacOS Recovery Mode."
    exit 1
  fi
}

function init() {
  # Detect architecture
  ARCH=$(uname -m)
  if [ "$ARCH" = "arm64" ]; then
    ARCH="arm64"
  elif [ "$ARCH" = "x86_64" ]; then
      ARCH="x86_64"
  else
      echo "Unsupported architecture: $ARCH"
      exit 1
  fi
  echo "Detected architecture: $ARCH"

  # Create temporary directory
  TEMP_DIR=$(mktemp -d)
  GUM_VERSION="0.15.2"
  GUM_FILENAME="gum_${GUM_VERSION}_Darwin_${ARCH}.tar.gz"
  GUM_URL="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/${GUM_FILENAME}"

  # Download gum binary
  echo "Downloading gum ${GUM_VERSION} for Darwin ${ARCH}..."
  curl -L "${GUM_URL}" -o "${TEMP_DIR}/${GUM_FILENAME}" --progress-bar

  # Extract the archive
  tar -xzf "${TEMP_DIR}/${GUM_FILENAME}" -C "${TEMP_DIR}"

  # Export the binary path for later use
  export GUM_BINARY="${TEMP_DIR}/gum_${GUM_VERSION}_Darwin_${ARCH}/gum"

  # Make the binary executable
  chmod +x "${GUM_BINARY}"
}

function message_of_the_day() {
  messages=(
    "Hello, world!"
    "*random keypresses* I'm in. B)"
    "There is no spoon."
    "What am I supposed to say here?"
    "Contribute to this software: https://github.com/sapphsky/mac.refurb.sh"
    "I'm not like the other girls"
    "If I could trap time in a bottle, the first thing that I'd do, is sell it to the highest bidder."
    "Don't forget to "
    "Coming to you LIVE from $(hostname)!"
    "Would you just reinstall MacOS already?"
    "asr = Apple Software Restore"
    "If you want that nice little 'hello' text, you need to reset the NVRAM."
    "Shoutout to the people who are still using Mojave."
    "Honk if you read this."
    "Always remember that you are braver than you believe, stronger than you seem, and smarter than you think."
    "Can I have your IP address?"
    "Your privacy is important to us. That's why we're not going to ask for it."
    "Go check out sapphsky.dev"
    "You better appreciate how much effort went into this. Just kidding, you don't have to."
    "This Mac is called $(hostname)."
    "The suggestions this AI is giving for MOTDs are unhinged."
    "Thanks for using mac.refurb.sh!"
    "Suggest more MOTDs at https://github.com/sapphsky/mac.refurb.sh"
    "Don't feel intimidated by the amount of options here. Take your time."
    "Hey, what does this button do?"
    "If I die, fork this repo and make your own version: https://github.com/sapphsky/mac.refurb.sh"
    "There is a 100% chance that this script is running on a Mac."
    "Tell the person next to you that they are a good person."
    "Would you rather do 50 pushups or install MacOS the hard way?"
    "SMC = System Management Controller"
    "NVRAM = Non-Volatile Random Access Memory"
    "Sequoia is a national park in California. It has redwood trees, which are the tallest trees in the world."
    "Sonoma is a city in California. It is known for its wine country. Sonoma was also the location of the famous 'Bliss' Windows XP wallpaper."
    "Ventura is a city in California. It is known for its beaches and surfing culture."
    "Monterey is a city in California. Known best for its Monterey Bay aquarium and the 17-mile drive."
    "Big Sur is a national park in California.  It is known for its rugged yet beautiful coastline."
    "Catalina is a an island off the coast of California. It is known for its beautiful beaches and clear blue waters."
    "By using this software, you agree to not complain about the software."
  )

  echo "${messages[$RANDOM % ${#messages[@]}]}"
}

function main_menu() {
  INSTALL_MACOS_OPTION='Install MacOS'
  RESET_NVRAM_OPTION='Reset NVRAM'
  DOWNLOAD_MACOS_IMAGE_OPTION='Download Disk Images'
  VIEW_DEVICE_INFO_OPTION='View Device Info' # TODO
  BUILD_MACOS_IMAGE_OPTION='Build Disk Image' # TODO

  clear
  ${GUM_BINARY} style --align left --bold --border rounded --padding 1 --width 40 'mac.refurb.sh' 'Version 2025.1' "$(if [ "$DRY_RUN" = true ]; then echo '[RUNNING IN DRY MODE -- NO ACTIONS WILL BE PERFORMED]'; fi)"
  ${GUM_BINARY} style --align left --padding 1 "$(message_of_the_day)"

  ${GUM_BINARY} style --underline 'Main Menu'
  CHOICE=$("${GUM_BINARY}" choose "$INSTALL_MACOS_OPTION" "$DOWNLOAD_MACOS_IMAGE_OPTION" "$RESET_NVRAM_OPTION" "$VIEW_DEVICE_INFO_OPTION" "$EXIT_OPTION" --header 'Select an option:')

  if [ "$CHOICE" = "$INSTALL_MACOS_OPTION" ]; then
    choose_source_os
  elif [ "$CHOICE" = "$RESET_NVRAM_OPTION" ]; then
    reset_nvram
  elif [ "$CHOICE" = "$VIEW_DEVICE_INFO_OPTION" ]; then
    view_device_info
  elif [ "$CHOICE" = "$DOWNLOAD_MACOS_IMAGE_OPTION" ]; then
    download_macos_image
  elif [ "$CHOICE" = "$EXIT_OPTION" ]; then
    clear
    exit 0
  fi
}

function download_macos_image() {
  STARTING_PATH="/Volumes"
  CATBOOT_IMAGE_LABEL="CatBoot: 2025 Edition - 10.5 GB"
  CATBOOT_IMAGE_FILENAME="Catboot.dmg"
  CATBOOT_IMAGE_URL="https://refurb-sh.hel1.your-objectstorage.com/sources/Catboot.dmg"

  CATALINA_IMAGE_LABEL="Catalina 10.15.7 - 10.5 GB"
  CATALINA_IMAGE_FILENAME="Catalina_10.15.7.dmg"
  CATALINA_IMAGE_URL="https://refurb-sh.hel1.your-objectstorage.com/sources/Catalina_10.15.7.dmg"

  # BIG_SUR_IMAGE_LABEL="Big Sur 11.7.10 - 10.5 GB"
  # BIG_SUR_IMAGE_FILENAME="Big_Sur_11.7.10.dmg"
  # BIG_SUR_IMAGE_URL="https://refurb-sh.hel1.your-objectstorage.com/sources/Big_Sur_11.7.10.dmg"

  # MONTEREY_IMAGE_LABEL="Monterey 12.7.4 - 10.5 GB"
  # MONTEREY_IMAGE_FILENAME="Monterey_12.7.4.dmg"
  # MONTEREY_IMAGE_URL="https://refurb-sh.hel1.your-objectstorage.com/sources/Monterey_12.7.4.dmg"

  VENTURA_IMAGE_LABEL="Ventura 13.7.3 - 18.2 GB"
  VENTURA_IMAGE_FILENAME="Ventura_13.7.3.dmg"
  VENTURA_IMAGE_URL="https://refurb-sh.hel1.your-objectstorage.com/sources/Ventura_13.7.3.dmg"

  SONOMA_IMAGE_LABEL="Sonoma 14.7.2 - 13.2 GB"
  SONOMA_IMAGE_FILENAME="Sonoma_14.7.2.dmg"
  SONOMA_IMAGE_URL="https://refurb-sh.hel1.your-objectstorage.com/sources/Sonoma_14.7.2.dmg"

  SEQUOIA_IMAGE_LABEL="Sequoia 15.2 - 14.1 GB"
  SEQUOIA_IMAGE_FILENAME="Sequoia_15.2.dmg"
  SEQUOIA_IMAGE_URL="https://refurb-sh.hel1.your-objectstorage.com/sources/Sequoia_15.2.dmg"

  clear
  "${GUM_BINARY}" style --bold --padding 1 "Disk Images"

  CHOICE_DOWNLOAD_IMAGE=$("${GUM_BINARY}" filter "$SEQUOIA_IMAGE_LABEL" "$SONOMA_IMAGE_LABEL" "$VENTURA_IMAGE_LABEL" "$CATALINA_IMAGE_LABEL" "$CATBOOT_IMAGE_LABEL" ${BACK_OPTION} --header 'Select a disk image to download:')

  if [ "$CHOICE_DOWNLOAD_IMAGE" = "$BACK_OPTION" ]; then
    main_menu

  elif [ "$CHOICE_DOWNLOAD_IMAGE" = "$SEQUOIA_IMAGE_LABEL" ]; then
    CHOICE_DOWNLOAD_IMAGE_LABEL=$SEQUOIA_IMAGE_LABEL
    CHOICE_DOWNLOAD_IMAGE_URL=$SEQUOIA_IMAGE_URL
    CHOICE_DOWNLOAD_IMAGE_FILENAME=$SEQUOIA_IMAGE_FILENAME

  elif [ "$CHOICE_DOWNLOAD_IMAGE" = "$SONOMA_IMAGE_LABEL" ]; then
    CHOICE_DOWNLOAD_IMAGE_LABEL=$SONOMA_IMAGE_LABEL
    CHOICE_DOWNLOAD_IMAGE_URL=$SONOMA_IMAGE_URL
    CHOICE_DOWNLOAD_IMAGE_FILENAME=$SONOMA_IMAGE_FILENAME

  elif [ "$CHOICE_DOWNLOAD_IMAGE" = "$VENTURA_IMAGE_LABEL" ]; then
    CHOICE_DOWNLOAD_IMAGE_LABEL=$VENTURA_IMAGE_LABEL
    CHOICE_DOWNLOAD_IMAGE_URL=$VENTURA_IMAGE_URL
    CHOICE_DOWNLOAD_IMAGE_FILENAME=$VENTURA_IMAGE_FILENAME
  
  elif [ "$CHOICE_DOWNLOAD_IMAGE" = "$CATALINA_IMAGE_LABEL" ]; then
    CHOICE_DOWNLOAD_IMAGE_LABEL=$CATALINA_IMAGE_LABEL
    CHOICE_DOWNLOAD_IMAGE_URL=$CATALINA_IMAGE_URL
    CHOICE_DOWNLOAD_IMAGE_FILENAME=$CATALINA_IMAGE_FILENAME

  elif [ "$CHOICE_DOWNLOAD_IMAGE" = "$CATBOOT_IMAGE_LABEL" ]; then
    CHOICE_DOWNLOAD_IMAGE_LABEL=$CATBOOT_IMAGE_LABEL
    CHOICE_DOWNLOAD_IMAGE_URL=$CATBOOT_IMAGE_URL
    CHOICE_DOWNLOAD_IMAGE_FILENAME=$CATBOOT_IMAGE_FILENAME
  fi

  choose_download_image_directory
}

function choose_download_image_directory() {
  clear
  "${GUM_BINARY}" style --bold --padding 1 "Choose a directory to save the image:"
  CHOICE_DOWNLOAD_IMAGE_PATH=$("${GUM_BINARY}" file --directory "$STARTING_PATH" --show-help)
  if [ "$CHOICE_DOWNLOAD_IMAGE_PATH" = "no file selected" ]; then
    download_macos_image
  fi
}

function download_image() {
  clear
  "${GUM_BINARY}" style --bold --padding 1 "Downloading ${CHOICE_DOWNLOAD_IMAGE_LABEL}... This may take some time."
  curl -L ${CHOICE_DOWNLOAD_IMAGE_URL} -o ${CHOICE_DOWNLOAD_IMAGE_PATH}/${CHOICE_DOWNLOAD_IMAGE_FILENAME}

  clear
  read -n 1 -s -r -p "Download complete: ${CHOICE_DOWNLOAD_IMAGE_PATH}/${CHOICE_DOWNLOAD_IMAGE_FILENAME} | Press any key to continue..."
}

function choose_image_scan() {
  clear
  "${GUM_BINARY}" confirm --show-output "Would you like to scan the image now? (asr imagescan)" && asr imagescan ${CHOICE_DOWNLOAD_IMAGE_PATH}/${CHOICE_DOWNLOAD_IMAGE_FILENAME} && download_macos_image || download_macos_image
}

function reset_nvram() {
  clear
  if [ "$DRY_RUN" = true ]; then
    "${GUM_BINARY}" spin --spinner dot --title "[DRY RUN] Simulating NVRAM clear..." -- sleep 1
  else
    "${GUM_BINARY}" spin --spinner dot --title "Clearing NVRAM..." -- nvram -c && pmset -a restoredefaults
  fi
  sleep 1
  main_menu
}

function view_device_info() {
  SYSTEM_PROFILER_PATH="/Volumes/OS X Base System/usr/sbin/system_profiler"
  clear
  gum spin --title "Generating System Profiler Info..." -- "${SYSTEM_PROFILER_PATH}" SPHardwareDataType SPMemoryDataType SPDisplaysDataType SPPowerDataType SPStorageDataType | gum pager
  main_menu
}

function choose_source_image_mode() {
  LOCAL_OPTION="Locally from external disk:Local"
  ONLINE_OPTION="Online from refurb.sh (may take longer):Online"
  CHOICE_SOURCE_IMAGE_MODE=$("${GUM_BINARY}" choose --header "Where should we source the image from?" --label-delimiter=":" "$LOCAL_OPTION" "$ONLINE_OPTION" ${BACK_OPTION} --selected "$LOCAL_OPTION")

  if [ "$CHOICE_SOURCE_IMAGE_MODE" = "$BACK_OPTION" || "$CHOICE_SOURCE_IMAGE_MODE" = "" ]; then
    main_menu
  elif [ "$CHOICE_SOURCE_IMAGE_MODE" = "Local" ]; then
    choose_source_os_from_file_picker
  elif [ "$CHOICE_SOURCE_IMAGE_MODE" = "Online" ]; then
    choose_source_os
  fi
}

function choose_source_os() {
  SEQUOIA="Sequoia 15.3.1"
  SONOMA="Sonoma 14.7.4"
  VENTURA="Ventura 13.7.4"
  MONTEREY="Monterey 12.7.4"
  BIG_SUR="Big Sur 11.7.10"
  CATALINA="Catalina 10.15.7"
  CUSTOM="Select from file picker..."

  clear
  "${GUM_BINARY}" style --bold --padding 1 '(1) Choose Operating System  ―――>  (2)  ―――>  (3)'
  CHOICE_SOURCE_OS=$("${GUM_BINARY}" filter "$SEQUOIA" "$SONOMA" "$VENTURA" "$MONTEREY" "$BIG_SUR" "$CATALINA" "$CUSTOM" ${BACK_OPTION} --header 'Select the MacOS version to install:')

  if [ "$CHOICE_SOURCE_OS" = "$BACK_OPTION" || "$CHOICE_SOURCE_OS" = "" ]; then
    main_menu
  elif [ "$CHOICE_SOURCE_OS" = "$CUSTOM" ]; then
    choose_source_os_from_file_picker
  else
    choose_target_disk
  fi
}

function choose_source_os_from_file_picker() {
  STARTING_PATH="/Volumes"
  clear

  "${GUM_BINARY}" style --bold --padding 1 'Select a .dmg Disk Image:'
  CHOICE_SOURCE_OS=$("${GUM_BINARY}" file "$STARTING_PATH" --file --show-help --size)
  if [ "$CHOICE_SOURCE_OS" = "" ]; then
    choose_source_os
  elif [[ "${CHOICE_SOURCE_OS}" != *.dmg ]]; then
    "${GUM_BINARY}" style --foreground "#ff0000" "Error: Please select a .dmg file"
    sleep 2
    choose_source_os
  fi
}

function fetch_disk_options() {
  # Get a list of internal physical disks and their partitions
  diskutil list internal | while read -r line || [[ -n "$line" ]]; do
    if [[ $line =~ ^/dev/disk[0-9]+ ]]; then
      # Extract disk identifier and type (internal/physical)
      current_disk=$(echo "$line" | cut -d' ' -f1)
      disk_type=$(echo "$line" | grep -o '(internal, physical)')
      if [[ -n "$disk_type" ]]; then
        # Store that we found a physical disk
        found_physical=1
      fi
    elif [[ -n "$found_physical" && $line =~ GUID_partition_scheme[[:space:]]+\*([0-9.]+[[:space:]][TGM]B) ]]; then
      # Extract size from GUID partition scheme line for physical disks
      disk_size="${BASH_REMATCH[1]}"
      echo "$current_disk ($disk_size - Physical Disk)"
      found_physical=0
    elif [[ $line =~ ^[[:space:]]*[0-9]+: ]]; then
      # Skip system partitions and empty entries
      if [[ $line =~ (GUID_partition_scheme|EFI|Apple_APFS_ISC|Apple_APFS_Recovery) ]]; then
        continue
      fi
      
      partition_num=$(echo "$line" | grep -o '^[[:space:]]*[0-9]\+' | tr -d '[:space:]')
      size=$(echo "$line" | grep -o '[0-9.]\+ [TGM]B')
      
      if [[ $line =~ Apple_APFS[[:space:]]+Container[[:space:]]+(disk[0-9]+) ]]; then
        # Handle APFS Container
        container_id="${BASH_REMATCH[1]}"
        # Get APFS volumes in this container using awk
        diskutil apfs list "$container_id" 2>/dev/null | awk -v container="$container_id" '
          /APFS Volume Disk \(Role\):/ {
            role = $0
            if (role ~ /\(System\)|\(Data\)/) {
              getline
              if ($0 ~ /Name:/) {
                name = $0
                sub(/.*Name:[[:space:]]*/, "", name)
                sub(/[[:space:]]*\(Case.*/, "", name)
                getline
                if ($0 ~ /Mount Point:/) {
                  getline
                  if ($0 ~ /Capacity Consumed:/) {
                    size = $0
                    if (size ~ /[0-9.]+[[:space:]][TGM]B/) {
                      match(size, /[0-9.]+[[:space:]][TGM]B/)
                      printf "/dev/%s (%s - %s)\n", container, substr(size, RSTART, RLENGTH), name
                    }
                  }
                }
              }
            }
          }
        '
      elif [[ $line =~ (Linux|Microsoft)[[:space:]]+(Filesystem|Basic[[:space:]]+Data) ]]; then
        # Handle non-APFS partitions
        name="${BASH_REMATCH[0]}"
        if [[ -n "$size" && -n "$name" ]]; then
          partition="${current_disk}s${partition_num}"
          echo "$partition|$size - $name"
        fi
      fi
    fi
  done | sort -u  # Remove any duplicate entries
}

function choose_target_disk() {
  clear
  "${GUM_BINARY}" style --bold --padding 1 '(✔️)  ―――>  (2) Choose Target Disk  ―――>  (3)'
  
  # Show disk options using gum filter
  CHOICE_TARGET_DISK=$((fetch_disk_options; echo "${BACK_OPTION}") | "${GUM_BINARY}" filter --header 'Select the disk to install MacOS to:' | cut -d' ' -f1)

  if [ "$CHOICE_TARGET_DISK" = "${BACK_OPTION}" || "$CHOICE_TARGET_DISK" = "" ]; then
    choose_source_os
  else
    choose_post_installation_options
  fi
}

function choose_post_installation_options() {
  CLEAR_NVRAM_OPTION="Clear NVRAM and SMC"
  REBOOT_OPTION="Reboot after installation"

  clear
  "${GUM_BINARY}" style --bold --padding 1 '(✔️)  ―――>  (✔️)  ―――>  (3) Post Installation Options'

  POST_INSTALLATION_OPTIONS=$("${GUM_BINARY}" choose "$CLEAR_NVRAM_OPTION" "$REBOOT_OPTION" \
    --header 'Select optional installation options:' \
    --no-limit \
    --selected="${CLEAR_NVRAM_OPTION},${REBOOT_OPTION}"
  )

  if [ "$POST_INSTALLATION_OPTIONS" = "" ]; then
    choose_target_disk
  else
    confirm_installation
  fi
}

function confirm_installation() {
  clear
  "${GUM_BINARY}" style --bold --padding 1 'Confirm Operation'
  "${GUM_BINARY}" style 'We will now perform the following operations. Please confirm to proceed.'
  "${GUM_BINARY}" style --border rounded --padding 1 \
  "Source Image: ${CHOICE_SOURCE_OS}" \
  "Target Disk: ${CHOICE_TARGET_DISK}" \
  "1. Erase ${CHOICE_TARGET_DISK} and reformat it to 'Macintosh HD' (APFS format)" \
  "2. Perform asr restore to ${CHOICE_TARGET_DISK}" \
  $(if [ "$POST_INSTALLATION_OPTIONS" == *"${CLEAR_NVRAM_OPTION}"* ]; then echo "3. Clear NVRAM and SMC"; fi) \
  $(if [ "$POST_INSTALLATION_OPTIONS" == *"${REBOOT_OPTION}"* ]; then echo "4. Reboot after installation"; fi)

  "${GUM_BINARY}" confirm --show-output 'Are you sure you want to proceed?' && install_macos || choose_target_disk
}

function install_macos() {
  clear
  "${GUM_BINARY}" style --bold --padding 1 "Installing ${CHOICE_SOURCE_OS} to ${CHOICE_TARGET_DISK}"

  if [ "$DRY_RUN" = true ]; then
    "${GUM_BINARY}" style --foreground "#yellow" "[DRY RUN] Would execute: diskutil eraseVolume APFS \"Macintosh HD\" \"${CHOICE_TARGET_DISK}\""
    sleep 2
  else
    "${GUM_BINARY}" spin --spinner line --title "Formatting ${CHOICE_TARGET_DISK}..." -- $(diskutil eraseVolume APFS "Macintosh HD" "${CHOICE_TARGET_DISK}")
  fi

  if [ "$DRY_RUN" = true ]; then
    "${GUM_BINARY}" style --foreground "#yellow" "[DRY RUN] Would execute: asr restore --source \"${CHOICE_SOURCE_OS}\" --target \"${CHOICE_TARGET_DISK}\" --erase --noprompt"
    sleep 2
  else
    asr restore --source "${CHOICE_SOURCE_OS}" --target "${CHOICE_TARGET_DISK}" --erase --noprompt
  fi

  if [[ "$POST_INSTALLATION_OPTIONS" == *"${CLEAR_NVRAM_OPTION}"* ]]; then
    if [ "$DRY_RUN" = true ]; then
      "${GUM_BINARY}" spin --spinner pulse --title "[DRY RUN] Simulating NVRAM clear..." -- sleep 2
    else
      "${GUM_BINARY}" spin --spinner pulse --title "Clearing NVRAM" --show-output -- $(reset_nvram)
    fi
  fi

  if [[ "$POST_INSTALLATION_OPTIONS" == *"${REBOOT_OPTION}"* ]]; then
    if [ "$DRY_RUN" = true ]; then
      "${GUM_BINARY}" spin --spinner pulse --title "[DRY RUN] Would execute: shutdown -r now" -- sleep 2
      exit 0
    else
      "${GUM_BINARY}" spin --spinner pulse --title "Performing reboot now. Goodbye!" --show-output -- $(shutdown -r now)
    fi
  fi
}

is_running_as_root
init
main_menu
