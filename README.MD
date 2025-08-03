# Floating Windows - Dynamic Equilibrium  
*Advanced Physics-Based Window Management*  

![Window Arrangement Visualization](https://github.com/Flalaski/FWDE/blob/ca69310d8c5f28540ddc644dd05b87b3b2d8b8d6/FWDEdesktop.png)

---

## 🚀 Overview

FWDE is a physics-driven window manager for Windows, designed for DAW plugins, terminals, dialogs, and floating windows. It uses real-time simulation for natural, intelligent arrangements, with multi-monitor support, manual controls, visual effects, and **adaptive performance scaling** that automatically optimizes system resource usage.

**Features:**  
- **Seamless Multi-Monitor Floating:** Toggle with `Ctrl + Alt + M` to allow windows to float freely across all monitors.
- **Manual Window Locking:** Lock/unlock windows with `Ctrl + Alt + L` to fix their position.
- **Space Optimization:** Optimize window positions for best fit with `Ctrl + Alt + O`.
- **Visual Feedback:** Manual window borders for locked windows.
- **Performance Optimizations:** Configurable update rates and adaptive scaling.

---

## 🎮 Controls & Hotkeys

| Shortcut              | Action                                         |
|-----------------------|------------------------------------------------|
| `Ctrl + Alt + Space`  | Toggle window arrangement ON/OFF               |
| `Ctrl + Alt + P`      | Toggle physics engine ON/OFF                   |
| `Ctrl + Alt + M`      | Toggle seamless multi-monitor floating         |
| `Ctrl + Alt + O`      | Optimize window positions for best fit         |
| `Ctrl + Alt + L`      | Lock/unlock active window                      |
| `Ctrl + Alt + T`      | Show taskbar menu                              |

> **Tip:** Use `Ctrl + Alt + O` to instantly optimize the arrangement of all unlocked floating windows for best space utilization. Locked windows will remain in place.

## 🧠 Core Features

FWDE includes intelligent systems for automatic window management:

### 🎯 Advanced Window Detection
- **DAW Plugin Support:** Automatic detection of VST plugins, audio effect windows, and music production tools.
- **Development Environment:** Handles command prompts, terminals, IDEs, and development floating windows.
- **Pattern Matching:** Configurable patterns for window classes, titles, and process names.

### 📦 Space Optimization
- **Optimize Hotkey (`Ctrl + Alt + O`):** Instantly arranges all unlocked windows for best fit and minimal overlap.
- **Packing Algorithm:** Space-efficient grid and gap-filling strategies for window placement.

### 🖥️ Multi-Monitor Support
- **Seamless Floating:** Windows can float across all monitors when enabled.
- **Monitor Detection:** Windows are assigned to their respective monitors.

---

## 📐 System Status & Monitoring

FWDE includes basic system monitoring and status reporting:

- **Window Count:** Number of currently managed floating windows.
- **Physics Status:** Current state of physics engine (ON/OFF).
- **Arrangement Status:** Automatic arrangement system status (Active/Inactive).

---

## ⚙️ Technical Specs & Configuration

**Requirements:**  
- AutoHotkey v2.0+  
- Windows 10/11  
- Multi-monitor setups supported
- High-DPI compatible

**Current Implementation:**
FWDE v2 focuses on core functionality with a simplified, stable implementation:
- Physics-based window management
- Smart window detection for DAWs, terminals, and development tools
- Performance optimizations for smooth operation
- Manual window locking and border feedback

**Config Map (current simplified version):**
```ahk
global Config := Map(
    "AttractionForce", 0.0001,
    "RepulsionForce", 0.369,
    "Damping", 0.001,
    "MaxSpeed", 12.0,
    "MinMargin", 42,
    "MinGap", 21,
    "EdgeRepulsionForce", 0.80,
    "PhysicsTimeStep", 1,
    "VisualTimeStep", 2,
    "UserMoveTimeout", 11111,
    "ManualLockDuration", 33333,
    "SeamlessMonitorFloat", false,
    "Smoothing", 0.5,
    "MinSpeedThreshold", 0.369
)
```

**Float Detection Patterns:**
The system automatically detects floating windows using:
- **Process Whitelist:** DAW applications (Reaper, FL Studio, Ableton, etc.), terminals, development tools
- **Window Class Patterns:** VST plugins, dialogs, console windows, floating tool windows
- **Title Patterns:** Plugin names, command prompts, development tools, audio effects

## 🛠️ Customization

Edit the Config map in the script for:

- **Physics:** Force strengths, speed limits, damping, update rates
- **Window Management:** Timeout durations, margins, detection patterns
- **Performance:** Update frequencies, monitoring thresholds, resource limits

**Easy Configuration Access:**
- All settings are documented in the script's Config map
- Real-time changes take effect immediately without restart

---

## 🔍 Advanced Configuration

- **High-DPI:** Lower MinSpeedThreshold (0.05-0.15) for precise movement
- **Low-Performance:** Higher MinSpeedThreshold (0.2-0.5), increase TimeStep values
- **Strict Spacing:** Increase RepulsionForce for more window separation
- **Loose Grouping:** Decrease RepulsionForce for closer window clustering  
- **Multi-Monitor:** Enable SeamlessMonitorFloat for cross-monitor window movement

---

## 🐛 Troubleshooting

**Common Issues:**
- **Windows not moving:** Check physics engine status (`Ctrl + Alt + P`) and arrangement system (`Ctrl + Alt + Space`)
- **Too aggressive movement:** Increase Damping value or decrease RepulsionForce in Config
- **Performance issues:** Increase PhysicsTimeStep and VisualTimeStep values for slower updates
- **Multi-monitor problems:** Toggle seamless floating (`Ctrl + Alt + M`) and check monitor detection

**Emergency Controls:**
- `Ctrl + Alt + Space`: Toggle window arrangement
- `Ctrl + Alt + P`: Toggle physics engine
- System automatically recovers from most error conditions with safe fallbacks

---

## 📋 Installation & Usage

1. **Install AutoHotkey v2.0+** from [autohotkey.com](https://autohotkey.com)
2. **Download FWDE.ahk** and run it (or compile to .exe for easier distribution)
3. **Automatic Detection:** Script starts managing eligible floating windows automatically
4. **Configuration:** Use hotkeys to control behavior or edit Config map in script for customization
5. **Multi-Monitor:** Enable seamless multi-monitor floating with `Ctrl + Alt + M`

**First Run:**
- FWDE will show a tooltip confirming successful startup
- Physics engine and arrangement system start enabled by default

**Supported Window Types:**
- DAW plugins (VST, AU, etc.) from Reaper, FL Studio, Ableton, Cubase, and more
- Development tools: Command Prompt, PowerShell, Windows Terminal, IDE floating windows
- System dialogs and utility windows
- Any window matching the configurable detection patterns

---

*Created by Flalaski with AI assistance (DeepSeek, Gemini, Copilot)*  
*Streamlined for stability and essential functionality. Hope it's helpful! ♥*
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
