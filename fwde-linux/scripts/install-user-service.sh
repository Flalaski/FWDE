#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

PROFILE="${1:-debug}"
DAEMON_BIN="$(binary_path "${PROFILE}")"
SERVICE_DIR="${HOME}/.config/systemd/user"
SERVICE_FILE="${SERVICE_DIR}/fwde-linux.service"

require_cargo
cd "${PROJECT_ROOT}"

if [[ ! -x "${DAEMON_BIN}" ]]; then
  log "Daemon binary not found for profile ${PROFILE}; building first"
  run_script build.sh "${PROFILE}"
fi

mkdir -p "${SERVICE_DIR}"
cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=FWDE Linux daemon
After=graphical-session.target

[Service]
Type=simple
WorkingDirectory=${PROJECT_ROOT}
Environment=RUST_LOG=info
ExecStart=${DAEMON_BIN}
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
EOF

log "Installed user service to ${SERVICE_FILE}"
systemctl --user daemon-reload
log "To enable on login: systemctl --user enable --now fwde-linux.service"
log "To inspect logs: journalctl --user -u fwde-linux.service -f"
