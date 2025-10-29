#!/usr/bin/bash
set -euo pipefail

echo "INFO" "Clearing NVRAM..."
nvram -c

echo "INFO" "Restoring System Management Controller to default settings..."
pmset -a restoredefaults

echo "INFO" "Done"
return 0
