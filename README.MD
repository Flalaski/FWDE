# FWDE - Floating Windows Dynamic Equilibrium

Physics-based window management for Windows using AutoHotkey v2.

Read my Blog Post about it to see Video of it working!: https://flalaski.com/index.php/2026/03/19/fwde-floating-windows-dynamic-equilibrium/

## What is FWDE? ("Fweddie")

FWDE automatically arranges floating windows using physics simulation. Windows repel each other to avoid overlap while staying within monitor bounds. Designed for workflows with multiple floating windows (DAW plugins, browser tabs, editor windows, terminals).

## Download

Get the latest installer from Releases:

`https://github.com/Flalaski/FWDE/releases`

## Features

### Physics Engine
- Overlap-based repulsion with damping forces
- Collision avoidance between windows
- Margin and gap constraints to keep windows on-screen
- Limit-cycle detection with automatic settle
- Configurable update rates and force parameters

### Multi-Monitor Support
- Per-monitor physics calculations
- Optional cross-monitor mode (multimonitor expanse)
- Fullscreen detection to exclude games and media players
- Virtual desktop bounds for unified workspace

### Window Detection
- Automatic detection by process name, window class, or title patterns
- Excludes system windows, taskbars, and fullscreen apps
- Manual force-add for any window
- Configurable inclusion patterns

### Manual Controls
- Lock individual windows in position
- Optimize layout on demand
- Toggle physics and arrangement independently
- Pause lock during window drag, resume on release

### Debug Tools
- Window analysis showing why windows are/aren't managed
- Pattern matching display
- Real-time tracking of managed windows
- Crash-safe debug log auto-copied to clipboard
- Periodic log persistence to disk every 60 seconds
- Force-add capability for stubborn windows

## Installation

### Requirements
- Windows 10/11 (x64)
- Windows 7 tested ok

### Recommended: Installer (no AutoHotkey required)
1. Download `FWDE_Setup_<version>.exe` from Releases.
2. Run the installer and follow the setup wizard.
3. Optional during install:
- Create desktop shortcut
- Run FWDE when you sign in

FWDE installs per-user (no admin rights needed) to:

`%AppData%\FWDE`

Update behavior:
- Existing `FWDE_Config.json` is preserved during upgrades.

Uninstall behavior:
- Uninstall from Windows Installed Apps / Add or remove programs.
- You will be prompted whether to remove user data (config and layouts).

### Manual: Script workflow (advanced)
Use this only if you want to run/edit the source script directly.

