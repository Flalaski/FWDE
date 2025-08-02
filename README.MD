# Floating Windows - Dynamic Equilibrium  
*Advanced Physics-Based Window Management*  

![Window Arrangement Visualization](https://github.com/Flalaski/FWDE/blob/ca69310d8c5f28540ddc644dd05b87b3b2d8b8d6/FWDEdesktop.png)

---

## 🚀 Overview

FWDE is a physics-driven window manager for Windows, designed for DAW plugins, terminals, dialogs, and floating windows. It uses real-time simulation for natural, intelligent arrangements, with multi-monitor support, manual controls, visual effects, sophisticated layout algorithms including bin packing, genetic evolution, custom presets, and **adaptive performance scaling** that automatically optimizes system resource usage.

**New Features:**  
- **Intelligent Screenshot Detection:** Smart detection system that only pauses physics during active screenshot operations, not when screenshot tools are idle in background
- **Reduced False Positives:** Advanced process monitoring that distinguishes between idle background processes and active screenshot UI
- **Manual Override Controls:** Toggle screenshot detection completely with hotkey or disable temporarily as needed
- **Enhanced Window Targeting:** Improved detection of floating windows for DAWs, terminals, plugins, and development tools
- **Performance Optimizations:** Reduced resource usage with smarter update frequencies and intelligent monitoring thresholds

---

## 🎮 Controls & Hotkeys

| Shortcut              | Action                                         |
|-----------------------|------------------------------------------------|
| `Ctrl + Alt + P`      | Toggle physics engine ON/OFF                   |
| `Ctrl + Alt + A`      | Toggle automatic window arrangement ON/OFF     |
| `Ctrl + Alt + M`      | Toggle seamless multi-monitor floating         |
| `Ctrl + Alt + S`      | Toggle screenshot detection ON/OFF             |
| `Ctrl + Alt + R`      | Refresh window list manually                   |
| `Ctrl + Alt + I`      | Show comprehensive system status               |
| `Ctrl + Alt + Pause`  | Emergency stop - pause all systems            |

## 🧠 Core Features

FWDE includes intelligent systems for automatic window management:

### 📷 Smart Screenshot Detection
- **Intelligent Process Monitoring**: Distinguishes between idle background screenshot tools and active capture operations
- **Window Activity Analysis**: Detects active screenshot UI elements and capture windows rather than just process existence
- **Reduced False Positives**: Physics only pauses during actual screenshot operations, not when tools like ShareX are idle
- **Manual Control**: Toggle screenshot detection entirely with `Ctrl + Alt + S` or disable temporarily as needed
- **Supported Applications**: ShareX, ScreenToGif, Greenshot, Snagit, Windows Snipping Tool, PowerToys Screen Ruler, and more

### 🎯 Advanced Window Detection
- **DAW Plugin Support**: Automatic detection of VST plugins, audio effect windows, and music production tools
- **Development Environment**: Handles command prompts, terminals, IDEs, and development floating windows  
- **Pattern Matching**: Configurable patterns for window classes, titles, and process names
- **Multi-Criteria Detection**: Combines window styles, process whitelists, and pattern matching for accurate targeting

### 📦 Bin Packing Algorithms
- **First Fit**: Places windows in the first available space for quick arrangement
- **Best Fit**: Finds the optimal position that minimizes wasted space
- **Next Fit**: Sequential placement for predictable arrangements
- **Worst Fit**: Maximizes remaining space for flexible layouts
- **Bottom-Left Fill**: Gravity-based packing for stable arrangements
- **Guillotine**: Recursive space division for complex layouts

### 🧬 Genetic Algorithm Evolution
- **Adaptive Learning**: System learns your preferences and evolves optimal layouts
- **Multi-Factor Fitness**: Considers overlap, accessibility, aesthetics, and user preferences
- **Real-Time Evolution**: Continuously improves layouts based on usage patterns
- **Population Management**: Maintains diverse layout solutions for different scenarios

### 💾 Custom Layout Presets
- **Named Layouts**: Save and load custom window arrangements with descriptive names
- **Visual Thumbnails**: Preview layouts before applying with generated thumbnails
- **Smart Matching**: Automatically matches windows across sessions for reliable restoration
- **Layout Sharing**: Export and import layouts for team collaboration

### 🖥️ Virtual Desktop Integration (Windows 11+)
- **Per-Workspace Layouts**: Isolated layout management for each virtual desktop
- **Automatic Switching**: Layouts automatically change when switching workspaces
- **Workspace Profiles**: Customizable per-workspace physics and layout rules
- **Seamless Integration**: Native Windows 11 virtual desktop API support

---

## 📐 System Status & Monitoring

FWDE includes comprehensive system monitoring and status reporting:

### 📊 Real-Time System Status
- **Window Count**: Number of currently managed floating windows
- **Physics Status**: Current state of physics engine (ON/OFF)
- **Arrangement Status**: Automatic arrangement system status (Active/Inactive)
- **Screenshot Detection**: Current screenshot detection state (Enabled/Disabled)
- **Physics State**: Whether physics is currently paused or active
- **Error Tracking**: System error count and recent error information

### 🔧 Status Display Hotkey
Use `Ctrl + Alt + I` to show a comprehensive status dialog with:
- Current window count being managed
- Physics engine status
- Arrangement system status  
- Screenshot detection status
- Current physics state (active/paused)
- System error count and health status

The status dialog auto-closes after 10 seconds for non-intrusive monitoring.

### 🧪 Physics Test Hotkey
Use `Ctrl + Alt + T` to test the physics system:
- Moves the currently active window to the top-left corner
- Window should automatically move back toward the center due to attraction forces
- Provides immediate visual feedback on physics system operation
- Useful for verifying physics parameters and responsiveness
⚡ Physics & Visual Effects

- **Physics Engine:**  
  - Center attraction with configurable gravitational pull toward screen center
  - Inter-window repulsion forces to prevent overlapping and maintain spacing
  - Edge barriers that push windows away from screen boundaries  
  - Velocity limiting and damping for natural, controlled movement
  - Smart collision detection and resolution for smooth interactions

- **Performance Features:**  
  - Configurable update frequencies for physics and visual systems
  - Performance metric tracking with automatic optimization
  - Emergency performance protection for system stability
  - Intelligent resource monitoring and adaptive scaling

- **Screenshot Integration:**
  - Smart detection of active screenshot operations vs. idle background processes
  - Automatic physics pausing during actual screenshot capture to prevent interference
  - Support for popular screenshot tools: ShareX, Greenshot, Snagit, Windows Snipping Tool
  - Manual override controls for complete screenshot detection management

---

## ⚙️ Technical Specs & Configuration

**Requirements:**  
- AutoHotkey v2.0+  
- Windows 10/11  
- Multi-monitor setups supported
- High-DPI compatible

**Current Implementation:**
FWDE v2 focuses on core functionality with a simplified, stable implementation:
- Essential physics-based window management
- Intelligent screenshot detection with minimal false positives
- Smart window detection for DAWs, terminals, and development tools
- Performance optimizations for smooth operation
- Comprehensive system status monitoring and error tracking

**Config Map (current simplified version):**
```ahk
global Config := Map(
    ; Core Physics
    "AttractionForce", 0.0001,      ; Center gravitational pull [0.0001-1.0]
    "RepulsionForce", 0.369,        ; Window separation force [0.01-50.0]
    "Damping", 0.001,               ; Friction coefficient [0.0001-0.1]
    "MaxSpeed", 12.0,               ; Maximum window velocity [1.0-100.0]
    
    ; Layout Parameters
    "MinMargin", 0,                 ; Distance from screen edges (pixels)
    "MinGap", 0,                    ; Minimum gap between windows
    "EdgeRepulsionForce", 0.80,     ; Screen edge push strength [0.1-10.0]
    
    ; Timing & Performance
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

**Supported Window Types:**
- DAW plugins (VST, AU, etc.) from Reaper, FL Studio, Ableton, Cubase, and more
- Development tools: Command Prompt, PowerShell, Windows Terminal, IDE floating windows
- System dialogs and utility windows
- Any window matching the configurable detection patterns

---

*Created by Flalaski with AI assistance (DeepSeek, Gemini, CoPilot)*  
*Streamlined for stability and essential functionality. Hope it's helpful! ♥*
