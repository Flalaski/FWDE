#Requires AutoHotkey v2.0
#SingleInstance Force
#WinActivateForce
#Warn
#MaxThreadsPerHotkey 255
#MaxThreads 255
A_IconTip := "Floating Windows - Dynamic Equilibrium"
ProcessSetPriority("High")
OutputDebug("Script started: FWDE.ahk initialized")

#DllLoad "gdi32.dll"
#DllLoad "user32.dll"
#DllLoad "dwmapi.dll" ; Desktop Composition API
OutputDebug("DLLs loaded: gdi32.dll, user32.dll, dwmapi.dll")

; Pre-allocate memory buffers
global g_NoiseBuffer := Buffer(1024)
global g_PhysicsBuffer := Buffer(4096)
OutputDebug("Memory buffers allocated: NoiseBuffer(1024), PhysicsBuffer(4096)")

global Config := Map(
    "MinMargin", 42,
    "MinGap", 21,
    "ManualGapBonus", 369,
    "AttractionForce", 0.0001,   ; << restore to a small value (not 3.2)
    "RepulsionForce", 0.369,    ; << restore to a small value (not 28)
    "ManualRepulsionMultiplier", 1.3,
    "EdgeRepulsionForce", 0.80,
    "UserMoveTimeout", 11111,        ; How long to keep focused window still after interaction (ms)
    "ManualLockDuration", 33333,     ; How long manual window locks last (ms) - about 33 seconds
    "ResizeDelay", 22,
    "TooltipDuration", 15000,
    "SeamlessMonitorFloat", false,   ; Toggle for seamless multi-monitor floating
    "FloatStyles",  0x00C00000 | 0x00040000 | 0x00080000 | 0x00020000 | 0x00010000,
    "FloatClassPatterns", [
        "Vst.*",         ; VST plugins
        "JS.*",          ; JS plugins
        ".*Plugin.*",    ; Generic plugin windows
        ".*Float.*",     ; Windows with "Float" in class
        ".*Dock.*",      ; Dockable windows
        "#32770",        ; Dialog boxes
        "ConsoleWindowClass"  ; CMD/Console windows
    ],
    "FloatTitlePatterns", [
        "VST.*",        ; VST windows
        "JS:.*",        ; JS effects
        "Plugin",       ; Generic plugins
        ".*FX.*",       ; Effects windows
        "Command Prompt",  ; CMD windows
        "cmd.exe",      ; Alternative CMD title
        "Windows Terminal" ; Windows Terminal
    ],
    "ForceFloatProcesses", [
        "reaper.exe",
        "ableton.exe",
        "flstudio.exe",
        "cubase.exe",
        "studioone.exe",
        "bitwig.exe",
        "protools.exe",
        "cmd.exe",       ; Command Prompt
        "conhost.exe",   ; Console Host
        "WindowsTerminal.exe" ; Windows Terminal
    ],
    "Damping", 0.001,    ; Lower = less friction (0.001-0.01)
    "MaxSpeed", 12.0,    ; Limits maximum velocity
    "PhysicsTimeStep", 1,   ; Lower = more frequent physics updates (1ms is max)
    "VisualTimeStep", 2,    ; Lower = smoother visuals (try 16-33ms for 60-30fps)
    "Smoothing", 0.5,  ; Higher = smoother but more lag (0.9-0.99)
    "Stabilization", Map(
        "MinSpeedThreshold", 0.369,  ; Lower values high-DPI (0.05-0.15) ~ Higher values (0.2-0.5)  low-performance systems
        "EnergyThreshold", 0.06,     ; Lower values (0.05-0.1): Early stabilization, prevents overshooting
        "DampingBoost", 0.12,       ; 0.01-0.05: Subtle braking (smooth stops) ~ 0.1+: Strong braking (quick stops but may feel robotic)
        "OverlapTolerance", 0     ; Zero tolerance for overlaps unless forced by constraints
    ),
    "ManualWindowColor", "FF5555",
    "ManualWindowAlpha", 222,
    "NoiseScale", 888,
    "NoiseInfluence", 100,
    "AnimationDuration", 32,    ; Higher = longer animations (try 16-32)
    "PhysicsUpdateInterval", 200,
)
OutputDebug("Config initialized")

global g := Map(
    "Monitor", Config["SeamlessMonitorFloat"] ? GetVirtualDesktopBounds() : GetCurrentMonitorInfo(),
    "ArrangementActive", true,
    "LastUserMove", 0,
    "ActiveWindow", 0,
    "Windows", [],
    "PhysicsEnabled", true,
    "FairyDustEnabled", true,
    "ManualWindows", Map(),
    "SystemEnergy", 1
)
OutputDebug("Global state 'g' initialized")

; --- Section: NoiseAnimator class ---
; Health: Logic is correct for simplex noise. Debug output is verbose but safe.
; No issues.

class NoiseAnimator {
    static permutations := [151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,190,6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,88,237,149,56,87,174,20,125,136,171,168,68,175,74,165,71,134,139,48,27,166,77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,102,143,54,65,25,63,161,1,216,80,73,209,76,132,187,208,89,18,169,200,196,135,130,116,188,159,86,164,100,109,198,173,186,3,64,52,217,226,250,124,123,5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,223,183,170,213,119,248,152,2,44,154,163,70,221,153,101,155,167,43,172,9,129,22,39,253,19,98,108,110,79,113,224,232,178,185,112,104,218,246,97,228,251,34,242,193,238,210,144,12,191,179,162,241,81,51,145,235,249,14,239,107,49,192,214,31,181,199,106,157,184,84,204,176,115,121,50,45,127,4,150,254,138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180]
    
    static grad3 := [[1,1,0],[-1,1,0],[1,-1,0],[-1,-1,0],[1,0,1],[-1,0,1],[1,0,-1],[-1,0,-1],[0,1,1],[0,-1,1],[0,1,-1],[0,-1,-1]]
    
    static F2 := 0.5*(Sqrt(3)-1)
    static G2 := (3-Sqrt(3))/6
    
