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
- Attraction, repulsion, and damping forces
- Collision avoidance between windows
- Edge repulsion to fill screen space
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
| `Ctrl+Alt+I` | Debug Active Window |
| `Ctrl+Alt+A` | Force Add Active Window |

## Configuration

Settings are in the `Config` map at the top of `FWDE.ahk`.

### Core Physics
```ahk
"MinMargin", 2,                    ; Distance from screen edges (px)
"MinGap", 21,                      ; Gap between windows
"AttractionForce", 0.00005,        ; Pull toward center
"RepulsionForce", 0.8,             ; Push apart from other windows
"EdgeRepulsionForce", 0.80,        ; Push from screen edges
"Damping", 0.001,                  ; Friction coefficient
"MaxSpeed", 12.0,                  ; Max velocity
```

### Performance
```ahk
"PhysicsTimeStep", 1,              ; Physics update frequency (ms)
"VisualTimeStep", 16,              ; Visual update frequency (ms) - ~60fps
"UserMoveTimeout", 11111,          ; Pause after user interaction (ms)
"ManualLockDuration", 33333,       ; Lock duration (ms, ~33 seconds)
```

### Window Detection
```ahk
"ForceFloatProcesses", [           ; Always manage these processes
    "firefox.exe", "chrome.exe", "cursor.exe", "code.exe",
    "notepad++.exe", "devenv.exe", "explorer.exe",
    "winword.exe", "excel.exe", "powerpnt.exe", "outlook.exe"
],
"FloatClassPatterns", [            ; Window classes to include
    "MozillaWindowClass", "Chrome_WidgetWin_1", "ApplicationFrameWindow",
    "Code.exe", "Cursor.exe", "Notepad", "Notepad++"
],
"FloatTitlePatterns", [            ; Window titles to include
    "VST.*", "JS:.*", "Plugin", "Command Prompt", "Windows Terminal"
]
```

### Advanced Features
```ahk
"MultimonitorExpanse", false,         ; Allow windows to float across monitors
"TooltipDuration", 15000,              ; Debug tooltip duration (ms)
"ResizeDelay", 22,                     ; Delay before physics after resize (ms)
```

## Debugging

### Tools
- `Ctrl+Alt+D` - Show all tracked/untracked windows with details
- `Ctrl+Alt+I` - Analyze active window (why managed/not managed)
- `Ctrl+Alt+A` - Manually add window to physics

### Troubleshooting

**Windows not moving**
1. Check arrangement: `Ctrl+Alt+Space` (must be ON)
2. Check physics: `Ctrl+Alt+P` (must be ON)
3. Debug window: `Ctrl+Alt+I` on the window
4. Force add: `Ctrl+Alt+A` if detection failed

**Too much movement**
- Increase damping: `"Damping"` to 0.005+
- Reduce repulsion: `"RepulsionForce"` to 0.3 or less
- Lock windows: `Ctrl+Alt+L` to fix position

**Performance issues**
- Increase timesteps: `"PhysicsTimeStep"` to 5, `"VisualTimeStep"` to 33
- Lock unnecessary windows: `Ctrl+Alt+L`

**Multi-monitor issues**
- Toggle mode: `Ctrl+Alt+M` for multimonitor expanse
- Check detection: `Ctrl+Alt+D` shows monitor assignments

**Window not detected**
- Check patterns: `Ctrl+Alt+I` shows which patterns match
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

- Enhanced window detection (fixed fullscreen detection for browsers/editors)
- Added common applications to default patterns (Firefox, Chrome, Cursor, VS Code, Office)
- Lock auto-extends during active drag to prevent timeout mid-interaction
- Lock state awareness: physics knows when lock expires and transitions cleanly
- Multimonitor expanse mode (renamed from "seamless float")
- Visual border for locked windows (red, 5px offset)
- Debug tools for pattern matching and window analysis
- Performance tuning (increased repulsion, reduced attraction, better edge positioning)

## License

See `LICENSE` file.

## Credits

Created by Flalaski with AI assistance (Copilot, DeepSeek, Gemini).

AutoHotkey v2 community for the platform.
