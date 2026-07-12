# fwde-linux

Linux-native recreation of FWDE with an X11-first backend and a platform-agnostic simulation core.

## Workspace layout

- `crates/fwde-core`: window model, physics engine, grouping-ready domain types
- `crates/fwde-backend`: backend traits and the first X11 backend surface
- `crates/fwde-daemon`: long-running service that ties the engine to a backend

## Current state

This is the initial rewrite scaffold. The core crate already contains a usable simulation step over abstract windows and outputs. The backend crate defines the integration boundary. The daemon starts the service process and is ready to host the event loop.

The daemon now supports a replay-driven execution path via `FWDE_SNAPSHOT_PATH`, which lets the transliterated Linux service compose end to end against recorded or hand-authored window snapshots before the real X11 backend is implemented.

## Intended target

- Debian-family distributions on X11 first
- Wayland/compositor-specific backends later

## Debian bootstrap

When you dual boot into Linux, use the provided scripts instead of assembling the toolchain manually.

Fastest first-time path:

```bash
cd fwde-linux
chmod +x scripts/*.sh
./scripts/first-run.sh
```

1. `scripts/bootstrap-debian.sh`
Installs Debian build dependencies and Rust via `rustup` if needed.

2. `scripts/build.sh`
Runs `cargo fmt`, `cargo check`, `cargo clippy`, and `cargo build -p fwde-daemon`.

3. `scripts/run-replay.sh`
Runs the daemon against the sample snapshot/config and writes applied move output to `examples/applied-moves.json`.

4. `scripts/run-daemon.sh`
Runs the built daemon binary directly.

5. `scripts/install-user-service.sh`
Installs a `systemd --user` service so you can start the daemon on login while testing.

6. `scripts/clean.sh`
Removes build artifacts and replay output.

7. `scripts/first-run.sh [debug|release]`
Runs the complete first-time Linux test path: bootstrap, build, then replay.

Example shell session:

```bash
cd fwde-linux
chmod +x scripts/*.sh
./scripts/first-run.sh
```

For a release build instead of debug:

```bash
./scripts/first-run.sh release
```

## Replay mode

Set `FWDE_SNAPSHOT_PATH` to a JSON snapshot file and run the daemon. The current X11 backend will use that file as a live snapshot source.

Example snapshot: `examples/sample-snapshot.json`
Example config override file: `examples/sample-config.json`

Optional environment variables:

- `FWDE_CONFIG_PATH`: load flat-path config overrides compatible with the transliterated FWDE settings model
- `FWDE_MAX_TICKS`: number of daemon ticks to run before exit
- `FWDE_APPLIED_MOVES_PATH`: write emitted move plans to a JSON file each time replay mode receives moves

## Script reference

See `scripts/README.md` for the full Linux helper script list.

Snapshot fields:

- `outputs`: array of `OutputInfo`
- `windows`: array of `WindowInfo`
- `focused_window`: optional window id
- `hovered_window`: optional window id
- `pointer_position`: optional `{ "x": number, "y": number }`
- `timestamp_ms`: current logical time

Example PowerShell run:

```powershell
$env:FWDE_SNAPSHOT_PATH = "examples/sample-snapshot.json"
$env:FWDE_APPLIED_MOVES_PATH = "examples/applied-moves.json"
$env:FWDE_MAX_TICKS = "5"
cargo run -p fwde-daemon
```

Equivalent Linux shell run:

```bash
export FWDE_SNAPSHOT_PATH="examples/sample-snapshot.json"
export FWDE_CONFIG_PATH="examples/sample-config.json"
export FWDE_APPLIED_MOVES_PATH="examples/applied-moves.json"
export FWDE_MAX_TICKS="5"
cargo run -p fwde-daemon
```
