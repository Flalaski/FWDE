#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

# Verify this is a Debian/Ubuntu system before proceeding.
if ! command -v apt-get >/dev/null 2>&1; then
  fail "This script requires a Debian/Ubuntu system (apt-get not found). Aborting."
fi

init_run_logging "bootstrap-debian.sh" "setup"

APT_PACKAGES=(
  build-essential
  pkg-config
  curl
  ca-certificates
  git
  libx11-dev
  libxrandr-dev
  libxinerama-dev
  libxext-dev
  libxi-dev
  libxcb1-dev
  jq
  shellcheck
)

if [[ "${EUID}" -eq 0 ]]; then
  SUDO=""
else
  require_command sudo
  SUDO="sudo"
fi

log "Installing Debian build dependencies"
${SUDO} apt-get update
${SUDO} apt-get install -y "${APT_PACKAGES[@]}"

if ! command -v cargo >/dev/null 2>&1; then
  log "Cargo not found; installing Rust toolchain via rustup"
  _rustup_init="$(mktemp /tmp/rustup-init.XXXXXX.sh)"
  # shellcheck disable=SC2064
  trap "rm -f '${_rustup_init}'" EXIT
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o "${_rustup_init}"
  sh "${_rustup_init}" -- -y
  rm -f "${_rustup_init}"
  trap - EXIT
fi

source_cargo_env

log "Ensuring requested Rust components are installed"
rustup component add rustfmt clippy

cd "${PROJECT_ROOT}"
log "Prefetching Cargo dependencies"
cargo fetch

log "Toolchain versions"
rustc --version
cargo --version

log "Bootstrap complete at ${PROJECT_ROOT}"
