# FWDE - Floating Windows Dynamic Equilibrium

**Advanced Physics-Based Window Management for Windows (AutoHotkey v2)**

---

## 🎯 What is FWDE?

FWDE is a sophisticated physics-driven window manager that transforms your desktop into a dynamic, self-organizing workspace. Using real-time physics simulation, it intelligently arranges floating windows (browsers, editors, plugins, dialogs) with natural movement, collision avoidance, and space optimization.

Perfect for developers, musicians, designers, and power users who work with multiple floating windows and want intelligent, automated organization.

---

## ✨ Key Features

### 🧠 **Intelligent Physics Engine**
- **Real-time simulation** with attraction, repulsion, and damping forces
- **Multi-window interactions** - windows push and pull each other naturally
- **Edge-aware positioning** - windows utilize full screen real estate
- **Collision avoidance** - no overlapping windows
- **Smooth animations** with configurable update rates

### 🖥️ **Multi-Monitor Support**
- **Per-monitor detection** - each window's physics calculated for its specific monitor
- **Seamless cross-monitor floating** - windows can move freely across all screens
- **Monitor-aware fullscreen detection** - accurate identification of true fullscreen apps
- **Virtual desktop bounds** - unified workspace across multiple displays

### 🎛️ **Advanced Window Detection**
- **Smart filtering** - automatically includes relevant windows (browsers, editors, plugins)
- **Excludes system windows** - taskbars, desktop, fullscreen apps left untouched
- **Configurable patterns** - easily add new applications to be managed
- **Manual override** - force-add any window to the physics system

### 🔧 **Manual Controls**
- **Window locking** - fix individual windows in place
- **Space optimization** - instantly arrange windows for maximum efficiency
- **Physics toggles** - enable/disable physics and visual effects
- **Real-time configuration** - change settings without restarting

### 🎨 **Visual Effects**
- **Time-phasing echoes** - beautiful trailing effects for floating windows
- **Procedural noise clouds** - dynamic visual feedback for plugin windows
- **Lock indicators** - clear visual borders for manually locked windows
- **Smooth transitions** - fluid movement with configurable easing

### 🐛 **Debug & Diagnostics**
- **Window analysis** - detailed information about why windows are/aren't managed
- **Pattern matching** - see which detection rules apply to specific windows
- **Real-time monitoring** - track which windows are being managed
- **Force-add capability** - manually include stubborn windows

---

## 🚀 Installation

