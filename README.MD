# Floating Windows - Dynamic Equilibrium  
*A Smart Window Arrangement Tool*  

![Window Arrangement Visualization](https://github.com/Flalaski/FWDE/blob/ca69310d8c5f28540ddc644dd05b87b3b2d8b8d6/FWDEdesktop.png)

## ✨ What This Does  
This tool gently organizes your open windows into a balanced, constantly-adjusting layout. Windows:  
- 🌀 Naturally avoid overlapping each other  
- 🖥️ Stay comfortably within screen edges  
- ✨ Smoothly animate into place when moved  
- 🖱️ Can be dragged manually when needed  

## 🎮 Basic Controls  
| Shortcut | Action |
|----------|--------|
| `Ctrl + Alt + Space` | Toggle automatic arrangement |
| `Ctrl + Alt + Left-Click Drag` | Manually move any window | (MIGHT BE OUTDATED, KINDA CHUNKY & UNNECESSARY)
| `Ctrl + Alt + O` | Optimize all window positions |

## 🌈 Visual Effects  (WIP)
| Shortcut | Effect |
|----------|--------|
| `Ctrl + Alt + F` | Toggle "fairy dust" particles |
| *Dragging* | Glowing border on active window |

## ⚙️ Technical Details  
**Requirements**:  
- AutoHotkey v2.0+  
- Windows 10/11  

**Default Settings 72025** (adjust in script):  
```ahk
global Config := Map(
    "MinMargin", 23,
    "MinGap", 0,
    "ManualGapBonus", 369,
    "AttractionForce", .32,
    "RepulsionForce", .28,
    "ManualRepulsionMultiplier", 1.3,
    "EdgeRepulsionForce", 1.80,
    "UserMoveTimeout", 11111,
    "ManualLockDuration", 11,
    "ResizeDelay", 111,
    "TooltipDuration", 15000,
    "FloatStyles", 0x40000|0x20000|0x800000,
    "Damping", 0.92,    ; Lower = less friction (0.001-0.01)
    "MaxSpeed", 1.5,    ; Limits maximum velocity
    "PhysicsTimeStep", 20,  ; Lower = more frequent physics updates (1ms is max)
    "VisualTimeStep", 16,   ; Lower = smoother visuals (try 16-33ms for 60-30fps)
    "Smoothing", 0.99,  ; Higher = smoother but more lag (0.9-0.99)
    "Stabilization", Map(
        "MinSpeedThreshold", 0.4,  ; Lower values high-DPI (0.05-0.15) ~ Higher values (0.2-0.5)  low-performance systems
        "EnergyThreshold", 0.03,     ; Lower values (0.05-0.1): Early stabilization, prevents overshooting
        "DampingBoost", 0.18,       ; 0.01-0.05: Subtle braking (smooth stops) ~ 0.1+: Strong braking (quick stops but may feel robotic)
        "OverlapTolerance", 4      ; Small values (5-10): Strict spacing (prevents all overlap) ~ Large (30+): Loose grouping (windows can temporarily overlap)
    ),
    "ManualWindowColor", "FF5555",
    "ManualWindowAlpha", 222,
    "NoiseScale", 8,
    "NoiseInfluence", 100,
    "AnimationDuration", 32,    ; Higher = longer animations (try 16-32)
    "PhysicsUpdateInterval", 200,
)

global g := Map(
    "Monitor", GetCurrentMonitorInfo(),
    "ArrangementActive", true,
    "LastUserMove", 0,
    "ActiveWindow", 0,
    "Windows", [],
    "PhysicsEnabled", true,
    "FairyDustEnabled", true,
    "ManualWindows", Map(),
    "SystemEnergy", 1
)