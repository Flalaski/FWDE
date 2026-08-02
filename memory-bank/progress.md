# Progress (Updated: 2026-07-21)

## Done

- **Steam windows are now manageable** — research confirmed Steam's UI runs in CEF `steamwebhelper.exe` with class `SDL_app` and custom chrome. It was (a) flagged `fullscreen` because `SDL_app` is a fullscreen-game class and `steamwebhelper.exe` was in `fullscreenProcesses`, and (b) would have been floated by rule 7 (WS_POPUP, no caption). Added `steam.exe`/`steamwebhelper.exe` to `IsFullscreenWindow`'s `manageableProcesses` (removed from `fullscreenProcesses`) and to the default `ForceTrackProcesses` config so Steam is always managed. True Steam popups/dialogs still handled by popup cohesion (checked first).
- **Elevated-window (UIPI) support** — Steam (`steamwebhelper.exe`), Notepad++ [Administrator], and elevated FileZilla showed as `invalid` because they run ELEVATED while FWDE runs non-elevated: Windows UIPI makes style/minmax queries throw "Access is denied" and blocks SetWindowPos. Added:
  - `_GetWindowExcludeReason()` — Ctrl+Alt+D now reports the precise reason (`invalid:minimized/maximized/toolwindow/not-visible/no-title/fullscreen/access-denied-elevated`)
  - New opt-in config `RunAsAdmin` — when enabled and FWDE isn't elevated, FWDE relaunches itself elevated at startup (Run '*RunAs') so it can manage elevated windows; debug output shows a NOTE when elevated windows are present
- **Fixed: AHK GUI / Steam-style windows wrongly floated** — `FloatStyles` (WS_POPUP) floated ANY popup-styled window, but AHK v1 GUIs (`AutoHotkeyGUI`, e.g. Ahk2Exe) and custom-chrome apps (Steam) use WS_POPUP + WS_CAPTION (they look like normal windows) → FWDE never managed them. `IsWindowFloating` rule 7 now requires no WS_CAPTION for the WS_POPUP float. Ctrl+Alt+D now lists untracked non-floating windows with the exact exclusion reason (owned-popup / fwde-self / companion / invalid / monitor-filter).
- **Fixed: self-moving apps freezing physics** — `WindowMoveHandler`/`WindowSizeHandler` refreshed `ActiveWindow`/`LastUserMove` on EVERY app-initiated WM_MOVE/WM_SIZE, so self-repositioning apps (e.g. DarkTide launcher realigning its decorate layer) became permanently "active" and frozen by the active-window protection (energy built, 0 moves, settle loop). Now only real button-held drags/resizes mark a window active or auto-lock it; app-initiated moves still sync position. Added `_DiagnoseIdlePhysics()` — when energy is elevated but 0 moves persist for ~1s, logs each tracked window's skip reason (minmax/popup-freeze/active/manual-lock/snap/resync/at-target/should-move) to `FWDE_debug.log` as `IdleDiag — …`.
- **Same-App Companion Cohesion** — decorate/overlay layers (e.g. Warhammer 40K DarkTide launcher) no longer get pushed off their main window:
  - `AreCompanionPair()`: same process + same WPF `HwndWrapper[exe;;guid]` family + partial overlap (low floor so already-drifted layers pair) + similar size; generic fallback requires an overlay-style window (WS_POPUP, no WS_CAPTION) to avoid gluing unrelated stacked windows
  - `ScanCompanionWindows()`: connected-component grouping, largest window = anchor, others = companions (registry `_companionRegistry`)
  - `SyncCompanionWindows()`: lockstep-follows anchor's exact delta each tick (physics, drags, external moves) — NO host freeze (permanent layer, unlike popups)
  - Companions excluded from independent physics in `GetVisibleWindows`; failsafe in HealthMonitor; dashboard + Ctrl+Alt+D observability
  - Config: `CompanionFollowEnabled`, `CompanionScanIntervalMs`, `CompanionMinOverlap`, `CompanionMaxSizeRatio`; ToggleArrangement resets companion history
  - Shared `_IsSelfWindow()` helper now used by popup detection, GetVisibleWindows, and companion scan
- **Owned-Popup Cohesion** — browser permission bubbles ("Chrome Legacy Window") no longer drift from their host while FWDE is active:
  - `IsOwnedInteractivePopup()` detection: GW_OWNER + Chromium/Firefox/dialog class + style/title heuristics, with system-chrome and self-process (FWDE's own GUI) exclusion
  - `ScanOwnedPopups()` throttled registry (popup → owner); popups excluded from independent physics in `GetVisibleWindows` so physics never fights the browser's own anchoring
  - `SyncOwnedPopups()` lockstep movement — re-applies the owner's exact movement delta each tick (covers physics moves, user drags, external moves), no smoothing lag
  - `_popupOwners` host freeze wired into CalculateDynamicLayout, CalculateWindowForces, ApplyWindowMovements, ResolveFloatingCollisions, ResolveOverlapsDirect so popup buttons stay clickable while open
  - HealthMonitor popup-registry failsafe + status dashboard + Ctrl+Alt+D debug output for popup tracking
  - Config keys: `PopupFollowEnabled` (bool), `PopupFreezeHost` (bool), `PopupScanIntervalMs` (number) — exposed in the parameter settings GUI
  - ToggleArrangement resets popup history so lockstep deltas never carry stale positions across toggles
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
