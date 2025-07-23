# Floating Windows - Dynamic Equilibrium  
*Advanced Physics-Based Window Management*  

![Window Arrangement Visualization](https://github.com/Flalaski/FWDE/blob/ca69310d8c5f28540ddc644dd05b87b3b2d8b8d6/FWDEdesktop.png)

## ✨ What This Does  
FWDE is a sophisticated window management system that uses real-time physics simulation to create dynamic, intelligent window arrangements. Features include:

🌊 **Physics-Based Movement**: Windows use attraction/repulsion forces for natural, fluid motion  
🖥️ **Multi-Monitor Support**: **NEW** - Seamless floating across all monitors (toggleable)  
🎯 **Smart Detection**: Automatically manages DAW plugins, dialogs, terminals, and floating windows  
🔒 **Manual Control**: Lock windows in place, optimize layouts, and fine-tune behavior  
✨ **Visual Effects**: Time-phasing echoes with dynamic particle systems  
🎮 **Adaptive Physics**: Energy-based system that responds to user activity and window interactions  

## 🎮 Control Hotkeys  
| Shortcut | Action |
|----------|--------|
| `Ctrl + Alt + Space` | Toggle automatic window arrangement ON/OFF |
| `Ctrl + Alt + P` | Toggle physics engine ON/OFF |
| `Ctrl + Alt + F` | Toggle time-phasing visual effects |
| `Ctrl + Alt + M` | **NEW** - Toggle seamless multi-monitor floating |
| `Ctrl + Alt + O` | Optimize all window positions for better space usage |
| `Ctrl + Alt + L` | Lock/unlock the currently active window |

## 🚀 Advanced Features

### 🖥️ Multi-Monitor Floating (`Ctrl + Alt + M`)
**NEW FEATURE**: When enabled, windows can float freely across all connected monitors as one unified workspace. When disabled, windows are confined to their current monitor boundaries.

### 🎯 Intelligent Window Detection
Automatically recognizes and manages:
- **DAW Plugin Windows**: VST, JS, and audio plugin interfaces from Reaper, Ableton, FL Studio, Cubase, Studio One, Bitwig, Pro Tools
- **Development Tools**: Command Prompt, Windows Terminal, console applications
- **Dialog Boxes**: System dialogs and floating tool windows
- **Custom Patterns**: Configurable window class and title pattern matching

### ⚡ Physics Engine Features
- **Dynamic Forces**: Center attraction, inter-window repulsion, edge barriers
- **Space-Seeking Behavior**: Windows automatically move toward less crowded areas
- **Energy State Management**: Adapts between "normal" and "chaos" modes based on system activity
- **Collision Resolution**: Prevents overlapping while maintaining smooth, natural motion
- **Velocity Limiting**: Configurable speed limits for stable movement

### 🔒 Window Locking System
- Lock individual windows to prevent physics-based movement
- Visual red borders appear around manually locked windows
- Automatic timeout system (33 seconds default)
- Manual lock/unlock with `Ctrl + Alt + L`

### 🎨 Visual Effects System
- **Time-Phasing Echoes**: Smooth particle trails for enhanced visual feedback
- **Manual Window Borders**: Red highlighting for locked windows
- **Blur Effects**: Desktop composition integration for modern visual appearance

## ⚙️ Technical Specifications  
**Requirements**:  
- AutoHotkey v2.0+  
- Windows 10/11  
- Multi-monitor setups fully supported
- High-DPI displays compatible

**Current Configuration** (all values adjustable in script):  
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

## 🔧 Supported Applications
**Optimized for DAW/Audio Software**:
- Reaper, Ableton Live, FL Studio
- Cubase, Studio One, Bitwig Studio, Pro Tools
- VST/JS plugin interfaces and effects windows

**Development & System Tools**:
- Command Prompt, Windows Terminal
- Console applications and development tools
- Dialog boxes and system utilities

**General Floating Windows**:
- Any window matching configurable patterns
- Tool windows and floating panels
- Custom window classes and titles

## 🎯 How the Physics Works
The system treats windows as particles in a 2D physics simulation:

1. **Forces Applied**:
   - **Center Attraction**: Gentle pull toward screen center to prevent drift
   - **Inter-Window Repulsion**: Pushes overlapping windows apart
   - **Edge Barriers**: Soft collision system at screen boundaries
   - **Space-Seeking**: Movement toward less crowded areas

2. **Energy Management**:
   - **Normal State**: Balanced forces for stable arrangements
   - **Chaos State**: Reduced forces during high activity periods
   - **Stabilization**: Progressive damping as movement slows

3. **Smart Behaviors**:
   - Active windows temporarily freeze in place
   - Recently moved windows have interaction timeouts
   - Small windows get priority positioning (always on top)
   - Plugin windows receive special handling for DAW workflows

## 📋 Installation & Usage
1. **Install AutoHotkey v2.0+** from [autohotkey.com](https://autohotkey.com)
2. **Download FWDE.ahk** and run it
3. **Automatic Operation**: Script immediately starts managing eligible windows
4. **Customize**: Use hotkeys to control behavior or edit Config values in script
5. **Multi-Monitor**: Press `Ctrl + Alt + M` to enable seamless floating across monitors

## 🛠️ Customization Options
Edit the Config map in the script to adjust:

**Physics Behavior**:
- Force strengths (attraction, repulsion, edge barriers)
- Speed limits and damping coefficients
- Update frequencies for performance tuning

**Window Management**:
- Timeout durations for user interaction
- Screen edge margins and boundaries
- Window pattern matching rules

**Visual Effects**:
- Animation durations and smoothing
- Manual window highlight colors
- Time-phasing effect parameters

## 🔍 Advanced Configuration
**For High-DPI Displays**: Lower MinSpeedThreshold (0.05-0.15)  
**For Low-Performance Systems**: Higher values (0.2-0.5), increase TimeStep values  
**For Strict Window Spacing**: Lower OverlapTolerance (0-5)  
**For Loose Grouping**: Higher OverlapTolerance (20+)  

## 🐛 Troubleshooting
- **Windows not moving**: Check if physics engine is enabled (`Ctrl + Alt + P`)
- **Too aggressive movement**: Increase damping, reduce force values
- **Performance issues**: Increase PhysicsTimeStep and VisualTimeStep values
- **Multi-monitor issues**: Toggle seamless floating (`Ctrl + Alt + M`)

---
*Created by Flalaski with AI assistance (DeepSeek, Gemini, CoPilot)*  
*This tool represents countless iterations and refinements to achieve the perfect balance of automatic organization and user control. Hope it's helpful! ♥*
