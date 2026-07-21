# Progress (Updated: 2026-07-21)

## Done

- **Health & Recovery Architecture** — comprehensive watchdog subsystem for autonomous stall detection & recovery:
  - Heartbeat timestamps in all 3 timer callbacks (CalculateDynamicLayout, ApplyWindowMovements, UpdateWindowStates)
  - HealthMonitor watchdog (5s period): detects stale timers, stuck drag threads, stale DragActive, stuck SnapInProgress entries, and auto-recovers
  - DragWindow refactored with try/catch/finally + timestamp-based thread guard (30s failsafe)
  - SnapInProgress failsafe: type validation + 15s hard timeout to prevent permanent window-list stall
  - WindowMoveHandler and WindowSizeHandler wrapped in try/catch (prevent silent state corruption)
  - Real-time Status Dashboard (Ctrl+Alt+S): timer health, drag state, snap state, energy, recovery counters
  - Icon zone cache invalidation when DesktopIconRepulsion toggled
  - Failsafe counters (`_dragFailsafeCount`, `_snapFailsafeCount`, `_recoveryCount`) for diagnostics
- User's tuned FWDE config adopted as new system defaults across all parameters
- All parameter slider ranges massively expanded (2-5x) for further fine-tuning
- Added missing parameter overrides: SeedDiagonalStep, NoiseScale, NoiseInfluence, ManualWindowAlpha, ManualLockDuration, UserMoveTimeout, TooltipDuration, ResizeDelay, MinMargin, MinGap, ManualGapBonus, AnimationDuration, PhysicsUpdateInterval
- Implemented multi-pass chain-effect collision resolution (3 iterative passes with diminishing force weights)
- Chain physics uses probed positions so velocity from pass 1 cascades to pass 2, creating realistic chain reactions
- Wired Config["Damping"] into all hardcoded damping factors across CalculateWindowForces
- Redesigned FWDE physics system from center-attraction to overlap-based repulsion
- Implemented user move detection to temporarily pause physics
- Added gentle edge repulsion to keep windows on screen
- Reduced physics timing for smoother, more subtle movement
- Added overlap calculation functions for accurate collision detection

## Doing

- Testing the chain-effect physics with real window clusters
- Monitoring HealthMonitor recovery events in real-world usage

## Next

- Fine-tune chain pass weights based on real-world testing
- Add visual indicators for chain propagation (debug overlay)
- Consider adaptive pass count based on window cluster density
