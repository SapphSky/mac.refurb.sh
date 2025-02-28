#!/bin/bash

#######################################
# mac.refurb.sh - MacOS Recovery Mode Installation Helper
# Version: 2025.2
# Repository: https://github.com/sapphsky/mac.refurb.sh
#######################################

# Script version
readonly VERSION="2025.2"

# Enable strict error handling
set -uo pipefail
IFS=$'\n\t'

# Logging setup
readonly LOG_FILE="/tmp/mac.refurb.sh.log"
readonly SCRIPT_NAME=$(basename "$0")

#######################################
# Check if a command exists
# Arguments:
#   $1 - Command to check
# Returns:
#   0 if command exists, 1 otherwise
#######################################
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

#######################################
# Check for required dependencies
#######################################
check_dependencies() {
  log "INFO" "Checking dependencies..."
  local missing_deps=()
  
  # Required commands
  local deps=(
    "curl"      # For downloading files
    "diskutil"  # For disk operations
    "asr"       # For disk restoration
    "nvram"     # For NVRAM operations
    "hdiutil"   # For disk image operations
    "pmset"     # For power management
  )
  
  for cmd in "${deps[@]}"; do
    if ! command_exists "$cmd"; then
      missing_deps+=("$cmd")
    fi
  done
  
  if [ ${#missing_deps[@]} -ne 0 ]; then
    log "ERROR" "Missing required dependencies: ${missing_deps[*]}"
    echo "This script requires the following commands to be available:"
    printf "  - %s\n" "${missing_deps[@]}"
    echo "Please ensure you are running in MacOS Recovery Mode."
    exit 1
  fi
  
  log "INFO" "All dependencies satisfied"
}

#######################################
# Log a message to both stdout and log file
# Arguments:
#   $1 - Log level (INFO, WARN, ERROR)
#   $2 - Message to log
#######################################
log() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

#######################################
# Display script usage information
#######################################
show_help() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

A utility for installing MacOS in Recovery Mode.

Options:
  -h, --help     Show this help message and exit
  -d, --dry-run  Run in dry-run mode (no changes will be made)
  -v, --version  Show version information

This script must be run as root in MacOS Recovery Mode.
For more information, visit: https://github.com/sapphsky/mac.refurb.sh
EOF
}

function trim_whitespace() {
  # Check if argument is provided
  if [ $# -eq 0 ]; then
    # If no argument provided, read from stdin
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
  else
    # If argument provided, use it
    echo "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
  fi
}

#######################################
# Display version information
#######################################
show_version() {
  echo "mac.refurb.sh version ${VERSION}"
}

# Parse command line arguments
DRY_RUN=false
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -h|--help) show_help; exit 0 ;;
    -v|--version) show_version; exit 0 ;;
    -d|--dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
  esac
done

# Create log file and set permissions
touch "$LOG_FILE" 2>/dev/null || {
  echo "Error: Cannot create log file at $LOG_FILE"
  exit 1
}
chmod 600 "$LOG_FILE"

log "INFO" "Starting mac.refurb.sh version ${VERSION}"
if [ "$DRY_RUN" = true ]; then
  log "INFO" "Running in dry-run mode"
fi

# Check dependencies before proceeding
check_dependencies

# Menu options
INSTALL_MACOS_OPTION_LABEL="Install MacOS"
DOWNLOAD_DISK_IMAGES_OPTION_LABEL="Get Disk Images"
SCAN_DISK_IMAGE_OPTION_LABEL="Scan Disk Image"
RESET_NVRAM_OPTION_LABEL="Reset NVRAM"
HARDWARE_TEST_OPTION_LABEL="Open Hardware Test"
VIEW_DEVICE_INFO_OPTION_LABEL="View Device Info"

DEEP_LOCAL_SCAN_LABEL="Deep scan for disk images"
DEEP_LOCAL_SCAN_VALUE="${DEEP_LOCAL_SCAN_LABEL}"


LOCAL_OPTION_LABEL="Locally from external disk"
LOCAL_OPTION_VALUE="Local"

ONLINE_OPTION_LABEL="Online from refurb.sh (may take longer)"
ONLINE_OPTION_VALUE="Online"

BACK_OPTION_LABEL="Go back"
BACK_OPTION="Back"
CANCEL_OPTION_LABEL="Cancel"
CANCEL_OPTION="Cancel"
EXIT_OPTION_LABEL="Exit"
EXIT_OPTION="Exit"
RETURN_VALUE=""

