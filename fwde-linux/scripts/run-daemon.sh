#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

PROFILE="${1:-debug}"
[[ "${PROFILE}" =~ ^(debug|release)$ ]] || fail "Invalid profile '${PROFILE}'. Use 'debug' (default) or 'release'."
DAEMON_BIN="$(binary_path "${PROFILE}")"
init_run_logging "run-daemon.sh" "${PROFILE}"

require_cargo
cd "${PROJECT_ROOT}"

if [[ ! -x "${DAEMON_BIN}" ]]; then
  log "Daemon binary not found for profile ${PROFILE}; building first"
  run_script build.sh "${PROFILE}"
fi

log "Running fwde-daemon (${PROFILE})"
exec "${DAEMON_BIN}"
