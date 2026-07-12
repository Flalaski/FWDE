#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

PROFILE="${1:-debug}"
[[ "${PROFILE}" =~ ^(debug|release)$ ]] || fail "Invalid profile '${PROFILE}'. Use 'debug' (default) or 'release'."
BUILD_FLAG="$(build_profile_flag "${PROFILE}")"
init_run_logging "build.sh" "${PROFILE}"

require_cargo

cd "${PROJECT_ROOT}"

log "Formatting workspace"
cargo fmt --all

log "Checking workspace"
cargo check

log "Linting workspace"
cargo clippy --workspace --all-targets -- -D warnings

log "Building fwde-daemon (${PROFILE})"
if [[ -n "${BUILD_FLAG}" ]]; then
  cargo build -p fwde-daemon ${BUILD_FLAG}
else
  cargo build -p fwde-daemon
fi

log "Build complete"
