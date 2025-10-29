#Warn
#MaxThreadsPerHotkey 255
#MaxThreads 255
ProcessSetPriority("High")
#DllLoad "gdi32.dll"
#DllLoad "user32.dll"
; Pre-allocate memory buffers
#DllLoad "dwmapi.dll" ; Desktop Composition API



; Pre-allocate memory buffers
global DebugMode := true
global g_NoiseBuffer := Buffer(1024)
global g_PhysicsBuffer := Buffer(4096)

; This script is the brainchild of:
; Human: Flalaski,
; AI: DeepSeek+Gemini+CoPilot,
; Lots of back & forth, toss around, backups & redo's,
; until finally I (the human) got this to do what I've been trying to find as a software.
; Hope it's helpful! ♥
;
; NEW FEATURE: Seamless Multi-Monitor Floating
; Toggle with Ctrl+Alt+M to allow windows to float freely across all monitors
; When enabled, windows are no longer confined to the current monitor boundaries

global Config := Map(
    "MinMargin", 2,  ; Reduced to allow windows closer to screen edges
    "MinGap", 21,
    "ManualGapBonus", 369,
    "AttractionForce", 0.00005,   ; Reduced to allow more spreading
    "RepulsionForce", 0.8,       ; Increased to push windows further apart
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
        "ConsoleWindowClass",  ; CMD/Console windows
        "TextToSpeechWndClass", ; <-- Added for speak.exe main window
        "MozillaWindowClass",  ; Firefox browser
        "Chrome_WidgetWin_1",  ; Chrome browser
        "ApplicationFrameWindow", ; Edge/UWP apps
        "SunAwtFrame",          ; Java applications
        "Notepad",              ; Notepad
        "Notepad++",            ; Notepad++
        "Code.exe",             ; VS Code
        "Cursor.exe",           ; Cursor
        "devenv.exe",           ; Visual Studio
        "XamlExplorerHost",     ; XAML applications
        "CabinetWClass",        ; File Explorer
        "OpusApp",              ; Microsoft Word
        "XLMAIN",               ; Microsoft Excel
        "PPTFrameClass",        ; Microsoft PowerPoint
        "rctrl_renwnd32"        ; Microsoft Outlook
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
        "WindowsTerminal.exe", ; Windows Terminal
        "DTDEMO.exe",       ; Dectalk TTS
        "speak.exe",     ; legacy speak.exe
        "speak",         ; legacy speak
        "speak.EXE",     ; <-- Added for uppercase variant
        "firefox.exe",   ; Firefox browser
        "chrome.exe",    ; Chrome browser
        "msedge.exe",    ; Edge browser
        "code.exe",      ; VS Code
        "cursor.exe",    ; Cursor editor
        "notepad.exe",   ; Notepad
        "notepad++.exe", ; Notepad++
        "devenv.exe",    ; Visual Studio
        "explorer.exe",  ; File Explorer
        "winword.exe",   ; Microsoft Word
        "excel.exe",     ; Microsoft Excel
        "powerpnt.exe",  ; Microsoft PowerPoint
        "outlook.exe"    ; Microsoft Outlook
    ],
    "Damping", 0.001,    ; Lower = less friction (0.001-0.01)
    "MaxSpeed", 12.0,    ; Limits maximum velocity
    "PhysicsTimeStep", 1,   ; Lower = more frequent physics updates (1ms is max)
    "VisualTimeStep", 16,    ; Lower = smoother visuals (16ms = 60fps, 33ms = 30fps)
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
    "PhysicsUpdateInterval", 1000,
    "ManualRepulsionMultiplier", 1.0
)

global g := Map(
    "Monitor", Config["SeamlessMonitorFloat"] ? GetVirtualDesktopBounds() : GetCurrentMonitorInfo(),
    "ArrangementActive", true,  ; Arrangement ON by default
    "LastUserMove", 0,
    "ActiveWindow", 0,
    "Windows", [],
    "PhysicsEnabled", true,
    "FairyDustEnabled", true,
    "TimePhasingConfig", Map(
        "MaxEchoesPerWindow", 5,
        "NoiseCloudDensity", 25,
        "EffectUpdateFrequency", 16,  ; 60fps for effects
        "EchoLifeRange", [20, 40],
        "NoiseScale", 0.05,
        "VisualQuality", "high",  ; "low", "medium", "high"
        "EnableParticleTrails", true,
        "TrailLength", 120,
        "EnableColorShifting", true,
        "EnableGlowEffects", true
    ),
    "ManualWindows", Map(),
    "SystemEnergy", 1
)
#Requires AutoHotkey v2.0

; --- Ensure arrangement timers start if ArrangementActive is true ---
if (g["ArrangementActive"]) {
    SetTimer(CalculateDynamicLayout, Config["PhysicsTimeStep"])
    SetTimer(ApplyWindowMovements, Config["VisualTimeStep"])
}

class NoiseAnimator {
    static permutations := [151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,190,6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,88,237,149,56,87,174,20,125,136,171,168,68,175,74,165,71,134,139,48,27,166,77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,102,143,54,65,25,63,161,1,216,80,73,209,76,132,187,208,89,18,169,200,196,135,130,116,188,159,86,164,100,109,198,173,186,3,64,52,217,226,250,124,123,5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,223,183,170,213,119,248,152,2,44,154,163,70,221,153,101,155,167,43,172,9,129,22,39,253,19,98,108,110,79,113,224,232,178,185,112,104,218,246,97,228,251,34,242,193,238,210,144,12,191,179,162,241,81,51,145,235,249,14,239,107,49,192,214,31,181,199,106,157,184,84,204,176,115,121,50,45,127,4,150,254,138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180]


    static grad3 := [[1,1,0],[-1,1,0],[1,-1,0],[-1,-1,0],[1,0,1],[-1,0,1],[1,0,-1],[-1,0,-1],[0,1,1],[0,-1,1],[0,1,-1],[0,-1,-1]]

    static F2 := 0.5*(Sqrt(3)-1)
    static G2 := (3-Sqrt(3))/6
#Requires AutoHotkey v2.0

    static noise(x, y) {
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

        return 70*(n0 + n1 + n2)
    }
}

; Duplicate SafeWinExist definition removed to fix function conflict error.

; Duplicate IsWindowValid definition removed to fix function conflict error.


; Duplicate EaseOutCubic removed to fix function conflict error.


; Duplicate GetCurrentMonitorInfo() removed to fix function conflict error.

; Duplicate MonitorGetFromPoint definition removed to fix function conflict error.

; Duplicate GetPrimaryMonitorCoordinates() removed to fix function conflict error.

; [REMOVED DUPLICATE] GetVirtualDesktopBounds() function definition removed to resolve conflict.

; [REMOVED DUPLICATE] FindNonOverlappingPosition function definition removed to resolve conflict.

; [REMOVED DUPLICATE] IsOverlapping function definition removed to resolve conflict.
; [REMOVED DUPLICATE] IsPluginWindow function definition removed to resolve conflict.

; [REMOVED DUPLICATE] IsWindowFloating function definition removed to resolve conflict.



; [REMOVED DUPLICATE] GetVisibleWindows function definition removed to resolve conflict.

; [REMOVED DUPLICATE] CleanupStaleWindows function definition removed to resolve conflict.

; [REMOVED DUPLICATE] TimePhasing class definition removed to resolve conflict.

SafeWinExist(hwnd) {
    try {
        return WinExist("ahk_id " hwnd)
    }
    catch {
        return 0
    }
}

IsFullscreenWindow(hwnd) {
    try {
        if (!SafeWinExist(hwnd))
            return false

        ; Get window position and size
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        if (w == 0 || h == 0)
            return false

        ; Get monitor bounds for the window
        winCenterX := x + w/2
        winCenterY := y + h/2
        monNum := MonitorGetFromPoint(winCenterX, winCenterY)
        if (!monNum) {
            ; Fallback to primary monitor
            monNum := MonitorGetPrimary()
        }
        
        try {
            MonitorGet monNum, &mL, &mT, &mR, &mB
        }
        catch {
            ; Fallback to screen dimensions
            mL := 0
            mT := 0
            mR := A_ScreenWidth
            mB := A_ScreenHeight
        }

        ; Check window properties
        winClass := WinGetClass("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)
        title := WinGetTitle("ahk_id " hwnd)
        
        ; Skip normal browser windows and common applications that should be manageable
        ; These are NOT considered fullscreen even if they cover the screen
        manageableClasses := [
            "MozillaWindowClass",        ; Firefox
            "Chrome_WidgetWin_1",        ; Chrome
            "ApplicationFrameWindow",    ; Edge/UWP apps
            "SunAwtFrame",              ; Java applications
            "Notepad",                  ; Notepad
            "Notepad++",                ; Notepad++
            "Code.exe",                 ; VS Code
            "Cursor.exe",               ; Cursor
            "devenv.exe",               ; Visual Studio
            "XamlExplorerHost",         ; XAML applications
            "CabinetWClass",            ; File Explorer
            "WorkerW",                  ; Desktop windows
            "Progman"                   ; Program Manager
        ]
        
        manageableProcesses := [
            "firefox.exe", "chrome.exe", "msedge.exe", "code.exe", "cursor.exe",
            "notepad.exe", "notepad++.exe", "devenv.exe", "explorer.exe",
            "winword.exe", "excel.exe", "powerpnt.exe", "outlook.exe"
        ]
        
        ; Check if this is a manageable window (not fullscreen)
        for pattern in manageableClasses {
            if (winClass == pattern)
                return false  ; This is a manageable window, not fullscreen
        }
        
        for pattern in manageableProcesses {
            if (InStr(processName, pattern))
                return false  ; This is a manageable process, not fullscreen
        }

        ; Check for actual fullscreen indicators
        try {
            style := WinGetStyle("ahk_id " hwnd)
            exStyle := WinGetExStyle("ahk_id " hwnd)
            
            ; Check for WS_POPUP style (common in fullscreen apps)
            isPopup := (style & 0x80000000) != 0
            
            ; Check for WS_EX_TOPMOST (many fullscreen apps use this)
            isTopmost := (exStyle & 0x8) != 0
            
            ; True fullscreen applications
            fullscreenClasses := [
                "UnityWndClass",      ; Unity games
                "UnrealWindow",       ; Unreal Engine games
                "Valve001",           ; Source games
                "SDL_app",            ; SDL applications
                "GLUT",               ; OpenGL applications
                "d3d",                ; DirectX applications
                "D3D"                 ; DirectX applications
            ]
            
            fullscreenProcesses := [
                "steam.exe", "steamwebhelper.exe",
                "vlc.exe", "mpc-hc.exe", "potplayer.exe",
                "obs64.exe", "obs32.exe", "streamlabs obs.exe"
            ]
            
            ; Check for actual fullscreen class patterns
            for pattern in fullscreenClasses {
                if (winClass == pattern)
                    return true
            }
            
            ; Check for actual fullscreen process patterns
            for pattern in fullscreenProcesses {
                if (InStr(processName, pattern))
                    return true
            }
            
            ; Check for fullscreen style combinations
            if (isPopup && isTopmost) {
                return true
            }
        }
        catch {
            ; If we can't get style info, continue with size-based detection
        }

        ; Check if window covers the entire monitor AND has fullscreen characteristics
        tolerance := 50  ; Increased tolerance for normal windows
        coversWidth := (w >= (mR - mL - tolerance))
        coversHeight := (h >= (mB - mT - tolerance))
        atOrigin := (x <= mL + tolerance && y <= mT + tolerance)

        ; Only consider it fullscreen if it covers the monitor AND has suspicious characteristics
        if (coversWidth && coversHeight && atOrigin) {
            ; Additional check: if it looks like a normal window (has titlebar, etc.), don't consider it fullscreen
            if (title != "" && !InStr(title, "Full Screen") && !InStr(title, "Fullscreen")) {
                ; Check if it has normal window characteristics
                if (style & 0x00C00000) {  ; WS_CAPTION (has titlebar)
                    return false  ; It's a normal window that happens to be large
                }
            }
            return true
        }

        return false
    }
    catch {
        return false
    }
}

IsWindowValid(hwnd) {
    try {
        if (!SafeWinExist(hwnd))
            return false

        ; Skip fullscreen windows completely
        if (IsFullscreenWindow(hwnd))
            return false

        try {
            if (WinGetMinMax("ahk_id " hwnd) != 0)
                return false
        }
        catch {
            return false
        }

        try {
            title := WinGetTitle("ahk_id " hwnd)
            if (title == "" || title == "Program Manager")
                return false
        }
        catch {
            return false
        }

        try {
            if (WinGetExStyle("ahk_id " hwnd) & 0x80)
                return false

            if (!(WinGetStyle("ahk_id " hwnd) & 0x10000000))
                return false
        }
        catch {
            return false
        }

        return true
    }
    catch {
        return false
    }
}

Lerp(a, b, t) {
    return a + (b - a) * t
}

EaseOutCubic(t) {
    return 1 - (1 - t) ** 3
}

ShowTooltip(text) {
    global g, Config
    ToolTip(text, g["Monitor"]["CenterX"] - 100, g["Monitor"]["Top"] + 20)
    SetTimer(() => ToolTip(), -Config["TooltipDuration"])
}

GetCurrentMonitorInfo() {
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
        return lastMonitor
    }
    return GetPrimaryMonitorCoordinates()
}

MonitorGetFromPoint(x, y) {
    try {
        Loop MonitorGetCount() {
            MonitorGet A_Index, &L, &T, &R, &B
            if (x >= L && x < R && y >= T && y < B)
                return A_Index
        }
    }
    return 0
}

GetPrimaryMonitorCoordinates() {
    try {
        primaryNum := MonitorGetPrimary()
        MonitorGet primaryNum, &L, &T, &R, &B
        return Map(
            "Left", L, "Right", R, "Top", T, "Bottom", B,
            "Width", R - L, "Height", B - T, "Number", primaryNum,
            "CenterX", (R + L) // 2, "CenterY", (B + T) // 2
        )
    }
    catch {
        return Map(
            "Left", 0, "Right", A_ScreenWidth, "Top", 0, "Bottom", A_ScreenHeight,
            "Width", A_ScreenWidth, "Height", A_ScreenHeight, "Number", 1,
            "CenterX", A_ScreenWidth // 2, "CenterY", A_ScreenHeight // 2
        )
    }
}

GetVirtualDesktopBounds() {
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

        return Map(
            "Left", minLeft, "Right", maxRight, "Top", minTop, "Bottom", maxBottom,
            "Width", maxRight - minLeft, "Height", maxBottom - minTop, "Number", 0,
            "CenterX", (maxRight + minLeft) // 2, "CenterY", (maxBottom + minTop) // 2
        )
    }
    catch {
        ; Fallback to primary monitor
        return GetPrimaryMonitorCoordinates()
    }
}