    static noise(x, y) {
        OutputDebug("NoiseAnimator.noise called with x: " x ", y: " y)
        s := (x + y) * this.F2
        i := Floor(x + s)
        j := Floor(y + s)
        
        t := (i + j) * this.G2
        X0 := i - t
        Y0 := j - t
        x0 := x - X0
        y0 := y - Y0
        
        i1 := x0 > y0 ? 1 : 0
        j1 := x0 > y0 ? 0 : 1
        
        x1 := x0 - i1 + this.G2
        y1 := y0 - j1 + this.G2
        x2 := x0 - 1 + 2*this.G2
        y2 := y0 - 1 + 2*this.G2
        
        ii := Mod(i, 256) + 1
        jj := Mod(j, 256) + 1
        
        p := this.permutations
        a := p.Has(ii) ? p[ii] : 0
        b := p.Has(jj) ? p[jj] : 0
        aa := p.Has(ii + i1) ? p[ii + i1] : 0
        ab := p.Has(jj + j1) ? p[jj + j1] : 0
        ba := p.Has(ii + 1) ? p[ii + 1] : 0
        bb := p.Has(jj + 1) ? p[jj + 1] : 0
        
        gi0 := Mod(a + b, 12) + 1
        gi1 := Mod(aa + ab, 12) + 1
        gi2 := Mod(ba + bb, 12) + 1
        
        t0 := 0.5 - x0*x0 - y0*y0
        n0 := 0
        if (t0 >= 0) {
            grad := this.grad3.Has(gi0) ? this.grad3[gi0] : [0,0,0]
            n0 := t0**4 * (grad[1]*x0 + grad[2]*y0)
        }
        
        t1 := 0.5 - x1*x1 - y1*y1
        n1 := 0
        if (t1 >= 0) {
            grad := this.grad3.Has(gi1) ? this.grad3[gi1] : [0,0,0]
            n1 := t1**4 * (grad[1]*x1 + grad[2]*y1)
        }
        
        t2 := 0.5 - x2*x2 - y2*y2
        n2 := 0
        if (t2 >= 0) {
            grad := this.grad3.Has(gi2) ? this.grad3[gi2] : [0,0,0]
            n2 := t2**4 * (grad[1]*x2 + grad[2]*y2)
        }
        
        OutputDebug("NoiseAnimator.noise result: " (n0 + n1 + n2))
        return 70*(n0 + n1 + n2)
    }
}

; --- Section: Window Validation ---
; Health: SafeWinExist and IsWindowValid are robust, with error handling and debug output.
; No issues.

SafeWinExist(hwnd) {
    OutputDebug("SafeWinExist called for hwnd: " hwnd)
    try {
        result := WinExist("ahk_id " hwnd)
        OutputDebug("SafeWinExist result: " result)
        return result
    }
    catch {
        OutputDebug("SafeWinExist failed for hwnd: " hwnd)
        return 0
    }
}

IsWindowValid(hwnd) {
    OutputDebug("IsWindowValid called for hwnd: " hwnd)
    try {
        if (!SafeWinExist(hwnd)) {
            OutputDebug("IsWindowValid: hwnd " hwnd " does not exist")
            return false
        }
        try {
            if (WinGetMinMax("ahk_id " hwnd) != 0) {
                OutputDebug("IsWindowValid: hwnd " hwnd " is minimized/maximized")
                return false
            }
        }
        catch {
            OutputDebug("IsWindowValid: WinGetMinMax failed for hwnd " hwnd)
            return false
        }
        try {
            title := WinGetTitle("ahk_id " hwnd)
            if (title == "" || title == "Program Manager") {
                OutputDebug("IsWindowValid: hwnd " hwnd " has invalid title: " title)
                return false
            }
        }
        catch {
            OutputDebug("IsWindowValid: WinGetTitle failed for hwnd " hwnd)
            return false
        }
        try {
            if (WinGetExStyle("ahk_id " hwnd) & 0x80) {
                OutputDebug("IsWindowValid: hwnd " hwnd " is a tool window")
                return false
            }
            if (!(WinGetStyle("ahk_id " hwnd) & 0x10000000)) {
                OutputDebug("IsWindowValid: hwnd " hwnd " is not visible")
                return false
            }
        }
        catch {
            OutputDebug("IsWindowValid: WinGetStyle/ExStyle failed for hwnd " hwnd)
            return false
        }
        OutputDebug("IsWindowValid: hwnd " hwnd " is valid")
        return true
    }
    catch {
        OutputDebug("IsWindowValid: exception for hwnd " hwnd)
        return false
    }
}

; --- Section: Utility Functions ---
; Health: Lerp, EaseOutCubic, ShowTooltip are correct.
; ShowTooltip uses SetTimer for hiding, which is safe.

ObjToText(obj) {
    if Type(obj) == "Map" {
        arr := []
        for k, v in obj
            arr.Push(k ": " v)
        joined := ""
        for i, item in arr
            joined .= (i > 1 ? ", " : "") item
        return "{" joined "}"
    } else if Type(obj) == "Array" {
        joined := ""
        for i, item in obj
            joined .= (i > 1 ? ", " : "") item
        return "[" joined "]"
    } else {
        return obj
    }
}

Lerp(a, b, t) {
    return a + (b - a) * t
}

EaseOutCubic(t) {
    return 1 - (1 - t) ** 3
}

Clamp(val, min, max) {
    return Min(Max(val, min), max)
}

ShowTooltip(text) {
    global g, Config
    OutputDebug("ShowTooltip: " text)
    ToolTip(text, g["Monitor"]["CenterX"] - 100, g["Monitor"]["Top"] + 20)
    SetTimer(() => ToolTip(), -Config["TooltipDuration"])
}

; --- Section: Monitor Info ---
; Health: GetCurrentMonitorInfo, MonitorGetFromPoint, GetPrimaryMonitorCoordinates, GetVirtualDesktopBounds
; All handle errors and fallback correctly. No logic issues.

GetCurrentMonitorInfo() {
    OutputDebug("GetCurrentMonitorInfo called")
    static lastPos := [0, 0], lastMonitor := Map()
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)
    
    if (Abs(mx - lastPos[1]) < 50 && Abs(my - lastPos[2]) < 50 && lastMonitor.Count)
        return lastMonitor
    
    lastPos := [mx, my]
    if (monNum := MonitorGetFromPoint(mx, my)) {
        MonitorGet monNum, &L, &T, &R, &B
        lastMonitor := Map(
            "Left", L, "Right", R, "Top", T, "Bottom", B,
            "Width", R - L, "Height", B - T, "Number", monNum,
            "CenterX", (R + L) // 2, "CenterY", (B + T) // 2
        )
        OutputDebug("GetCurrentMonitorInfo result: " ObjToText(lastMonitor))
        return lastMonitor
    }
    return GetPrimaryMonitorCoordinates()
}

