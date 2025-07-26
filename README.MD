# Floating Windows - Dynamic Equilibrium  
*Advanced Physics-Based Window Management*  

![Window Arrangement Visualization](https://github.com/Flalaski/FWDE/blob/ca69310d8c5f28540ddc644dd05b87b3b2d8b8d6/FWDEdesktop.png)

---

## 🚀 Overview

FWDE is a physics-driven window manager for Windows, designed for DAW plugins, terminals, dialogs, and floating windows. It uses real-time simulation for natural, intelligent arrangements, with multi-monitor support, manual controls, and visual effects.

---

## 🎮 Controls & Hotkeys

| Shortcut              | Action                                         |
|-----------------------|------------------------------------------------|
| `Ctrl + Alt + Space`  | Toggle automatic window arrangement ON/OFF     |
| `Ctrl + Alt + P`      | Toggle physics engine ON/OFF                   |
| `Ctrl + Alt + F`      | Toggle time-phasing visual effects             |
| `Ctrl + Alt + M`      | Toggle seamless multi-monitor floating         |
| `Ctrl + Alt + O`      | Optimize all window positions                  |
| `Ctrl + Alt + L`      | Lock/unlock the currently active window        |

---

## 🖥️ Window Management Features

- **Multi-Monitor Floating:**  
  Seamless workspace across all monitors (toggleable).  
  Windows can float freely or be confined per monitor.

- **Intelligent Detection:**  
  - DAW plugins (VST, JS, etc.) from Reaper, Ableton, FL Studio, Cubase, Studio One, Bitwig, Pro Tools  
  - Development tools (Command Prompt, Windows Terminal, console apps)  
  - Dialog boxes, floating tool windows  
  - Custom class/title pattern matching

- **Manual Control:**  
  - Lock windows in place (red border, timeout, hotkey)  
  - Optimize layouts for space usage  
  - Fine-tune behavior via config

---

## ⚡ Physics & Visual Effects

- **Physics Engine:**  
  - Center attraction, inter-window repulsion, edge barriers  
  - Space-seeking: windows move toward less crowded areas  
  - Energy state management: adapts between "normal" and "chaos"  
  - Collision resolution, velocity limiting, friction/damping

- **Visual Effects:**  
  - Time-phasing echoes (particle trails)  
  - Manual window borders (red highlight for locked)  
  - Blur effects (desktop composition integration)

---

## ⚙️ Technical Specs & Configuration

**Requirements:**  
- AutoHotkey v2.0+  
- Windows 10/11  
- Multi-monitor setups  
- High-DPI compatible

**Config Map (editable in script):**
```ahk
global Config := Map(
    "MinMargin", 42,                ; Distance from screen edges (pixels)
    "AttractionForce", 0.01,        ; Center gravitational pull strength
    "RepulsionForce", 0.369,        ; Window separation force
    "EdgeRepulsionForce", 0.80,     ; Screen edge push strength
    "SeamlessMonitorFloat", false,  ; Multi-monitor floating toggle
    "UserMoveTimeout", 11111,       ; User interaction timeout (ms)
    "ManualLockDuration", 33333,    ; Manual lock duration (ms)
    "PhysicsTimeStep", 1,           ; Physics update frequency (1ms)
    "VisualTimeStep", 2,            ; Visual update frequency (2ms)
    "MaxSpeed", 12.0,               ; Maximum window velocity
    "Damping", 0.001,               ; Friction coefficient
    "Smoothing", 0.5                ; Motion smoothing factor
)
```

---

## 🛠️ Supported Applications

- **DAW/Audio:** Reaper, Ableton Live, FL Studio, Cubase, Studio One, Bitwig, Pro Tools, VST/JS plugin windows
- **Development/System:** Command Prompt, Windows Terminal, console apps, dialogs
- **General:** Any window matching patterns, tool windows, floating panels

---

## 🧠 How the Physics Works

1. **Forces:**  
   - Center attraction  
   - Inter-window repulsion  
   - Edge barriers  
   - Space-seeking

2. **Energy Management:**  
   - Normal/chaos states  
   - Stabilization/damping

3. **Smart Behaviors:**  
   - Active windows freeze  
   - User interaction timeouts  
   - Small/plugin windows prioritized

---

## 📋 Installation & Usage

1. Install AutoHotkey v2.0+ from [autohotkey.com](https://autohotkey.com)
2. Download FWDE.ahk and run it
3. Script starts managing eligible windows automatically
4. Use hotkeys or edit config for customization
5. Enable multi-monitor floating with `Ctrl + Alt + M`

---

## 🛠️ Customization

Edit the Config map for:

- **Physics:** Force strengths, speed limits, damping, update rates
- **Window Management:** Timeout durations, margins, pattern rules
- **Visuals:** Animation/smoothing, border colors, echo parameters

---

## 🔍 Advanced Configuration

- **High-DPI:** Lower MinSpeedThreshold (0.05-0.15)
- **Low-Performance:** Higher MinSpeedThreshold (0.2-0.5), increase TimeStep
- **Strict Spacing:** Lower OverlapTolerance (0-5)
- **Loose Grouping:** Higher OverlapTolerance (20+)

---

## 🐛 Troubleshooting

- Windows not moving: Check physics engine (`Ctrl + Alt + P`)
- Too aggressive: Increase damping, reduce forces
- Performance: Increase PhysicsTimeStep/VisualTimeStep
- Multi-monitor: Toggle seamless floating (`Ctrl + Alt + M`)

---

*Created by Flalaski with AI assistance (DeepSeek, Gemini, CoPilot)*  
*Countless iterations for the perfect balance of automatic organization and user control. Hope it's helpful! ♥*
*This tool represents countless iterations and refinements to achieve the perfect balance of automatic organization and user control. Hope it's helpful! ♥*
