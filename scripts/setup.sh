#!/usr/bin/env bash

set -euo pipefail

# Get the directory of the current script
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Run each numbered build script under _base in order. Grouping the output
# keeps the build log readable in GitHub Actions.
for script in "$SCRIPT_DIR"/_base/*.sh; do
  if [[ -f "$script" ]]; then
    echo "::group::===$(basename "$script")==="
    bash "$script"
    echo "::endgroup::"
  fi
done
