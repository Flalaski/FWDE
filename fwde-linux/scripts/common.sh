#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EXAMPLES_DIR="${PROJECT_ROOT}/examples"
DEFAULT_BUILD_PROFILE="debug"
DEFAULT_DEBUG_ROOT="${SCRIPT_DIR}/debug outputs/runs"

# Redirect Cargo's target directory to the local filesystem so that build
# scripts and compiled binaries can be executed even when the project lives
# on a drive mounted noexec (e.g. MX Linux live / USB environments).
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-${HOME}/.cache/fwde-target}"

FWDE_DEBUG_ENABLED=0
FWDE_RUN_ID=""
FWDE_RUN_DIR=""
FWDE_LOG_FILE=""
FWDE_RUN_START_EPOCH="0"

log() {
  echo "[fwde-linux] $*"
}

fail() {
  echo "[fwde-linux] $*" >&2
  exit 1
}

record_run_metadata() {
  local entry_file="$1"
  local script_name="$2"
  local profile="$3"

  {
    echo "run_id=${FWDE_RUN_ID}"
    echo "script=${script_name}"
    echo "profile=${profile}"
    echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "project_root=${PROJECT_ROOT}"
    echo "script_dir=${SCRIPT_DIR}"
    echo "cargo_target_dir=${CARGO_TARGET_DIR}"
    echo "pwd=${PWD}"
    echo "host=$(hostname 2>/dev/null || echo unknown)"
    if command -v git >/dev/null 2>&1; then
      echo "git_commit=$(git -C "${PROJECT_ROOT}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
      echo "git_branch=$(git -C "${PROJECT_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
      echo "git_status_short=$(git -C "${PROJECT_ROOT}" status --short 2>/dev/null | wc -l | tr -d ' ')"
    fi
  } >"${entry_file}"
}

init_run_logging() {
  local script_name="$1"
  local profile="${2:-${DEFAULT_BUILD_PROFILE}}"
  local enable_debug="${FWDE_DEBUG_LOGGING:-1}"

  if [[ "${enable_debug}" == "0" ]]; then
    return
  fi

  if [[ "${FWDE_DEBUG_ENABLED}" == "1" ]]; then
    return
  fi

  local safe_script
  local day_bucket
  local run_stamp
  local debug_root

  safe_script="$(basename "${script_name}" .sh)"
  day_bucket="$(date -u +%Y%m%d)"
  run_stamp="$(date -u +%Y%m%d_%H%M%S)"
  debug_root="${FWDE_DEBUG_ROOT:-${DEFAULT_DEBUG_ROOT}}"

  FWDE_RUN_ID="${run_stamp}_${safe_script}_${profile}_pid${$}"
  FWDE_RUN_DIR="${debug_root}/${day_bucket}/${FWDE_RUN_ID}"
  FWDE_LOG_FILE="${FWDE_RUN_DIR}/session.log"
  FWDE_RUN_START_EPOCH="$(date +%s)"
  FWDE_DEBUG_ENABLED=1

  mkdir -p "${FWDE_RUN_DIR}/artifacts"
  record_run_metadata "${FWDE_RUN_DIR}/meta.env" "${safe_script}" "${profile}"

  ln -sfn "${FWDE_RUN_DIR}" "${debug_root}/latest" 2>/dev/null || true

  # Mirror all output to per-run log file while keeping stdout/stderr visible.
  exec > >(tee -a "${FWDE_LOG_FILE}") 2>&1

  if [[ "${FWDE_DEBUG_TRACE:-0}" == "1" ]]; then
    set -x
  fi

  trap 'finalize_run_logging $?' EXIT
  log "Run logging enabled"
  log "  Run ID: ${FWDE_RUN_ID}"
  log "  Log file: ${FWDE_LOG_FILE}"
}

finalize_run_logging() {
  local exit_code="$1"

  if [[ "${FWDE_DEBUG_ENABLED}" != "1" ]]; then
    return
  fi

  local end_epoch
  local duration

  end_epoch="$(date +%s)"
  duration="$((end_epoch - FWDE_RUN_START_EPOCH))"

  {
    echo "exit_code=${exit_code}"
    echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "duration_seconds=${duration}"
  } >>"${FWDE_RUN_DIR}/meta.env"

  log "Run complete with exit code ${exit_code} (${duration}s)"
  log "Saved debug output under ${FWDE_RUN_DIR}"
}

run_artifacts_dir() {
  if [[ -n "${FWDE_RUN_DIR}" ]]; then
    echo "${FWDE_RUN_DIR}/artifacts"
  else
    echo "${PROJECT_ROOT}/debug-artifacts"
  fi
}

source_cargo_env() {
  if [[ -f "${HOME}/.cargo/env" ]]; then
    # shellcheck source=/dev/null
    source "${HOME}/.cargo/env"
  fi
}

require_command() {
  local command_name="$1"
  command -v "${command_name}" >/dev/null 2>&1 || fail "Required command not found: ${command_name}"
}

require_cargo() {
  source_cargo_env
  require_command cargo
}

ensure_file() {
  local file_path="$1"
  [[ -f "${file_path}" ]] || fail "Required file not found: ${file_path}"
}

run_script() {
  local script_name="$1"
  shift
  bash "${SCRIPT_DIR}/${script_name}" "$@"
}

build_profile_flag() {
  local profile="${1:-${DEFAULT_BUILD_PROFILE}}"
  if [[ "${profile}" == "release" ]]; then
    echo "--release"
  else
    echo ""
  fi
}

binary_path() {
  local profile="${1:-${DEFAULT_BUILD_PROFILE}}"
  if [[ "${profile}" == "release" ]]; then
    echo "${CARGO_TARGET_DIR}/release/fwde-daemon"
  else
    echo "${CARGO_TARGET_DIR}/debug/fwde-daemon"
  fi
}