# gnu bash doesn't have a clear function, so we need to define our own
function clear() {
  printf "\033c"
}

# Check that the script has sufficient permissions to run
function is_running_as_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root in MacOS Recovery Mode."
    exit 1
  fi
}

function detect_architecture() {
  # Detect architecture
  ARCH=$(uname -m)
  case "$ARCH" in
    arm64|x86_64)
      log "INFO" "Detected architecture: $ARCH"
      ;;
    *)
      log "ERROR" "Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac
}

function install_gum() {
  # Create temporary directory
  TEMP_DIR=$(mktemp -d) || {
    log "ERROR" "Failed to create temporary directory"
    exit 1
  }
  log "INFO" "Created temporary directory: $TEMP_DIR"
  
  # Set up cleanup trap
  trap 'cleanup' EXIT
  
  GUM_VERSION="0.15.2"
  GUM_FILENAME="gum_${GUM_VERSION}_Darwin_${ARCH}.tar.gz"
  GUM_URL="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/${GUM_FILENAME}"

  # Download gum binary
  log "INFO" "Downloading gum ${GUM_VERSION} for Darwin ${ARCH}..."
  if ! curl -L --connect-timeout 30 --retry 3 --retry-delay 5 \
       --progress-bar "${GUM_URL}" -o "${TEMP_DIR}/${GUM_FILENAME}"; then
    log "ERROR" "Failed to download gum binary"
    exit 1
  fi

  # Extract the archive
  if ! tar -xzf "${TEMP_DIR}/${GUM_FILENAME}" -C "${TEMP_DIR}"; then
    log "ERROR" "Failed to extract gum archive"
    exit 1
  fi

  # Export the binary path for later use
  export GUM_BINARY="${TEMP_DIR}/gum_${GUM_VERSION}_Darwin_${ARCH}/gum"

  # Make the binary executable
  chmod +x "${GUM_BINARY}" || {
    log "ERROR" "Failed to make gum binary executable"
    exit 1
  }
}

function check_if_gum_is_installed() {
  # Check if gum is installed
  if ! command_exists gum; then
    install_gum
  else
    # Use the installed gum binary
    export GUM_BINARY=$(which gum)
  fi
}

