#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

PROFILE="${1:-debug}"
[[ "${PROFILE}" =~ ^(debug|release)$ ]] || fail "Invalid profile '${PROFILE}'. Use 'debug' (default) or 'release'."
init_run_logging "first-run.sh" "${PROFILE}"

trap 'fail "First-run flow failed (last command: ${BASH_COMMAND})"' ERR

log "Starting first-run flow (${PROFILE})"
run_script bootstrap-debian.sh
run_script build.sh "${PROFILE}"
run_script run-replay.sh "${PROFILE}"
log "First-run flow complete"
