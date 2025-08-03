# FWDE - Floating Windows Dynamic Equilibrium
*Advanced Physics-Based Window Management for Windows (AutoHotkey v2)*

![Window Arrangement Visualization](FWDEdesktop.png)

---

## Overview

FWDE is a physics-driven window manager for Windows, designed for DAW plugins, terminals, dialogs, and floating windows. It uses real-time simulation for natural, intelligent arrangements, with multi-monitor support, manual controls, visual effects, and adaptive performance scaling.

---

## Main Features

- **Physics-Based Window Arrangement:** Windows move and settle using simulated forces, attraction, repulsion, and damping.
- **Manual Window Locking:** Lock/unlock windows to fix their position (`Ctrl + Alt + L`).
- **Space Optimization:** Instantly optimize window positions for best fit (`Ctrl + Alt + O`).
- **Multi-Monitor Support:** Seamless floating across all monitors (`Ctrl + Alt + M`).
- **Visual Feedback:** Manual window borders for locked windows.
- **Performance Scaling:** Adaptive update rates and resource management.
- **Screenshot Detection:** Pauses physics during active screenshot operations.

---

## Controls & Hotkeys

| Shortcut              | Action                                         |
|-----------------------|------------------------------------------------|
| `Ctrl + Alt + Space`  | Toggle window arrangement ON/OFF               |
| `Ctrl + Alt + P`      | Toggle physics engine ON/OFF                   |
| `Ctrl + Alt + M`      | Toggle seamless multi-monitor floating         |
| `Ctrl + Alt + O`      | Optimize window positions for best fit         |
| `Ctrl + Alt + L`      | Lock/unlock active window                      |
| `Ctrl + Alt + T`      | Show taskbar menu                              |

---

## Script Structure & Key Functions

### Core Functions

- `GetVisibleWindows(monitor)` - Detects and lists eligible windows for management.
- `CleanupStaleWindows()` - Removes windows no longer present.
- `CalculateWindowForces(win, allWindows)` - Computes physics forces for each window.
- `ApplyWindowMovements()` - Smoothly moves windows toward their target positions.
- `OptimizeWindowPositions()` - Runs space-efficient packing and applies optimal positions.
- `PackWindowsOptimally(windows, monitor)` - Advanced packing algorithm for best fit.
- `FindBestPosition(window, placedWindows, monitor, ...)` - Finds best position for a window.
- `CalculateSpaceSeekingForce(win, allWindows)` - Moves windows toward less crowded areas.
- `ResolveFloatingCollisions(windows)` - Gently separates overlapping windows.

### Manual Controls

- `AddManualWindowBorder(hwnd)` / `RemoveManualWindowBorder(hwnd)` - Visual feedback for locked windows.
- `DragWindow()` - Allows manual dragging and locks window position.
- `ToggleArrangement()` - Enables/disables automatic arrangement.
- `TogglePhysics()` - Enables/disables physics engine.
- `ToggleTimePhasing()` - Enables/disables visual echo effects.
- `ToggleSeamlessMonitorFloat()` - Enables/disables cross-monitor floating.
- `ToggleWindowLock()` - Locks/unlocks the active window.

### Utility & Visuals

- `ShowTooltip(msg)` - Displays status tooltips.
- `OrderWindowsBySize()` - Z-ordering for plugin windows.
- `RenderCloudsNoise()` - Renders visual noise overlay.

---

## Configuration

All settings are in the `Config` map at the top of the script. Edit values for real-time changes:

```ahk2
global Config := Map(
    "AttractionForce", 0.0001,           ; Center attraction force
    "RepulsionForce", 0.369,             ; Window repulsion force
    "Damping", 0.001,                    ; Physics damping
    "MaxSpeed", 12.0,                    ; Maximum window speed
    "MinMargin", 42,                     ; Minimum margin from screen edges
    "MinGap", 21,                        ; Minimum gap between windows
    "EdgeRepulsionForce", 0.80,          ; Edge repulsion strength
    "PhysicsTimeStep", 1,                ; Physics update frequency (ms)
    "VisualTimeStep", 2,                 ; Visual update frequency (ms)
    "UserMoveTimeout", 11111,            ; User interaction timeout (ms)
    "ManualLockDuration", 33333,         ; Manual lock duration (ms)
    "SeamlessMonitorFloat", false,       ; Multi-monitor floating toggle
    "Smoothing", 0.5,                    ; Motion smoothing factor
    "MinSpeedThreshold", 0.369           ; Minimum movement threshold
)
```

