# Active Context

## Current Goals

- Testing chain-effect multi-pass collision resolution with real window clusters
- Fine-tuning expanded parameter ranges against real-world DAW/plugin workflows
- All hardcoded damping factors now wired to Config["Damping"] for unified control
- **Health & Recovery Architecture deployed** — heartbeat watchdogs, drag-thread failsafes, SnapInProgress deadlock protection, timer auto-recovery, real-time status dashboard (Ctrl+Alt+S)
- **Owned-Popup Cohesion deployed (2026-08-01)** — browser permission bubbles ("Chrome Legacy Window") now follow their host 1:1 and the host is frozen while the popup is open, fixing missed clicks. Keys: `PopupFollowEnabled`, `PopupFreezeHost`, `PopupScanIntervalMs`
- **Same-App Companion Cohesion deployed (2026-08-01)** — decorate/overlay layers (DarkTide launcher's WPF `HwndWrapper` frame) glued to their main window 1:1. Keys: `CompanionFollowEnabled`, `CompanionScanIntervalMs`, `CompanionMinOverlap`, `CompanionMaxSizeRatio`
- **WM_MOVE active-window freeze fixed (2026-08-01)** — self-moving apps no longer get permanently marked "active"; `IdleDiag — …` lines in `FWDE_debug.log` now show exactly why a window isn't moving when physics has energy
- **AHK GUI / Steam-style windows fixed (2026-08-01)** — WS_POPUP only floats when there's no caption, so `AutoHotkeyGUI` (Ahk2Exe) and custom-chrome apps (Steam) are managed; Ctrl+Alt+D now shows the exclusion reason for untracked non-floating windows
- **Elevated-window (UIPI) support (2026-08-01)** — Steam/Notepad++[Admin]/FileZilla were "invalid" because they run elevated; Ctrl+Alt+D now reports `invalid:access-denied (elevated?)`, and the opt-in `RunAsAdmin` config makes FWDE relaunch elevated so it can manage them
- **Steam manageable (2026-08-01)** — Steam's UI lives in CEF `steamwebhelper.exe` with class `SDL_app` + custom chrome; it was flagged `fullscreen` (SDL_app is a game class) and would have floated (WS_POPUP, no caption). Added steam processes to `manageableProcesses` + default `ForceTrackProcesses`

## Current Blockers

- None yet

## Verified (2026-08-01)

- ✅ Steam fixed — `Steam` + `About Steam` (`SDL_app` / `steamwebhelper.exe`) now appear under TRACKED WINDOWS and are managed by physics. Ahk2Exe (`AutoHotkeyGUI`) also managed.
- ✅ Remaining `invalid:minimized` (FileZilla, Notepad++ [Administrator]) confirmed as correct-by-design — FWDE doesn't manage minimized windows.

## To Verify Next Session

- Reload FWDE with Steam open (restored, not minimized) — Steam should appear under TRACKED WINDOWS and move with physics; Ctrl+Alt+D should no longer list it under UNTRACKED NON-FLOATING
- Reload FWDE, open the parameter settings, enable `RunAsAdmin`, and reload (FWDE relaunches elevated — accept the UAC prompt). Steam / Notepad++ [Administrator] / elevated FileZilla should then move from "invalid" to TRACKED WINDOWS
- If you prefer NOT to run FWDE elevated: Ctrl+Alt+D now shows the exact reason for each untracked window (`invalid:minimized/maximized` = by design; `invalid:access-denied (elevated?)` = needs elevation)
- Watch the `About Steam` dialog (500x300, tracked as its own body): if it ever visually separates from the Steam main window while FWDE rearranges, it needs companion/owned-popup treatment (it currently doesn't overlap the main window, so it isn't paired)
- Reload FWDE with Ahk2Exe open — it should appear under TRACKED WINDOWS and move with physics
- Reload FWDE with the DarkTide launcher open and overlapping windows present — windows should now actually move (energy → moves). If any window still doesn't move, check `FWDE_debug.log` for `IdleDiag — …` lines
- Real-world: open a Chrome location-permission prompt, let FWDE rearrange windows around it, then click "Allow" — button should land
- Real-world: drag the host Chrome window while the popup is open — popup should track it exactly
- Confirm no owned non-popup windows (e.g. DevTools) get misclassified by `IsOwnedInteractivePopup`
- Real-world: open the DarkTide launcher, let FWDE arrange windows — the "Alpha" decorate layer should stay glued to the "Launcher" main window (check via Ctrl+Alt+D → COMPANION COHESION section)
- Confirm two unrelated same-process windows (e.g. two VS Code windows) are NOT glued together