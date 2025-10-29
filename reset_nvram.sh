#!/usr/bin/env bash
set -o errexit -o pipefail

echo "INFO" "Clearing NVRAM..."
nvram -c

echo "INFO" "Restoring System Management Controller to default settings..."
pmset -a restoredefaults

echo "INFO" "Done"
return 0
