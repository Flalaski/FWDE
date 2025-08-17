# FWDE - Floating Windows Dynamic Equilibrium

**Physics-Based Window Management for Windows (AutoHotkey v2)**

---

## What is FWDE?

FWDE is a physics-driven window manager for Windows, designed to intelligently arrange floating windows such as DAW plugins, terminals, dialogs, and tool windows. It uses real-time simulation for natural movement, multi-monitor support, manual controls, and visual effects.

---

## Features

- **Physics-Based Arrangement:** Windows move and settle using simulated forces (attraction, repulsion, damping).
- **Manual Locking:** Lock/unlock windows to fix their position.
- **Space Optimization:** Instantly optimize window positions for best fit.
- **Multi-Monitor Support:** Seamless floating across all monitors.
- **Visual Feedback:** Borders for locked windows, time-phasing effects, and procedural noise clouds.
- **Performance Scaling:** Adaptive update rates and resource management.
- **Screenshot Detection:** Pauses physics during screenshots.
- **Context Menu:** Quick actions from the taskbar.

---

## Installation

1. **Install [AutoHotkey v2](https://autohotkey.com)**
2. **Download `FWDE.ahk`** and run it (or compile to .exe)
3. **Use hotkeys or the taskbar menu** to control features

---

## Usage

- FWDE automatically detects and manages eligible floating windows.
- Use hotkeys or the taskbar menu for manual control.
- Configuration is at the top of `FWDE.ahk` in the `Config` map.

---

## Configuration

All settings are in the `Config` map at the top of `FWDE.ahk`.  
Edit values for real-time changes. Example:

```ahk2
global Config := Map(
    "MinMargin", 42,
    "MinGap", 21,
    "AttractionForce", 0.0001,
    "RepulsionForce", 0.369,
    "EdgeRepulsionForce", 0.80,
    "UserMoveTimeout", 11111,
    "ManualLockDuration", 33333,
    "ResizeDelay", 22,
    "TooltipDuration", 15000,
    "SeamlessMonitorFloat", false,
    ...other settings...
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

## How It Works

- **Detection:** Windows are included based on process, class, title, and style patterns (see `Config`).
- **Physics:** Each window is simulated with forces for natural movement and collision avoidance.
- **Manual Control:** Drag windows, lock/unlock, and optimize positions.
- **Visuals:** Borders for locked windows, time-phasing echoes, and noise clouds for plugins.

---

## Troubleshooting

- **Windows not moving:** Check arrangement (`Ctrl+Alt+Space`) and physics (`Ctrl+Alt+P`).
- **Aggressive movement:** Increase `Damping` or decrease `RepulsionForce` in `Config`.
- **Performance issues:** Increase `PhysicsTimeStep` and `VisualTimeStep`.
- **Multi-monitor problems:** Toggle seamless floating (`Ctrl+Alt+M`).
- **Manual lock not working:** Ensure the window is managed and not excluded by detection patterns.

---

## Credits

Created by Flalaski with AI assistance (Copilot, DeepSeek, Gemini).  
Streamlined for stability and essential functionality.