#######################################
# Cleanup function to remove temporary files
#######################################
cleanup() {
  local exit_code=$?
  log "INFO" "Cleaning up temporary files"
  
  # Remove temporary directory if it exists
  if [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
    log "INFO" "Removed temporary directory: $TEMP_DIR"
  fi
  
  # Log final status
  if [ $exit_code -eq 0 ]; then
    log "INFO" "Script completed successfully"
  else
    log "ERROR" "Script exited with error code: $exit_code"
  fi
  
  exit $exit_code
}

# display a random message of the day
function message_of_the_day() {
  local repo_url="https://github.com/sapphsky/mac.refurb.sh"
  local messages=(
    "Hello, world!"
    "*random keypresses* I'm in. B)"
    "There is no spoon."
    "What am I supposed to say here?"
    "Contribute to this software: ${repo_url}"
    "I'm not like the other girls"
    "Don't forget to- "
    "Coming to you LIVE from $(hostname)!"
    "Would you just reinstall MacOS already?"
    "asr: Apple Software Restore"
    "If you want that nice little 'hello' text, you need to reset the NVRAM."
    "Shoutout to the people who are still using Mojave."
    "Honk if you read this."
    "Always remember that you are braver than you believe, stronger than you seem, and smarter than you think."
    "Can I have your IP address?"
    "Your privacy is important to us. That's why we're not going to ask for it."
    "Now running on $(hostname)."
    "The suggestions this AI is giving for MOTDs are unhinged."
    "Thanks for using mac.refurb.sh!"
    "Suggest more MOTDs at ${repo_url}"
    "Don't feel intimidated by the amount of options here. Take your time."
    "Hey, what does this button do?"
    "If I die, fork this repo and make your own version: ${repo_url}"
    "There is a 100% chance that this script is running on a Mac."
    "Be the change you want to see!"
    "Would you rather do 50 pushups or install MacOS the hard way?"
    "SMC: System Management Controller"
    "NVRAM: Non-Volatile Random Access Memory"
    "Sequoia is a national park in California. It has redwood trees, which are the tallest trees in the world."
    "Sonoma is a city in California. It is known for its wine country. Sonoma was also the location of the famous 'Bliss' Windows XP wallpaper."
    "Ventura is a city in California. It is known for its beaches and surfing culture."
    "Monterey is a city in California. Known best for its Monterey Bay aquarium and the 17-mile drive."
    "Big Sur is a national park in California.  It is known for its rugged yet beautiful coastline."
    "Catalina is a an island off the coast of California. It is known for its beautiful beaches and clear blue waters."
    "By using this software, you agree to not complain about the software. :^)"
    "Also try win.refurb.sh!"
  )

  echo "${messages[$RANDOM % ${#messages[@]}]}"
}

function main_menu() {
  clear
  ${GUM_BINARY} style \
  --align center \
  --bold \
  --border rounded \
  --padding 1 \
  --width 40 \
  'mac.refurb.sh' \
  "$VERSION" \
  "" \
  "$(message_of_the_day)" \
  "$(if [ "$DRY_RUN" = true ]; then echo '[RUNNING IN DRY MODE -- NO ACTIONS WILL BE PERFORMED]'; fi)"

  local CHOICE=$("${GUM_BINARY}" choose \
    --header 'Main Menu' \
    "$INSTALL_MACOS_OPTION_LABEL" \
    "$DOWNLOAD_DISK_IMAGES_OPTION_LABEL" \
    "$SCAN_DISK_IMAGE_OPTION_LABEL" \
    "$RESET_NVRAM_OPTION_LABEL" \
    "$HARDWARE_TEST_OPTION_LABEL" \
    "$VIEW_DEVICE_INFO_OPTION_LABEL" \
    "$EXIT_OPTION_LABEL"
  )

  case "$CHOICE" in
    "$INSTALL_MACOS_OPTION_LABEL")
      choose_disk_image_method
      ;;
    "$RESET_NVRAM_OPTION_LABEL")
      clear && clear_nvram && main_menu
      ;;
    "$VIEW_DEVICE_INFO_OPTION_LABEL")
      view_device_info
      ;;
    "$HARDWARE_TEST_OPTION_LABEL")
      open_hardware_test
      ;;
    "$DOWNLOAD_DISK_IMAGES_OPTION_LABEL")
      download_disk_images
      ;;
    "$SCAN_DISK_IMAGE_OPTION_LABEL")
      choose_disk_image_to_scan
      ;;
    "$RETURN_VALUE")
      clear && exit 0
      ;;
  esac
}

function download_disk_images() {
  STARTING_PATH="/Volumes"
  BASE_URL="https://refurb-sh.hel1.your-objectstorage.com/sources/"
  # choose_download_image_directory
  not_yet_implemented
}

function choose_download_image_directory() {
  clear
  "${GUM_BINARY}" style --bold --padding 1 "Choose a directory to save the image to:"
  CHOICE_DOWNLOAD_IMAGE_PATH=$("${GUM_BINARY}" file --directory "$STARTING_PATH" --show-help)
  if [ "$CHOICE_DOWNLOAD_IMAGE_PATH" = "$RETURN_VALUE" ]; then
    download_disk_images
  else
    download_image
  fi
}