FindNonOverlappingPosition(window, otherWindows, monitor) {
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

            if (!IsOverlapping(testPos, otherWindows))
                return pos
        }
    }

    ; Fallback: slight offset from original position, but clamp to visible area
    fallbackX := Clamp(window["x"] + 20, monitor["Left"] + Config["MinMargin"], monitor["Right"] - window["width"] - Config["MinMargin"])
    fallbackY := Clamp(window["y"] + 20, monitor["Top"] + Config["MinMargin"], monitor["Bottom"] - window["height"] - Config["MinMargin"])
    return Map("x", fallbackX, "y", fallbackY)
}

IsOverlapping(window, otherWindows) {
    for other in otherWindows {
        if (window["hwnd"] == other["hwnd"])
            continue

        overlapX := Max(0, Min(window["x"] + window["width"], other["x"] + other["width"]) - Max(window["x"], other["x"]))
        overlapY := Max(0, Min(window["y"] + window["height"], other["y"] + other["height"]) - Max(window["y"], other["y"]))

        if (overlapX > Config["Stabilization"]["OverlapTolerance"] && overlapY > Config["Stabilization"]["OverlapTolerance"])
            return true
    }
    return false
}
IsPluginWindow(hwnd) {
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

        return false
    }
    catch {
        return false
    }
}

IsWindowFloating(hwnd) {
    global Config

    ; Basic window existence check
    if (!SafeWinExist(hwnd))
        return false

    ; Skip fullscreen windows completely
    if (IsFullscreenWindow(hwnd))
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

        ; Debug output - remove after testing if not needed
        ; OutputDebug("Window Check - Class: " winClass " | Process: " processName " | Title: " title)

        ; 1. First check for forced processes (simplified)
        for pattern in Config["ForceFloatProcesses"] {
            if (processName ~= "i)^" pattern "$") {  ; Exact match with case insensitivity
                return true
            }
        }

        ; 2. Special cases that should always float
        if (winClass == "ConsoleWindowClass" || winClass == "CASCADIA_HOSTING_WINDOW_CLASS") {
            return true  ; CMD and Windows Terminal
        }

        ; 3. Plugin window detection (basic but effective)
        if (winClass ~= "i)(Vst|JS|Plugin|Float)") {
            return true
        }

        if (title ~= "i)(VST|JS:|Plugin|FX)") {
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
                return true
            }
        }

        ; 6. Check title patterns from config
        for pattern in Config["FloatTitlePatterns"] {
            if (title ~= "i)" pattern) {
                return true
            }
        }

        ; 7. Final style check
        return (style & Config["FloatStyles"]) != 0
    }
    catch {
        return false
    }
}



