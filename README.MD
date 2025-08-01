# Floating Windows - Dynamic Equilibrium  
*Advanced Physics-Based Window Management*  

![Window Arrangement Visualization](https://github.com/Flalaski/FWDE/blob/ca69310d8c5f28540ddc644dd05b87b3b2d8b8d6/FWDEdesktop.png)

---

## 🚀 Overview

FWDE is a physics-driven window manager for Windows, designed for DAW plugins, terminals, dialogs, and floating windows. It uses real-time simulation for natural, intelligent arrangements, with multi-monitor support, manual controls, visual effects, sophisticated layout algorithms including bin packing, genetic evolution, custom presets, and **adaptive performance scaling** that automatically optimizes system resource usage.

**New Features:**  
- **Adaptive performance scaling:** Intelligent system resource monitoring with automatic quality level adjustment based on CPU, memory, and frame timing metrics
- **Performance budget management:** Operation-specific performance budgets with automatic enforcement to maintain optimal responsiveness
- **Emergency performance protection:** Critical resource detection with automatic system protection and recovery mechanisms

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
| `Ctrl + Alt + Shift + L` | Save current layout with custom name       |
| `Ctrl + Alt + Shift + K` | Load saved layout from selection dialog    |
| `Ctrl + Alt + Shift + G` | Toggle genetic algorithm evolution          |
| `Ctrl + Alt + Shift + B` | Change bin packing strategy                 |
| `Ctrl + Alt + Shift + V` | Toggle virtual desktop integration          |
| `Ctrl + Alt + Shift + Q` | Toggle automatic performance adjustment          |
| `Ctrl + Alt + Shift + W` | Show comprehensive performance metrics           |
| `Ctrl + Alt + Shift + E` | Manual quality level cycling                     |

## 🧠 Sophisticated Layout Algorithms

FWDE includes advanced layout optimization algorithms for intelligent window arrangement:

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

- **Layout Algorithms:**
  - Advanced bin packing for optimal space utilization
  - Genetic algorithm evolution for adaptive layout learning
  - Custom layout presets with visual management
  - Virtual desktop integration for multi-workspace productivity

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

**Layout Algorithm Configuration:**
```ahk
global LayoutAlgorithms := Map(
    "BinPacking", Map(
        "Strategy", "BestFit",           ; FirstFit, BestFit, NextFit, WorstFit
        "AllowRotation", false,          ; Allow window rotation for better fit
        "PackingEfficiency", 0.85        ; Target packing efficiency (0.0-1.0)
    ),
    "GeneticAlgorithm", Map(
        "PopulationSize", 50,            ; Size of layout population
        "MutationRate", 0.1,             ; Rate of layout mutations (0.0-1.0)
        "CrossoverRate", 0.8,            ; Rate of layout crossover (0.0-1.0)
        "FitnessWeights", Map(           ; Weights for fitness calculation
            "Overlap", 0.3,              ; Penalty for window overlaps
            "ScreenUsage", 0.25,         ; Reward for efficient screen usage
            "Accessibility", 0.2,        ; Reward for accessible layouts
            "UserPreference", 0.15,      ; Reward for user preference alignment
            "Aesthetics", 0.1            ; Reward for aesthetic appeal
        )
    )
)
```

**Layout Management Commands:**
- Save current layout: `Ctrl + Alt + Shift + L`
- Load saved layout: `Ctrl + Alt + Shift + K`
- Toggle genetic evolution: `Ctrl + Alt + Shift + G`
- Change packing strategy: `Ctrl + Alt + Shift + B`
- Virtual desktop toggle: `Ctrl + Alt + Shift + V`

---

## ⚡ Adaptive Performance Scaling

FWDE includes an intelligent performance scaling system that monitors system resources and automatically adjusts quality settings:

### 📊 Real-Time Resource Monitoring
- **CPU Usage Tracking**: Continuous monitoring of system CPU load with historical analysis
- **Memory Usage Analysis**: Real-time memory consumption tracking with threshold detection
- **Frame Timing Metrics**: Frame rate and timing variance analysis for smooth operation
- **Performance Trend Analysis**: Historical performance data for predictive optimization

### 🎚️ Automatic Quality Adjustment
- **Five-Tier Quality System**: Ultra, High, Medium, Low, and Minimal quality levels
- **Intelligent Quality Selection**: Automatic quality level recommendation based on system performance
- **Smooth Quality Transitions**: Seamless quality adjustments with user notification
- **Emergency Performance Protection**: Automatic critical resource detection and protection

### 📈 Performance Budget Management
- **Operation-Specific Budgets**: Individual performance budgets for physics, movement, and visual operations
- **Automatic Budget Enforcement**: Real-time performance monitoring with automatic adjustment
- **Performance Metrics Dashboard**: Comprehensive real-time performance statistics and trends
- **User-Controllable Settings**: Manual override and configuration of automatic performance scaling

### Quality Level Characteristics:
- **Ultra**: Maximum quality for high-end systems (1ms physics/visual updates, all advanced features)
- **High**: High quality for powerful systems (1-2ms updates, advanced visuals enabled)
- **Medium**: Balanced quality for most systems (2-3ms updates, selective advanced features)
- **Low**: Performance optimized for older systems (3-5ms updates, essential features only)
- **Minimal**: Minimum resource usage for limited systems (5-10ms updates, basic functionality)

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

Edit the LayoutAlgorithms map for:

- **Bin Packing:** Strategy selection, rotation options, efficiency targets
- **Genetic Algorithm:** Population size, mutation rates, fitness weights
- **Custom Layouts:** Auto-save options, layout directory, maximum saved layouts
- **Virtual Desktop:** Per-workspace settings, automatic switching, workspace profiles

**Configuration Management:**
- Real-time validation prevents destabilizing parameter combinations
- Automatic fallback to safe defaults if validation fails
- Configuration status checking with Ctrl+Alt+C
- Easy preset switching for different workflow requirements

**Advanced Layout Configuration:**
- **Algorithm Selection**: Choose optimal packing strategy based on your workflow
- **Evolution Parameters**: Tune genetic algorithm for faster or more thorough optimization
- **Workspace Management**: Configure per-desktop layout rules and automatic switching
- **Performance Optimization**: Adjust algorithm timing and efficiency for your system

---

## 🔍 Advanced Configuration

- **High-DPI:** Lower MinSpeedThreshold (0.05-0.15)
- **Low-Performance:** Higher MinSpeedThreshold (0.2-0.5), increase TimeStep
- **Strict Spacing:** Lower OverlapTolerance (0-5)
- **Loose Grouping:** Higher OverlapTolerance (20+)
- **Layout Optimization:** Use genetic algorithm for workflows requiring perfect arrangements
- **Space Efficiency:** Enable bin packing for maximum screen utilization
- **Multi-Workspace:** Virtual desktop integration for complex professional workflows
- **Performance Tuning:** Adjust algorithm parameters based on window count and system specs

---

## 🐛 Troubleshooting

- Windows not moving: Check physics engine (`Ctrl + Alt + P`) or system tray icon status
- Too aggressive: Try Office Work preset (`Ctrl + Alt + 4`) or increase damping
- Performance issues: Try Gaming preset (`Ctrl + Alt + 3`) or check performance metrics
- Multi-monitor: Toggle seamless floating (`Ctrl + Alt + M`) or try High Performance preset (`Ctrl + Alt + 5`)
- Configuration errors: Check status with `Ctrl + Alt + C` and load Default preset (`Ctrl + Alt + 1`)
- Visual feedback issues: Check system tray for error indicators or reset system state
- Window clipped at bottom: Window will be automatically resized to fit the monitor margin during optimization or placement.
- **Layout issues**: Try different bin packing strategies (`Ctrl + Alt + Shift + B`) or reset genetic algorithm
- **Virtual desktop problems**: Check Windows 11 virtual desktop settings and restart FWDE
- **Performance with many windows**: Disable genetic algorithm or reduce population size
- **Layout restoration failures**: Verify window titles and classes haven't changed

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

**Layout Algorithm Troubleshooting:**
- **Poor packing efficiency**: Try Best Fit or Guillotine strategies for complex arrangements
- **Genetic algorithm not improving**: Increase population size or adjust fitness weights
- **Layout presets not loading**: Check layout file integrity and window matching criteria
- **Virtual desktop integration issues**: Ensure Windows 11 virtual desktop API is available

**Performance Issues:**
- **High resource usage**: System automatically reduces quality level with notification
- **Critical resource situations**: Emergency performance reduction with automatic recovery
- **Performance monitoring**: Use `Ctrl + Alt + Shift + W` for comprehensive performance metrics
- **Manual quality control**: Use `Ctrl + Alt + Shift + E` to manually cycle through quality levels

---

*Created by Flalaski with AI assistance (DeepSeek, Gemini, CoPilot)*  
*Countless iterations for the perfect balance of automatic organization and user control. Hope it's helpful! ♥*