function download_image() {
  clear
  "${GUM_BINARY}" style --bold --padding 1 "Downloading ${CHOICE_DOWNLOAD_IMAGE_LABEL}... This may take some time."
  log "INFO" "Starting download of ${CHOICE_DOWNLOAD_IMAGE_FILENAME}"
  
  # Create temporary file for download
  local temp_file="${CHOICE_DOWNLOAD_IMAGE_PATH}/${CHOICE_DOWNLOAD_IMAGE_FILENAME}.tmp"
  
  # Download with retry logic and timeout
  local max_retries=3
  local retry_count=0
  local success=false
  
  while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
    log "INFO" "Download attempt $((retry_count + 1))/$max_retries"
    
    if curl -L --connect-timeout 30 --max-time 3600 --retry 3 --retry-delay 5 \
         --progress-bar "${CHOICE_DOWNLOAD_IMAGE_URL}" -o "$temp_file"; then
      
      # Verify download completed successfully
      if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
        # Verify it's a valid disk image
        if hdiutil verify "$temp_file" >/dev/null 2>&1; then
          log "INFO" "Download completed and verified successfully"
          mv "$temp_file" "${CHOICE_DOWNLOAD_IMAGE_PATH}/${CHOICE_DOWNLOAD_IMAGE_FILENAME}"
          success=true
          choose_image_scan
        else
          log "ERROR" "Downloaded file is not a valid disk image"
          "${GUM_BINARY}" style --foreground "#red" "Error: Downloaded file is not a valid disk image"
        fi
      else
        log "ERROR" "Downloaded file is empty or missing"
        "${GUM_BINARY}" style --foreground "#red" "Error: Downloaded file is empty or missing"
      fi
    else
      log "WARN" "Download attempt failed"
      retry_count=$((retry_count + 1))
      if [ $retry_count -lt $max_retries ]; then
        "${GUM_BINARY}" style --foreground "#yellow" "Download failed, retrying ($retry_count/$max_retries)..."
        sleep 5
      fi
    fi
  done

  if [ "$success" = false ]; then
    log "ERROR" "Failed to download after $max_retries attempts"
    "${GUM_BINARY}" style --foreground "#red" "Failed to download after $max_retries attempts"
    rm -f "$temp_file"
    download_disk_images
  fi
}

function choose_image_scan() {
  clear
  "${GUM_BINARY}" confirm --show-output "Download complete. Would you like to scan the image now? (Recommended)" && scan_disk_image ${CHOICE_DOWNLOAD_IMAGE_PATH}/${CHOICE_DOWNLOAD_IMAGE_FILENAME} || download_disk_images
}

function choose_disk_image_to_scan() {
  local STARTING_PATH="/Volumes"
  clear
  "${GUM_BINARY}" style --bold --padding 1 "Choose a disk image to scan:"
  CHOICE_DISK_IMAGE_TO_SCAN=$("${GUM_BINARY}" file --file "$STARTING_PATH" --show-help)

  case "$CHOICE_DISK_IMAGE_TO_SCAN" in
    "$RETURN_VALUE")
      main_menu
      ;;
    *)
      scan_disk_image ${CHOICE_DISK_IMAGE_TO_SCAN}
      ;;
  esac
}

function scan_disk_image() {
  clear
  "${GUM_BINARY}" spin \
    --spinner minidot \
    --title "Verifying ${1}..." \
    --show-output \
    -- asr imagescan --source ${1} && echo 'Done!' && sleep 5 && main_menu
}

#######################################
# Run a command with error handling and logging
# Arguments:
#   $1 - Command description for logging
#   $2... - Command and its arguments
# Returns:
#   Command exit status
#######################################
run_cmd() {
  local desc="$1"
  shift
  local cmd=("$@")
  
  log "INFO" "Running: $desc"
  if [ "$DRY_RUN" = true ]; then
    log "INFO" "[DRY RUN] Would execute: ${cmd[*]}"
    return 0
  fi
  
  if ! "${cmd[@]}" 2>&1 | tee -a "$LOG_FILE"; then
    log "ERROR" "Failed to $desc"
    return 1
  fi
  return 0
}

#######################################
# Show a progress spinner with a message
# Arguments:
#   $1 - Message to display
#   $2... - Command to run
#######################################
show_progress() {
  local message="$1"
  shift
  local cmd=("$@")
  
  if [ "$DRY_RUN" = true ]; then
    "${GUM_BINARY}" style --foreground "#yellow" "[DRY RUN] Would execute: ${cmd[*]}"
    sleep 1
    return 0
  fi
  
  "${GUM_BINARY}" spin --spinner line \
    --title "$message" \
    -- "${cmd[@]}"
}

function clear_nvram() {
  log "INFO" "Resetting NVRAM"
  
  if ! run_cmd "clear NVRAM" nvram -c; then
    log "ERROR" "Failed to clear NVRAM"
    "${GUM_BINARY}" style --foreground "#red" "Error: Failed to clear NVRAM"
    sleep 2
  else
    log "INFO" "Successfully cleared NVRAM"
  fi
  
  if ! run_cmd "restore power management defaults" pmset -a restoredefaults; then
    log "WARN" "Failed to restore power management defaults"
  fi
  
  sleep 1
}

