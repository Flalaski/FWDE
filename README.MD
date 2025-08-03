# FWDE - Floating Windows Dynamic Equilibrium

*Advanced Physics-Based Window Management for Windows (AutoHotkey v2)*

---

## Overview

FWDE is a physics-driven window manager for Windows, designed for DAW plugins, terminals, dialogs, and floating windows.  
It uses real-time simulation for natural, intelligent arrangements, with multi-monitor support, manual controls, visual effects, and adaptive performance scaling.

---

## File Structure

- `FWDE.ahk` — Main script (all logic, config, hotkeys, functions)
- `FWDEdesktop.png` — Window arrangement visualization
- Other files/modules are optional and not required for core operation.

---

## Script Structure

### Global Variables

- `Config` — Main configuration map (physics, detection, visuals, timing, etc.)
- `g` — Runtime state map (window list, monitor info, arrangement state, etc.)
- `TaskbarMenu` — Context menu for quick actions
- `CloudNoiseOverlay` — GUI overlay for visual noise effects

### Classes

- `NoiseAnimator` — Generates procedural noise for visual effects
- `TimePhasing` — Manages echo effects and noise clouds for plugin windows

### Main Functions

- **Window Detection & Management**
  - `GetVisibleWindows(monitor)`
  - `CleanupStaleWindows()`
  - `IsWindowValid(hwnd)`
  - `IsPluginWindow(hwnd)`
  - `IsWindowFloating(hwnd)`

- **Physics & Layout**
  - `CalculateWindowForces(win, allWindows)`
  - `ApplyWindowMovements()`
  - `CalculateDynamicLayout()`
  - `ResolveFloatingCollisions(windows)`
  - `OptimizeWindowPositions()`
  - `PackWindowsOptimally(windows, monitor)`
  - `FindBestPosition(window, placedWindows, monitor, ...)`
  - `CalculateSpaceSeekingForce(win, allWindows)`

- **Manual Controls & Visuals**
  - `AddManualWindowBorder(hwnd)`
  - `RemoveManualWindowBorder(hwnd)`
  - `UpdateManualBorders()`
  - `DragWindow()`
  - `ToggleArrangement()`
  - `TogglePhysics()`
  - `ToggleTimePhasing()`
  - `ToggleSeamlessMonitorFloat()`
  - `ToggleWindowLock()`
  - `ShowTooltip(text)`
  - `OrderWindowsBySize()`
  - `RenderCloudsNoise()`
  - `InitCloudNoiseOverlay()`

- **Utility**
  - `Clamp(val, min, max)`
  - `MoveWindowAPI(hwnd, x, y, w, h)`
  - Partitioning and collision helpers

---

## Configuration

All settings are in the `Config` map at the top of the script.  
Edit values for real-time changes:

```ahk2
global Config := Map(
    "MinMargin", 42,
    "MinGap", 21,
    "ManualGapBonus", 369,
    "AttractionForce", 0.0001,
    "RepulsionForce", 0.369,
    "EdgeRepulsionForce", 0.80,
    "UserMoveTimeout", 11111,
    "ManualLockDuration", 33333,
    "ResizeDelay", 22,
    "TooltipDuration", 15000,
    "SeamlessMonitorFloat", false,
    "FloatStyles", 0x00C00000 | 0x00040000 | 0x00080000 | 0x00020000 | 0x00010000,
    "FloatClassPatterns", [...],
    "FloatTitlePatterns", [...],
    "ForceFloatProcesses", [...],
    "Damping", 0.001,
    "MaxSpeed", 12.0,
    "PhysicsTimeStep", 1,
    "VisualTimeStep", 2,
    "Smoothing", 0.5,
    "Stabilization", Map(
        "MinSpeedThreshold", 0.369,
        "EnergyThreshold", 0.06,
        "DampingBoost", 0.12,
        "OverlapTolerance", 0
    ),
    "ManualWindowColor", "FF5555",
    "ManualWindowAlpha", 222,
    "NoiseScale", 888,
    "NoiseInfluence", 100,
    "AnimationDuration", 32,
    "PhysicsUpdateInterval", 1000,
    "ManualRepulsionMultiplier", 1.0
)
```

---

## Hotkeys

| Shortcut              | Action                                         |
|-----------------------|------------------------------------------------|
| `Ctrl + Alt + Space`  | Toggle window arrangement ON/OFF               |
| `Ctrl + Alt + P`      | Toggle physics engine ON/OFF                   |
| `Ctrl + Alt + F`      | Toggle time-phasing visual effects             |
| `Ctrl + Alt + M`      | Toggle seamless multi-monitor floating         |
| `Ctrl + Alt + O`      | Optimize window positions for best fit         |
| `Ctrl + Alt + L`      | Lock/unlock active window                      |
| `Ctrl + Alt + T`      | Show taskbar menu                              |

---

## Features

- **Physics-Based Window Arrangement:** Windows move and settle using simulated forces, attraction, repulsion, and damping.
- **Manual Window Locking:** Lock/unlock windows to fix their position.
- **Space Optimization:** Instantly optimize window positions for best fit.
- **Multi-Monitor Support:** Seamless floating across all monitors.
- **Visual Feedback:** Manual window borders for locked windows.
- **Performance Scaling:** Adaptive update rates and resource management.
- **Screenshot Detection:** Pauses physics during active screenshot operations.
- **Visual Effects:** Time-phasing echoes and procedural noise clouds for plugin windows.

---

## Window Detection Patterns

- **Process Whitelist:** DAW apps (Reaper, FL Studio, Ableton, etc.), terminals, development tools
- **Window Class Patterns:** VST plugins, dialogs, console windows, floating tool windows
- **Title Patterns:** Plugin names, command prompts, development tools, audio effects
- **Window Style Analysis:** Popup/tool/always-on-top windows

---

## Installation & Usage

1. **Install AutoHotkey v2.0+** from [autohotkey.com](https://autohotkey.com)
2. **Download FWDE.ahk** and run it (or compile to .exe)
3. **Automatic Detection:** Script manages eligible floating windows automatically
4. **Configuration:** Use hotkeys or edit `Config` map for customization
5. **Multi-Monitor:** Enable seamless floating with `Ctrl + Alt + M`

---

## Troubleshooting

- **Windows not moving:** Check physics (`Ctrl + Alt + P`) and arrangement (`Ctrl + Alt + Space`)
- **Aggressive movement:** Increase `Damping` or decrease `RepulsionForce` in Config
- **Performance issues:** Increase `PhysicsTimeStep` and `VisualTimeStep` for slower updates
- **Multi-monitor problems:** Toggle seamless floating (`Ctrl + Alt + M`)
- **Manual window lock not working:** Ensure window is managed and not excluded by detection patterns

---

## Credits

Created by Flalaski with AI assistance (DeepSeek, Gemini, Copilot).  
Streamlined for stability and essential functionality. Hope it's helpful! ♥