MonitorGetFromPoint(x, y) {
    OutputDebug("MonitorGetFromPoint called with x: " x ", y: " y)
    try {
        Loop MonitorGetCount() {
            MonitorGet A_Index, &L, &T, &R, &B
            if (x >= L && x < R && y >= T && y < B)
                return A_Index
        }
    }
    OutputDebug("MonitorGetFromPoint result: " A_Index)
    return 0
}

GetPrimaryMonitorCoordinates() {
    OutputDebug("GetPrimaryMonitorCoordinates called")
    try {
        primaryNum := MonitorGetPrimary()
        MonitorGet primaryNum, &L, &T, &R, &B
        OutputDebug("GetPrimaryMonitorCoordinates result: " Map("Left", L, "Right", R, "Top", T, "Bottom", B, "Width", R - L, "Height", B - T, "Number", primaryNum, "CenterX", (R + L) // 2, "CenterY", (B + T) // 2))
        return Map(
            "Left", L, "Right", R, "Top", T, "Bottom", B,
            "Width", R - L, "Height", B - T, "Number", primaryNum,
            "CenterX", (R + L) // 2, "CenterY", (B + T) // 2
        )
    }
    catch {
        OutputDebug("GetPrimaryMonitorCoordinates exception")
        return Map(
            "Left", 0, "Right", A_ScreenWidth, "Top", 0, "Bottom", A_ScreenHeight,
            "Width", A_ScreenWidth, "Height", A_ScreenHeight, "Number", 1,
            "CenterX", A_ScreenWidth // 2, "CenterY", A_ScreenHeight // 2
        )
    }
}

GetVirtualDesktopBounds() {
    OutputDebug("GetVirtualDesktopBounds called")
    ; Get the combined bounds of all monitors for seamless floating
    global Config
    
    if (!Config["SeamlessMonitorFloat"]) {
        ; Return current monitor bounds if seamless floating is disabled
        return GetCurrentMonitorInfo()
    }
    
    try {
        minLeft := 999999, maxRight := -999999
        minTop := 999999, maxBottom := -999999
        
        Loop MonitorGetCount() {
            MonitorGet A_Index, &L, &T, &R, &B
            minLeft := Min(minLeft, L)
            maxRight := Max(maxRight, R)
            minTop := Min(minTop, T)
            maxBottom := Max(maxBottom, B)
        }
        
        OutputDebug("GetVirtualDesktopBounds result: " Map("Left", minLeft, "Right", maxRight, "Top", minTop, "Bottom", maxBottom, "Width", maxRight - minLeft, "Height", maxBottom - minTop, "Number", 0, "CenterX", (maxRight + minLeft) // 2, "CenterY", (maxBottom + minTop) // 2))
        return Map(
            "Left", minLeft, "Right", maxRight, "Top", minTop, "Bottom", maxBottom,
            "Width", maxRight - minLeft, "Height", maxBottom - minTop, "Number", 0,
            "CenterX", (maxRight + minLeft) // 2, "CenterY", (maxBottom + minTop) // 2
        )
    }
    catch {
        OutputDebug("GetVirtualDesktopBounds exception")
        ; Fallback to primary monitor
        return GetPrimaryMonitorCoordinates()
    }
}

; --- Section: Window Positioning ---
; Health: FindNonOverlappingPosition, IsOverlapping, IsPluginWindow, IsWindowFloating
; All use robust logic and error handling. No logic issues.

FindNonOverlappingPosition(window, otherWindows, monitor) {
    OutputDebug("FindNonOverlappingPosition called for hwnd: " window["hwnd"])
    if (!IsOverlapping(window, otherWindows))
        return Map("x", window["x"], "y", window["y"])
    
    ; Try multiple positioning strategies for better space utilization
    strategies := ["gaps", "edges", "center", "grid"]
    
    for strategy in strategies {
        candidatePositions := GeneratePositionCandidates(window, otherWindows, monitor, strategy)
        
        for pos in candidatePositions {
            ; Ensure position is within bounds
            if (pos["x"] < monitor["Left"] + Config["MinMargin"] || 
                pos["x"] > monitor["Right"] - window["width"] - Config["MinMargin"] ||
                pos["y"] < monitor["Top"] + Config["MinMargin"] || 
                pos["y"] > monitor["Bottom"] - window["height"] - Config["MinMargin"])
                continue
                
            testPos := Map(
                "x", pos["x"],
                "y", pos["y"],
                "width", window["width"],
                "height", window["height"],
                "hwnd", window["hwnd"]
            )
            
            if (!IsOverlapping(testPos, otherWindows)) {
                OutputDebug("FindNonOverlappingPosition result: x=" pos["x"] ", y=" pos["y"])
                return pos
            }
        }
    }
    
    ; Fallback: slight offset from original position, but clamp to visible area
    fallbackX := Clamp(window["x"] + 20, monitor["Left"] + Config["MinMargin"], monitor["Right"] - window["width"] - Config["MinMargin"])
    fallbackY := Clamp(window["y"] + 20, monitor["Top"] + Config["MinMargin"], monitor["Bottom"] - window["height"] - Config["MinMargin"])
    OutputDebug("FindNonOverlappingPosition fallback result: x=" fallbackX ", y=" fallbackY)
    return Map("x", fallbackX, "y", fallbackY)
}

GeneratePositionCandidates(window, otherWindows, monitor, strategy) {
    candidates := []
    left := monitor["Left"] + Config["MinMargin"]
    right := monitor["Right"] - window["width"] - Config["MinMargin"]
    top := monitor["Top"] + Config["MinMargin"]
    bottom := monitor["Bottom"] - window["height"] - Config["MinMargin"]

    if (strategy == "center") {
        candidates.Push(Map("x", (left + right) // 2, "y", (top + bottom) // 2))
    } else if (strategy == "edges") {
        candidates.Push(Map("x", left, "y", top))
        candidates.Push(Map("x", right, "y", top))
        candidates.Push(Map("x", left, "y", bottom))
        candidates.Push(Map("x", right, "y", bottom))
    } else if (strategy == "grid") {
        gridRows := 3
        gridCols := 3
        for r in gridRows {
            for c in gridCols {
                gx := left + ((right - left) * (c - 1) // (gridCols - 1))
                gy := top + ((bottom - top) * (r - 1) // (gridRows - 1))
                candidates.Push(Map("x", gx, "y", gy))
            }
        }
    } else if (strategy == "gaps") {
        ; Try to find gaps between other windows
        for other in otherWindows {
            candidates.Push(Map("x", other["x"] + other["width"] + Config["MinGap"], "y", other["y"]))
            candidates.Push(Map("x", other["x"], "y", other["y"] + other["height"] + Config["MinGap"]))
        }
    }
    return candidates
}

IsOverlapping(window, otherWindows) {
    OutputDebug("IsOverlapping called for hwnd: " window["hwnd"])
    for other in otherWindows {
        if (window["hwnd"] == other["hwnd"])
            continue
            
        overlapX := Max(0, Min(window["x"] + window["width"], other["x"] + other["width"]) - Max(window["x"], other["x"]))
        overlapY := Max(0, Min(window["y"] + window["height"], other["y"] + other["height"]) - Max(window["y"], other["y"]))
        
        if (overlapX > Config["Stabilization"]["OverlapTolerance"] && overlapY > Config["Stabilization"]["OverlapTolerance"])
            return true
    }
    OutputDebug("IsOverlapping result: false")
    return false
}
IsPluginWindow(hwnd) {
    OutputDebug("IsPluginWindow called for hwnd: " hwnd)
    try {
        winClass := WinGetClass("ahk_id " hwnd)
        title := WinGetTitle("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)
        
        ; Common DAW plugin window classes and patterns
        pluginClasses := [
            "VST", "VSTPlugin", "AudioUnit", "AU", "RTAS", "AAX",
            "ReaperVSTPlugin", "FL_Plugin", "StudioOnePlugin",
            "CubaseVST", "LogicAU", "ProToolsAAX", "Ableton",
            "Qt5QWindowIcon", "Qt6QWindowIcon",  ; Many modern plugins use Qt
            "Vst", "JS", "Plugin", "Float", "Dock"
        ]
        
        pluginTitlePatterns := [
            "VST", "AU", "JS:", "Plugin", "Synth", "Effect", "EQ", "Compressor",
            "Reverb", "Delay", "Filter", "Oscillator", "Sampler", "Drum", "FX",
            "Kontakt", "Massive", "Serum", "Sylenth", "Omnisphere", "Nexus",
            "FabFilter", "Waves", "iZotope", "Native Instruments", "Arturia",
            "U-He", "TAL-", "Valhalla", "SoundToys", "Plugin Alliance"
        ]
        
        ; Check DAW processes first
        dawProcesses := ["reaper", "ableton", "flstudio", "cubase", "studioone", "bitwig", "protools"]
        isDAWProcess := false
        for daw in dawProcesses {
            if (InStr(processName, daw)) {
                isDAWProcess := true
                break
            }
        }
        
        ; If it's from a DAW process, check plugin patterns
        if (isDAWProcess) {
            ; Check window class patterns
            for pattern in pluginClasses {
                if (InStr(winClass, pattern))
                    return true
            }
            
            ; Check window title patterns
            for pattern in pluginTitlePatterns {
                if (InStr(title, pattern))
                    return true
            }
            
            ; Check for small window dimensions typical of plugin UIs
            try {
                WinGetPos(,, &w, &h, "ahk_id " hwnd)
                if (w < 800 && h < 600)
                    return true
            }
        } else {
            ; For non-DAW processes, use basic patterns
            if (winClass ~= "i)(Vst|JS|Plugin|Float|Dock)") 
                return true
            if (title ~= "i)(VST|JS:|Plugin|FX)") 
                return true
        }
        
        OutputDebug("IsPluginWindow result: false")
        return false
    }
    catch {
        OutputDebug("IsPluginWindow exception for hwnd: " hwnd)
        return false
    }
}

IsWindowFloating(hwnd) {
    global Config
    OutputDebug("IsWindowFloating called for hwnd: " hwnd)
    ; Basic window existence check
    if (!SafeWinExist(hwnd))
        return false
        
    try {
        ; Skip minimized/maximized windows
        if (WinGetMinMax("ahk_id " hwnd) != 0)
            return false
            
        ; Get window properties
        title := WinGetTitle("ahk_id " hwnd)
        if (title == "" || title == "Program Manager")
            return false
            
        winClass := WinGetClass("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)
        style := WinGetStyle("ahk_id " hwnd)
        exStyle := WinGetExStyle("ahk_id " hwnd)

        OutputDebug("Window Check - Class: " winClass " | Process: " processName " | Title: " title)

        ; 1. First check for forced processes (simplified)
        for pattern in Config["ForceFloatProcesses"] {
            if (processName ~= "i)^" pattern "$") {  ; Exact match with case insensitivity
                OutputDebug("IsWindowFloating: hwnd " hwnd " matches forced process pattern: " pattern)
                return true
            }
        }

        ; 2. Special cases that should always float
        if (winClass == "ConsoleWindowClass" || winClass == "CASCADIA_HOSTING_WINDOW_CLASS") {
            OutputDebug("IsWindowFloating: hwnd " hwnd " is a console window")
            return true  ; CMD and Windows Terminal
        }
        
        ; 3. Plugin window detection (basic but effective)
        if (winClass ~= "i)(Vst|JS|Plugin|Float)") {
            OutputDebug("IsWindowFloating: hwnd " hwnd " detected as plugin window by class")
            return true
        }
        
        if (title ~= "i)(VST|JS:|Plugin|FX)") {
            OutputDebug("IsWindowFloating: hwnd " hwnd " detected as plugin window by title")
            return true
        }

        ; 4. Standard floating window checks
        if (exStyle & 0x80)  ; WS_EX_TOOLWINDOW
            return true
            
        if (!(style & 0x10000000))  ; WS_VISIBLE
            return true

        ; 5. Check class patterns from config
        for pattern in Config["FloatClassPatterns"] {
            if (winClass ~= "i)" pattern) {
                OutputDebug("IsWindowFloating: hwnd " hwnd " matches class pattern: " pattern)
                return true
            }
        }
        
        ; 6. Check title patterns from config
        for pattern in Config["FloatTitlePatterns"] {
            if (title ~= "i)" pattern) {
                OutputDebug("IsWindowFloating: hwnd " hwnd " matches title pattern: " pattern)
                return true
            }
        }
        
        ; 7. Final style check
        result := (style & Config["FloatStyles"]) != 0
        OutputDebug("IsWindowFloating result: " result)
        return result
    }
    catch {
        OutputDebug("IsWindowFloating exception for hwnd: " hwnd)
        return false
    }
}



GetVisibleWindows(monitor) {
    global Config, g
    OutputDebug("GetVisibleWindows called for monitor: " monitor)
    WinList := []
    allWindows := []
    for hwnd in WinGetList() {
        try {
            ; Skip invalid windows
            if (!IsWindowValid(hwnd))
                continue
                
            ; Get window properties
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            if (w == 0 || h == 0)
                continue
                
            ; Special handling for plugin windows
            isPlugin := IsPluginWindow(hwnd)
            
            ; Force include plugin windows or check floating status
            if (isPlugin || IsWindowFloating(hwnd)) {
                allWindows.Push(Map(
                    "hwnd", hwnd,
                    "x", x, "y", y,
                    "width", w, "height", h,
                    "isPlugin", isPlugin,
                    "lastSeen", A_TickCount
                ))
            }
        }
        catch {
            continue
        }
    }
    
    ; Get current mouse position for monitor check
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)
    activeMonitor := MonitorGetFromPoint(mx, my)
    
    for window in allWindows {
        try {
            winCenterX := window["x"] + window["width"]/2
            winCenterY := window["y"] + window["height"]/2
            
            ; Determine which monitor the window is on
            winMonitor := MonitorGetFromPoint(winCenterX, winCenterY)
            try {
                MonitorGet winMonitor, &mL, &mT, &mR, &mB
            }
            catch {
                ; Fallback to primary monitor if detection fails
                winMonitor := MonitorGetPrimary()
                MonitorGet winMonitor, &mL, &mT, &mR, &mB
            }
            
            ; Check if window should be included based on floating mode
            includeWindow := false
            
            if (Config["SeamlessMonitorFloat"]) {
                ; In seamless mode, include all windows from all monitors
                includeWindow := true
            } else {
                ; In traditional mode, only include windows on current monitor or already tracked
                isTracked := false
                for trackedWin in g["Windows"] {
                    if (trackedWin["hwnd"] == window["hwnd"]) {
                        isTracked := true
                        break
                    }
                }
                includeWindow := (winMonitor == monitor["Number"] || isTracked || window["isPlugin"])
            }
            
            if (includeWindow) {
                ; Apply margin constraints based on floating mode
                if (Config["SeamlessMonitorFloat"]) {
                    ; Use virtual desktop bounds for seamless floating
                    virtualBounds := GetVirtualDesktopBounds()
                    window["x"] := Clamp(window["x"], virtualBounds["Left"] + Config["MinMargin"], virtualBounds["Right"] - window["width"] - Config["MinMargin"])
                    window["y"] := Clamp(window["y"], virtualBounds["Top"] + Config["MinMargin"], virtualBounds["Bottom"] - window["height"] - Config["MinMargin"])
                } else {
                    ; Apply margin constraints for current monitor
                    window["x"] := Clamp(window["x"], mL + Config["MinMargin"], mR - window["width"] - Config["MinMargin"])
                    window["y"] := Clamp(window["y"], mT + Config["MinMargin"], mB - window["height"] - Config["MinMargin"])
                }
                
                ; Find existing window data if available
                existingWin := 0
                for win in g["Windows"] {
                    if (win["hwnd"] == window["hwnd"]) {
                        existingWin := win
                        break
                    }
                }
                
                ; Create window entry with physics properties
                WinList.Push(Map(
                    "hwnd", window["hwnd"], 
                    "x", window["x"], "y", window["y"],
                    "width", window["width"], "height", window["height"],
                    "area", window["width"] * window["height"],
                    "mass", window["width"] * window["height"] / 100000,
                    "lastMove", existingWin ? existingWin["lastMove"] : 0,
                    "vx", existingWin ? existingWin["vx"] : 0,
                    "vy", existingWin ? existingWin["vy"] : 0,
                    "targetX", window["x"], "targetY", window["y"],
                    "monitor", winMonitor,
                    "isPlugin", window["isPlugin"],
                    "lastSeen", window["lastSeen"],
                    "lastZOrder", existingWin ? existingWin.Get("lastZOrder", -1) : -1  ; Cache z-order state
                ))
                
                ; Add time-phasing echo for plugin windows
                if (window["isPlugin"] && g["FairyDustEnabled"]) {
                    TimePhasing.AddEcho(window["hwnd"])
                }
            }
        }
        catch {
            continue
        }
    }
    
    ; Clean up windows that are no longer valid
    CleanupStaleWindows()
    
    OutputDebug("GetVisibleWindows result: " WinList.Length " windows found")
    return WinList
}

CleanupStaleWindows() {
    global g
    OutputDebug("CleanupStaleWindows called")
    threshold := 5000 ; 5 seconds
    
    ; Use a while loop instead of for-loop with index to avoid 'i' variable issues
    index := g["Windows"].Length
    while (index >= 1) {
        win := g["Windows"][index]
        if (A_TickCount - win["lastSeen"] > threshold && !SafeWinExist(win["hwnd"])) {
            g["Windows"].RemoveAt(index)
            if (g["ManualWindows"].Has(win["hwnd"])) {
                RemoveManualWindowBorder(win["hwnd"])
            }
        }
        index--
    }
    OutputDebug("CleanupStaleWindows completed")
}

RemoveManualWindowBorder(hwnd) {
    OutputDebug("RemoveManualWindowBorder called for hwnd: " hwnd)
    ; Implement border removal logic here if needed, or leave empty if not required
    ; Example: Remove any custom border overlays or reset window style
    ; This is a stub to prevent compile errors
    return
}

; --- Section: TimePhasing class ---
; Health: Handles echo effects for plugin windows. Cleanup and update logic is correct.

class TimePhasing {
    static echoes := Map()
    static lastCleanup := 0

    static AddEcho(hwnd) {
        OutputDebug("TimePhasing.AddEcho called for hwnd: " hwnd)
        if (!SafeWinExist(hwnd))
            return

        if (!this.echoes.Has(hwnd)) {
            this.echoes[hwnd] := {
                phases: [],
                lastUpdate: 0
            }
        }

        if (A_TickCount - this.echoes[hwnd].lastUpdate < 500)
            return
            
        try {
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            this.echoes[hwnd].lastUpdate := A_TickCount

            ; Create temporal echo phases
            phases := []
            phaseCount := Random(3, 6)
            Loop phaseCount {
                timeOffset := A_Index * Random(100, 300)
                opacity := Random(30, 80) / A_Index
                phases.Push({
                    timeOffset: timeOffset,
                    opacity: opacity,
                    life: Random(20, 40)
                })
            }
            this.echoes[hwnd].phases := phases
        }
        catch {
            return
        }
        
        if (A_TickCount - this.lastCleanup > 2000) {
            this.CleanupEffects()
            this.lastCleanup := A_TickCount
        }
        OutputDebug("TimePhasing.AddEcho completed for hwnd: " hwnd)
    }

    static UpdateEchoes() {
        OutputDebug("TimePhasing.UpdateEchoes called")
        for hwnd, data in this.echoes.Clone() {
            try {
                if (!SafeWinExist(hwnd)) {
                    if (this.echoes.Has(hwnd))
                        this.echoes.Delete(hwnd)
                    continue
                }

                ; Update phase lifetimes
                for phase in data.phases {
                    phase.life--
                }
                
                ; Remove expired phases
                data.phases := data.phases.Filter(p => p.life > 0)
            }
            catch {
                this.echoes.Delete(hwnd)
                continue
            }
        }
        OutputDebug("TimePhasing.UpdateEchoes completed")
    }

    static CleanupEffects() {
        OutputDebug("TimePhasing.CleanupEffects called")
        for hwnd, data in this.echoes.Clone() {
            if (!this.echoes.Has(hwnd))
                continue
            try {
                if (!SafeWinExist(hwnd) || data.phases.Length == 0) {
                    if (this.echoes.Has(hwnd))
                        this.echoes.Delete(hwnd)
                }
            }
            catch {
                if (this.echoes.Has(hwnd))
                    this.echoes.Delete(hwnd)
            }
        }
        OutputDebug("TimePhasing.CleanupEffects completed")
    }
}

CreateBlurBehindStruct() {
    OutputDebug("CreateBlurBehindStruct called")
    bb := Buffer(20)
    NumPut("UInt", 1, bb, 0)
    NumPut("Int", 1, bb, 4)
    NumPut("Ptr", 0, bb, 8)
    NumPut("Int", 0, bb, 16)
    OutputDebug("CreateBlurBehindStruct completed")
    return bb.Ptr
}

ApplyStabilization(win) {
    OutputDebug("ApplyStabilization called for hwnd: " win["hwnd"])
    static velocityBuffers := Map()
    
    ; Initialize velocity buffer if needed
    if (!velocityBuffers.Has(win["hwnd"])) {
        velocityBuffers[win["hwnd"]] := []
    }
    buf := velocityBuffers[win["hwnd"]]
    
    ; Store current velocity
    buf.Push(Map("vx", win["vx"], "vy", win["vy"]))
    if (buf.Length > 5) {
        buf.RemoveAt(1)
    }
    
    ; Calculate averaged velocity
    avgVx := 0, avgVy := 0
    for frame in buf {
        avgVx += frame["vx"]
        avgVy += frame["vy"]
    }
    avgVx /= buf.Length
    avgVy /= buf.Length
    avgSpeed := Sqrt(avgVx**2 + avgVy**2)
    
    minThreshold := Config["Stabilization"]["MinSpeedThreshold"]
    
    ; Apply smoothed damping
    if (avgSpeed < minThreshold * 2) {
        ; Smooth transition curve
        t := Min(1, avgSpeed / (minThreshold * 2))
        stabilityFactor := EaseOutCubic(t)
        
        ; Interpolate between boosted damping and normal damping
        currentDamping := Lerp(Config["Damping"] - Config["Stabilization"]["DampingBoost"], 
                          Config["Damping"], 
                          stabilityFactor)
        
        win["vx"] *= currentDamping
        win["vy"] *= currentDamping
        
        ; Gradual stop when very slow
        if (avgSpeed < 0.1) {
            stopFactor := EaseOutCubic(avgSpeed/0.1)
            win["vx"] *= stopFactor
            win["vy"] *= stopFactor
        }
    } else {
        win["vx"] *= Config["Damping"]
        win["vy"] *= Config["Damping"]
    }
    
    ; Snap to target if very close and slow
    if (avgSpeed < 0.05 && 
        Abs(win["x"] - win["targetX"]) < 0.5 && 
        Abs(win["y"] - win["targetY"]) < 0.5) {
        win["x"] := win["targetX"]
        win["y"] := win["targetY"]
        win["vx"] := 0
        win["vy"] := 0
    }
    OutputDebug("ApplyStabilization completed for hwnd: " win["hwnd"])
}

CalculateWindowForces(win, allWindows) {
    global g, Config
    OutputDebug("CalculateWindowForces called for hwnd: " win["hwnd"])
    ; Keep active window and recently moved windows still
    isActiveWindow := (win["hwnd"] == g["ActiveWindow"])
    isRecentlyMoved := (A_TickCount - g["LastUserMove"] < Config["UserMoveTimeout"])
    isCurrentlyFocused := (win["hwnd"] == WinExist("A"))
    isManuallyLocked := (win.Has("ManualLock") && A_TickCount < win["ManualLock"])
    
    if (isActiveWindow || isRecentlyMoved && isCurrentlyFocused || isManuallyLocked) {
        win["vx"] := 0
        win["vy"] := 0
        OutputDebug("CalculateWindowForces: hwnd " win["hwnd"] " is active/recently moved/locked, forces set to 0")
        return
    }

    ; Predeclare monitor bounds to avoid local variable warning
    mL := 0, mT := 0, mR := A_ScreenWidth, mB := A_ScreenHeight
    
    if (Config["SeamlessMonitorFloat"]) {
        ; Use virtual desktop bounds for seamless multi-monitor floating
        virtualBounds := GetVirtualDesktopBounds()
        mL := virtualBounds["Left"]
        mT := virtualBounds["Top"] 
        mR := virtualBounds["Right"]
        mB := virtualBounds["Bottom"]
    } else {
        ; Use current monitor bounds for traditional single-monitor floating
        try {
            MonitorGet win["monitor"], &mL, &mT, &mR, &mB
        }
    }

    monLeft := mL
    monRight := mR - win["width"]
    monTop := mT + Config["MinMargin"]
    monBottom := mB - Config["MinMargin"] - win["height"]

    prev_vx := win.Has("vx") ? win["vx"] : 0
    prev_vy := win.Has("vy") ? win["vy"] : 0
    
    wx := win["x"] + win["width"]/2
    wy := win["y"] + win["height"]/2
    
    ; Very weak gravitational pull toward center (space-like)
    dx := (mL + mR)/2 - wx
    dy := (mT + mB)/2 - wy
    centerDist := Sqrt(dx*dx + dy*dy)
    
    ; Gentle center attraction with distance falloff - stronger for equilibrium
    if (centerDist > 100) {  ; Reduced threshold for earlier attraction
        attractionScale := Min(0.25, centerDist/1200)  ; Stronger attraction (was 0.15 and /1500)
        vx := prev_vx * 0.98 + dx * Config["AttractionForce"] * 0.08 * attractionScale  ; Increased from 0.05
        vy := prev_vy * 0.98 + dy * Config["AttractionForce"] * 0.08 * attractionScale
    } else {
        vx := prev_vx * 0.995  ; Slightly more damping near center
        vy := prev_vy * 0.995
    }
    
    ; Space-seeking behavior: move toward empty areas when crowded
    spaceForce := Map("vx", 0, "vy", 0)
    ; Space-seeking force: move toward less crowded regions
    emptyX := 0, emptyY := 0, emptyCount := 0
    wx := win["x"] + win["width"]/2
    wy := win["y"] + win["height"]/2
    for other in allWindows {
        if (other == win)
            continue
        ox := other["x"] + other["width"]/2
        oy := other["y"] + other["height"]/2
        dist := Sqrt((wx - ox)**2 + (wy - oy)**2)
        if (dist > 300) { ; Only consider windows far enough away
            emptyX += ox
            emptyY += oy
            emptyCount++
        }
    }
    if (emptyCount > 0) {
        avgX := emptyX / emptyCount
        avgY := emptyY / emptyCount
        ; Seek away from the average position of distant windows (toward emptier space)
        spaceVx := (wx - avgX)
        spaceVy := (wy - avgY)
        norm := Sqrt(spaceVx**2 + spaceVy**2)
        if (norm > 0) {
            spaceForce["vx"] := spaceVx / norm
            spaceForce["vy"] := spaceVy / norm
        }
    }
    if (spaceForce.Count > 0) {
        vx += spaceForce["vx"] * 0.02  ; Small but persistent force toward empty space
        vy += spaceForce["vy"] * 0.02
    }
    
    ; Soft edge boundaries (like invisible force fields)
    edgeBuffer := 50
    if (win["x"] < monLeft + edgeBuffer) {
        push := (monLeft + edgeBuffer - win["x"]) * 0.01
        vx += push
    }
    if (win["x"] > monRight - edgeBuffer) {
        push := (win["x"] - (monRight - edgeBuffer)) * 0.01
        vx -= push
    }
    if (win["y"] < monTop + edgeBuffer) {
        push := (monTop + edgeBuffer - win["y"]) * 0.01
        vy += push
    }
    if (win["y"] > monBottom - edgeBuffer) {
        push := (win["y"] - (monBottom - edgeBuffer)) * 0.01
        vy -= push
    }
    
    ; Dynamic inter-window forces (no grid constraints)
    for other in allWindows {
        if (other == win || other["hwnd"] == g["ActiveWindow"])
            continue
        
        ; Calculate distance between window centers
        otherX := other["x"] + other["width"]/2
        otherY := other["y"] + other["height"]/2
        dx := wx - otherX
        dy := wy - otherY
        dist := Max(Sqrt(dx*dx + dy*dy), 1)
        
        ; Dynamic interaction range based on window sizes
        interactionRange := Sqrt(win["width"] * win["height"] + other["width"] * other["height"]) / 4  ; Reduced from /3 for tighter zones
        
        ; Smaller windows get proportionally larger interaction zones
        sizeBonus := Max(1, 200 / Min(win["width"], win["height"]))  ; Boost for small windows
        interactionRange *= sizeBonus
        
        if (dist < interactionRange * 1.2) {  ; Expanded repulsion zone from 0.8 to 1.2
            ; Close range: much stronger repulsion to prevent prolonged overlap
            repulsionForce := Config["RepulsionForce"] * (interactionRange * 1.2 - dist) / (interactionRange * 1.2)
            repulsionForce *= (other.Has("IsManual") ? Config["ManualRepulsionMultiplier"] : 1)
            
            ; Progressive force scaling - stronger when closer
            proximityMultiplier := 1 + (1 - dist / (interactionRange * 1.2)) * 2  ; Up to 3x stronger when very close
            
            vx += dx * repulsionForce * proximityMultiplier / dist * 0.6  ; Increased from 0.4
            vy += dy * repulsionForce * proximityMultiplier / dist * 0.6
        } else if (dist < interactionRange * 3) {  ; Reduced attraction range for tighter equilibrium
            ; Medium range: gentle attraction for stable clustering
            attractionForce := Config["AttractionForce"] * 0.012 * (dist - interactionRange) / interactionRange  ; Increased from 0.005
            
            vx -= dx * attractionForce / dist * 0.04  ; Increased from 0.02
            vy -= dy * attractionForce / dist * 0.04
        }
    }
    
    ; Space-like momentum with equilibrium-seeking damping
    vx *= 0.994  ; Slightly more friction for settling
    vy *= 0.994
    
    ; Floating speed limits (balanced for equilibrium)
    maxFloatSpeed := Config["MaxSpeed"] * 2.0  ; Reduced from 2.5
    vx := Min(Max(vx, -maxFloatSpeed), maxFloatSpeed)
    vy := Min(Max(vy, -maxFloatSpeed), maxFloatSpeed)
    
    ; Progressive stabilization based on speed
    if (Abs(vx) < 0.15 && Abs(vy) < 0.15) {  ; Increased threshold for earlier settling
        vx *= 0.88  ; Stronger dampening when slow for equilibrium
        vy *= 0.88
    }
    
    win["vx"] := vx
    win["vy"] := vy
    
    ; Calculate target position
    win["targetX"] := win["x"] + win["vx"]
    win["targetY"] := win["y"] + win["vy"]
    
    ; Apply bounds
    win["targetX"] := Max(monLeft, Min(win["targetX"], monRight))
    win["targetY"] := Max(monTop, Min(win["targetY"], monBottom))
}

Bezier3(p0, p1, p2, p3, t) {
    a := Lerp(p0, p1, t)
    b := Lerp(p1, p2, t)
    c := Lerp(p2, p3, t)
    d := Lerp(a, b, t)
    e := Lerp(b, c, t)
    return Lerp(d, e, t)
}

SmoothStep(t) {
    return t * t * (3 - 2 * t)
}

ApplyWindowMovements() {
    global g, Config
    OutputDebug("ApplyWindowMovements called")
    static lastUpdate := 0
    static lastPositions := Map()
    static smoothPos := Map()

    Critical

    now := A_TickCount
    frameTime := now - lastUpdate
    lastUpdate := now

    ; --- Add debug to confirm physics and arrangement are enabled ---
    if (!g["ArrangementActive"] || !g["PhysicsEnabled"]) {
        OutputDebug("ApplyWindowMovements: Arrangement or Physics is disabled")
        return
    }

    moveBatch := []
    movedAny := false

    for win in g["Windows"] {
        if (win["hwnd"] == g["ActiveWindow"])
            continue

        ; --- Add debug to check if window is locked ---
        if (win.Has("ManualLock") && A_TickCount < win["ManualLock"]) {
            OutputDebug("ApplyWindowMovements: Window " win["hwnd"] " is locked, skipping movement")
            continue
        }

        hwnd := win["hwnd"]
        ; Initialize smooth position if not present
        if (!smoothPos.Has(hwnd)) {
            smoothPos[hwnd] := { x: win["x"], y: win["y"] }
        }
        ; Track current window position for movement threshold
        hwndPos := Map()
        hwndPos[hwnd] := { x: win["x"], y: win["y"] }
        newX := win["targetX"]
        newY := win["targetY"]

        ; Get monitor bounds for this window
        monLeft := 0, monRight := A_ScreenWidth, monTop := 0, monBottom := A_ScreenHeight
        if (Config["SeamlessMonitorFloat"]) {
            bounds := GetVirtualDesktopBounds()
            monLeft := bounds["Left"]
            monRight := bounds["Right"] - win["width"]
            monTop := bounds["Top"]
            monBottom := bounds["Bottom"] - win["height"]
        } else {
            try {
            MonitorGet win["monitor"], &mL, &mT, &mR, &mB
            monLeft := mL
            monRight := mR - win["width"]
            monTop := mT
            monBottom := mB - win["height"]
            }
        }
        
        ; Space-like smooth movement (balanced for equilibrium)
        alpha := 0.35  ; Higher value = faster convergence to target positions
        smoothPos[hwnd].x := smoothPos[hwnd].x + (newX - smoothPos[hwnd].x) * alpha
        smoothPos[hwnd].y := smoothPos[hwnd].y + (newY - smoothPos[hwnd].y) * alpha

        ; Gentle boundary enforcement (soft collision with edges)
        edgeBuffer := 20
        if (smoothPos[hwnd].x < monLeft + edgeBuffer) {
            resistance := (monLeft + edgeBuffer - smoothPos[hwnd].x) / edgeBuffer
            smoothPos[hwnd].x := Lerp(smoothPos[hwnd].x, monLeft + edgeBuffer, resistance * 0.1)
        } else if (smoothPos[hwnd].x > monRight - edgeBuffer) {
            resistance := (smoothPos[hwnd].x - (monRight - edgeBuffer)) / edgeBuffer
            smoothPos[hwnd].x := Lerp(smoothPos[hwnd].x, monRight - edgeBuffer, resistance * 0.1)
        }
        
        if (smoothPos[hwnd].y < monTop + edgeBuffer) {
            resistance := (monTop + edgeBuffer - smoothPos[hwnd].y) / edgeBuffer
            smoothPos[hwnd].y := Lerp(smoothPos[hwnd].y, monTop + edgeBuffer, resistance * 0.1)
        } else if (smoothPos[hwnd].y > monBottom - edgeBuffer) {
            resistance := (smoothPos[hwnd].y - (monBottom - edgeBuffer)) / edgeBuffer
            smoothPos[hwnd].y := Lerp(smoothPos[hwnd].y, monBottom - edgeBuffer, resistance * 0.1)
        }

        ; Final hard clamp (fallback only)
        smoothPos[hwnd].x := Max(monLeft, Min(smoothPos[hwnd].x, monRight))
        smoothPos[hwnd].y := Max(monTop, Min(smoothPos[hwnd].y, monBottom))

        if (!lastPositions.Has(hwnd))
            lastPositions[hwnd] := { x: hwndPos[hwnd].x, y: hwndPos[hwnd].y }

        ; More sensitive movement threshold for floating feel
        if (Abs(smoothPos[hwnd].x - lastPositions[hwnd].x) >= 0.2 || Abs(smoothPos[hwnd].y - lastPositions[hwnd].y) >= 0.2) {
            moveBatch.Push({ hwnd: hwnd, x: smoothPos[hwnd].x, y: smoothPos[hwnd].y })
            lastPositions[hwnd].x := smoothPos[hwnd].x
            lastPositions[hwnd].y := smoothPos[hwnd].y
            win["x"] := smoothPos[hwnd].x
            win["y"] := smoothPos[hwnd].y
            movedAny := true
        }
    }

    for move in moveBatch {
        try WinMove(move.hwnd, , move.x, move.y)
    }

    ; --- Add debug if no windows moved ---
    if (!movedAny) {
        OutputDebug("ApplyWindowMovements: No windows moved in this frame")
        ; --- Fallback: forcibly enable arrangement and physics if stuck ---
        if (!g["ArrangementActive"] || !g["PhysicsEnabled"]) {
            g["ArrangementActive"] := true
            g["PhysicsEnabled"] := true
            OutputDebug("ApplyWindowMovements: Forcing ArrangementActive and PhysicsEnabled ON")
            SetTimer(CalculateDynamicLayout, Config["PhysicsTimeStep"])
            SetTimer(ApplyWindowMovements, Config["VisualTimeStep"])
        }
    }
}

; --- Add missing CalculateDynamicLayout function ---
CalculateDynamicLayout() {
    ; Placeholder implementation, add your layout calculation logic here
    OutputDebug("CalculateDynamicLayout called")
    ; Example: update window physics and layout
    global g, Config
    for win in g["Windows"] {
        CalculateWindowForces(win, g["Windows"])
        ApplyStabilization(win)
    }
}