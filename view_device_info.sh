#!/usr/bin/bash
set -euo pipefail

echo "INFO: Running system profiler"
system_profiler_path="/usr/sbin/system_profiler"

if [[ ! -x "${system_profiler_path}" ]]; then
  gum style --foreground "#red" "Error: System Profiler not found. You will need to install macOS first."
  sleep 1
  return 1
fi

# Get list of available DataTypes for user selection
default_selected="SPHardwareDataType,SPMemoryDataType,SPDisplaysDataType,SPPowerDataType,SPStorageDataType"
datatypes=$("${system_profiler_path}" -listDataTypes | tail -n +2)

choice=$(echo "$datatypes" | gum choose \
  --ordered \
  --header="Toggle system information to display. Default items are already selected." \
  --selected="$default_selected" \
  --no-limit \
  --label-delimiter ":"
)

if [[ -z "$choice" ]]; then
  gum style --foreground "#yellow" "No data types selected. Exiting."
  return 0
fi

gum spin --spinner jump --title "Gathering system information..." -- \
  "${system_profiler_path}" $choice | gum pager

return 0
