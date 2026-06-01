#!/bin/bash

# FluidVoice Fast Incremental Build Wrapper
# Keeps build_dev.sh unchanged; only overrides defaults for local fast loops.
#
# Defaults:
# - Release configuration
# - Incremental Swift compilation
# - Install + launch enabled
#
# You can override any value:
#   INSTALL_APP=1 LAUNCH_APP=1 ./build_incremental.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

CONFIGURATION="${CONFIGURATION:-Release}" \
SWIFT_COMPILATION_MODE="${SWIFT_COMPILATION_MODE:-incremental}" \
INSTALL_APP="${INSTALL_APP:-1}" \
LAUNCH_APP="${LAUNCH_APP:-1}" \
"${PROJECT_DIR}/build_dev.sh"