function view_device_info() {
  SYSTEM_PROFILER_PATH="/usr/sbin/system_profiler"
  clear
  log "INFO" "Gathering system information"
  
  if [ ! -x "$SYSTEM_PROFILER_PATH" ]; then
    log "ERROR" "System Profiler not found at $SYSTEM_PROFILER_PATH"
    "${GUM_BINARY}" style --foreground "#red" "Error: System Profiler not found"
    sleep 2
    main_menu
    return 1
  fi
  
  show_progress "Generating System Profile..." \
    "$SYSTEM_PROFILER_PATH" \
    SPHardwareDataType \
    SPMemoryDataType \
    SPDisplaysDataType \
    SPPowerDataType \
    SPStorageDataType | \
    "${GUM_BINARY}" pager || {
      log "ERROR" "Failed to generate system profile"
      "${GUM_BINARY}" style --foreground "#red" "Error: Failed to generate system profile"
      sleep 2
    }
  
  main_menu
}

function choose_disk_image_method() {
  LOCAL_OPTION="${LOCAL_OPTION_LABEL}:${LOCAL_OPTION_VALUE}"
  ONLINE_OPTION="${ONLINE_OPTION_LABEL}:${ONLINE_OPTION_VALUE}"

  clear
  "${GUM_BINARY}" style --bold --padding 1 '(1) Select Source Image  ―――>  (2)  ―――>  (3)'
  case $("${GUM_BINARY}" choose \
    --header "Where should we source the image from?" \
    --label-delimiter=":" \
    "$LOCAL_OPTION" \
    "$ONLINE_OPTION" \
  ) in
    "$RETURN_VALUE") main_menu;;
    "$LOCAL_OPTION_VALUE") choose_local_disk_image;;
    "$ONLINE_OPTION_VALUE") choose_online_disk_image;;
  esac
}

function scan_online_images() { # TODO
  local url="https://refurb-sh.hel1.your-objectstorage.com/sources/"
  clear
  "${GUM_BINARY}" spin --spinner moon \
    --title "Scanning refurb.sh for disk images... (WIP)" \
    --show-output \
    -- sleep 2
    # -- curl -s "$url" | grep -o '"[^"]*\.dmg"' | tr -d '"'
}

function scan_local_images() {
  local LOCAL_IMAGES_SCAN_PATH="/Volumes"
  clear
  "${GUM_BINARY}" spin --spinner globe \
    --title "Scanning ${LOCAL_IMAGES_SCAN_PATH} for disk images..." \
    --show-output \
    -- find "$LOCAL_IMAGES_SCAN_PATH" -type f -iname '*.dmg' 2>/dev/null
}

function choose_local_disk_image() {
  local SCAN_RESULTS=$(scan_local_images)
  
  if [ -z "$SCAN_RESULTS" ]; then
    SCAN_RESULTS=$(scan_local_images)
    if [ -z "$SCAN_RESULTS" ]; then
      clear
      "${GUM_BINARY}" confirm "No disk images found. Would you like to download a disk image instead?" && \
        download_disk_images || main_menu
      return
    fi
  fi

  clear
  "${GUM_BINARY}" style --bold --padding 1 '(1) Select Source Image  ―――>  (2)  ―――>  (3)'

  local DOWNLOAD_DISK_IMAGES_OPTION_LABEL="Download disk images"

  CHOICE_SOURCE_IMAGE=$(echo -e "${SCAN_RESULTS[@]}\n${DOWNLOAD_DISK_IMAGES_OPTION_LABEL}" | "${GUM_BINARY}" choose \
    --header 'Select the MacOS disk image to install:'
  )
  
  case $CHOICE_SOURCE_IMAGE in
    $DOWNLOAD_DISK_IMAGES_OPTION_LABEL)
      download_disk_images
      ;;
    *)
      choose_target_disk
      ;;
    "")
      choose_disk_image_method
      ;;
  esac
}

function list_disks() {
  diskutil list internal physical | grep -E "^/dev/disk[0-9]+" | cut -d' ' -f1
}

function get_device_name() {
  diskutil info $1 | grep -E "Device / Media Name:" | cut -d':' -f2 | trim_whitespace
}

function get_device_size() {
  diskutil info $1 | grep -E "Disk Size:" | cut -d':' -f2 | cut -d'(' -f1 | trim_whitespace
}

function disk_to_label() {
  for disk in $disks; do
    label="$disk ($(get_device_name $disk) - $(get_device_size $disk))"
    echo "$label:$disk"
  done
}