### Prerequisites
- **Windows 10/11**
- **[AutoHotkey v2](https://autohotkey.com)** (latest version)

### Quick Setup
1. **Download** `FWDE.ahk` to your preferred location
2. **Run** the script directly or compile to `.exe` for standalone use
3. **Configure** settings in the `Config` map (optional)
4. **Use hotkeys** to control the system

### Compilation (Optional)
```bash
# Compile to standalone executable
autohotkey.exe /in FWDE.ahk
```

---

## 🎮 Usage

### Getting Started
1. **Launch FWDE** - the system starts automatically
2. **Open applications** - browsers, editors, terminals, etc.
3. **Watch the magic** - windows arrange themselves naturally
4. **Use hotkeys** for manual control when needed

### Window Management
- **Automatic**: FWDE detects and manages eligible windows automatically
- **Manual Lock**: Press `Ctrl+Alt+L` on any window to lock it in place
- **Force Add**: Press `Ctrl+Alt+A` to manually add a window to physics
- **Optimize**: Press `Ctrl+Alt+O` to instantly optimize all window positions

---

## ⌨️ Hotkeys Reference

| Shortcut | Action | Description |
|----------|--------|-------------|
| `Ctrl + Alt + Space` | Toggle Arrangement | Enable/disable the entire physics system |
| `Ctrl + Alt + P` | Toggle Physics | Enable/disable physics calculations |
| `Ctrl + Alt + F` | Toggle Visual Effects | Enable/disable time-phasing and visual effects |
| `Ctrl + Alt + M` | Toggle Multi-Monitor | Switch between single-monitor and seamless multi-monitor mode |
| `Ctrl + Alt + O` | Optimize Positions | Instantly arrange windows for optimal space usage |
| `Ctrl + Alt + L` | Lock/Unlock Window | Lock or unlock the currently active window |
| `Ctrl + Alt + T` | Show Taskbar Menu | Display the context menu from the taskbar |
| `Ctrl + Alt + D` | Debug Window Info | Show comprehensive window tracking information |
| `Ctrl + Alt + I` | Debug Active Window | Analyze the currently active window in detail |
| `Ctrl + Alt + A` | Force Add Window | Manually add the active window to physics tracking |

---

## ⚙️ Configuration

All settings are in the `Config` map at the top of `FWDE.ahk`. Changes take effect immediately without restarting.

### Core Physics Settings
```ahk
global Config := Map(
    "MinMargin", 2,                    ; Minimum distance from screen edges (pixels)
    "MinGap", 21,                      ; Minimum gap between windows
    "AttractionForce", 0.00005,        ; Force pulling windows toward center
    "RepulsionForce", 0.8,             ; Force pushing windows apart
    "EdgeRepulsionForce", 0.80,        ; Force from screen edges
    "Damping", 0.001,                  ; Friction/damping coefficient
    "MaxSpeed", 12.0,                  ; Maximum window velocity
)
```

### Performance Settings
```ahk
"PhysicsTimeStep", 1,                  ; Physics update frequency (ms)
"VisualTimeStep", 16,                  ; Visual update frequency (ms) - 60fps
"UserMoveTimeout", 11111,              ; Pause physics after user interaction (ms)
"ManualLockDuration", 33333,           ; How long manual locks last (ms)
```

### Window Detection Settings
```ahk
"ForceFloatProcesses", [               ; Processes that should always float
    "firefox.exe", "chrome.exe", "cursor.exe", "code.exe",
    "notepad++.exe", "devenv.exe", "explorer.exe",
    "winword.exe", "excel.exe", "powerpnt.exe", "outlook.exe"
],
"FloatClassPatterns", [                ; Window classes to include
    "MozillaWindowClass", "Chrome_WidgetWin_1", "ApplicationFrameWindow",
    "Code.exe", "Cursor.exe", "Notepad", "Notepad++"
],
"FloatTitlePatterns", [                ; Window titles to include
    "VST.*", "JS:.*", "Plugin", "Command Prompt", "Windows Terminal"
]
```

### Advanced Features
```ahk
"SeamlessMonitorFloat", false,         ; Allow windows to float across monitors
"TooltipDuration", 15000,              ; How long debug tooltips stay visible
"ResizeDelay", 22,                     ; Delay before applying physics after resize
```

---

## 🔍 Debugging & Troubleshooting

### Debug Tools
- **`Ctrl+Alt+D`** - Shows all tracked vs untracked windows with detailed information
- **`Ctrl+Alt+I`** - Analyzes the active window and shows why it is/isn't being managed
- **`Ctrl+Alt+A`** - Manually add any window to the physics system

### Common Issues

#### Windows Not Moving
1. **Check arrangement status**: Press `Ctrl+Alt+Space` to ensure it's ON
2. **Check physics status**: Press `Ctrl+Alt+P` to ensure physics is ON
3. **Debug window**: Press `Ctrl+Alt+I` on the problematic window
4. **Force add**: Press `Ctrl+Alt+A` if the window should be managed

#### Too Much Movement
- **Increase damping**: Set `"Damping"` to 0.005 or higher
- **Reduce repulsion**: Lower `"RepulsionForce"` to 0.3 or less
- **Lock windows**: Use `Ctrl+Alt+L` to lock windows in place

#### Performance Issues
- **Increase timesteps**: Set `"PhysicsTimeStep"` to 5 and `"VisualTimeStep"` to 33
- **Reduce window count**: Lock unnecessary windows with `Ctrl+Alt+L`
- **Disable effects**: Press `Ctrl+Alt+F` to turn off visual effects

#### Multi-Monitor Problems
- **Toggle seamless mode**: Press `Ctrl+Alt+M` to switch between modes
- **Check monitor detection**: Use `Ctrl+Alt+D` to see monitor assignments
- **Verify window positions**: Ensure windows are on the intended monitors

#### Windows Not Detected
- **Check patterns**: Use `Ctrl+Alt+I` to see which patterns match
- **Add to ForceFloatProcesses**: Add the process name to the config
- **Force add manually**: Use `Ctrl+Alt+A` for immediate inclusion

---

## 🎯 Use Cases

### 🎵 **Music Production**
- **DAW Plugin Management**: Automatically arranges VST plugins, effects, and instruments
- **Multi-Monitor Workflow**: Seamless plugin organization across multiple screens
- **Lock Critical Windows**: Keep your main DAW interface fixed while plugins float

### 💻 **Software Development**
- **IDE + Browser**: Firefox/Chrome and code editors work together harmoniously
- **Terminal Management**: Command prompts and terminals arrange themselves
- **Documentation Windows**: Reference materials stay accessible without overlap

### 🎨 **Design & Creative Work**
- **Tool Palette Organization**: Photoshop, Illustrator, and other creative tools
- **Reference Management**: Image viewers, color pickers, and design references
- **Multi-Application Workflow**: Seamless switching between design applications

### 📊 **Data Analysis**
- **Spreadsheet + Browser**: Excel and web research tools work together
- **Chart Management**: Multiple data visualization windows organized automatically
- **Research Workflow**: PDFs, browsers, and analysis tools in harmony

---

## 🏗️ Technical Details

### Architecture
- **Physics Engine**: Custom implementation with attraction/repulsion forces
- **Window Detection**: Multi-pattern matching system (process, class, title, style)
- **Multi-Monitor**: Per-monitor physics calculations with cross-monitor support
- **Performance**: Adaptive update rates with resource management

### Window Detection Logic
1. **Existence Check**: Window must exist and be accessible
2. **Fullscreen Check**: Excludes true fullscreen applications (games, media players)
3. **Min/Max Check**: Excludes minimized or maximized windows
4. **Pattern Matching**: Checks against ForceFloatProcesses, FloatClassPatterns, FloatTitlePatterns
5. **Style Analysis**: Examines Windows API style flags
6. **Manual Override**: Allows force-adding any window

### Physics Simulation
- **Force Calculation**: Attraction toward center, repulsion from other windows and edges
- **Velocity Integration**: Smooth movement with configurable damping
- **Collision Detection**: Prevents window overlap with configurable tolerance
- **Boundary Enforcement**: Keeps windows within monitor bounds

---

## 🔄 Recent Updates

### Enhanced Window Detection
- **Fixed fullscreen detection** - browsers and editors no longer incorrectly excluded
- **Added common applications** - Firefox, Chrome, Cursor, VS Code, Office apps
- **Improved pattern matching** - more accurate detection of relevant windows
- **Multi-monitor awareness** - per-monitor physics calculations

### Debug & Diagnostic Tools
- **Real-time window analysis** - see exactly why windows are/aren't managed
- **Pattern matching display** - understand which rules apply to each window
- **Force-add capability** - manually include any window in the physics system
- **Comprehensive monitoring** - track all managed windows at a glance

### Performance Optimizations
- **Increased repulsion force** - windows spread out more effectively
- **Reduced attraction force** - allows better space utilization
- **Enhanced interaction ranges** - larger gaps between windows
- **Improved edge positioning** - better use of screen real estate

---

## 🤝 Contributing

FWDE is actively developed and welcomes contributions:

- **Bug Reports**: Use the debug tools to identify issues
- **Feature Requests**: Suggest new capabilities or improvements
- **Code Contributions**: Submit pull requests for enhancements
- **Documentation**: Help improve this README and inline comments

---

## 📄 License

This project is open source. See the `LICENSE` file for details.

---

## 👨‍💻 Credits

**Created by Flalaski** with AI assistance (Copilot, DeepSeek, Gemini)  
**Streamlined for stability and essential functionality**

Special thanks to the AutoHotkey community for the excellent v2 platform.

---

## 🆘 Support

Having issues? Here's how to get help:

1. **Use debug tools** (`Ctrl+Alt+D`, `Ctrl+Alt+I`) to identify the problem
2. **Check this README** for common solutions
3. **Review the configuration** - most issues are settings-related
4. **Test with minimal setup** - disable effects and reduce window count

**Happy floating! 🪟✨**