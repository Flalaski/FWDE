#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

log "Removing Cargo build artifacts"
rm -rf "${CARGO_TARGET_DIR}"
# Also remove legacy source-tree target/ that may exist from pre-CARGO_TARGET_DIR builds.
if [[ -d "${PROJECT_ROOT}/target" ]]; then
  log "Removing legacy source-tree target/"
  rm -rf "${PROJECT_ROOT}/target"
fi

log "Removing replay output artifacts"
rm -f "${EXAMPLES_DIR}/applied-moves.json"

log "Clean complete"