function choose_target_disk() {
  disks=$(list_disks)
  disks_labels=$(disk_to_label $disks)
  clear
  "${GUM_BINARY}" style --bold '(✔️)  ―――>  (2) Choose Target Disk  ―――>  (3)'
  "${GUM_BINARY}" style --bold --padding 1 "Source Image: ${CHOICE_SOURCE_IMAGE}" ''

  CHOICE_TARGET_DISK=$(echo -e "$disks_labels" | "${GUM_BINARY}" choose \
    --header 'Select a disk to install MacOS to:' \
    --label-delimiter=":" \
    --select-if-one \
    | cut -d' ' -f1)
  
  # Show disk options using gum filter
  case $CHOICE_TARGET_DISK in
    $RETURN_VALUE) main_menu;;
    *) choose_CHOICE_POST_OPTIONS;;
  esac
}

function choose_CHOICE_POST_OPTIONS() {
  CLEAR_NVRAM_OPTION="Clear NVRAM and SMC"
  REBOOT_OPTION="Reboot after installation"

  clear
  "${GUM_BINARY}" style --bold '(✔️)  ―――>  (✔️)  ―――>  (3) Post Installation Options' ''
  "${GUM_BINARY}" style --bold --padding 1 "Source Image: ${CHOICE_SOURCE_IMAGE}" "Target Disk: ${CHOICE_TARGET_DISK}" ''


  CHOICE_POST_OPTIONS=$("${GUM_BINARY}" choose "$CLEAR_NVRAM_OPTION" "$REBOOT_OPTION" \
    --header 'Select optional installation options:' \
    --no-limit \
    --selected="${CLEAR_NVRAM_OPTION},${REBOOT_OPTION}"
  )

  case $CHOICE_POST_OPTIONS in
    *) confirm_installation;;
  esac
}

function confirm_installation() {
  clear
  "${GUM_BINARY}" style --bold --padding 1 'Confirm Operation'
  "${GUM_BINARY}" style --border rounded --padding 1 \
  'We will now perform the following operations. Please confirm to proceed.' \
  "- Erase ${CHOICE_TARGET_DISK} and reformat it to 'Macintosh HD' (APFS format)" \
  "- Perform asr restore to ${CHOICE_TARGET_DISK} using $CHOICE_SOURCE_IMAGE"

  "${GUM_BINARY}" confirm --show-output 'Are you sure you want to proceed?' && install_macos || main_menu
}

function format_target_disk() {
  "${GUM_BINARY}" spin --title "Formatting ${CHOICE_TARGET_DISK}..." --show-output -- diskutil eraseDisk APFS "Macintosh HD" "${CHOICE_TARGET_DISK}"
}

function restore_source_image() {
  "${GUM_BINARY}" style --bold --padding 1 "Restoring ${CHOICE_SOURCE_IMAGE}"
  "${GUM_BINARY}" spin --title "Restoring ${CHOICE_SOURCE_IMAGE}..." --show-output \
    -- asr restore \
    --source "${CHOICE_SOURCE_IMAGE}" \
    --target "${CHOICE_TARGET_DISK}" \
    --erase --noprompt
}

function install_macos() {
  clear
  format_target_disk && \
  restore_source_image
  
  # Handle post-installation options
  if [[ "$CHOICE_POST_OPTIONS" == *"${CLEAR_NVRAM_OPTION}"* ]]; then
    clear_nvram
  fi

  if [[ "$CHOICE_POST_OPTIONS" == *"${REBOOT_OPTION}"* ]]; then
    log "INFO" "Installation complete, rebooting system"
    "${GUM_BINARY}" style --foreground "#green" "Installation complete! Rebooting in 5 seconds..."
    sleep 5
    run_cmd "reboot system" shutdown -r now
  else
    log "INFO" "Installation complete"
    "${GUM_BINARY}" style --foreground "#green" "Installation complete!"
    sleep 2
    main_menu
  fi
}

function open_hardware_test() {
  not_yet_implemented
}

function not_yet_implemented() {
  clear
  case $("${GUM_BINARY}" choose \
    --header "This feature is not yet implemented." \
    "Ok"
  ) in
    *) main_menu;;
  esac
}

start() {
  is_running_as_root && \
  detect_architecture && \
  check_if_gum_is_installed && \
  main_menu
}

start
