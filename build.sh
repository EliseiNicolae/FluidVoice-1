#!/bin/bash

# FluidVoice Build Profile Router
# Routes to existing scripts without changing build_dev.sh behavior.
#
# Usage:
#   ./build.sh                    # dev/full-compatible path (build_dev.sh)
#   ./build.sh dev                # same as above
#   ./build.sh full               # same as above
#   ./build.sh incremental        # fast local loop (build_incremental.sh)
#   BUILD_PROFILE=incremental ./build.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILE="${1:-${BUILD_PROFILE:-dev}}"

case "${PROFILE}" in
    dev|full)
        exec "${PROJECT_DIR}/build_dev.sh"
        ;;
    incremental|fast)
        exec "${PROJECT_DIR}/build_incremental.sh"
        ;;
    *)
        echo "Unknown build profile: ${PROFILE}"
        echo "Valid profiles: dev, full, incremental (or fast)"
        exit 1
        ;;
esac
