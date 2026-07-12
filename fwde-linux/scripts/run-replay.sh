#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

PROFILE="${1:-debug}"
[[ "${PROFILE}" =~ ^(debug|release)$ ]] || fail "Invalid profile '${PROFILE}'. Use 'debug' (default) or 'release'."
DAEMON_BIN="$(binary_path "${PROFILE}")"
init_run_logging "run-replay.sh" "${PROFILE}"

require_cargo

export FWDE_SNAPSHOT_PATH="${FWDE_SNAPSHOT_PATH:-${EXAMPLES_DIR}/sample-snapshot.json}"
export FWDE_CONFIG_PATH="${FWDE_CONFIG_PATH:-${EXAMPLES_DIR}/sample-config.json}"
export FWDE_APPLIED_MOVES_PATH="${FWDE_APPLIED_MOVES_PATH:-$(run_artifacts_dir)/applied-moves.json}"
export FWDE_MAX_TICKS="${FWDE_MAX_TICKS:-5}"

ensure_file "${FWDE_SNAPSHOT_PATH}"
ensure_file "${FWDE_CONFIG_PATH}"
mkdir -p "$(dirname "${FWDE_APPLIED_MOVES_PATH}")"

cd "${PROJECT_ROOT}"

if [[ ! -x "${DAEMON_BIN}" ]]; then
  log "Daemon binary not found for profile ${PROFILE}; building first"
  run_script build.sh "${PROFILE}"
fi

log "Running replay daemon"
log "  FWDE_SNAPSHOT_PATH=${FWDE_SNAPSHOT_PATH}"
log "  FWDE_CONFIG_PATH=${FWDE_CONFIG_PATH}"
log "  FWDE_APPLIED_MOVES_PATH=${FWDE_APPLIED_MOVES_PATH}"
log "  FWDE_MAX_TICKS=${FWDE_MAX_TICKS}"

"${DAEMON_BIN}"

log "Replay run complete"
if [[ -f "${FWDE_APPLIED_MOVES_PATH}" ]]; then
  log "Applied moves written to ${FWDE_APPLIED_MOVES_PATH}"
fi