Requirements:
- Windows 10/11
- [AutoHotkey v2](https://autohotkey.com)

Steps:
1. Download or clone this repository.
2. Run `FWDE.ahk` with AutoHotkey v2.
3. Edit `FWDE_Config.json` for your settings.

## Usage

The system starts automatically when launched. Windows matching detection patterns are managed automatically. Use hotkeys for manual control.

- **Automatic**: Eligible windows are detected and managed
- **Lock window**: `Ctrl+Alt+L` locks active window in place (33 second duration, auto-extends during drag)
- **Force add**: `Ctrl+Alt+A` manually adds active window to physics
- **Optimize**: `Ctrl+Alt+O` instantly rearranges all windows

## Hotkeys

| Shortcut | Action | 
|----------|--------|
| `Ctrl+Alt+Space` | Toggle Arrangement (master switch) |
| `Ctrl+Alt+P` | Toggle Physics |
| `Ctrl+Alt+M` | Toggle Multimonitor Expanse |
| `Ctrl+Alt+O` | Optimize Window Positions |
| `Ctrl+Alt+L` | Lock/Unlock Active Window |
| `Ctrl+Alt+T` | Show Taskbar Menu |
| `Ctrl+Alt+D` | Debug Window Info |
| `Ctrl+Alt+I` | Toggle Icon Repulsion |
| `Ctrl+Alt+C` | Copy Debug Log to Clipboard |
| `Ctrl+Alt+S` | Status Dashboard |
| `Ctrl+Alt+F` | Toggle Performance Profiling |
| `Ctrl+Alt+A` | Force Add Active Window |

## Configuration

Defaults live in the `Config` map at the top of `FWDE.ahk`. At runtime, tune them from
**⚙️ Parameter Settings** (taskbar/tray menu, or `Ctrl+Alt+T` → Parameter Settings):

- Changes apply instantly while dragging sliders.
- Hover any row for a description, current value, default, and allowed range.
- **Default** resets one parameter; **Restore All Defaults** resets everything.
- **Save Settings** / **Load Settings** persist to `FWDE_Config.json` next to the script.
- Saved values are clamped to their slider range on load.

### Physics core
| Parameter | Default | Meaning |
|---|---|---|
| `MinMargin` | 0 | Minimum distance from monitor edges (px) |
| `MinGap` | 0 | Preferred spacing between windows (px) |
| `AttractionForce` | 0.00045 | Center-seeking pull |
| `RepulsionForce` | 13.31 | Base push strength when windows get close |
| `RepulsionRangeMultiplier` | 3.069 | How far out repulsion starts acting |
| `RepulsionImpulseScale` | 6.92 | Per-step push intensity in close interactions |
| `CollisionOverlapThreshold` | 100 | Minimum overlap before separation engages (px²) |
| `Damping` | 0.1429 | Velocity retained per tick (1.0 = no damping, 0.0 = full stop) |
| `MaxSpeed` | 240.0 | Velocity cap for floating windows |
| `ManualRepulsionMultiplier` | 15.0 | Extra push while a manual window is involved |

### Collision separation
| Parameter | Default | Meaning |
|---|---|---|
| `PairSeparationBase` | 0.08 | Base overlap separation strength |
| `PairSeparationOverlapScale` | 5.933 | Extra separation scaling for deeper overlaps |
| `PairSmallWindowBoost` | 0.5 | Extra separation boost for small windows |

### Small-window classification
| Parameter | Default | Meaning |
|---|---|---|
| `SmallWindowReferenceDim` | 507 | Reference dimension for small-window classification (px) |
| `MaxSmallWindowRepulsionBoost` | 3.5 | Cap on the small-window repulsion boost |
| `SmallWindowThresholdW` | 507 | Width threshold (px) |
| `SmallWindowThresholdH` | 504 | Height threshold (px) |

### Seeding / placement
| Parameter | Default | Meaning |
|---|---|---|
| `SeedDiagonalStep` | 200 | Base diagonal offset used to de-stack similar windows (px) |
| `SeedDiagonalMaxSteps` | 50 | Maximum diagonal seed offsets tried per window |
| `SeedJitterRange` | 100 | Random per-window offset range (px) |

### Timing and locking
| Parameter | Default | Meaning |
|---|---|---|
| `PhysicsTimeStep` | 16 | Physics tick interval (ms) |
| `VisualTimeStep` | 16 | Movement apply interval (ms) |
| `UserMoveTimeout` | 50 | Cooldown before a focused window rejoins physics (ms) |
| `MoveLockTimeout` | 100 | Physics lock after a drag/resize (ms) |
| `ManualLockDuration` | 22156 | Manual lock duration for `Ctrl+Alt+L` (ms) |
| `ResizeDelay` | 1 | Delay before resize/move events refresh state (ms) |
| `TooltipDuration` | 6767 | Standard status tooltip duration (ms) |
| `ParameterHelpTooltipDuration` | 2200 | Parameter hover-help duration (ms) |

### Popups, companions, and elevation
| Parameter | Default | Meaning |
|---|---|---|
| `MultimonitorExpanse` | false | Let windows float across all monitors (`Ctrl+Alt+M`) |
| `PopupFollowEnabled` | true | Owned popups follow their host window 1:1 |
| `PopupFreezeHost` | true | Freeze the host while an interactive popup is open |
| `PopupScanIntervalMs` | 250 | Popup re-scan cadence (ms) |
| `CompanionFollowEnabled` | true | Same-app overlay/companion layers follow their main window 1:1 |
| `CompanionScanIntervalMs` | 500 | Companion re-scan cadence (ms) |
| `CompanionMinOverlap` | 0.15 | Minimum overlap fraction to pair an anchor + companion |
| `CompanionMaxSizeRatio` | 3.0 | Maximum anchor/companion area ratio |
| `RunAsAdmin` | true | Relaunch elevated at startup so Administrator windows can be managed (UAC prompt) |

### Desktop icons
| Parameter | Default | Meaning |
|---|---|---|
| `DesktopIconRepulsion` | false | Push windows away from desktop icons (opt-in, `Ctrl+Alt+I`) |
| `DesktopIconPhysics` | true | Simulate icons as physics bodies (spring + inter-icon repulsion) |
| `DesktopIconMargin` | 0 | Padding around each icon's repulsion rect (px) |
| `DesktopIconRepulsionForce` | 0.112358 | Icon → window repulsion strength |
| `MaxIconSpeed` | 93.7 | Per-frame displacement cap for icons (px/frame) |
| `DesktopIconSpring` | 0.008 | Spring constant pulling icons back to grid (0 = static) |
| `DesktopIconDamping` | 0.65 | Icon velocity retained per frame (0 = instant stop) |
| `DesktopIconInterRepel` | 0.4 | Icon → icon repulsion strength |
| `DesktopIconInterRepelRange` | 0.7 | Icon → icon repulsion reach, as a multiple of icon spacing |

### Stabilization
| Parameter | Default | Meaning |
|---|---|---|
| `Stabilization.MinSpeedThreshold` | 0.369 | Speed below which stronger settling starts |
| `Stabilization.EnergyThreshold` | 0.06 | Energy threshold separating calm from chaotic state |
| `Stabilization.DampingBoost` | 0.12 | Extra damping applied while settling |
| `Stabilization.OverlapTolerance` | 120 | Overlap allowed before stabilization treats windows as colliding |

### Window detection
```ahk
"FloatClassPatterns", [            ; Window classes treated as floating/popup
    "Vst.*", "JS.*", ".*Plugin.*", ".*Float.*", ".*Dock.*",
    "ConsoleWindowClass", "TextToSpeechWndClass", "SunAwtFrame",
    "XamlExplorerHost", "TApplication", "wxWindowClassNR"
],
"FloatTitlePatterns", [            ; Window titles treated as floating/popup
    "VST.*", "JS:.*", "Plugin", ".*FX.*",
    "Command Prompt", "cmd.exe", "Windows Terminal"
],
"ForceFloatProcesses", [           ; Never managed by physics (DAWs, consoles, TTS)
    "reaper.exe", "ableton.exe", "flstudio.exe", "cubase.exe",
    "studioone.exe", "bitwig.exe", "protools.exe",
    "cmd.exe", "conhost.exe", "WindowsTerminal.exe",
    "DTDEMO.exe", "speak.exe", "speak", "speak.EXE"
],
"ForceTrackProcesses", [           ; Always managed, overriding float checks
    "WinXShell_x64.exe", "steam.exe", "steamwebhelper.exe", "Everything.exe"
]
```

## Debugging

### Tools
- `Ctrl+Alt+D` - Show all tracked/untracked windows with details
- `Ctrl+Alt+S` - Real-time status dashboard (energy, drag state, timer health)
- `Ctrl+Alt+C` - Copy full debug log to clipboard
- `Ctrl+Alt+F` - Toggle performance profiling overlay
- `Ctrl+Alt+A` - Manually add window to physics

### Troubleshooting

**Windows not moving**
1. Check arrangement: `Ctrl+Alt+Space` (must be ON)
2. Check physics: `Ctrl+Alt+P` (must be ON)
3. Debug window: `Ctrl+Alt+I` on the window
4. Force add: `Ctrl+Alt+A` if detection failed

**Too much movement**
- Lower `"Damping"` toward 0.01 (below the 0.1429 default) to brake harder
- Lower `"RepulsionForce"` (13.31 default) or raise `"CollisionOverlapThreshold"`
- Lock windows: `Ctrl+Alt+L` to fix position

**Performance issues**
- Raise intervals: `"PhysicsTimeStep"` and `"VisualTimeStep"` to 33 (from 16)
- Lock unnecessary windows: `Ctrl+Alt+L`

**Multi-monitor issues**
- Toggle mode: `Ctrl+Alt+M` for multimonitor expanse
- Check detection: `Ctrl+Alt+D` shows monitor assignments

**Window not detected**
- Check patterns: `Ctrl+Alt+D` shows which patterns match
- Add to `ForceFloatProcesses`: Add process name to config
- Force add: `Ctrl+Alt+A` for immediate inclusion

## Use Cases

**Music Production**
- DAW plugin management (VST windows)
- Multi-monitor plugin layouts
- Lock main DAW interface, float plugins

**Software Development**
- IDE + browser + terminal arrangements
- Documentation windows without overlap
- Reference materials accessible

**Design & Creative Work**
- Tool palettes from Photoshop, Illustrator, etc.
- Reference images and color pickers
- Multi-application workflows

**Data Analysis**
- Spreadsheet + browser coordination
- Multiple data visualization windows
- PDF + browser + analysis tool layouts

## Technical Details

**Physics Engine**
- Custom attraction/repulsion force model
- Velocity integration with damping
- Per-frame collision detection
- Boundary enforcement

**Window Detection**
- Multi-pattern matching (process, class, title, style)
- Fullscreen exclusion via Windows API
- Min/max state checking
- Manual override support

**Multi-Monitor**
- Per-monitor physics calculations
- Optional cross-monitor mode
- Virtual desktop bounds
- Monitor-aware positioning

**Performance**
- Adaptive update rates
- High-resolution timer for drag operations
- Resource management (timer acquisition/release)
- Lock state tracking with expiration

## Recent Changes

- Crash-safe debug logging with automatic clipboard copy and periodic disk persistence
- HealthMonitor watchdog with autonomous stall detection and recovery
- Multi-pass chain-effect collision resolution for realistic window cascading
- Overlap-based repulsion physics (redesigned from center-attraction model)
- Status Dashboard (`Ctrl+Alt+S`) with real-time timer health and energy metrics
- Performance profiling overlay (`Ctrl+Alt+F`)
- Desktop icon repulsion toggle (`Ctrl+Alt+I`)
- Lock auto-extends during active drag to prevent timeout mid-interaction
- Multimonitor expanse mode for cross-monitor window floating
- Enhanced window detection for browsers, editors, DAW plugins, and Office apps

## License

See `LICENSE` file.

## Credits

Created by Flalaski with AI assistance (Copilot, DeepSeek, Gemini).

AutoHotkey v2 community for the platform.