GetVisibleWindows(monitor) {
    global Config, g
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
                ; Find existing window data if available
                existingWin := 0
                for win in g["Windows"] {
                    if (win["hwnd"] == window["hwnd"]) {
                        existingWin := win
                        break
                    }
                }
                
                ; CRITICAL: Check if window is manually locked BEFORE applying any position constraints
                ; User-placed windows should NEVER have their position modified
                isManuallyLocked := (existingWin && existingWin.Has("ManualLock") && A_TickCount < existingWin["ManualLock"])
                ; Check if this window is the active window - CRITICAL: Never move the active window
                isActiveWindow := (window["hwnd"] == g["ActiveWindow"])
                ; Check if currently being dragged - CRITICAL: Never move during drag
                isCurrentlyDragging := (GetKeyState("LButton", "P") && window["hwnd"] == g["ActiveWindow"])
                
                ; Only apply position constraints if window is NOT manually locked and NOT active and NOT currently being dragged
                if (!isManuallyLocked && !isActiveWindow && !isCurrentlyDragging) {
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
                    
                    ; Apply taskbar boundary constraints
                    taskbarRect := GetTaskbarRect()
                    if (taskbarRect) {
                        ; Check if taskbar is at bottom of screen
                        if (taskbarRect.top > A_ScreenHeight / 2) {
                            ; Taskbar at bottom - adjust bottom boundary
                            maxY := taskbarRect.top - Config["MinMargin"] - window["height"]
                            window["y"] := Min(window["y"], maxY)
                        }
                        ; Check if taskbar is at top of screen
                        else if (taskbarRect.bottom < A_ScreenHeight / 2) {
                            ; Taskbar at top - adjust top boundary
                            minY := taskbarRect.bottom + Config["MinMargin"]
                            window["y"] := Max(window["y"], minY)
                        }
                        ; Check if taskbar is at left of screen
                        else if (taskbarRect.right < A_ScreenWidth / 2) {
                            ; Taskbar at left - adjust left boundary
                            minX := taskbarRect.right + Config["MinMargin"]
                            window["x"] := Max(window["x"], minX)
                        }
                        ; Check if taskbar is at right of screen
                        else if (taskbarRect.left > A_ScreenWidth / 2) {
                            ; Taskbar at right - adjust right boundary
                            maxX := taskbarRect.left - Config["MinMargin"] - window["width"]
                            window["x"] := Min(window["x"], maxX)
                        }
                    }
                } else {
                    ; Use EXISTING window position for manually locked or active windows
                    ; This ensures user-placed windows stay exactly where the user put them
                    if (existingWin) {
                        window["x"] := existingWin["x"]
                        window["y"] := existingWin["y"]
                    }
                }

                ; Create window entry with physics properties
                ; CRITICAL: Preserve ManualLock and other critical state from existing window
                winEntry := Map(
                    "hwnd", window["hwnd"],
                    "x", window["x"], "y", window["y"],
                    "width", window["width"], "height", window["height"],
                    "area", window["width"] * window["height"],
                    "mass", window["width"] * window["height"] / 100000,
                    "lastMove", existingWin ? existingWin["lastMove"] : 0,
                    "vx", existingWin ? existingWin["vx"] : 0,
                    "vy", existingWin ? existingWin["vy"] : 0,
                    "targetX", existingWin ? existingWin["targetX"] : window["x"],
                    "targetY", existingWin ? existingWin["targetY"] : window["y"],
                    "monitor", winMonitor,
                    "isPlugin", window["isPlugin"],
                    "lastSeen", window["lastSeen"],
                    "lastZOrder", existingWin ? existingWin.Get("lastZOrder", -1) : -1  ; Cache z-order state
                )
                
                ; Preserve ManualLock and IsManual flags - CRITICAL for user-placed windows
                if (existingWin) {
                    if (existingWin.Has("ManualLock"))
                        winEntry["ManualLock"] := existingWin["ManualLock"]
                    if (existingWin.Has("IsManual"))
                        winEntry["IsManual"] := existingWin["IsManual"]
                    if (existingWin.Has("JustDragged"))
                        winEntry["JustDragged"] := existingWin["JustDragged"]
                        
                    ; CRITICAL: For manually locked or active windows, preserve their exact x/y target positions
                    ; This prevents physics from moving them away from user placement
                    if ((isManuallyLocked || isActiveWindow) && existingWin.Has("targetX") && existingWin.Has("targetY")) {
                        winEntry["targetX"] := existingWin["targetX"]
                        winEntry["targetY"] := existingWin["targetY"]
                        ; Also preserve x/y from existing window to keep it exact
                        winEntry["x"] := existingWin["x"]
                        winEntry["y"] := existingWin["y"]
                    }
                }
                
                WinList.Push(winEntry)

                ; Add time-phasing echo for all floating windows
                if (g["FairyDustEnabled"]) {
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

    return WinList
}

CleanupStaleWindows() {
    global g
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
}

class TimePhasing {
    static echoes := Map()
    static lastCleanup := 0
    static noiseClouds := Map() ; Store noise cloud data per hwnd
    static particleTrails := Map() ; Store particle trails per window
    static gdiPlusToken := 0
    static overlayGui := 0
    static overlayBitmap := 0
    static overlayGraphics := 0
    static lastRenderTime := 0

    static InitGdiPlus() {
        if (this.gdiPlusToken != 0)
            return true
            
        try {
            ; Initialize GDI+
            DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", 0, "Ptr", 0)
            this.gdiPlusToken := token
            
            ; Create overlay GUI
            this.overlayGui := Gui("+ToolWindow -Caption +E0x20 +AlwaysOnTop +LastFound +E0x08000000")
            this.overlayGui.BackColor := "000000"
            this.overlayGui.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight " NA")
            WinSetTransparent(200, this.overlayGui.Hwnd)  ; Semi-transparent to see effects
            WinSetExStyle("+0x20", this.overlayGui.Hwnd)
            
            ; Create bitmap and graphics for drawing
            DllCall("gdiplus\GdipCreateBitmap", "Int", A_ScreenWidth, "Int", A_ScreenHeight, "Int", 0, "Int", 0x26200A, "Ptr*", &bitmap)
            this.overlayBitmap := bitmap
            DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bitmap, "Ptr*", &graphics)
            this.overlayGraphics := graphics
            
            ; Set up graphics for transparency
            DllCall("gdiplus\GdipSetCompositingMode", "Ptr", graphics, "Int", 1)  ; SourceOver
            DllCall("gdiplus\GdipSetCompositingQuality", "Ptr", graphics, "Int", 2)  ; HighQuality
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 2)  ; AntiAlias
            
            return true
        }
        catch {
            return false
        }
    }

    static AddEcho(hwnd) {
        if (!SafeWinExist(hwnd))
            return

        ; Initialize GDI+ if needed
        if (!this.InitGdiPlus())
            return

        if (!this.echoes.Has(hwnd)) {
            this.echoes[hwnd] := {
                phases: [],
                lastUpdate: 0
            }
        }

        ; Use configurable update frequency
        updateInterval := g["TimePhasingConfig"]["EffectUpdateFrequency"]
        if (A_TickCount - this.echoes[hwnd].lastUpdate < updateInterval)
            return

        try {
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            this.echoes[hwnd].lastUpdate := A_TickCount

            ; Enhanced echo generation with better visual effects
            phases := []
            maxEchoes := g["TimePhasingConfig"]["MaxEchoesPerWindow"]
            phaseCount := Random(2, maxEchoes)
            
            ; Create more varied and visually appealing echoes
            Loop phaseCount {
                idx := A_Index
                ; Progressive expansion with smoother curves
                step := idx - 1
                baseRadius := Random(15, 30)
                radius := baseRadius + step * Random(8, 15)
                
                ; Better opacity curve for smoother fading
                baseOpacity := Random(40, 90)
                opacity := baseOpacity * (1 - step * 0.3)
                
                ; Configurable life range
                lifeRange := g["TimePhasingConfig"]["EchoLifeRange"]
                life := Random(lifeRange[1], lifeRange[2]) + step * Random(3, 8)
                
                ; More natural angle distribution
                angle := Random(0, 359)
                offsetX := Round(radius * Cos(angle * 3.14159 / 180))
                offsetY := Round(radius * Sin(angle * 3.14159 / 180))
                
                ; Enhanced phase properties
                phases.Push({
                    timeOffset: step * Random(60, 120),
                    opacity: Max(opacity, 10),
                    life: life,
                    offsetX: offsetX,
                    offsetY: offsetY,
                    radius: radius,
                    color: this.GenerateEchoColor(idx),
                    size: Random(3, 8)
                })
            }
            this.echoes[hwnd].phases := phases
        }
        catch {
            return
        }

        ; --- Add/Update enhanced noise cloud ---
        this.GenerateNoiseCloud(hwnd, x, y, w, h)
        
        ; --- Add particle trails if enabled ---
        if (g["TimePhasingConfig"]["EnableParticleTrails"]) {
            this.GenerateParticleTrail(hwnd, x, y, w, h)
        }
    }

    static GenerateEchoColor(index) {
        ; Generate vibrant, varied colors for echoes
        colors := [
            "FF6B6B",  ; Coral
            "4ECDC4",  ; Teal
            "45B7D1",  ; Sky Blue
            "96CEB4",  ; Mint
            "FFEAA7",  ; Soft Yellow
            "DDA0DD",  ; Plum
            "98D8C8",  ; Seafoam
            "F7DC6F"   ; Light Gold
        ]
        return colors[Mod(index - 1, colors.Length) + 1]
    }

    static GenerateNoiseCloud(hwnd, x, y, w, h) {
        ; Generate enhanced noise cloud with better distribution
        density := g["TimePhasingConfig"]["NoiseCloudDensity"]
        noiseScale := g["TimePhasingConfig"]["NoiseScale"]
        points := []
        
        ; Use Poisson disk sampling for better distribution
        Loop density {
            i := A_Index
            ; Try multiple positions for better coverage
            attempts := 0
            while (attempts < 10) {
                px := x + Random(0, w)
                py := y + Random(0, h)
                
                ; Check minimum distance from other points
                minDist := 20
                validPos := true
                for pt in points {
                    dist := Sqrt((px - pt.x)**2 + (py - pt.y)**2)
                    if (dist < minDist) {
                        validPos := false
                        break
                    }
                }
                
                if (validPos) {
                    ; Enhanced noise calculation
                    noise := NoiseAnimator.noise(px * noiseScale, py * noiseScale)
                    alpha := 25 + Round(40 * Abs(noise))
                    
                    ; Add color variation based on noise
                    colorIntensity := Abs(noise)
                    color := this.GenerateNoiseColor(colorIntensity)
                    
                    points.Push({ 
                        x: px, 
                        y: py, 
                        alpha: Max(alpha, 60),  ; Ensure minimum visibility
                        color: color,
                        size: Random(4, 8),  ; Larger particles
                        driftX: Random(-1.0, 1.0),
                        driftY: Random(-1.0, 1.0)
                    })
                    break
                }
                attempts++
            }
        }
        
        this.noiseClouds[hwnd] := {
            points: points,
            lastUpdate: A_TickCount
        }
    }

    static GenerateNoiseColor(intensity) {
        ; Generate vibrant colors based on noise intensity
        if (intensity < 0.3) {
            return "FF6B6B"  ; Bright coral
        } else if (intensity < 0.6) {
            return "4ECDC4"  ; Bright teal
        } else {
            return "FFE66D"  ; Bright yellow
        }
    }

    static GenerateParticleTrail(hwnd, x, y, w, h) {
        ; Generate particle trails for enhanced visual effects
        if (!this.particleTrails.Has(hwnd)) {
            this.particleTrails[hwnd] := {
                particles: [],
                lastUpdate: 0
            }
        }
        
        trailData := this.particleTrails[hwnd]
        
        ; Add new particles to the trail
        trailLength := g["TimePhasingConfig"]["TrailLength"]
        if (trailData.particles.Length < trailLength) {
            particleCount := Random(2, 4)
            Loop particleCount {
                particle := {
                    x: x + Random(0, w),
                    y: y + Random(0, h),
                    life: trailLength,
                    maxLife: trailLength,
                    size: Random(3, 6),  ; Larger particles
                    color: this.GenerateTrailColor(),
                    alpha: 120,  ; More visible
                    velocityX: Random(-1.5, 1.5),
                    velocityY: Random(-1.5, 1.5)
                }
                trailData.particles.Push(particle)
            }
        }
        
        ; Update existing particles
        validParticles := []
        for particle in trailData.particles {
            particle.life--
            if (particle.life > 0) {
                ; Move particle
                particle.x += particle.velocityX
                particle.y += particle.velocityY
                
                ; Fade out over time
                lifeRatio := particle.life / particle.maxLife
                particle.alpha := Round(80 * lifeRatio)
                particle.size := Max(1, particle.size * lifeRatio)
                
                ; Add subtle color shift
                if (g["TimePhasingConfig"]["EnableColorShifting"]) {
                    particle.color := this.ShiftTrailColor(particle.color, lifeRatio)
                }
                
                validParticles.Push(particle)
            }
        }
        
        trailData.particles := validParticles
        trailData.lastUpdate := A_TickCount
    }

    static GenerateTrailColor() {
        ; Generate colors for particle trails
        colors := [
            "FFD700",  ; Gold
            "FF69B4",  ; Hot Pink
            "00CED1",  ; Dark Turquoise
            "FF6347",  ; Tomato
            "9370DB",  ; Medium Purple
            "32CD32"   ; Lime Green
        ]
        return colors[Random(1, colors.Length)]
    }

    static ShiftTrailColor(color, lifeRatio) {
        ; Shift trail color based on life remaining
        r := Integer("0x" SubStr(color, 1, 2))
        green := Integer("0x" SubStr(color, 3, 2))
        b := Integer("0x" SubStr(color, 5, 2))
        
        ; Shift toward cooler colors as particle fades
        shift := (1 - lifeRatio) * 50
        r := Max(0, Min(255, r - shift * 0.3))
        green := Max(0, Min(255, green + shift * 0.2))
        b := Max(0, Min(255, b + shift * 0.4))
        
        return Format("{:02X}{:02X}{:02X}", r, green, b)
    }

    static UpdateEchoes() {
        ; Debug: Check if we have any effects to render
        if (this.echoes.Count == 0 && this.noiseClouds.Count == 0 && this.particleTrails.Count == 0) {
            ; No effects to render, skip
            return
        }
        
        ; Periodic cleanup to prevent memory leaks
        if (A_TickCount - this.lastCleanup > 10000) {  ; Cleanup every 10 seconds
            this.PerformCleanup()
            this.lastCleanup := A_TickCount
        }

        ; Update echoes with improved performance
        for hwnd, data in this.echoes.Clone() {
            try {
                if (!SafeWinExist(hwnd)) {
                this.echoes.Delete(hwnd)
                if (this.noiseClouds.Has(hwnd))
                    this.noiseClouds.Delete(hwnd)
                if (this.particleTrails.Has(hwnd))
                    this.particleTrails.Delete(hwnd)
                continue
                }

                ; Update phase lifetimes and expansion with smoother animation
                validPhases := []
                for phase in data.phases {
                    phase.life--
                    if (phase.life > 0) {
                        ; Smoother expansion and fading
                        expansionRate := 1 + phase.life * 0.008
                        phase.radius += expansionRate
                        phase.opacity := Max(phase.opacity - 1.5, 0)
                        
                        ; Add subtle color shift over time
                        phase.color := this.ShiftColorOverTime(phase.color, phase.life)
                        
                        validPhases.Push(phase)
                    }
                }
                data.phases := validPhases
            }
            catch {
                this.echoes.Delete(hwnd)
                continue
            }
        }

        ; Update noise clouds with optimized animation
        for hwnd, cloud in this.noiseClouds.Clone() {
            if (!SafeWinExist(hwnd)) {
                this.noiseClouds.Delete(hwnd)
                continue
            }
            
            ; Animate cloud points with smoother drifting
            for pt in cloud.points {
                ; Apply drift with smoothing
                pt.x += pt.driftX
                pt.y += pt.driftY
                
                ; Keep points within window bounds (approximate)
                WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
                pt.x := Max(wx, Min(pt.x, wx + ww))
                pt.y := Max(wy, Min(pt.y, wy + wh))
                
                ; Recalculate alpha with noise (less frequently for performance)
                if (Random(1, 10) == 1) {  ; Only recalculate 10% of the time
                    noiseScale := g["TimePhasingConfig"]["NoiseScale"]
                    noise := NoiseAnimator.noise(pt.x * noiseScale, pt.y * noiseScale)
                    pt.alpha := 25 + Round(40 * Abs(noise))
                }
            }
            cloud.lastUpdate := A_TickCount
        }
        
        ; Render effects if enough time has passed
        renderInterval := g["TimePhasingConfig"]["EffectUpdateFrequency"]
        if (A_TickCount - this.lastRenderTime >= renderInterval) {
            this.RenderEffects()
            this.lastRenderTime := A_TickCount
        }
    }

    static ShiftColorOverTime(color, life) {
        ; Subtle color shifting for dynamic effects
        ; Convert hex to RGB
        r := Integer("0x" SubStr(color, 1, 2))
        green := Integer("0x" SubStr(color, 3, 2))
        b := Integer("0x" SubStr(color, 5, 2))
        
        ; Apply subtle shift based on life remaining
        shift := (20 - life) * 2
        r := Max(0, Min(255, r + shift))
        green := Max(0, Min(255, green - shift * 0.5))
        b := Max(0, Min(255, b + shift * 0.3))
        
        ; Convert back to hex
        return Format("{:02X}{:02X}{:02X}", r, green, b)
    }

    static PerformCleanup() {
        ; Clean up expired echoes and noise clouds
        for hwnd, data in this.echoes.Clone() {
            if (!SafeWinExist(hwnd) || data.phases.Length == 0) {
                this.echoes.Delete(hwnd)
            }
        }
        
        for hwnd, cloud in this.noiseClouds.Clone() {
            if (!SafeWinExist(hwnd) || A_TickCount - cloud.lastUpdate > 30000) {
                this.noiseClouds.Delete(hwnd)
            }
        }
        
        for hwnd, trailData in this.particleTrails.Clone() {
            if (!SafeWinExist(hwnd) || A_TickCount - trailData.lastUpdate > 30000) {
                this.particleTrails.Delete(hwnd)
            }
        }
    }

    static GetNoiseCloud(hwnd) {
        ; Retrieve noise cloud points for rendering
        return this.noiseClouds.Has(hwnd) ? this.noiseClouds[hwnd].points : []
    }

    static RenderEffects() {
        if (!this.overlayGraphics || !this.InitGdiPlus())
            return

        try {
            ; Clear the bitmap with transparent background
            DllCall("gdiplus\GdipGraphicsClear", "Ptr", this.overlayGraphics, "UInt", 0x00000000)
            
            ; Debug: Count effects being rendered
            echoCount := 0
            cloudCount := 0
            particleCount := 0
            
            ; Render echoes
            for hwnd, data in this.echoes {
                if (!SafeWinExist(hwnd))
                    continue
                    
                WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
                
                for phase in data.phases {
                    if (phase.life > 0 && phase.opacity > 0) {
                        this.DrawEcho(wx, wy, phase)
                        echoCount++
                    }
                }
            }
            
            ; Render noise clouds
            for hwnd, cloud in this.noiseClouds {
                if (!SafeWinExist(hwnd))
                    continue
                    
                for pt in cloud.points {
                    if (pt.alpha > 0) {
                        this.DrawNoisePoint(pt)
                        cloudCount++
                    }
                }
            }
            
            ; Render particle trails
            if (g["TimePhasingConfig"]["EnableParticleTrails"]) {
                for hwnd, trailData in this.particleTrails {
                    if (!SafeWinExist(hwnd))
                        continue
                        
                    for particle in trailData.particles {
                        if (particle.life > 0 && particle.alpha > 0) {
                            this.DrawParticle(particle)
                            particleCount++
                        }
                    }
                }
            }
            
            ; Present the rendered frame to the GUI
            ; Update the GUI with the bitmap content
            if (this.overlayGui && this.overlayBitmap) {
                ; Get the GUI's device context
                hdc := DllCall("GetDC", "Ptr", this.overlayGui.Hwnd, "Ptr")
                if (hdc) {
                    ; Create a graphics object from the GUI's DC
                    DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc, "Ptr*", &guiGraphics)
                    if (guiGraphics) {
                        ; Draw the bitmap to the GUI
                        DllCall("gdiplus\GdipDrawImage", "Ptr", guiGraphics, "Ptr", this.overlayBitmap, "Int", 0, "Int", 0)
                        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", guiGraphics)
                    }
                    DllCall("ReleaseDC", "Ptr", this.overlayGui.Hwnd, "Ptr", hdc)
                }
                this.overlayGui.Show("NA")  ; Show without activating
            }
            
            ; Debug output (remove after testing)
            if (echoCount > 0 || cloudCount > 0 || particleCount > 0) {
                ; OutputDebug("Rendered: " echoCount " echoes, " cloudCount " clouds, " particleCount " particles")
            }
        }
        catch {
            ; Handle rendering errors gracefully
        }
    }

    static DrawEcho(windowX, windowY, phase) {
        ; Draw echo phase using GDI+
        centerX := windowX + phase.offsetX
        centerY := windowY + phase.offsetY
        
        ; Create brush for the echo
        color := "0x" phase.color
        alpha := Round(phase.opacity * 255 / 100)
        brushColor := (alpha << 24) | color
        
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", brushColor, "Ptr*", &brush)
        DllCall("gdiplus\GdipFillEllipse", "Ptr", this.overlayGraphics, "Ptr", brush, 
                "Float", centerX - phase.size, "Float", centerY - phase.size, 
                "Float", phase.size * 2, "Float", phase.size * 2)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
    }

    static DrawNoisePoint(pt) {
        ; Draw noise cloud point using GDI+
        alpha := Round(pt.alpha * 255 / 100)
        color := Integer("0x" pt.color)
        brushColor := (alpha << 24) | color
        
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", brushColor, "Ptr*", &brush)
        DllCall("gdiplus\GdipFillEllipse", "Ptr", this.overlayGraphics, "Ptr", brush,
                "Float", pt.x - pt.size, "Float", pt.y - pt.size,
                "Float", pt.size * 2, "Float", pt.size * 2)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
    }

    static DrawParticle(particle) {
        ; Draw particle with glow effect if enabled
        alpha := Round(particle.alpha * 255 / 100)
        color := Integer("0x" particle.color)
        brushColor := (alpha << 24) | color
        
        ; Draw main particle
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", brushColor, "Ptr*", &brush)
        DllCall("gdiplus\GdipFillEllipse", "Ptr", this.overlayGraphics, "Ptr", brush,
                "Float", particle.x - particle.size, "Float", particle.y - particle.size,
                "Float", particle.size * 2, "Float", particle.size * 2)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
        
        ; Add glow effect if enabled
        if (g["TimePhasingConfig"]["EnableGlowEffects"]) {
            glowAlpha := Round(alpha * 0.3)
            glowColor := (glowAlpha << 24) | color
            glowSize := particle.size * 2
            
            DllCall("gdiplus\GdipCreateSolidFill", "UInt", glowColor, "Ptr*", &glowBrush)
            DllCall("gdiplus\GdipFillEllipse", "Ptr", this.overlayGraphics, "Ptr", glowBrush,
                    "Float", particle.x - glowSize, "Float", particle.y - glowSize,
                    "Float", glowSize * 2, "Float", glowSize * 2)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", glowBrush)
        }
    }

    static CleanupEffects() {
        ; Enhanced cleanup with proper resource management
        this.PerformCleanup()
        
        ; Clean up GDI+ resources
        if (this.overlayGraphics) {
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", this.overlayGraphics)
            this.overlayGraphics := 0
        }
        
        if (this.overlayBitmap) {
            DllCall("gdiplus\GdipDisposeImage", "Ptr", this.overlayBitmap)
            this.overlayBitmap := 0
        }
        
        if (this.overlayGui) {
            this.overlayGui.Destroy()
            this.overlayGui := 0
        }
        
        if (this.gdiPlusToken) {
            DllCall("gdiplus\GdiplusShutdown", "Ptr", this.gdiPlusToken)
            this.gdiPlusToken := 0
        }
        
        ; Clear all effect data
        this.echoes.Clear()
        this.noiseClouds.Clear()
        this.particleTrails.Clear()
    }
}

CreateBlurBehindStruct() {
    bb := Buffer(20)
    NumPut("UInt", 1, bb, 0)
    NumPut("Int", 1, bb, 4)
    NumPut("Ptr", 0, bb, 8)
    NumPut("Int", 0, bb, 16)
    return bb.Ptr
}

ApplyStabilization(win) {
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
}

