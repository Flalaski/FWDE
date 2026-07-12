#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

DEBUG_ROOT="${FWDE_DEBUG_ROOT:-${DEFAULT_DEBUG_ROOT}}"
EXPORT_DIR="${1:-${DEBUG_ROOT}/exports}"

[[ -d "${DEBUG_ROOT}" ]] || fail "Debug root not found: ${DEBUG_ROOT}"
mkdir -p "${EXPORT_DIR}"

latest_run_dir="$(
  find "${DEBUG_ROOT}" \
    -mindepth 2 \
    -maxdepth 2 \
    -type d \
    ! -name exports \
    -printf '%T@ %p\n' \
    | sort -nr \
    | head -n 1 \
    | cut -d' ' -f2-
)"

[[ -n "${latest_run_dir}" ]] || fail "No run folders found under ${DEBUG_ROOT}"

run_id="$(basename "${latest_run_dir}")"
archive_path="${EXPORT_DIR}/${run_id}.tar.gz"

log "Collecting latest run folder"
log "  Source: ${latest_run_dir}"
log "  Archive: ${archive_path}"

tar -C "$(dirname "${latest_run_dir}")" -czf "${archive_path}" "${run_id}"

log "Collection complete"
log "  Saved: ${archive_path}"
