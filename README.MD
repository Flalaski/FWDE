# Floating Windows - Dynamic Equilibrium  
*Advanced Physics-Based Window Management*  

![Window Arrangement Visualization](https://github.com/Flalaski/FWDE/blob/ca69310d8c5f28540ddc644dd05b87b3b2d8b8d6/FWDEdesktop.png)

---

## 🚀 Overview

FWDE is a physics-driven window manager for Windows, designed for DAW plugins, terminals, dialogs, and floating windows. It uses real-time simulation for natural, intelligent arrangements, with multi-monitor support, manual controls, and visual effects.

**New Features:**  
- **Automatic window resizing:** Any window that would extend below the monitor's bottom margin is automatically resized to fit within the visible area.
- **Configuration validation system:** Prevents invalid parameter combinations that could destabilize the physics engine.
- **Configuration presets:** Pre-configured settings optimized for different use cases (DAW Production, Gaming, Office Work, etc.).
- **Advanced visual feedback:** Comprehensive system tray integration, real-time notifications, and visual status indicators.

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
| `Ctrl + Alt + 1`      | Load Default configuration preset               |
| `Ctrl + Alt + 2`      | Load DAW Production preset                      |
| `Ctrl + Alt + 3`      | Load Gaming preset                              |
| `Ctrl + Alt + 4`      | Load Office Work preset                         |
| `Ctrl + Alt + 5`      | Load High Performance preset                    |
| `Ctrl + Alt + C`      | Show configuration status and validation        |
| `Ctrl + Alt + V`      | View available configuration presets            |
| `Ctrl + Alt + S`      | Save current configuration to file              |
| `Ctrl + Alt + R`      | Reload configuration from file                  |
| `Ctrl + Alt + E`      | Export configuration                            |
| `Ctrl + Alt + I`      | Import configuration                            |

## 🎨 Visual Feedback System

FWDE includes a comprehensive visual feedback system providing real-time status monitoring and user interaction:

### System Tray Integration
- **Status Icons:** Real-time indicators showing system health (Normal, Active, Error, Paused)
- **Context Menu:** Quick access to all major functions including configuration presets
- **Balloon Notifications:** Important system events and status changes
- **Performance Tooltips:** Active window count and current operational mode

### Window Visual Indicators  
- **Colored Borders:** Visual feedback for window states
  - 🔴 Red: Manually locked windows
  - 🟢 Green: Physics-controlled windows  
  - 🔵 Blue: User-dragged windows
  - 🟡 Yellow: Warning states
- **Automatic Cleanup:** Borders automatically expire based on lock duration

### Enhanced Notifications
- **Smart Notifications:** Context-aware messages for all system operations
- **Notification Themes:** Dark, Light, and Default visual themes
- **History Management:** Automatic cleanup with configurable retention
- **Error Tracking:** Comprehensive error reporting with recovery suggestions

### Real-Time Status Display
- **Performance Metrics:** Operation timing and memory usage monitoring  
- **System Health:** Error rates, recovery status, and stability indicators
- **Window Statistics:** Count of managed, plugin, and locked windows
- **Configuration Status:** Real-time validation and parameter monitoring

---

## 📐 Configuration Presets

FWDE includes professionally tuned presets for different use cases:

### 🎵 DAW Production
Optimized for Digital Audio Workstation environments with plugin windows:
- Higher repulsion forces for better plugin separation
- Longer user interaction timeouts for precise positioning
- Multi-monitor floating enabled by default
- Reduced overlap tolerance for cleaner layouts

### 🎮 Gaming  
High-performance settings for gaming environments:
- Faster physics updates for responsive behavior
- Strong edge repulsion to keep windows away from game areas
- Shorter lock durations for quick adjustments
- Optimized for single-monitor setups

### 🏢 Office Work
Conservative settings for productivity environments:
- Larger margins and gaps for professional appearance
- Slower, smoother movements to avoid distraction
- Longer lock durations for stable layouts
- Higher overlap tolerance for document windows

### ⚡ High Performance
Optimized for powerful systems with many windows:
- Maximum update frequencies for smooth operation
- Multi-monitor floating for complex workflows
- Minimal stabilization delays for immediate response
- Fine-tuned for systems with 16+ concurrent windows

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

**Configuration Validation:**
FWDE includes a comprehensive validation system that prevents invalid parameter combinations:
- Range validation for all numeric parameters
- Dependency checking between related settings  
- Automatic fallback to safe defaults on validation failure
- Real-time configuration status monitoring

**Config Map (editable in script):**
```ahk
global Config := Map(
    "MinMargin", 0,                 ; Distance from screen edges (pixels) [0-200]
    "AttractionForce", 0.0001,      ; Center gravitational pull [0.0001-1.0]
    "RepulsionForce", 0.369,        ; Window separation force [0.01-50.0]
    "EdgeRepulsionForce", 0.80,     ; Screen edge push strength [0.1-10.0]
    "SeamlessMonitorFloat", false,  ; Multi-monitor floating toggle
    "UserMoveTimeout", 11111,       ; User interaction timeout (ms) [1000-60000]
    "ManualLockDuration", 33333,    ; Manual lock duration (ms) [5000-300000]
    "PhysicsTimeStep", 1,           ; Physics update frequency [1-100ms]
    "VisualTimeStep", 2,            ; Visual update frequency [1-100ms]
    "MaxSpeed", 12.0,               ; Maximum window velocity [1.0-100.0]
    "Damping", 0.001,               ; Friction coefficient [0.0001-0.1]
    "Smoothing", 0.5                ; Motion smoothing factor [0.1-0.99]
)
```

**Validation Rules:**
- Attraction force must not exceed repulsion force for system stability
- Physics updates should be more frequent than visual updates for smoothness
- Speed and damping combinations are validated to prevent instability
- All parameters are range-checked against safe operational limits

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
- **Presets:** Use hotkeys Ctrl+Alt+1-5 to quickly switch between optimized configurations

**Configuration Management:**
- Real-time validation prevents destabilizing parameter combinations
- Automatic fallback to safe defaults if validation fails
- Configuration status checking with Ctrl+Alt+C
- Easy preset switching for different workflow requirements

---

## 🔍 Advanced Configuration

- **High-DPI:** Lower MinSpeedThreshold (0.05-0.15)
- **Low-Performance:** Higher MinSpeedThreshold (0.2-0.5), increase TimeStep
- **Strict Spacing:** Lower OverlapTolerance (0-5)
- **Loose Grouping:** Higher OverlapTolerance (20+)

---

## 🐛 Troubleshooting

- Windows not moving: Check physics engine (`Ctrl + Alt + P`) or system tray icon status
- Too aggressive: Try Office Work preset (`Ctrl + Alt + 4`) or increase damping
- Performance issues: Try Gaming preset (`Ctrl + Alt + 3`) or check performance metrics
- Multi-monitor: Toggle seamless floating (`Ctrl + Alt + M`) or try High Performance preset (`Ctrl + Alt + 5`)
- Configuration errors: Check status with `Ctrl + Alt + C` and load Default preset (`Ctrl + Alt + 1`)
- Visual feedback issues: Check system tray for error indicators or reset system state
- Window clipped at bottom: Window will be automatically resized to fit the monitor margin during optimization or placement.

**System Tray Troubleshooting:**
- Right-click system tray icon for quick access to all functions
- Use "System Status" for comprehensive health monitoring  
- "Reset System" clears all errors and restarts physics engine
- "Performance Metrics" shows real-time operation statistics

**Configuration Issues:**
- If system becomes unstable, load the Default preset with `Ctrl + Alt + 1`
- Use `Ctrl + Alt + C` to check for configuration validation errors
- Invalid parameter combinations are automatically detected and prevented
- System includes automatic fallback to safe defaults on critical errors
- Visual notifications confirm all configuration changes and status

---

*Created by Flalaski with AI assistance (DeepSeek, Gemini, CoPilot)*  
*Countless iterations for the perfect balance of automatic organization and user control. Hope it's helpful! ♥*