CalculateWindowForces(win, allWindows) {
    global g, Config

    ; Check if user is actively dragging a window
    isDragging := GetKeyState("LButton", "P")
    isDraggedWindow := false
    
    if (isDragging) {
        ; Check if this window is the one being dragged
        MouseGetPos(,, &hoverHwnd)
        isDraggedWindow := (win["hwnd"] == hoverHwnd)
        
        ; For the dragged window, skip its own physics calculations
        ; but allow it to apply forces to other windows in the allWindows loop
        if (isDraggedWindow) {
            win["vx"] := 0
            win["vy"] := 0
            ; Don't return - we need to continue to apply forces from this window to others
        }
    }

    ; Keep active window and recently moved windows still
    ; CRITICAL: The active window should NEVER be affected by physics (unless dragging)
    isActiveWindow := (win["hwnd"] == g["ActiveWindow"])
    isRecentlyMoved := (A_TickCount - g["LastUserMove"] < Config["UserMoveTimeout"])
    isCurrentlyFocused := (win["hwnd"] == WinExist("A"))
    isManuallyLocked := (win.Has("ManualLock") && A_TickCount < win["ManualLock"])

    ; CRITICAL: Manually locked windows and the active window should NEVER be affected by physics
    ; Also protect recently moved windows that are currently focused
    ; BUT: when dragging, allow the dragged window to calculate forces to push other windows
    isProtected := (isManuallyLocked || isActiveWindow || (isRecentlyMoved && isCurrentlyFocused)) && !isDraggedWindow
    if (isProtected) {
        win["vx"] := 0
        win["vy"] := 0
        return
    }
    
    ; Check if window has any actual collisions
    hasCollision := false
    for other in allWindows {
        if (other == win)
            continue
        
        overlapX := Max(0, Min(win["x"] + win["width"], other["x"] + other["width"]) - Max(win["x"], other["x"]))
        overlapY := Max(0, Min(win["y"] + win["height"], other["y"] + other["height"]) - Max(win["y"], other["y"]))
        
        if (overlapX > 5 && overlapY > 5) {
            hasCollision := true
            break
        }
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
    
    ; Check if window is out of bounds
    isOutOfBounds := (win["x"] < monLeft || win["x"] > monRight || win["y"] < monTop || win["y"] > monBottom)
    
    ; If no collision, no out-of-bounds, and velocity is already near zero, keep window still
    if (!hasCollision && !isOutOfBounds && Abs(win["vx"]) < 0.1 && Abs(win["vy"]) < 0.1) {
        win["vx"] := 0
        win["vy"] := 0
        ; Clear target position so window stays exactly where it is
        if (win.Has("targetX"))
            win.Delete("targetX")
        if (win.Has("targetY"))
            win.Delete("targetY")
        return
    }

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
        ; Use less damping for Electron apps
        dampingFactor := IsElectronApp(win["hwnd"]) ? 0.99 : 0.98
        vx := prev_vx * dampingFactor + dx * Config["AttractionForce"] * 0.08 * attractionScale  ; Increased from 0.05
        vy := prev_vy * dampingFactor + dy * Config["AttractionForce"] * 0.08 * attractionScale
    } else {
        ; Use less damping for Electron apps near center
        dampingFactor := IsElectronApp(win["hwnd"]) ? 0.998 : 0.995
        vx := prev_vx * dampingFactor  ; Slightly more damping near center
        vy := prev_vy * dampingFactor
    }

    ; Space-seeking behavior: move toward empty areas when crowded (reduced for less jumpiness)
    spaceForce := CalculateSpaceSeekingForce(win, allWindows)
    if (spaceForce.Count > 0) {
        vx += spaceForce["vx"] * 0.005  ; Much smaller force to reduce jumpiness
        vy += spaceForce["vy"] * 0.005
    }

    ; Soft edge boundaries (like invisible force fields)
    edgeBuffer := 5  ; Reduced to allow windows closer to edges
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
    isDragging := GetKeyState("LButton", "P")
    
    for other in allWindows {
        if (other == win)
            continue
        
        ; Skip maximized and fullscreen windows - they should never be affected
        try {
            if (WinGetMinMax("ahk_id " other["hwnd"]) != 0 || IsFullscreenWindow(other["hwnd"]))
                continue
        } catch {
            continue
        }
            
        ; CRITICAL: Skip interaction with active windows UNLESS we're currently dragging
        ; When dragging, allow the dragged window to push other windows
        if (!isDragging && other["hwnd"] == g["ActiveWindow"]) {
            continue
        }

        ; Calculate distance between window centers
        otherX := other["x"] + other["width"]/2
        otherY := other["y"] + other["height"]/2
        dx := wx - otherX
        dy := wy - otherY
        dist := Max(Sqrt(dx*dx + dy*dy), 1)

        ; Dynamic interaction range based on window sizes
        interactionRange := Sqrt(win["width"] * win["height"] + other["width"] * other["height"]) / 2.5  ; Increased for wider gaps

        ; Smaller windows get proportionally larger interaction zones
        sizeBonus := Max(1, 200 / Min(win["width"], win["height"]))  ; Boost for small windows
        interactionRange *= sizeBonus

        if (dist < interactionRange * 1.5) {  ; Further expanded repulsion zone for wider gaps
            ; Close range: much stronger repulsion to prevent prolonged overlap
            repulsionForce := Config["RepulsionForce"] * (interactionRange * 1.5 - dist) / (interactionRange * 1.5)
            repulsionForce *= (other.Has("IsManual") ? Config["ManualRepulsionMultiplier"] : 1)

            ; Reduced force scaling to prevent jumpiness
            proximityMultiplier := 1 + (1 - dist / (interactionRange * 1.5)) * 1  ; Reduced from 2x to 1x max

            vx += dx * repulsionForce * proximityMultiplier / dist * 0.3  ; Reduced from 0.6
            vy += dy * repulsionForce * proximityMultiplier / dist * 0.3
        } else if (dist < interactionRange * 3) {  ; Reduced attraction range for tighter equilibrium
            ; Medium range: gentle attraction for stable clustering
            attractionForce := Config["AttractionForce"] * 0.012 * (dist - interactionRange) / interactionRange  ; Increased from 0.005

            vx -= dx * attractionForce / dist * 0.04  ; Increased from 0.02
            vy -= dy * attractionForce / dist * 0.04
        }
    }

    ; Space-like momentum with equilibrium-seeking damping
    ; Use less damping for Electron apps to make them more responsive
    dampingFactor := IsElectronApp(win["hwnd"]) ? 0.998 : 0.994  ; Less friction for Electron apps
    vx *= dampingFactor
    vy *= dampingFactor

    ; Floating speed limits (balanced for equilibrium)
    maxFloatSpeed := Config["MaxSpeed"] * 2.0  ; Reduced from 2.5
    vx := Min(Max(vx, -maxFloatSpeed), maxFloatSpeed)
    vy := Min(Max(vy, -maxFloatSpeed), maxFloatSpeed)

    ; Progressive stabilization based on speed - less aggressive for Electron apps
    if (Abs(vx) < 0.15 && Abs(vy) < 0.15) {  ; Increased threshold for earlier settling
        stabilizationFactor := IsElectronApp(win["hwnd"]) ? 0.95 : 0.88  ; Less aggressive stabilization for Electron apps
        vx *= stabilizationFactor
        vy *= stabilizationFactor
    }

    win["vx"] := vx
    win["vy"] := vy

    ; CRITICAL: Do NOT update target position for manually locked windows or active windows
    ; User placed them there, and they should stay exactly where placed
    ; The active window should NEVER have its position modified
    ; Also skip for dragged window
    isManuallyLocked := (win.Has("ManualLock") && A_TickCount < win["ManualLock"])
    if (isManuallyLocked || win["hwnd"] == g["ActiveWindow"] || isDraggedWindow) {
        ; Keep target position exactly where it is - don't modify it
        return
    }

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
    static lastUpdate := 0
    static lastPositions := Map()
    static smoothPos := Map()

    Critical

    ; Keep physics running during drag to allow dragged window to push other windows
    ; The dragged window itself will be protected from movement in the loop below

    now := A_TickCount
    frameTime := now - lastUpdate
    lastUpdate := now

    ; Cache all window positions at the start
    hwndPos := Map()
    for win in g["Windows"] {
        hwnd := win["hwnd"]
        try {
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            hwndPos[hwnd] := { x: x, y: y }
        } catch {
            continue
        }
    }

    moveBatch := []
    movedAny := false

    ; Check if currently dragging
    isDragging := GetKeyState("LButton", "P")
    draggedHwnd := 0
    if (isDragging) {
        MouseGetPos(,, &draggedHwnd)
    }
    
    for win in g["Windows"] {
        ; Skip maximized and fullscreen windows - they should never be moved
        try {
            if (WinGetMinMax("ahk_id " win["hwnd"]) != 0 || IsFullscreenWindow(win["hwnd"]))
                continue
        } catch {
            continue
        }
        
        ; CRITICAL: Never move the active window when not dragging - it should stay exactly where it is
        ; When dragging, never move the window being dragged
        if ((win["hwnd"] == g["ActiveWindow"] && !isDragging) || win["hwnd"] == draggedHwnd)
            continue
        
        ; CRITICAL: Never move manually locked windows - user placed them there
        isManuallyLocked := (win.Has("ManualLock") && A_TickCount < win["ManualLock"])
        if (isManuallyLocked)
            continue

        ; Safely get monitor bounds
        try {
            if (Config["SeamlessMonitorFloat"]) {
                ; Use virtual desktop bounds for seamless multi-monitor floating
                virtualBounds := GetVirtualDesktopBounds()
                monLeft := virtualBounds["Left"]
                monTop := virtualBounds["Top"] + Config["MinMargin"]
                monRight := virtualBounds["Right"] - win["width"]
                monBottom := virtualBounds["Bottom"] - Config["MinMargin"] - win["height"]
            } else {
                ; Use current monitor bounds for traditional single-monitor floating
                MonitorGet win["monitor"], &mL, &mT, &mR, &mB
                monLeft := mL
                monRight := mR - win["width"]
                monTop := mT + Config["MinMargin"]
                monBottom := mB - Config["MinMargin"] - win["height"]
            }
        } catch {
            monLeft := 0
            monRight := A_ScreenWidth - win["width"]
            monTop := Config["MinMargin"]
            monBottom := A_ScreenHeight - Config["MinMargin"] - win["height"]
        }
        
        ; Apply taskbar boundary constraints
        taskbarRect := GetTaskbarRect()
        if (taskbarRect) {
            ; Check if taskbar is at bottom of screen
            if (taskbarRect.top > A_ScreenHeight / 2) {
                ; Taskbar at bottom - adjust bottom boundary
                monBottom := Min(monBottom, taskbarRect.top - Config["MinMargin"] - win["height"])
            }
            ; Check if taskbar is at top of screen
            else if (taskbarRect.bottom < A_ScreenHeight / 2) {
                ; Taskbar at top - adjust top boundary
                monTop := Max(monTop, taskbarRect.bottom + Config["MinMargin"])
            }
            ; Check if taskbar is at left of screen
            else if (taskbarRect.right < A_ScreenWidth / 2) {
                ; Taskbar at left - adjust left boundary
                monLeft := Max(monLeft, taskbarRect.right + Config["MinMargin"])
            }
            ; Check if taskbar is at right of screen
            else if (taskbarRect.left > A_ScreenWidth / 2) {
                ; Taskbar at right - adjust right boundary
                monRight := Min(monRight, taskbarRect.left - Config["MinMargin"] - win["width"])
            }
        }

        hwnd := win["hwnd"]
        newX := win.Has("targetX") ? win["targetX"] : win["x"]
        newY := win.Has("targetY") ? win["targetY"] : win["y"]

        if (!hwndPos.Has(hwnd))
            continue

        ; Clear smoothing state for windows that were just dragged to prevent lag
        if (win.Has("JustDragged") && A_TickCount - win["JustDragged"] < 100) {
            if (smoothPos.Has(hwnd)) {
                smoothPos.Delete(hwnd)
            }
            if (lastPositions.Has(hwnd)) {
                lastPositions.Delete(hwnd)
            }
            win.Delete("JustDragged")
        }

        ; Skip processing if window is already at its target position
        ; This prevents unnecessary micro-adjustments for stable windows
        currentX := hwndPos[hwnd].x
        currentY := hwndPos[hwnd].y
        if (Abs(newX - currentX) < 0.5 && Abs(newY - currentY) < 0.5) {
            ; Clear smoothing state for windows at target to prevent accumulated drift
            if (smoothPos.Has(hwnd)) {
                smoothPos.Delete(hwnd)
            }
            continue
        }

        if (!smoothPos.Has(hwnd)) {
            ; Initialize smoothPos with current position to prevent jumping
            smoothPos[hwnd] := { x: hwndPos[hwnd].x, y: hwndPos[hwnd].y }
            ; Also initialize lastPositions to prevent immediate movement
            if (!lastPositions.Has(hwnd))
                lastPositions[hwnd] := { x: hwndPos[hwnd].x, y: hwndPos[hwnd].y }
        }

        ; Increase smoothing for less jitter
        ; Use less smoothing for Electron apps to make them more responsive
        alpha := IsElectronApp(hwnd) ? 0.45 : 0.18  ; Higher alpha = more responsive movement
        smoothPos[hwnd].x := smoothPos[hwnd].x + (newX - smoothPos[hwnd].x) * alpha
        smoothPos[hwnd].y := smoothPos[hwnd].y + (newY - smoothPos[hwnd].y) * alpha

        ; Gentle boundary enforcement (soft collision with edges)
        edgeBuffer := 10  ; Reduced to allow windows closer to edges
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

        ; Increase threshold to avoid micro-movements and reduce jumpiness
        if (Abs(smoothPos[hwnd].x - lastPositions[hwnd].x) >= 1.5 || Abs(smoothPos[hwnd].y - lastPositions[hwnd].y) >= 1.5) {
            moveBatch.Push({ hwnd: hwnd, x: smoothPos[hwnd].x, y: smoothPos[hwnd].y })
            lastPositions[hwnd].x := smoothPos[hwnd].x
            lastPositions[hwnd].y := smoothPos[hwnd].y
            win["x"] := smoothPos[hwnd].x
            win["y"] := smoothPos[hwnd].y
            movedAny := true
        }
    }

    for move in moveBatch {
        try MoveWindowAPI(move.hwnd, move.x, move.y)
    }

    ; Z-index ordering: smaller DAW plugin windows on top so they don't get lost
    ; Only reorder when layout changes significantly, not every frame
    ; Reduced frequency to prevent flashing
    static lastZOrderUpdate := 0
    static lastWindowCount := 0
    static lastPluginCount := 0
    static lastPluginOrder := []

    ; Count DAW plugin windows and track their order
    pluginCount := 0
    pluginOrder := []
    for win in g["Windows"] {
        if (IsDAWPlugin(win)) {
            pluginCount++
            pluginOrder.Push(win["hwnd"])
        }
    }

    ; Only update Z-order if plugin count, window count, or plugin order changed, or enough time passed
    ; Also check for maximized windows to prevent looping issues
    orderChanged := (pluginOrder != lastPluginOrder)
    hasMaximizedWindows := false
    
    ; Check if any tracked windows are maximized (shouldn't happen, but safety check)
    for win in g["Windows"] {
        try {
            if (WinGetMinMax("ahk_id " win["hwnd"]) != 0) {
                hasMaximizedWindows := true
                break
            }
        } catch {
            continue
        }
    }
    
    if (pluginCount > 1 && !hasMaximizedWindows &&
        (A_TickCount - lastZOrderUpdate > 5000 || pluginCount != lastPluginCount || g["Windows"].Length != lastWindowCount || orderChanged)) {
        OrderWindowsBySize()
        lastZOrderUpdate := A_TickCount
        lastWindowCount := g["Windows"].Length
        lastPluginCount := pluginCount
        lastPluginOrder := pluginOrder.Clone()
    }

    if (g["FairyDustEnabled"] && movedAny)
        TimePhasing.UpdateEchoes()
}

; Calc overlap
CalculateFutureOverlap(win, x, y, otherWindows) {
    overlapScore := 0
    for other in otherWindows {
        if (other["hwnd"] == win["hwnd"])
            continue

        overlapX := Max(0, Min(x + win["width"], other["x"] + other["width"]) - Max(x, other["x"]))
        overlapY := Max(0, Min(y + win["height"], other["y"] + other["height"]) - Max(y, other["y"]))

        overlapScore += (overlapX * overlapY) / (win["width"] * win["height"])
    }
    return overlapScore
}

Atan2(y, x) {
    return DllCall("msvcrt\atan2", "Double", y, "Double", x, "CDECL Double")
}

ResolveCollisions(positions) {
    global g, Config

    changed := true
    iterations := 0
    maxIterations := 8

    while (changed && iterations < maxIterations) {
        changed := false
        iterations++

        Loop positions.Length {
            i := A_Index
            pos1 := positions[i]

            try {
                MonitorGet pos1["monitor"], &mL, &mT, &mR, &mB
            }
            catch {
                mL := 0
                mT := 0
                mR := A_ScreenWidth
                mB := A_ScreenHeight
            }

            newX := Max(mL + Config["MinMargin"],
                       Min(pos1["x"], mR - pos1["width"] - Config["MinMargin"]))
            newY := Max(mT + Config["MinMargin"],
                       Min(pos1["y"], mB - pos1["height"] - Config["MinMargin"]))
            
            ; Apply taskbar boundary constraints
            taskbarRect := GetTaskbarRect()
            if (taskbarRect) {
                ; Check if taskbar is at bottom of screen
                if (taskbarRect.top > A_ScreenHeight / 2) {
                    ; Taskbar at bottom - adjust bottom boundary
                    maxY := taskbarRect.top - Config["MinMargin"] - pos1["height"]
                    newY := Min(newY, maxY)
                }
                ; Check if taskbar is at top of screen
                else if (taskbarRect.bottom < A_ScreenHeight / 2) {
                    ; Taskbar at top - adjust top boundary
                    minY := taskbarRect.bottom + Config["MinMargin"]
                    newY := Max(newY, minY)
                }
                ; Check if taskbar is at left of screen
                else if (taskbarRect.right < A_ScreenWidth / 2) {
                    ; Taskbar at left - adjust left boundary
                    minX := taskbarRect.right + Config["MinMargin"]
                    newX := Max(newX, minX)
                }
                ; Check if taskbar is at right of screen
                else if (taskbarRect.left > A_ScreenWidth / 2) {
                    ; Taskbar at right - adjust right boundary
                    maxX := taskbarRect.left - Config["MinMargin"] - pos1["width"]
                    newX := Min(newX, maxX)
                }
            }

            if (newX != pos1["x"] || newY != pos1["y"]) {
                pos1["x"] := newX
                pos1["y"] := newY
                changed := true
            }

            Loop positions.Length {
                j := A_Index
                if (i == j)
                    continue

                pos2 := positions[j]
                overlapX := Max(0, Min(pos1["x"] + pos1["width"], pos2["x"] + pos2["width"]) - Max(pos1["x"], pos2["x"]))
                overlapY := Max(0, Min(pos1["y"] + pos1["height"], pos2["y"] + pos2["height"]) - Max(pos1["y"], pos2["y"]))

                if (overlapX > Config["Stabilization"]["OverlapTolerance"] &&
                    overlapY > Config["Stabilization"]["OverlapTolerance"]) {
                    dx := (pos1["x"] + pos1["width"]/2) - (pos2["x"] + pos2["width"]/2)
                    dy := (pos1["y"] + pos1["height"]/2) - (pos2["y"] + pos2["height"]/2)
                    dist := Max(Sqrt(dx*dx + dy*dy), 1)
                    push := (overlapX + overlapY) / 8

                    pos1["x"] += dx * push / dist * 0.12
                    pos1["y"] += dy * push / dist * 0.12
                    pos2["x"] -= dx * push / dist * 0.12
                    pos2["y"] -= dy * push / dist * 0.12

                    changed := true
                }
            }
        }
    }

    if (iterations >= maxIterations) {
        otherWindows := []
        for pos in positions
            otherWindows.Push(pos)

        for pos in positions {
            if (IsOverlapping(pos, otherWindows)) {
                try {
                    MonitorGet pos["monitor"], &mL, &mT, &mR, &mB
                    monitor := Map(
                        "Left", mL, "Right", mR,
                        "Top", mT, "Bottom", mB,
                        "CenterX", (mL + mR)/2,
                        "CenterY", (mT + mB)/2
                    )
                    newPos := FindNonOverlappingPosition(pos, otherWindows, monitor)
                    pos["x"] := newPos["x"]
                    pos["y"] := newPos["y"]
                }
                catch {
                    continue
                }
            }
        }
    }

    return positions
}

CalculateDynamicLayout() {
    global g, Config
    static forceMultipliers := Map("normal", 1.0, "chaos", 0.6)
    static lastState := "normal"
    static transitionTime := 300
    static lastFocusCheck := 0

    ; Keep physics calculations running during drag to allow dragged window to push other windows
    ; The dragged window itself will be protected from movement in CalculateWindowForces and ApplyWindowMovements

    ; Update active window detection periodically
    if (A_TickCount - lastFocusCheck > 250) {  ; Check every 250ms
        try {
            focusedWindow := WinExist("A")
            if (focusedWindow) {
                ; Check if the focused window is one of our managed windows
                isManagedWindow := false
                for win in g["Windows"] {
                    if (win["hwnd"] == focusedWindow) {
                        isManagedWindow := true
                        break
                    }
                }
                
                ; CRITICAL: If this is a managed window, it should IMMEDIATELY become the active window
                ; The currently active window should NEVER be affected by physics or arrangement
                if (isManagedWindow && focusedWindow != g["ActiveWindow"]) {
                    g["ActiveWindow"] := focusedWindow
                    g["LastUserMove"] := A_TickCount  ; Reset timeout when focus changes
                }
            }

            ; Clear active window ONLY if timeout expired and it's no longer focused
            ; CRITICAL: Never clear ActiveWindow until the full UserMoveTimeout has elapsed
            ; This ensures user-placed windows stay exactly where placed until timeout
            if (g["ActiveWindow"] != 0 &&
                A_TickCount - g["LastUserMove"] > Config["UserMoveTimeout"] &&
                focusedWindow != g["ActiveWindow"]) {
                g["ActiveWindow"] := 0
            }
        }
        lastFocusCheck := A_TickCount
    }

    ; Dynamic force adjustment based on system energy
    currentEnergy := 0
    for win in g["Windows"] {
        CalculateWindowForces(win, g["Windows"]) ; Pass all windows for dynamic interactions
        currentEnergy += win["vx"]**2 + win["vy"]**2
    }
    g["SystemEnergy"] := Lerp(g["SystemEnergy"], currentEnergy, 0.1)

    ; State machine for natural motion transitions
    newState := (g["SystemEnergy"] > Config["Stabilization"]["EnergyThreshold"] * 2) ? "chaos" : "normal"

    if (newState != lastState) {
        transitionTime := (newState == "chaos") ? 200 : 800  ; Quick chaos entry, slow stabilization
        g["ForceTransition"] := A_TickCount + transitionTime
    }

    ; Smooth force transition for natural feel
    if (A_TickCount < g["ForceTransition"]) {
        t := (g["ForceTransition"] - A_TickCount) / transitionTime
        currentMultiplier := Lerp(forceMultipliers[newState], forceMultipliers[lastState], SmoothStep(t))
    } else {
        currentMultiplier := forceMultipliers[newState]
    }

    ; Apply space-like physics adjustments
    for win in g["Windows"] {
        ; Preserve momentum but allow gentle course corrections
        win["vx"] *= currentMultiplier
        win["vy"] *= currentMultiplier

        ; Higher speed limits for floating feel
        maxSpeed := Config["MaxSpeed"] * 1.5
        win["vx"] := Min(Max(win["vx"], -maxSpeed), maxSpeed)
        win["vy"] := Min(Max(win["vy"], -maxSpeed), maxSpeed)
    }

    ; Gentle collision resolution (no rigid partitioning)
    if (g["Windows"].Length > 1) {
        ResolveFloatingCollisions(g["Windows"])
    }

    lastState := newState
}

; New floating collision system
ResolveFloatingCollisions(windows) {
    global Config, g
    
    ; Check if currently dragging
    isDragging := GetKeyState("LButton", "P")

    ; More aggressive but gentle collision resolution for overlapping windows
    for i, win1 in windows {
        ; Skip maximized and fullscreen windows
        try {
            if (WinGetMinMax("ahk_id " win1["hwnd"]) != 0 || IsFullscreenWindow(win1["hwnd"]))
                continue
        } catch {
            continue
        }
        
        ; CRITICAL: Skip manually locked windows from collision
        ; Allow active window to participate in collisions ONLY when dragging
        isManuallyLocked1 := (win1.Has("ManualLock") && A_TickCount < win1["ManualLock"])
        isActive1 := (win1["hwnd"] == g["ActiveWindow"])
        if (isManuallyLocked1 || (isActive1 && !isDragging))
            continue
            
        for j, win2 in windows {
            if (i >= j)
                continue

            ; Skip maximized and fullscreen windows
            try {
                if (WinGetMinMax("ahk_id " win2["hwnd"]) != 0 || IsFullscreenWindow(win2["hwnd"]))
                    continue
            } catch {
                continue
            }

            ; CRITICAL: Skip manually locked or active windows from collision forces
            ; Allow active window to participate in collisions ONLY when dragging
            isManuallyLocked2 := (win2.Has("ManualLock") && A_TickCount < win2["ManualLock"])
            isActive2 := (win2["hwnd"] == g["ActiveWindow"])
            if (isManuallyLocked2 || (isActive2 && !isDragging))
                continue

            ; Check for overlap with smaller tolerance for quicker separation
            overlapX := Max(0, Min(win1["x"] + win1["width"], win2["x"] + win2["width"]) - Max(win1["x"], win2["x"]))
            overlapY := Max(0, Min(win1["y"] + win1["height"], win2["y"] + win2["height"]) - Max(win1["y"], win2["y"]))

            if (overlapX > 5 && overlapY > 5) {  ; Increased tolerance to reduce jumpiness
                ; Gentle separation force
                centerX1 := win1["x"] + win1["width"]/2
                centerY1 := win1["y"] + win1["height"]/2
                centerX2 := win2["x"] + win2["width"]/2
                centerY2 := win2["y"] + win2["height"]/2

                dx := centerX1 - centerX2
                dy := centerY1 - centerY2
                dist := Max(Sqrt(dx*dx + dy*dy), 1)

                ; Stronger separation for small windows or high overlap
                overlapArea := overlapX * overlapY
                avgSize := (win1["width"] * win1["height"] + win2["width"] * win2["height"]) / 2
                overlapRatio := overlapArea / avgSize

                ; Reduced force to prevent jumpiness
                separationForce := (overlapX + overlapY) * 0.01 * (1 + overlapRatio * 2)  ; Reduced from 0.02 and 3x scaling

                ; Reduced small window bonus to prevent excessive jumping
                if (win1["width"] < 300 || win1["height"] < 200 || win2["width"] < 300 || win2["height"] < 200) {
                    separationForce *= 1.2  ; Reduced from 1.5
                }

                win1["vx"] += dx * separationForce / dist
                win1["vy"] += dy * separationForce / dist
                win2["vx"] -= dx * separationForce / dist
                win2["vy"] -= dy * separationForce / dist
            }
        }
    }
}


;;MANUAL WINDOW HANDLING
AddManualWindowBorder(hwnd) {
    global Config, g
    try {
        ; Skip if already exists
        if (g["ManualWindows"].Has(hwnd))
            return

        ; Create GUI with unique name
        borderGui := Gui("+ToolWindow -Caption +E0x20 +LastFound +AlwaysOnTop +E0x08000000")
        borderGui.Opt("+Owner" hwnd)  ; Set owner to prevent stealing focus
        borderGui.BackColor := Config["ManualWindowColor"]

        ; Position border around window
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        borderGui.Show("x" x-2 " y" y-2 " w" w+4 " h" h+4 " NA")

        ; Set transparency
        WinSetTransparent(Config["ManualWindowAlpha"], borderGui.Hwnd)
        WinSetTransColor(Config["ManualWindowColor"] " " Config["ManualWindowAlpha"], borderGui.Hwnd)

        ; Try blur effect (Windows 10/11)
        try {
            bbStruct := Buffer(20, 0)
            NumPut("UInt", 1, bbStruct, 0)  ; dwFlags - DWM_BB_ENABLE
            NumPut("Int", 1, bbStruct, 4)   ; fEnable
            DllCall("dwmapi\DwmEnableBlurBehindWindow", "Ptr", borderGui.Hwnd, "Ptr", bbStruct.Ptr)
        }

        ; Store reference - using Map() instead of object literal
        g["ManualWindows"][hwnd] := Map(
            "gui", borderGui,
            "expire", A_TickCount + Config["ManualLockDuration"]
        )

    } catch as Err {
        OutputDebug("Border Error: " Err.Message "`n" Err.What "`n" Err.Extra)
    }
}

RemoveManualWindowBorder(hwnd) {
    global g
    try {
        if (g["ManualWindows"].Has(hwnd)) {
            g["ManualWindows"][hwnd]["gui"].Destroy()
            g["ManualWindows"].Delete(hwnd)
        }
    }
}

UpdateManualBorders() {
    global g, Config
    for hwnd, data in g["ManualWindows"].Clone() {
        try {
            ; Remove expired borders
            if (A_TickCount > data["expire"]) {
                RemoveManualWindowBorder(hwnd)
                continue
            }

            ; Update position
            if (WinExist("ahk_id " hwnd)) {
                WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
                data["gui"].Show("x" x-2 " y" y-2 " w" w+4 " h" h+4 " NA")
            } else {
                RemoveManualWindowBorder(hwnd)
            }
        }
    }
}

ClearManualFlags() {
    global g, Config
    for hwnd, expireTime in g["ManualWindows"].Clone() {
        if (A_TickCount > expireTime) {
            RemoveManualWindowBorder(hwnd)
            for win in g["Windows"] {
                if (win["hwnd"] == hwnd) {
                    win.Delete("ManualLock")
                    win.Delete("IsManual")
                    break
                }
            }
        }
    }
}

DragWindow() {
    global g, Config
    static isDragging := false

    if isDragging
        return

    MouseGetPos(&mx, &my, &winID)
    if (!SafeWinExist(winID)) {
        try {
            if (WinGetMinMax("ahk_id " winID) != 0)
                return
        }
        catch {
            return
        }
    }

    isDragging := true
    g["ActiveWindow"] := winID
    g["LastUserMove"] := A_TickCount
    
    ; Keep physics running during drag to allow dragged window to push other windows
    ; The physics will skip the dragged window itself but apply to all others

    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " winID)
        ; CRITICAL: Store original window dimensions to prevent any reshaping
        origW := w
        origH := h
        winCenterX := x + w/2
        winCenterY := y + h/2
        monNum := MonitorGetFromPoint(winCenterX, winCenterY)
        MonitorGet monNum, &mL, &mT, &mR, &mB

        for win in g["Windows"] {
            if (win["hwnd"] == winID) {
                ; Don't auto-lock Electron apps - they update their UI frequently
                if (!IsElectronApp(winID)) {
                    win["ManualLock"] := A_TickCount + Config["ManualLockDuration"]
                    win["IsManual"] := true
                    win["vx"] := 0
                    win["vy"] := 0
                    AddManualWindowBorder(winID)
                }
                win["monitor"] := monNum
                break
            }
        }

        offsetX := mx - x
        offsetY := my - y

        DllCall("winmm\timeBeginPeriod", "UInt", 1)

        while GetKeyState("LButton", "P") {
            MouseGetPos(&nx, &ny)
            newX := nx - offsetX
            newY := ny - offsetY

            ; Update monitor bounds based on current mouse position for seamless multi-monitor dragging
            ; This allows windows to be dragged freely across all monitors
            currentMonNum := MonitorGetFromPoint(nx, ny)
            if (currentMonNum) {
                try {
                    MonitorGet currentMonNum, &currML, &currMT, &currMR, &currMB
                    ; Use current monitor bounds for clamping, using original dimensions
                    newX := Max(currML + Config["MinMargin"], Min(newX, currMR - origW - Config["MinMargin"]))
                    newY := Max(currMT + Config["MinMargin"], Min(newY, currMB - origH - Config["MinMargin"]))
                } catch {
                    ; Fallback to original monitor bounds
                    newX := Max(mL + Config["MinMargin"], Min(newX, mR - origW - Config["MinMargin"]))
                    newY := Max(mT + Config["MinMargin"], Min(newY, mB - origH - Config["MinMargin"]))
                }
            } else {
                ; Fallback to original monitor bounds
                newX := Max(mL + Config["MinMargin"], Min(newX, mR - origW - Config["MinMargin"]))
                newY := Max(mT + Config["MinMargin"], Min(newY, mB - origH - Config["MinMargin"]))
            }

            ; CRITICAL: Explicitly pass original dimensions to prevent any reshaping
            try WinMove(newX, newY, origW, origH, "ahk_id " winID)
            
            ; CRITICAL: Verify window size hasn't changed (safety check)
            ; This catches any accidental resizing and immediately corrects it
            try {
                WinGetPos(,, &currW, &currH, "ahk_id " winID)
                if (currW != origW || currH != origH) {
                    ; Window was accidentally resized - restore original size immediately
                    WinMove(,, origW, origH, "ahk_id " winID)
                }
            }

            for win in g["Windows"] {
                if (win["hwnd"] == winID) {
                    win["x"] := newX
                    win["y"] := newY
                    win["targetX"] := newX
                    win["targetY"] := newY
                    win["lastMove"] := A_TickCount
                    ; CRITICAL: Zero velocity on every frame during drag to prevent physics interference
                    win["vx"] := 0
                    win["vy"] := 0
                    ; Update monitor tracking based on window position
                    if (currentMonNum) {
                        win["monitor"] := currentMonNum
                    }
                    break
                }
            }

            Sleep(1)
        }
    }
    catch {
    }
    isDragging := false
    DllCall("winmm\timeEndPeriod", "UInt", 1)

    ; Mark the window as just dragged to prevent smoothing lag
    for win in g["Windows"] {
        if (win["hwnd"] == winID) {
            win["JustDragged"] := A_TickCount
            
            ; Force zero velocity and sync final position to ensure window stays exactly where user placed it
            win["vx"] := 0
            win["vy"] := 0
            
            ; Get the final actual position of the window
            try {
                WinGetPos(&finalX, &finalY, &finalW, &finalH, "ahk_id " winID)
                win["x"] := finalX
                win["y"] := finalY
                win["targetX"] := finalX
                win["targetY"] := finalY
            }
            
            ; Ensure ManualLock is extended to keep window stationary
            if (!IsElectronApp(winID)) {
                win["ManualLock"] := A_TickCount + Config["ManualLockDuration"]
                win["IsManual"] := true
            }
            break
        }
    }

    ; Keep the window as active for longer to ensure it stays where placed
    ; Don't immediately reset to 0 - let it time out naturally
    g["LastUserMove"] := A_TickCount
    
    ; Physics were kept running during drag, so no need to resume them
}

