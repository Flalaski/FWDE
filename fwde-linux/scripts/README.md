# Script Reference

- `bootstrap-debian.sh`: install Debian dependencies and Rust toolchain.
- `build.sh [debug|release]`: format, lint, check, and build `fwde-daemon`.
- `first-run.sh [debug|release]`: bootstrap, build, and run replay in one command.
- `first-run.bash`: wrapper alias for `first-run.sh`.

Launch scripts with `bash` if the checkout is on a filesystem that does not preserve execute bits.
- `run-daemon.sh [debug|release]`: run the daemon binary directly.
- `run-replay.sh [debug|release]`: run the daemon against the sample snapshot/config.
- `install-user-service.sh [debug|release]`: install a systemd user service for the daemon.
- `clean.sh`: remove build artifacts and replay output.
- `collect-latest-run.bat`: Windows helper that packages the latest run logs into a zip.
- `collect-latest-run.ps1`: PowerShell implementation used by the batch wrapper.

## Automatic Debug Logging

Every script run now writes a timestamped debug bundle by default.

- Root: `scripts/debug outputs/runs`
- Daily partition: `scripts/debug outputs/runs/YYYYMMDD`
- Per run: `scripts/debug outputs/runs/YYYYMMDD/<timestamp>_<script>_<profile>_pid<id>`
- A `latest` symlink is updated when supported by the filesystem.

Each run folder includes:

- `session.log`: full stdout/stderr stream from the script
- `meta.env`: run metadata, git context, timestamps, and exit code
- `artifacts/`: generated outputs associated with that run

For `run-replay.sh`, `FWDE_APPLIED_MOVES_PATH` now defaults to the current run's `artifacts/applied-moves.json` so replay outputs never overwrite each other.

### Logging controls

- Disable logging for one run: `FWDE_DEBUG_LOGGING=0 bash first-run.sh`
- Move log root: `FWDE_DEBUG_ROOT=/path/to/logs bash first-run.sh`
- Enable command tracing in logs: `FWDE_DEBUG_TRACE=1 bash build.sh`

### Build a shareable bug bundle on Windows

From a Windows shell in `fwde-linux/scripts`:

```bat
collect-latest-run.bat
```

Optional overrides (PowerShell style arguments are forwarded to the script):

```bat
collect-latest-run.bat -RunsRoot "D:\logs\fwde\runs" -OutputDir "D:\logs\fwde\bundles"
```

The helper creates `debug outputs/bundles/fwde-debug-<run-id>-<timestamp>.zip` containing the newest run directory.




"


# Navigate to the scripts dir (path will look something like this)
cd /media/Bountiful/Coding/FWDE/FWDE-1/fwde-linux/scripts

# Full first-run (installs deps, builds, runs replay test)
bash first-run.sh

# Or step by step:
bash bootstrap-debian.sh   # installs apt packages + Rust
bash build.sh              # compiles fwde-daemon
bash run-replay.sh         # quick smoke test

"