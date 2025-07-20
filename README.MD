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

## 🌈 Visual Effects  (CURRENTLY NOT WORKING YET, LOW PRIORITY (FOR NOW))
| Shortcut | Effect |
|----------|--------|
| `Ctrl + Alt + F` | Toggle "fairy dust" particles |
| *Dragging* | Glowing border on active window |

## ⚙️ Technical Details  
**Requirements**:  
- AutoHotkey v2.0+  
- Windows 10/11  

**Physics Settings** (adjust in script):  
```ahk
Config := Map(
    "MinMargin", 42,          ; Space from screen edges
    "AttractionForce", 0.32,  ; Center pull strength
    "RepulsionForce", 0.28    ; Window push strength
)