ToggleArrangement() {
    global g
    g["ArrangementActive"] := !g["ArrangementActive"]
    if (g["ArrangementActive"]) {
        UpdateWindowStates()
        SetTimer(CalculateDynamicLayout, Config["PhysicsTimeStep"])
        SetTimer(ApplyWindowMovements, Config["VisualTimeStep"])
        ShowTooltip("Window Arrangement: ON")
    } else {
        SetTimer(CalculateDynamicLayout, 0)
        SetTimer(ApplyWindowMovements, 0)
        ShowTooltip("Window Arrangement: OFF")
    }
}

TogglePhysics() {
    global g
    g["PhysicsEnabled"] := !g["PhysicsEnabled"]
    if (g["PhysicsEnabled"]) {
        SetTimer(CalculateDynamicLayout, Config["PhysicsTimeStep"])
        ShowTooltip("Physics Engine: ON")
    } else {
        SetTimer(CalculateDynamicLayout, 0)
        ShowTooltip("Physics Engine: OFF")
    }
}

ToggleTimePhasing() {
    global g
    g["FairyDustEnabled"] := !g["FairyDustEnabled"]
    if (!g["FairyDustEnabled"]) {
        TimePhasing.CleanupEffects()
        SetTimer(TimePhasing.UpdateEchoes.Bind(TimePhasing), 0)
    } else {
        SetTimer(TimePhasing.UpdateEchoes.Bind(TimePhasing), g["TimePhasingConfig"]["EffectUpdateFrequency"])
    }
    ShowTooltip("Time Phasing Effects: " (g["FairyDustEnabled"] ? "ON" : "OFF"))
}

