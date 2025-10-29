#!/usr/bin/bash
set -euo pipefail

echo "INFO" "Running system profiler"
system_profiler_path="/usr/sbin/system_profiler"

if [ ! -x "${system_profiler_path}" ]; then
  gum style --foreground "#red" "Error: System Profiler not found. You will need to install macOS first."
  sleep 1
  return 1
fi

choice=$("${system_profiler_path}" -listDataTypes \
 | tail -n +2 \
 | gum choose \
 --ordered \
 --header="Toggle system information to display. Default items are already selected." \
 --selected="SPHardwareDataType,SPMemoryDataType,SPDisplaysDataType,SPPowerDataType,SPStorageDataType" \
 --no-limit)

gum spin --spinner jump --title "Gathering system information..." -- "${system_profiler_path}" $choice | gum pager

return 0
