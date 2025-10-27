#!/usr/bin/env bash
set -o errexit -o pipefail

echo "INFO" "Running system profiler"
system_profiler_path="${miau}/usr/sbin/system_profiler"

if [ ! -x "$system_profiler_path" ]; then
  echo "ERROR" "System Profiler not found at $system_profiler_path"
  "${gum}" style --foreground "#red" "Error: System Profiler not found"
  sleep 2
  exit 0
fi

choice=$("${system_profiler_path}" -listDataTypes \
 | tail -n +2 \
 | "${gum}" choose \
 --ordered \
 --header="Toggle system information to display. Default items are already selected." \
 --selected="SPHardwareDataType,SPMemoryDataType,SPDisplaysDataType,SPPowerDataType,SPStorageDataType" \
 --no-limit)

"${gum}" spin --spinner jump --title "Gathering system information..." -- "$system_profiler_path" $choice | "${gum}" pager

exit 0