ToggleSeamlessMonitorFloat() {
    global Config, g
    Config["SeamlessMonitorFloat"] := !Config["SeamlessMonitorFloat"]

    if (Config["SeamlessMonitorFloat"]) {
        ; Update monitor bounds to use virtual desktop
        g["Monitor"] := GetVirtualDesktopBounds()
        ShowTooltip("Seamless Multi-Monitor Floating: ON - Windows can float across all monitors")
    } else {
        ; Revert to current monitor
        g["Monitor"] := GetCurrentMonitorInfo()
        ShowTooltip("Seamless Multi-Monitor Floating: OFF - Windows confined to current monitor")
    }

    ; Force update of all window states to apply new boundaries
    if (g["ArrangementActive"]) {
        UpdateWindowStates()
    }
}

ToggleWindowLock() {
    global g, Config
    try {
        focusedWindow := WinExist("A")
        if (!focusedWindow) {
            ShowTooltip("No active window to lock/unlock")
            return
        }

        ; Find the window in our managed windows
        targetWin := 0
        for win in g["Windows"] {
            if (win["hwnd"] == focusedWindow) {
                targetWin := win
                break
            }
        }

        if (!targetWin) {
            ShowTooltip("Window is not managed by the floating system")
            return
        }

        ; Toggle lock status
        isCurrentlyLocked := (targetWin.Has("ManualLock") && A_TickCount < targetWin["ManualLock"])
        if (isCurrentlyLocked) {
            ; Unlock the window
            if (targetWin.Has("ManualLock"))
                targetWin.Delete("ManualLock")
            g["ActiveWindow"] := 0
            RemoveManualWindowBorder(focusedWindow)
            ShowTooltip("Window UNLOCKED - will move with physics")
        } else {
            ; Lock the window
            targetWin["ManualLock"] := A_TickCount + Config["ManualLockDuration"]
            g["ActiveWindow"] := focusedWindow
            g["LastUserMove"] := A_TickCount
            ; Stop the window's movement immediately
            targetWin["vx"] := 0
            targetWin["vy"] := 0
            AddManualWindowBorder(focusedWindow)
            ShowTooltip("Window LOCKED - will stay in place")
        }
    }
    catch {
        ShowTooltip("Error: Could not lock/unlock window")
    }
}

OptimizeWindowPositions() {
    global g, Config

    if (g["Windows"].Length <= 1) {
        ShowTooltip("Not enough windows to optimize")
        return
    }

    ; Get current monitor info
    monitor := GetCurrentMonitorInfo()
    if (!monitor.Count) {
        ShowTooltip("Could not get monitor information")
        return
    }

    ; Create a copy of windows for repositioning
    windowsToPlace := []
    for win in g["Windows"] {
        ; Skip locked or active windows
        isLocked := (win["hwnd"] == g["ActiveWindow"] ||
                    (win.Has("ManualLock") && A_TickCount < win["ManualLock"]))
        if (!isLocked) {
            windowsToPlace.Push(win)
        }
    }

    if (windowsToPlace.Length == 0) {
        ShowTooltip("All windows are locked - nothing to optimize")
        return
    }

    ; Manual sort by area (largest first)
    Loop windowsToPlace.Length - 1 {
        i := A_Index
        Loop windowsToPlace.Length - i {
            j := A_Index
            if (windowsToPlace[j]["area"] < windowsToPlace[j + 1]["area"]) {
                temp := windowsToPlace[j]
                windowsToPlace[j] := windowsToPlace[j + 1]
                windowsToPlace[j + 1] := temp
            }
        }

    }

    ; Find optimal positions using space-efficient packing
    optimizedPositions := PackWindowsOptimally(windowsToPlace, monitor)

    ; Apply optimized positions
    repositionedCount := 0
    for i, win in windowsToPlace {
        if (optimizedPositions.Has(i)) {
            newPos := optimizedPositions[i]
            win["targetX"] := newPos["x"]
            win["targetY"] := newPos["y"]
            ; Add some velocity toward the target for smooth movement
            win["vx"] := (newPos["x"] - win["x"]) * 0.1
            win["vy"] := (newPos["y"] - win["y"]) * 0.1
            repositionedCount++
        }
    }

    ShowTooltip("Optimized " repositionedCount " window positions for better space utilization")

}

; Advanced space packing algorithm to find optimal window positions
PackWindowsOptimally(windows, monitor) {
    if (windows.Length == 0)
        return Map()

    positions := Map()
    placedWindows := []
    gridSize := 50  ; pixels per grid cell (tune for your window sizes)

    for i, win in windows {
        ; Calculate usable area for this window
        useableLeft := monitor["Left"] + Config["MinMargin"]
        useableTop := monitor["Top"] + Config["MinMargin"]
        useableRight := monitor["Right"] - Config["MinMargin"] - win["width"]
        useableBottom := monitor["Bottom"] - Config["MinMargin"] - win["height"]
        useableWidth := useableRight - useableLeft
        useableHeight := useableBottom - useableTop
        gridCols := Floor(useableWidth / gridSize)
        gridRows := Floor(useableHeight / gridSize)

        ; CRITICAL: NEVER change window dimensions - windows should maintain their original size
        ; Place windows even if partially off-screen, or skip if they don't fit at all
        bestPos := FindBestPosition(win, placedWindows, monitor, gridSize, gridCols, gridRows)
        if (bestPos.Count > 0) {
            positions[i] := bestPos
            placedWindows.Push(Map(
                "x", bestPos["x"],
                "y", bestPos["y"],
                "width", win["width"],
                "height", win["height"],
                "hwnd", win["hwnd"]
            ))
        }
    }

    return positions
}

; Find the best position for a window considering existing windows and available space
FindBestPosition(window, placedWindows, monitor, gridSize, gridCols, gridRows) {
    useableLeft := monitor["Left"] + Config["MinMargin"]
    useableTop := monitor["Top"] + Config["MinMargin"]
    useableRight := monitor["Right"] - Config["MinMargin"] - window["width"]
    useableBottom := monitor["Bottom"] - Config["MinMargin"] - window["height"]

    bestPos := Map()
    bestScore := -999999

    ; Try multiple placement strategies
    strategies := [
        "topLeft",      ; Pack from top-left
        "center",       ; Try near center first
        "edges",        ; Prefer screen edges
        "gaps"                   ; Fill gaps between existing windows
    ]

    for strategy in strategies {
        candidatePositions := GeneratePositionCandidates(window, placedWindows, monitor, strategy)

        for pos in candidatePositions {
            ; Ensure position is within bounds
            if (pos["x"] < useableLeft || pos["x"] > useableRight ||
                pos["y"] < useableTop || pos["y"] > useableBottom)
                continue

            ; --- Resize window height if it would exceed monitor bottom margin ---
            tempHeight := window["height"]
            if (pos["y"] + tempHeight > monitor["Bottom"] - Config["MinMargin"]) {
                tempHeight := Max(80, monitor["Bottom"] - Config["MinMargin"] - pos["y"])
            }

            ; Check if position overlaps with existing windows
            testWindow := Map(
                "x", pos["x"], "y", pos["y"],
                "width", window["width"], "height", tempHeight,
                "hwnd", window["hwnd"]
            )

            if (!IsOverlapping(testWindow, placedWindows)) {
                score := ScorePosition(pos, window, placedWindows, monitor, strategy)
                if (score > bestScore) {
                    bestScore := score
                    bestPos := pos.Clone()
                    bestPos["height"] := tempHeight ; Store adjusted height
                }
            }
        }

        ; If we found a good position, use it
        if (bestPos.Count > 0 && bestScore > 0)
            break
    }

    return bestPos
}