---

## Window Detection Patterns

- **Process Whitelist:** DAW apps (Reaper, FL Studio, Ableton, etc.), terminals, development tools
- **Window Class Patterns:** VST plugins, dialogs, console windows, floating tool windows
- **Title Patterns:** Plugin names, command prompts, development tools, audio effects
- **Window Style Analysis:** Popup/tool/always-on-top windows

---

## Advanced Packing & Physics

- **Space Optimization:** Uses grid and gap-filling strategies for best fit
- **Physics Simulation:** Attraction, repulsion, damping, and edge forces
- **Collision Resolution:** Gentle separation of overlapping windows
- **Manual Locking:** Locked windows are excluded from optimization and physics
- **Multi-Monitor:** Enable seamless floating for cross-monitor movement

---

## Troubleshooting

- **Windows not moving:** Check physics (`Ctrl + Alt + P`) and arrangement (`Ctrl + Alt + Space`)
- **Aggressive movement:** Increase `Damping` or decrease `RepulsionForce` in Config
- **Performance issues:** Increase `PhysicsTimeStep` and `VisualTimeStep` for slower updates
- **Multi-monitor problems:** Toggle seamless floating (`Ctrl + Alt + M`)

---

## Installation & Usage

1. **Install AutoHotkey v2.0+** from [autohotkey.com](https://autohotkey.com)
2. **Download FWDE.ahk** and run it (or compile to .exe)
3. **Automatic Detection:** Script manages eligible floating windows automatically
4. **Configuration:** Use hotkeys or edit `Config` map for customization
5. **Multi-Monitor:** Enable seamless floating with `Ctrl + Alt + M`

---

## File Structure

- `FWDE.ahk` - Main script (all logic, config, hotkeys, functions)
- `FWDE.exe` - Compiled executable (optional)
- `FWDE_Config.json` - Optional config file
- `FWDE_MIDI_OSC.ahk` / `FWDE_PerformanceScaling.ahk` - Optional modules
- `FWDE_PluginDependencies.ahk` - Plugin detection helpers
- `FWDE_Debug.log` - Debug log
- `Layouts/` - Layout files
- `memory-bank/` - Project memory and documentation

---

## Credits

Created by Flalaski with AI assistance (DeepSeek, Gemini, Copilot)
Streamlined for stability and essential functionality. Hope it's helpful! ♥
    "PhysicsTimeStep", 1,           ; Physics update frequency (ms)
    "VisualTimeStep", 2,            ; Visual update frequency (ms)
    "UserMoveTimeout", 11111,       ; User interaction timeout (ms)
    "ManualLockDuration", 33333,    ; Manual lock duration (ms)
    
    ; Screenshot Detection
    "ScreenshotPauseDuration", 5000,    ; How long to pause physics after detection (ms)
    "ScreenshotCheckInterval", 500,     ; How often to check for screenshot activity (ms)
    
    ; Features
    "SeamlessMonitorFloat", false,  ; Multi-monitor floating toggle
    "Smoothing", 0.5,               ; Motion smoothing factor [0.1-0.99]
    "MinSpeedThreshold", 0.369      ; Minimum movement threshold
)
```

**Screenshot Detection Configuration:**
The system monitors these applications and window classes for active screenshot operations:
- **Processes**: ShareX.exe, ScreenToGif.exe, Greenshot.exe, Snagit32.exe, SnippingTool.exe, PowerToys.ScreenRuler.exe, obs64.exe, and more
- **Window Classes**: GDI+ Hook Window Class, CrosshairOverlay, ScreenshotOverlay, CaptureOverlay, SelectionOverlay
- **Activity Detection**: Only pauses when screenshot tools show active capture UI, not when running idle in background

**Float Detection Patterns:**
The system automatically detects floating windows using:
- **Process Whitelist**: DAW applications (Reaper, FL Studio, Ableton, etc.), terminals, development tools
- **Window Class Patterns**: VST plugins, dialogs, console windows, floating tool windows
- **Title Patterns**: Plugin names, command prompts, development tools, audio effects
- **Window Style Analysis**: Popup windows, tool windows, always-on-top windows
## 🛠️ Customization

Edit the Config map in the script for:

- **Physics:** Force strengths, speed limits, damping, update rates
- **Window Management:** Timeout durations, margins, detection patterns
- **Screenshot Detection:** Pause duration, check intervals, process lists
- **Performance:** Update frequencies, monitoring thresholds, resource limits

**Easy Configuration Access:**
- All settings are clearly documented in the script's Config map
- Real-time changes take effect immediately without restart
- Use `Ctrl + Alt + I` to monitor current system status and configuration effectiveness
- Safe defaults ensure system stability even with experimental settings

**Screenshot Detection Customization:**
- Add new screenshot applications to the process list
- Configure pause duration after screenshot detection
- Adjust detection sensitivity and check intervals
- Enable/disable detection entirely for specific workflows

---

## 🔍 Advanced Configuration

- **High-DPI:** Lower MinSpeedThreshold (0.05-0.15) for precise movement
- **Low-Performance:** Higher MinSpeedThreshold (0.2-0.5), increase TimeStep values
- **Strict Spacing:** Increase RepulsionForce for more window separation
- **Loose Grouping:** Decrease RepulsionForce for closer window clustering  
- **Multi-Monitor:** Enable SeamlessMonitorFloat for cross-monitor window movement
- **Screenshot Workflows:** Adjust ScreenshotPauseDuration based on your capture workflow timing
- **Performance Tuning:** Adjust TimeStep values based on window count and system capabilities

---

## 🐛 Troubleshooting

**Common Issues:**
- **Windows not moving**: Check physics engine status (`Ctrl + Alt + P`) and arrangement system (`Ctrl + Alt + A`)
- **Physics not visible**: Use the physics test hotkey (`Ctrl + Alt + T`) to move a window and verify attraction forces
- **Too aggressive movement**: Increase Damping value or decrease RepulsionForce in Config
- **Performance issues**: Increase PhysicsTimeStep and VisualTimeStep values for slower updates
- **Multi-monitor problems**: Toggle seamless floating (`Ctrl + Alt + M`) and check monitor detection
- **Screenshot interference**: Toggle screenshot detection (`Ctrl + Alt + S`) or adjust pause duration

**System Status Checking:**
- Use `Ctrl + Alt + I` to get comprehensive system status information
- Check window count, physics status, and error information
- Monitor screenshot detection status and physics pause state
- Use `Ctrl + Alt + R` to manually refresh the window list if windows aren't being detected

**Screenshot Detection Issues:**
- **False positives from idle processes**: The new system should eliminate this, but you can disable detection with `Ctrl + Alt + S`
- **Physics not resuming after screenshot**: Check if screenshot process is still running active capture windows
- **Screenshot tools not detected**: Add the process name to Config["ScreenshotProcesses"] array
- **Detection too sensitive**: Increase ScreenshotCheckInterval or adjust detection thresholds

**Emergency Controls:**
- `Ctrl + Alt + Pause`: Complete emergency stop of all systems
- `Ctrl + Alt + P`: Quick physics engine toggle for immediate control
- `Ctrl + Alt + R`: Manual window list refresh to reset window tracking
- System automatically recovers from most error conditions with safe fallbacks

---

## 📋 Installation & Usage

1. **Install AutoHotkey v2.0+** from [autohotkey.com](https://autohotkey.com)
2. **Download FWDE.ahk** and run it (or compile to .exe for easier distribution)
3. **Automatic Detection**: Script starts managing eligible floating windows automatically
4. **Configuration**: Use hotkeys to control behavior or edit Config map in script for customization
5. **Multi-Monitor**: Enable seamless multi-monitor floating with `Ctrl + Alt + M`

**First Run:**
- FWDE will show a tooltip confirming successful startup
- Check system status anytime with `Ctrl + Alt + I`
- Physics engine and arrangement system start enabled by default
- Screenshot detection is enabled and will intelligently pause physics during capture operations
- **Optimize window positions anytime with `Ctrl + Alt + O`**

**Supported Window Types:**
- DAW plugins (VST, AU, etc.) from Reaper, FL Studio, Ableton, Cubase, and more
- Development tools: Command Prompt, PowerShell, Windows Terminal, IDE floating windows
- System dialogs and utility windows
- Any window matching the configurable detection patterns

---

*Created by Flalaski with AI assistance (DeepSeek, Gemini, CoPilot)*  
*Streamlined for stability and essential functionality. Hope it's helpful! ♥*