; Generate candidate positions based on different strategies
GeneratePositionCandidates(window, placedWindows, monitor, strategy) {
    candidates := []
    useableLeft := monitor["Left"] + Config["MinMargin"]
    useableTop := monitor["Top"] + Config["MinMargin"]
    useableRight := monitor["Right"] - Config["MinMargin"] - window["width"]
    useableBottom := monitor["Bottom"] - Config["MinMargin"] - window["height"]

    switch strategy {
        case "topLeft":
            ; Grid-based placement from top-left
            stepX := 60
            stepY := 60
            posY := useableTop
            while (posY <= useableBottom) {
                posX := useableLeft
                while (posX <= useableRight) {
                    candidates.Push(Map("x", posX, "y", posY))
                    if (candidates.Length > 100)
                        return candidates
                    posX += stepX
                }
                posY += stepY
            }
        case "center":
            ; Spiral outward from center
            centerX := monitor["CenterX"] - window["width"]/2
            centerY := monitor["CenterY"] - window["height"]/2
            candidates.Push(Map("x", centerX, "y", centerY))
            maxSpiralRadius := 300
            spiralRadius := 50
            while (spiralRadius <= maxSpiralRadius) {
                spiralAngles := Max(8, Floor(spiralRadius / 25))
                spiralAngleStep := 1
                while (spiralAngleStep <= spiralAngles) {
                    angle := (spiralAngleStep - 1) * (2 * 3.14159 / spiralAngles)
                    posX := centerX + spiralRadius * Cos(angle)
                    posY := centerY + spiralRadius * Sin(angle)
                    if (posX >= useableLeft && posX <= useableRight && posY >= useableTop && posY <= useableBottom)
                        candidates.Push(Map("x", posX, "y", posY))
                    spiralAngleStep++
                }
                spiralRadius += 50
            }
        case "edges":
            ; Prefer positions along screen edges
            margin := 20
            ; Top edge
            posX := useableLeft
            while (posX <= useableRight) {
                candidates.Push(Map("x", posX, "y", useableTop))
                posX += 80
            }
            ; Left edge
            posY := useableTop
            while (posY <= useableBottom) {
                candidates.Push(Map("x", useableLeft, "y", posY))
                posY += 80
            }
            ; Right edge
            posY := useableTop
            while (posY <= useableBottom) {
                candidates.Push(Map("x", useableRight, "y", posY))
                posY += 80
            }
            ; Bottom edge
            posX := useableLeft
            while (posX <= useableRight) {
                candidates.Push(Map("x", posX, "y", useableBottom))
                posX += 80
            }
        case "gaps":
            ; Fill gaps between existing windows
            if (placedWindows.Length > 0) {
                for placed in placedWindows {
                    adjacentPositions := [
                        Map("x", placed["x"] + placed["width"] + Config["MinGap"], "y", placed["y"]),
                        Map("x", placed["x"] - window["width"] - Config["MinGap"], "y", placed["y"]),
                        Map("x", placed["x"], "y", placed["y"] + placed["height"] + Config["MinGap"]),
                        Map("x", placed["x"], "y", placed["y"] - window["height"] - Config["MinGap"])
                    ]
                    for pos in adjacentPositions {
                        if (pos["x"] >= useableLeft && pos["x"] <= useableRight &&
                            pos["y"] >= useableTop && pos["y"] <= useableBottom)
                            candidates.Push(pos)
                    }
                }
            }
    }
    ; Optimize: Remove duplicate positions
    unique := Map()
    for pos in candidates {
        key := pos["x"] "," pos["y"]
        if !unique.Has(key)
            unique[key] := pos
    }
    ; Return all values as an array
    arr := []
    for _, v in unique
        arr.Push(v)
    return arr
}

; Score a position based on various criteria
ScorePosition(pos, window, placedWindows, monitor, strategy) {
    score := 1000
    centerX := monitor["CenterX"]
    centerY := monitor["CenterY"]
    distFromCenter := Sqrt((pos["x"] + window["width"]/2 - centerX)**2 + (pos["y"] + window["height"]/2 - centerY)**2)

    switch strategy {
        case "center":
            score -= distFromCenter * 0.5
        case "edges":
            score += distFromCenter * 0.3
        case "topLeft":
            score -= (pos["x"] + pos["y"]) * 0.1
    }

    for placed in placedWindows {
        centerDist := Sqrt((pos["x"] + window["width"]/2 - placed["x"] - placed["width"]/2)**2 +
                          (pos["y"] + window["height"]/2 - placed["y"] - placed["height"]/2)**2)
        if (centerDist < 100)
            score -= (100 - centerDist) * 2
        else if (centerDist > 200)
            score += 50
    }

    margin := Config["MinMargin"]
    if (pos["x"] > monitor["Left"] + margin && pos["x"] < monitor["Right"] - window["width"] - margin &&
        pos["y"] > monitor["Top"] + margin && pos["y"] < monitor["Bottom"] - window["height"] - margin)
        score += 200

    return score
}

; Calculate force to move windows toward less crowded areas of the screen
CalculateSpaceSeekingForce(win, allWindows) {
    if (allWindows.Length <= 2)
        return Map()  ; Not enough windows to need space seeking

    ; Get current monitor bounds
    try {
        MonitorGet win["monitor"], &mL, &mT, &mR, &mB
    } catch {
        return Map()
    }

    winCenterX := win["x"] + win["width"]/2
    winCenterY := win["y"] + win["height"]/2

    ; Calculate local density around this window
    densityRadius := 250  ; pixels
    localDensity := 0

    for other in allWindows {
        if (other["hwnd"] == win["hwnd"])
            continue

        otherCenterX := other["x"] + other["width"]/2
        otherCenterY := other["y"] + other["height"]/2
        dist := Sqrt((winCenterX - otherCenterX)**2 + (winCenterY - otherCenterY)**2)

        if (dist < densityRadius) {
            ; Weight by window size and proximity
            proximityWeight := (densityRadius - dist) / densityRadius
            sizeWeight := Sqrt(other["width"] * other["height"]) / 1000
            localDensity += proximityWeight * sizeWeight
        }
    }

    ; If not crowded, no space seeking needed
    if (localDensity < 2.0)
        return Map()

    ; Find direction toward less crowded space
    bestDirection := FindLeastCrowdedDirection(win, allWindows, mL, mT, mR, mB)

    if (bestDirection.Count == 0)
        return Map()

    ; Calculate force magnitude based on crowding level
    forceMagnitude := Min(localDensity - 2.0, 3.0)  ; Cap the force

    return Map(
        "vx", bestDirection["x"] * forceMagnitude,
        "vy", bestDirection["y"] * forceMagnitude
    )
}

; Find the direction with the least window density
FindLeastCrowdedDirection(win, allWindows, mL, mT, mR, mB) {
    winCenterX := win["x"] + win["width"]/2
    winCenterY := win["y"] + win["height"]/2

    ; Test 8 directions around the window
    directions := [
        Map("x", 0, "y", -1),    ; North
        Map("x", 1, "y", -1),    ; Northeast
        Map("x", 1, "y", 0),     ; East
        Map("x", 1, "y", 1),     ; Southeast
        Map("x", 0, "y", 1),     ; South
        Map("x", -1, "y", 1),    ; Southwest
        Map("x", -1, "y", 0),    ; West
        Map("x", -1, "y", -1)    ; Northwest
    ]

    bestDirection := Map()
    lowestDensity := 999999
    searchDistance := 300  ; How far to look ahead - increased for better space utilization

    for dir in directions {
        ; Calculate test point in this direction
        testX := winCenterX + dir["x"] * searchDistance
        testY := winCenterY + dir["y"] * searchDistance

        ; Skip if test point would be outside screen bounds
        if (testX < mL + win["width"]/2 || testX > mR - win["width"]/2 ||
            testY < mT + win["height"]/2 || testY > mB - win["height"]/2)
            continue

        ; Calculate density at test point
        density := CalculateDensityAtPoint(testX, testY, allWindows, win["hwnd"])

        if (density < lowestDensity) {
            lowestDensity := density
            bestDirection := dir.Clone()
        }
    }

    return bestDirection
}

; Calculate window density at a specific point
CalculateDensityAtPoint(testX, testY, allWindows, excludeHwnd := 0) {
    density := 0
    influenceRadius := 200  ; Increased for better space distribution

    for win in allWindows {
        if (excludeHwnd != 0 && win["hwnd"] == excludeHwnd)
            continue

        winCenterX := win["x"] + win["width"]/2
        winCenterY := win["y"] + win["height"]/2
        dist := Sqrt((testX - winCenterX)**2 + (testY - winCenterY)**2)

        if (dist < influenceRadius) {
            ; Closer windows contribute more to density
            influence := (influenceRadius - dist) / influenceRadius
            sizeWeight := Sqrt(win["width"] * win["height"]) / 1000
            density += influence * sizeWeight
        }
    }

    return density
}

WindowMoveHandler(wParam, lParam, msg, hwnd) {
    global g, Config
    if (!g["ArrangementActive"] || (A_TickCount - g["LastUserMove"] < Config["ResizeDelay"]))
        return

    Critical
    g["LastUserMove"] := A_TickCount
    g["ActiveWindow"] := hwnd

    try {
        if (WinGetMinMax("ahk_id " hwnd) != 0)
            return
    }
    catch {
        return
    }

    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        winCenterX := x + w/2
        winCenterY := y + h/2
        monNum := MonitorGetFromPoint(winCenterX, winCenterY)

        for win in g["Windows"] {
            if (win["hwnd"] == hwnd) {
                ; Don't auto-lock Electron apps - they update their UI frequently
                if (!IsElectronApp(hwnd)) {
                    win["ManualLock"] := A_TickCount + Config["ManualLockDuration"]
                    win["IsManual"] := true
                    win["vx"] := 0
                    win["vy"] := 0
                    AddManualWindowBorder(hwnd)
                }
                win["monitor"] := monNum
                break
            }
        }
    }
    catch {
        return
    }

    SetTimer(UpdateWindowStates, -Config["ResizeDelay"])
}

WindowSizeHandler(wParam, lParam, msg, hwnd) {
    global g, Config
    if (!g["ArrangementActive"] || (A_TickCount - g["LastUserMove"] < Config["ResizeDelay"]))
        return

    Critical
    g["LastUserMove"] := A_TickCount
    g["ActiveWindow"] := hwnd

    try {
        if (WinGetMinMax("ahk_id " hwnd) != 0)
            return
    }
    catch {
        return
    }

    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        winCenterX := x + w/2
        winCenterY := y + h/2
        monNum := MonitorGetFromPoint(winCenterX, winCenterY)

        for win in g["Windows"] {
            if (win["hwnd"] == hwnd) {
                ; Don't auto-lock Electron apps - they update their UI frequently
                if (!IsElectronApp(hwnd)) {
                    win["ManualLock"] := A_TickCount + Config["ManualLockDuration"]
                    win["IsManual"] := true
                    win["vx"] := 0
                    win["vy"] := 0
                    AddManualWindowBorder(hwnd)
                }
                win["monitor"] := monNum
                break
            }
        }
    }
    catch {
        return
    }

    SetTimer(UpdateWindowStates, -Config["ResizeDelay"])
}

UpdateWindowStates() {
    global g, Config
    
    ; CRITICAL: Skip rebuilding window list if user is actively dragging a window
    ; This prevents interference with user placement
    if (GetKeyState("LButton", "P"))
        return
    
    ; Get current monitor info or virtual desktop bounds
    monitor := Config["SeamlessMonitorFloat"] ? GetVirtualDesktopBounds() : GetCurrentMonitorInfo()
    ; Update window list
    g["Windows"] := GetVisibleWindows(monitor)
    ; Update manual borders and clear expired flags
    UpdateManualBorders()
    ClearManualFlags()
}

; --- Improved Taskbar Detection and Context Menu ---

global TaskbarMenu := Menu()
TaskbarMenu.Add("Toggle Arrangement", (*) => ToggleArrangement())
TaskbarMenu.Add("Optimize Windows", (*) => OptimizeWindowPositions())
TaskbarMenu.Add("Toggle Physics", (*) => TogglePhysics())
TaskbarMenu.Add("Toggle Time Phasing", (*) => ToggleTimePhasing())
TaskbarMenu.Add("Toggle Seamless Float", (*) => ToggleSeamlessMonitorFloat())
TaskbarMenu.Add("Exit", (*) => ExitApp())

ShowTaskbarMenu() {
    rect := GetTaskbarRect()
    if (rect) {
        TaskbarMenu.Show(rect.left + 10, rect.top + 10)
    } else {
        TaskbarMenu.Show(10, 10)
    }
}

GetTaskbarRect() {
    hwnd := WinExist("ahk_class Shell_TrayWnd")
    if (hwnd && WinExist("ahk_id " hwnd)) {
        try {
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            return { left: x, top: y, right: x + w, bottom: y + h }
        } catch {
            ; fall through
        }
    }
    hwnd := WinExist("ahk_class RetroBarWnd")
    if (!hwnd)
        hwnd := WinExist("ahk_exe RetroBar.exe")
    if (hwnd && WinExist("ahk_id " hwnd)) {
        try {
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            return { left: x, top: y, right: x + w, bottom: y + h }
        } catch {
            ; fall through
        }
    }
    ; Try secondary taskbars (multi-monitor)
    hwnd := WinExist("ahk_class Shell_SecondaryTrayWnd")
    if (hwnd && WinExist("ahk_id " hwnd)) {
        try {
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            return { left: x, top: y, right: x + w, bottom: y + h }
        } catch {
            ; fall through
        }
    }
    ; If we cannot determine taskbar, return 0 to signal absence to callers
    return 0
}

; --- Debug function to show window information ---
DebugWindowInfo() {
    global g, Config
    
    ; Get all visible windows
    allWindows := []
    trackedWindows := []
    untrackedWindows := []
    
    ; Get current monitor for filtering
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)
    activeMonitor := MonitorGetFromPoint(mx, my)
    try {
        MonitorGet activeMonitor, &mL, &mT, &mR, &mB
    } catch {
        mL := 0, mT := 0, mR := A_ScreenWidth, mB := A_ScreenHeight
    }
    
    ; Check all windows
    for hwnd in WinGetList() {
        try {
            if (!SafeWinExist(hwnd))
                continue
                
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            if (w == 0 || h == 0)
                continue
                
            title := WinGetTitle("ahk_id " hwnd)
            winClass := WinGetClass("ahk_id " hwnd)
            processName := WinGetProcessName("ahk_id " hwnd)
            
            if (title == "" || title == "Program Manager")
                continue
                
            isPlugin := IsPluginWindow(hwnd)
            isFloating := IsWindowFloating(hwnd)
            isTracked := false
            
            ; Check if window is currently tracked
            for trackedWin in g["Windows"] {
                if (trackedWin["hwnd"] == hwnd) {
                    isTracked := true
                    break
                }
            }
            
            windowInfo := Map(
                "hwnd", hwnd,
                "title", title,
                "class", winClass,
                "process", processName,
                "x", x, "y", y, "width", w, "height", h,
                "isPlugin", isPlugin,
                "isFloating", isFloating,
                "isTracked", isTracked
            )
            
            allWindows.Push(windowInfo)
            
            if (isTracked) {
                trackedWindows.Push(windowInfo)
            } else if (isFloating || isPlugin) {
                untrackedWindows.Push(windowInfo)
            }
            
        } catch {
            continue
        }
    }
    
    ; Create debug message
    debugMsg := "=== FWDE WINDOW DEBUG ===`n`n"
    debugMsg .= "Arrangement Active: " . (g["ArrangementActive"] ? "YES" : "NO") . "`n"
    debugMsg .= "Total Windows: " . allWindows.Length . "`n"
    debugMsg .= "Tracked Windows: " . trackedWindows.Length . "`n"
    debugMsg .= "Untracked Floating Windows: " . untrackedWindows.Length . "`n`n"
    
    debugMsg .= "--- TRACKED WINDOWS ---`n"
    for win in trackedWindows {
        debugMsg .= "✓ " . win["title"] . " (" . win["class"] . ") [" . win["process"] . "]`n"
        debugMsg .= "  Size: " . win["width"] . "x" . win["height"] . " at " . win["x"] . "," . win["y"] . "`n"
    }
    
    debugMsg .= "`n--- UNTRACKED FLOATING WINDOWS ---`n"
    for win in untrackedWindows {
        debugMsg .= "✗ " . win["title"] . " (" . win["class"] . ") [" . win["process"] . "]`n"
        debugMsg .= "  Size: " . win["width"] . "x" . win["height"] . " at " . win["x"] . "," . win["y"] . "`n"
        debugMsg .= "  Plugin: " . (win["isPlugin"] ? "YES" : "NO") . " | Floating: " . (win["isFloating"] ? "YES" : "NO") . "`n"
    }
    
    debugMsg .= "`n--- CONFIG PATTERNS ---`n"
    debugMsg .= "ForceFloatProcesses: " . Config["ForceFloatProcesses"].Length . " patterns`n"
    debugMsg .= "FloatClassPatterns: " . Config["FloatClassPatterns"].Length . " patterns`n"
    debugMsg .= "FloatTitlePatterns: " . Config["FloatTitlePatterns"].Length . " patterns`n"
    
    ; Show tooltip with debug info
    ToolTip(debugMsg)
    SetTimer(() => ToolTip(), -10000)  ; Hide after 10 seconds
}

; --- Force add active window to tracking ---
ForceAddActiveWindow() {
    global g, Config
    
    hwnd := WinExist("A")
    if (!hwnd || !SafeWinExist(hwnd)) {
        ToolTip("No active window found!")
        SetTimer(() => ToolTip(), -2000)
        return
    }
    
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        title := WinGetTitle("ahk_id " hwnd)
        winClass := WinGetClass("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)
        
        if (w == 0 || h == 0) {
            ToolTip("Invalid window size!")
            SetTimer(() => ToolTip(), -2000)
            return
        }
        
        ; Check if already tracked
        for win in g["Windows"] {
            if (win["hwnd"] == hwnd) {
                ToolTip("Window already tracked: " . title)
                SetTimer(() => ToolTip(), -2000)
                return
            }
        }
        
        ; Get monitor info
        winCenterX := x + w/2
        winCenterY := y + h/2
        winMonitor := MonitorGetFromPoint(winCenterX, winCenterY)
        if (!winMonitor) {
            winMonitor := MonitorGetPrimary()
        }
        
        ; Add to tracking
        g["Windows"].Push(Map(
            "hwnd", hwnd,
            "x", x, "y", y,
            "width", w, "height", h,
            "area", w * h,
            "mass", w * h / 100000,
            "lastMove", 0,
            "vx", 0, "vy", 0,
            "targetX", x, "targetY", y,
            "monitor", winMonitor,
            "isPlugin", IsPluginWindow(hwnd),
            "lastSeen", A_TickCount,
            "lastZOrder", -1,
            "forced", true  ; Mark as manually added
        ))
        
        ToolTip("Added to tracking: " . title . " (" . winClass . ")")
        SetTimer(() => ToolTip(), -3000)
        
    } catch {
        ToolTip("Failed to add window to tracking!")
        SetTimer(() => ToolTip(), -2000)
    }
}

; --- Debug active window details ---
DebugActiveWindow() {
    global g, Config
    
    hwnd := WinExist("A")
    if (!hwnd) {
        ToolTip("No active window!")
        SetTimer(() => ToolTip(), -2000)
        return
    }
    
    try {
        title := WinGetTitle("ahk_id " hwnd)
        winClass := WinGetClass("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)
        style := WinGetStyle("ahk_id " hwnd)
        exStyle := WinGetExStyle("ahk_id " hwnd)
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        minMax := WinGetMinMax("ahk_id " hwnd)
        
        isPlugin := IsPluginWindow(hwnd)
        isFloating := IsWindowFloating(hwnd)
        isValid := IsWindowValid(hwnd)
        isFullscreen := IsFullscreenWindow(hwnd)
        
        debugMsg := "=== ACTIVE WINDOW DEBUG ===`n`n"
        debugMsg .= "Title: " . title . "`n"
        debugMsg .= "Class: " . winClass . "`n"
        debugMsg .= "Process: " . processName . "`n"
        debugMsg .= "Position: " . x . "," . y . " Size: " . w . "x" . h . "`n"
        debugMsg .= "Min/Max: " . minMax . "`n"
        debugMsg .= "Style: 0x" . Format("{:08X}", style) . "`n"
        debugMsg .= "ExStyle: 0x" . Format("{:08X}", exStyle) . "`n`n"
        
        debugMsg .= "--- DETECTION RESULTS ---`n"
        debugMsg .= "IsValid: " . (isValid ? "YES" : "NO") . "`n"
        debugMsg .= "IsPlugin: " . (isPlugin ? "YES" : "NO") . "`n"
        debugMsg .= "IsFloating: " . (isFloating ? "YES" : "NO") . "`n"
        debugMsg .= "IsFullscreen: " . (isFullscreen ? "YES" : "NO") . "`n`n"
        
        debugMsg .= "--- PATTERN CHECKS ---`n"
        
        ; Check ForceFloatProcesses
        debugMsg .= "ForceFloatProcesses: "
        for pattern in Config["ForceFloatProcesses"] {
            if (processName ~= "i)^" pattern "$") {
                debugMsg .= "MATCH (" . pattern . ") "
            }
        }
        debugMsg .= "`n"
        
        ; Check FloatClassPatterns
        debugMsg .= "FloatClassPatterns: "
        for pattern in Config["FloatClassPatterns"] {
            if (winClass ~= "i)" pattern) {
                debugMsg .= "MATCH (" . pattern . ") "
            }
        }
        debugMsg .= "`n"
        
        ; Check FloatTitlePatterns
        debugMsg .= "FloatTitlePatterns: "
        for pattern in Config["FloatTitlePatterns"] {
            if (title ~= "i)" pattern) {
                debugMsg .= "MATCH (" . pattern . ") "
            }
        }
        debugMsg .= "`n"
        
        ; Check style flags
        debugMsg .= "FloatStyles: " . ((style & Config["FloatStyles"]) != 0 ? "MATCH" : "NO MATCH") . "`n"
        debugMsg .= "WS_EX_TOOLWINDOW: " . ((exStyle & 0x80) ? "YES" : "NO") . "`n"
        debugMsg .= "WS_VISIBLE: " . ((style & 0x10000000) ? "YES" : "NO") . "`n"
        
        ToolTip(debugMsg)
        SetTimer(() => ToolTip(), -15000)  ; Show for 15 seconds
        
    } catch {
        ToolTip("Failed to get window details!")
        SetTimer(() => ToolTip(), -2000)
    }
}

; --- Hotkey to show the menu on right-click of the taskbar ---
^!T::ShowTaskbarMenu() ; Ctrl+Alt+T to show the upgraded taskbar menu

;HOTKEYS

^!Space::ToggleArrangement()      ; Ctrl+Alt+Space to toggle
^!P::TogglePhysics()              ; Ctrl+Alt+P for physics
^!F::ToggleTimePhasing()          ; Ctrl+Alt+F for time phasing effects
^!M::ToggleSeamlessMonitorFloat() ; Ctrl+Alt+M for seamless multi-monitor floating
^!O::OptimizeWindowPositions()    ; Ctrl+Alt+O to optimize
^!L::ToggleWindowLock()           ; Ctrl+Alt+L to lock/unlock active window
^!D::DebugWindowInfo()            ; Ctrl+Alt+D to debug window information
^!A::ForceAddActiveWindow()       ; Ctrl+Alt+A to force add active window
^!I::DebugActiveWindow()          ; Ctrl+Alt+I to debug active window details
 
; Start timers - but respect active window protection
SetTimer(UpdateWindowStates, Config["PhysicsTimeStep"])
SetTimer(ApplyWindowMovements, Config["VisualTimeStep"])
SetTimer(TimePhasing.UpdateEchoes.Bind(TimePhasing), g["TimePhasingConfig"]["EffectUpdateFrequency"])
UpdateWindowStates()

; Start physics calculations but only AFTER ensuring manual locks are respected
SetTimer(CalculateDynamicLayout, Config["PhysicsTimeStep"])      ; Only need this once

OnMessage(0x0003, WindowMoveHandler)
OnMessage(0x0005, WindowSizeHandler)

OnExit(*) {
    for hwnd in g["ManualWindows"]
        RemoveManualWindowBorder(hwnd)
    TimePhasing.CleanupEffects()
    DllCall("winmm\timeEndPeriod", "UInt", 1)
}

; ====== REQUIRED HELPER FUNCTIONS ======
MoveWindowAPI(hwnd, x, y, w := "", h := "") {
    ; CRITICAL: Always use SWP_NOSIZE to ensure window size is NEVER changed
    ; Flags: 0x0010 (SWP_NOACTIVATE) | 0x0004 (SWP_NOZORDER) | 0x0001 (SWP_NOSIZE)
    ; When SWP_NOSIZE is set, w and h parameters are ignored, so we can pass anything
    flags := 0x0010 | 0x0004 | 0x0001  ; SWP_NOACTIVATE | SWP_NOZORDER | SWP_NOSIZE
    if (w == "" || h == "")
        w := 0, h := 0  ; Not needed when SWP_NOSIZE is set, but required for function signature
    return DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", flags)
}

global PartitionGridSize := 400  ; pixels per grid cell (tune for your window sizes)

PartitionWindows(windows) {
    global PartitionGridSize
    buckets := Map()
    for win in windows {
        gx := Floor(win["x"] / PartitionGridSize)
        gy := Floor(win["y"] / PartitionGridSize)
        key := gx "," gy
        if !buckets.Has(key)
            buckets[key] := []
        buckets[key].Push(win)
        win["_grid"] := [gx, gy]
    }
    return buckets
}

; Add this Clamp helper function near the top-level (outside any class)
Clamp(val, min, max) {
    return val < min ? min : val > max ? max : val
}

; Z-index ordering: smaller windows on top so they don't get lost behind larger ones
; Only applies to DAW plugin windows to prevent flashing of regular windows
OrderWindowsBySize() {
    global g

    if (g["Windows"].Length <= 1)
        return

    ; Create array of DAW plugin windows with their areas, excluding active window
    windowAreas := []
    for win in g["Windows"] {
        if (win["hwnd"] != g["ActiveWindow"] && IsDAWPlugin(win)) {
            ; Double-check that window is not maximized/minimized before processing
            try {
                if (WinGetMinMax("ahk_id " win["hwnd"]) != 0)
                    continue
            } catch {
                continue
            }
            
            windowAreas.Push({
                hwnd: win["hwnd"],
                area: win["width"] * win["height"],
                lastZOrder: win.Has("lastZOrder") ? win["lastZOrder"] : 0
            })
        }
    }

    if (windowAreas.Length <= 1)
        return

    ; Sort by area (largest first) - manual bubble sort since AHK v2 arrays don't have built-in sort
    Loop windowAreas.Length - 1 {
        i := A_Index
        Loop windowAreas.Length - i {
            j := A_Index
            if (windowAreas[j].area < windowAreas[j + 1].area) {
                ; Swap elements
                temp := windowAreas[j]
                windowAreas[j] := windowAreas[j + 1]
                windowAreas[j + 1] := temp
            }
        }
    }

    ; Set Z-order for DAW plugin windows only: largest plugins at bottom, smallest at top
    ; This ensures tiny plugin windows are never hidden behind larger ones
    ; Use gentle reordering to prevent flashing
    for i, winData in windowAreas {
        try {
            ; Final safety check - ensure window is still valid and not maximized
            if (!SafeWinExist(winData.hwnd) || WinGetMinMax("ahk_id " winData.hwnd) != 0)
                continue
                
            ; Only reorder if the window's z-order actually needs to change
            newZOrder := (i <= windowAreas.Length // 2) ? 1 : 0  ; 1 for bottom, 0 for top

            if (winData.lastZOrder != newZOrder) {
                ; Use SWP_NOACTIVATE and SWP_NOMOVE to prevent flashing and focus changes
                ; 0x0010 = SWP_NOACTIVATE, 0x0002 = SWP_NOMOVE, 0x0001 = SWP_NOSIZE
                flags := 0x0010 | 0x0002 | 0x0001  ; Don't activate, move, or resize

                if (newZOrder == 1) {
                    ; Larger plugin windows go to bottom (HWND_BOTTOM = 1)
                    DllCall("SetWindowPos", "Ptr", winData.hwnd, "Ptr", 1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", flags)
                } else {
                    ; Smaller plugin windows stay on top (HWND_TOP = 0)
                    DllCall("SetWindowPos", "Ptr", winData.hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", flags)
                }

                ; Update the stored z-order for this window
                for win in g["Windows"] {
                    if (win["hwnd"] == winData.hwnd) {
                        win["lastZOrder"] := newZOrder
                        break
                    }
                }
            }
        }
        catch {
            continue
        }
    }
}

; Helper function to identify DAW plugin windows
IsDAWPlugin(win) {
    try {
        ; Use the consolidated IsPluginWindow function
        return IsPluginWindow(win["hwnd"])
    }
    catch {
        return false
    }
}

; Helper function to identify Electron-based applications
IsElectronApp(hwnd) {
    try {
        if (!SafeWinExist(hwnd))
            return false
            
        winClass := WinGetClass("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)
        
        ; Electron apps typically use Chrome_WidgetWin_1 class
        electronClasses := [
            "Chrome_WidgetWin_1",        ; Standard Electron/Chromium class
            "Chrome_WidgetWin_0",        ; Alternative Electron class
            "ElectronMainWindow",         ; Some Electron apps use this
            "CEF-OSC-WIDGET"             ; Chromium Embedded Framework
        ]
        
        ; Electron-based applications
        electronProcesses := [
            "cursor.exe",                ; Cursor editor
            "code.exe",                  ; VS Code
            "discord.exe",               ; Discord
            "slack.exe",                 ; Slack
            "spotify.exe",               ; Spotify
            "whatsapp.exe",              ; WhatsApp Desktop
            "telegram.exe",              ; Telegram Desktop
            "notion.exe",                ; Notion
            "obsidian.exe",              ; Obsidian
            "typora.exe",                ; Typora
            "hyper.exe",                 ; Hyper terminal
            "insomnia.exe",              ; Insomnia
            "postman.exe",               ; Postman
            "figma.exe",                 ; Figma Desktop
            "sketch.exe",                ; Sketch (if Electron-based)
            "atom.exe",                  ; Atom editor
            "vscode.exe"                 ; Alternative VS Code process name
        ]
        
        ; Check window class
        for electronClass in electronClasses {
            if (winClass == electronClass)
                return true
        }
        
        ; Check process name
        for process in electronProcesses {
            if (processName ~= "i)^" process "$")
                return true
        }
        
        return false
    }
    catch {
        return false
    }
}

; Old broken rendering system removed - now using proper GDI+ rendering in TimePhasing class