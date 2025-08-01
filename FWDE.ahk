#Requires AutoHotkey v2.0
#SingleInstance Force
#WinActivateForce
#Warn
#MaxThreadsPerHotkey 255
#MaxThreads 255
A_IconTip := "Floating Windows - Dynamic Equilibrium"
ProcessSetPriority("High")

; Enhanced debug logging system
global DebugLevel := 3  ; 0=None, 1=Error, 2=Warning, 3=Info, 4=Verbose, 5=Trace
global DebugToFile := true
global DebugFile := A_ScriptDir "\FWDE_Debug.log"

; Initialize debug log
DebugLog("SYSTEM", "FWDE Starting - Debug Level: " DebugLevel, 1)
DebugLog("SYSTEM", "Script Path: " A_ScriptFullPath, 2)
DebugLog("SYSTEM", "Working Directory: " A_WorkingDir, 2)

#DllLoad "gdi32.dll"
#DllLoad "user32.dll"
#DllLoad "dwmapi.dll" ; Desktop Composition API



; Pre-allocate memory buffers
global g_NoiseBuffer := Buffer(1024)
global g_PhysicsBuffer := Buffer(4096)

; CRITICAL FIX: Add missing global data structures for movement system
global hwndPos := Map()         ; Cache of current window positions
global smoothPos := Map()       ; Smooth interpolated positions
global lastPositions := Map()   ; Last applied positions for change detection
global moveBatch := []          ; Batch of pending movements
global PerfTimers := Map()      ; Performance monitoring timers

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
    "MinMargin", 0,
    "MinGap", 0,
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
    "ScreenshotPauseDuration", 5000, ; How long to pause system during screenshot operations (ms)
    "ScreenshotProcesses", [          ; Screenshot tools that trigger system pause
        "ShareX.exe",
        "ScreenToGif.exe", 
        "Greenshot.exe",
        "LightShot.exe",
        "Snagit32.exe",
        "SnippingTool.exe",
        "ms-screenclip.exe",
        "PowerToys.ScreenRuler.exe",
        "flameshot.exe",
        "obs64.exe",
        "obs32.exe"
    ],
    "ScreenshotWindowClasses", [      ; Window classes that indicate screenshot activity
        "GDI+ Hook Window Class",
        "CrosshairOverlay",
        "ScreenshotOverlay", 
        "CaptureOverlay",
        "SelectionOverlay",
        "SnipOverlay"
    ],
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
    "ScreenshotCheckInterval", 250    ; How often to check for screenshot activity (ms)
)

; Log configuration values
DebugLog("CONFIG", "Configuration loaded with " Config.Count " parameters", 2)
for key, value in Config {
    if (Type(value) = "Array") {
        DebugLog("CONFIG", key ": [Array with " value.Length " items]", 4)
    } else if (Type(value) = "Map") {
        DebugLog("CONFIG", key ": [Map with " value.Count " items]", 4)
    } else {
        DebugLog("CONFIG", key ": " String(value), 4)
    }
}

global g := Map(
    "Monitor", Config["SeamlessMonitorFloat"] ? GetVirtualDesktopBounds() : GetCurrentMonitorInfo(),
    "ArrangementActive", true,
    "LastUserMove", 0,
    "ActiveWindow", 0,
    "Windows", [],
    "PhysicsEnabled", true,
    "FairyDustEnabled", true,
    "ManualWindows", Map(),
    "SystemEnergy", 1,
    "ScreenshotPaused", false,        ; System pause state for screenshots
    "ScreenshotPauseUntil", 0,        ; When to resume after screenshot pause
    "LastScreenshotCheck", 0          ; Throttle screenshot detection
)

DebugLog("INIT", "Global state initialized. Monitor bounds: " g["Monitor"]["Left"] "," g["Monitor"]["Top"] " to " g["Monitor"]["Right"] "," g["Monitor"]["Bottom"], 2)

; Enhanced debug logging function
DebugLog(category, message, level := 3) {
    global DebugLevel, DebugToFile, DebugFile
    
    if (level > DebugLevel)
        return
    
    timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss.fff")
    levelName := ["", "ERROR", "WARN", "INFO", "VERBOSE", "TRACE"][level + 1]
    logMessage := timestamp " [" levelName "] " category ": " message
    
    ; Output to debug console
    OutputDebug(logMessage)
    
    ; Optional file logging
    if (DebugToFile) {
        try {
            FileAppend(logMessage "`n", DebugFile)
        }
    }
}

; Performance monitoring helpers
StartPerfTimer(name) {
    global PerfTimers := Map()
    PerfTimers[name] := A_TickCount
    DebugLog("PERF", "Timer started: " name, 5)
}

EndPerfTimer(name) {
    global PerfTimers
    if (!PerfTimers.Has(name))
        return 0
    elapsed := A_TickCount - PerfTimers[name]
    DebugLog("PERF", "Timer ended: " name " (" elapsed "ms)", elapsed > 50 ? 3 : 4)
    PerfTimers.Delete(name)
    return elapsed
}

SafeWinExist(hwnd) {
    try {
        result := WinExist("ahk_id " hwnd)
        DebugLog("WINDOW", "SafeWinExist(" hwnd "): " (result ? "exists" : "not found"), 5)
        return result
    }
    catch as e {
        DebugLog("WINDOW", "SafeWinExist(" hwnd ") error: " e.Message, 2)
        return 0
    }
}

IsWindowValid(hwnd) {
    DebugLog("VALIDATION", "Checking window validity for hwnd: " hwnd, 5)
    
    try {
        if (!SafeWinExist(hwnd)) {
            DebugLog("VALIDATION", "Window " hwnd " does not exist", 4)
            return false
        }

        try {
            minMax := WinGetMinMax("ahk_id " hwnd)
            if (minMax != 0) {
                DebugLog("VALIDATION", "Window " hwnd " is minimized/maximized (state: " minMax ")", 4)
                return false
            }
        }
        catch as e {
            DebugLog("VALIDATION", "Error getting MinMax for " hwnd ": " e.Message, 2)
            return false
        }

        try {
            title := WinGetTitle("ahk_id " hwnd)
            if (title == "" || title == "Program Manager") {
                DebugLog("VALIDATION", "Window " hwnd " has invalid title: '" title "'", 4)
                return false
            }
        }
        catch as e {
            DebugLog("VALIDATION", "Error getting title for " hwnd ": " e.Message, 2)
            return false
        }

        try {
            exStyle := WinGetExStyle("ahk_id " hwnd)
            style := WinGetStyle("ahk_id " hwnd)
            
            if (exStyle & 0x80) {
                DebugLog("VALIDATION", "Window " hwnd " has WS_EX_TOOLWINDOW style", 4)
                return false
            }

            if (!(style & 0x10000000)) {
                DebugLog("VALIDATION", "Window " hwnd " is not visible", 4)
                return false
            }
        }
        catch as e {
            DebugLog("VALIDATION", "Error getting styles for " hwnd ": " e.Message, 2)
            return false
        }

        DebugLog("VALIDATION", "Window " hwnd " is valid", 5)
        return true
    }
    catch as e {
        DebugLog("VALIDATION", "Unexpected error validating window " hwnd ": " e.Message, 1)
        return false
    }
}

Lerp(a, b, t) {
    return a + (b - a) * t
}

Clamp(value, min, max) {
    return Max(min, Min(value, max))
}

EaseOutCubic(t) {
    return 1 - (1 - t) ** 3
}

ShowTooltip_Main(text) {
    global g, Config
    ToolTip(text, g["Monitor"]["CenterX"] - 100, g["Monitor"]["Top"] + 20)
    SetTimer(() => ToolTip(), -Config["TooltipDuration"])
}

GetCurrentMonitorInfo() {
    DebugLog("MONITOR", "Getting current monitor info", 4)
    static lastPos := [0, 0], lastMonitor := Map()
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)

    if (Abs(mx - lastPos[1]) < 50 && Abs(my - lastPos[2]) < 50 && lastMonitor.Count) {
        DebugLog("MONITOR", "Using cached monitor info (mouse position unchanged)", 5)
        return lastMonitor
    }

    lastPos := [mx, my]
    DebugLog("MONITOR", "Mouse position: " mx "," my, 4)
    
    if (monNum := MonitorGetFromPoint(mx, my)) {
        MonitorGet monNum, &L, &T, &R, &B
        lastMonitor := Map(
            "Left", L, "Right", R, "Top", T, "Bottom", B,
            "Width", R - L, "Height", B - T, "Number", monNum,
            "CenterX", (R + L) // 2, "CenterY", (B + T) // 2
        )
        DebugLog("MONITOR", "Current monitor #" monNum ": " L "," T " to " R "," B " (size: " (R-L) "x" (B-T) ")", 3)
        return lastMonitor
    }
    
    DebugLog("MONITOR", "Could not determine monitor from mouse position, falling back to primary", 2)
    return GetPrimaryMonitorCoordinates()
}

MonitorGetFromPoint(x, y) {
    DebugLog("MONITOR", "Finding monitor for point " x "," y, 5)
    try {
        Loop MonitorGetCount() {
            MonitorGet A_Index, &L, &T, &R, &B
            if (x >= L && x < R && y >= T && y < B) {
                DebugLog("MONITOR", "Point " x "," y " is on monitor #" A_Index, 5)
                return A_Index
            }
        }
        DebugLog("MONITOR", "Point " x "," y " is not on any monitor", 2)
    }
    catch as e {
        DebugLog("MONITOR", "Error finding monitor for point " x "," y ": " e.Message, 1)
    }
    return 0
}

GetVirtualDesktopBounds() {
    DebugLog("MONITOR", "Getting virtual desktop bounds for seamless floating", 3)
    global Config

    if (!Config["SeamlessMonitorFloat"]) {
        DebugLog("MONITOR", "Seamless floating disabled, returning current monitor bounds", 4)
        return GetCurrentMonitorInfo()
    }

    try {
        minLeft := 999999, maxRight := -999999
        minTop := 999999, maxBottom := -999999
        monitorCount := MonitorGetCount()

        DebugLog("MONITOR", "Processing " monitorCount " monitors for virtual desktop", 4)

        Loop monitorCount {
            MonitorGet A_Index, &L, &T, &R, &B
            DebugLog("MONITOR", "Monitor #" A_Index ": " L "," T " to " R "," B, 5)
            minLeft := Min(minLeft, L)
            maxRight := Max(maxRight, R)
            minTop := Min(minTop, T)
            maxBottom := Max(maxBottom, B)
        }

        bounds := Map(
            "Left", minLeft, "Right", maxRight, "Top", minTop, "Bottom", maxBottom,
            "Width", maxRight - minLeft, "Height", maxBottom - minTop, "Number", 0,
            "CenterX", (maxRight + minLeft) // 2, "CenterY", (maxBottom + minTop) // 2
        )
        
        DebugLog("MONITOR", "Virtual desktop bounds: " minLeft "," minTop " to " maxRight "," maxBottom " (size: " (maxRight-minLeft) "x" (maxBottom-minTop) ")", 3)
        return bounds
    }
    catch as e {
        DebugLog("MONITOR", "Error getting virtual desktop bounds: " e.Message ", falling back to primary", 1)
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
                return

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
            return

        overlapX := Max(0, Min(window["x"] + window["width"], other["x"] + other["width"]) - Max(window["x"], other["x"]))
        overlapY := Max(0, Min(window["y"] + window["height"], other["y"] + other["height"]) - Max(window["y"], other["y"]))

        if (overlapX > Config["Stabilization"]["OverlapTolerance"] && overlapY > Config["Stabilization"]["OverlapTolerance"])
            return true
    }
    return false
}
IsPluginWindow(hwnd) {
    DebugLog("PLUGIN", "Checking if window " hwnd " is a plugin", 5)
    
    try {
        winClass := WinGetClass("ahk_id " hwnd)
        title := WinGetTitle("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)

        DebugLog("PLUGIN", "Window " hwnd " - Class: '" winClass "', Title: '" title "', Process: '" processName "'", 5)

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
                DebugLog("PLUGIN", "Window " hwnd " is from DAW process: " processName, 4)
                break
            }
        }

        ; If it's from a DAW process, check plugin patterns
        if (isDAWProcess) {
            ; Check window class patterns
            for pattern in pluginClasses {
                if (InStr(winClass, pattern)) {
                    DebugLog("PLUGIN", "Window " hwnd " matches plugin class pattern: " pattern, 3)
                    return true
                }
            }

            ; Check window title patterns
            for pattern in pluginTitlePatterns {
                if (InStr(title, pattern)) {
                    DebugLog("PLUGIN", "Window " hwnd " matches plugin title pattern: " pattern, 3)
                    return true
                }
            }

            ; Check for small window dimensions typical of plugin UIs
            try {
                WinGetPos(,, &w, &h, "ahk_id " hwnd)
                if (w < 800 && h < 600) {
                    DebugLog("PLUGIN", "Window " hwnd " has plugin-like dimensions: " w "x" h, 4)
                    return true
                }
            }
            catch as e {
                DebugLog("PLUGIN", "Error getting dimensions for window " hwnd ": " e.Message, 2)
            }
        } else {
            ; For non-DAW processes, use basic patterns
            if (winClass ~= "i)(Vst|JS|Plugin|Float|Dock)") {
                DebugLog("PLUGIN", "Window " hwnd " matches basic plugin class pattern", 4)
                return true
            }
            if (title ~= "i)(VST|JS:|Plugin|FX)") {
                DebugLog("PLUGIN", "Window " hwnd " matches basic plugin title pattern", 4)
                return true
            }
        }

        DebugLog("PLUGIN", "Window " hwnd " is not a plugin", 5)
        return false
    }
    catch as e {
        DebugLog("PLUGIN", "Error checking plugin status for window " hwnd ": " e.Message, 1)
        return false
    }
}

IsWindowFloating(hwnd) {
    global Config
    DebugLog("FLOATING", "Checking if window " hwnd " should float", 5)

    ; Basic window existence check
    if (!SafeWinExist(hwnd)) {
        DebugLog("FLOATING", "Window " hwnd " does not exist", 4)
        return false
    }

    try {
        ; Skip minimized/maximized windows
        minMax := WinGetMinMax("ahk_id " hwnd)
        if (minMax != 0) {
            DebugLog("FLOATING", "Window " hwnd " is minimized/maximized (state: " minMax ")", 4)
            return false
        }

        ; Get window properties
        title := WinGetTitle("ahk_id " hwnd)
        if (title == "" || title == "Program Manager") {
            DebugLog("FLOATING", "Window " hwnd " has invalid title: '" title "'", 4)
            return false
        }

        winClass := WinGetClass("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)
        
        ; Get window styles
        style := WinGetStyle("ahk_id " hwnd)
        exStyle := WinGetExStyle("ahk_id " hwnd)

        DebugLog("FLOATING", "Window " hwnd " analysis - Class: '" winClass "', Process: '" processName "', Title: '" SubStr(title, 1, 30) "...'", 4)

        ; Allow more windows to float by default (less restrictive)
        if (title != "" && winClass != "WorkerW" && winClass != "Shell_TrayWnd" 
            && winClass != "Progman" && title != "Start" && !InStr(winClass, "TaskListThumbnailWnd")) {
            DebugLog("FLOATING", "Window " hwnd " passes basic floating criteria", 4)
            return true
        }

        ; Keep all the other checks as fallback
        ; 1. First check for forced processes (simplified)
        for pattern in Config["ForceFloatProcesses"] {
            if (processName ~= "i)^" pattern "$") {  ; Exact match with case insensitivity
                DebugLog("FLOATING", "Window " hwnd " matches forced float process: " pattern, 3)
                return true
            }
        }

        ; 2. Special cases that should always float
        if (winClass == "ConsoleWindowClass" || winClass == "CASCADIA_HOSTING_WINDOW_CLASS") {
            DebugLog("FLOATING", "Window " hwnd " is console/terminal window", 3)
            return true  ; CMD and Windows Terminal
        }

        ; 3. Plugin window detection (basic but effective)
        if (winClass ~= "i)(Vst|JS|Plugin|Float)") {
            DebugLog("FLOATING", "Window " hwnd " matches plugin class pattern", 3)
            return true
        }

        if (title ~= "i)(VST|JS:|Plugin|FX)") {
            DebugLog("FLOATING", "Window " hwnd " matches plugin title pattern", 3)
            return true
        }

        ; 4. Standard floating window checks
        if (exStyle & 0x80) { ; WS_EX_TOOLWINDOW
            DebugLog("FLOATING", "Window " hwnd " has tool window style", 4)
            return true
        }

        if (!(style & 0x10000000)) { ; WS_VISIBLE
            DebugLog("FLOATING", "Window " hwnd " is not visible", 4)
            return true
        }

        ; 5. Check class patterns from config
        for pattern in Config["FloatClassPatterns"] {
            if (winClass ~= "i)" pattern) {
                DebugLog("FLOATING", "Window " hwnd " matches config class pattern: " pattern, 3)
                return true
            }
        }

        ; 6. Check title patterns from config
        for pattern in Config["FloatTitlePatterns"] {
            if (title ~= "i)" pattern) {
                DebugLog("FLOATING", "Window " hwnd " matches config title pattern: " pattern, 3)
                return true
            }
        }

        ; 7. Final style check
        styleCheck := (style & Config["FloatStyles"]) != 0
        if (styleCheck) {
            DebugLog("FLOATING", "Window " hwnd " matches float styles", 4)
        } else {
            DebugLog("FLOATING", "Window " hwnd " does not qualify for floating", 5)
        }
        return styleCheck
    }
    catch as e {
        DebugLog("FLOATING", "Error checking floating status for window " hwnd ": " e.Message, 1)
        return false
    }
}



GetVisibleWindows(monitor) {
    global Config, g
    DebugLog("WINDOWS", "Getting visible windows for monitor", 4)
    StartPerfTimer("GetVisibleWindows")
    
    WinList := []
    allWindows := []
    windowCount := 0
    validCount := 0
    pluginCount := 0
    
    hwndList := WinGetList()
    DebugLog("WINDOWS", "Processing " hwndList.Length " total windows", 3)
    
    for hwnd in hwndList {
        windowCount++
        try {
            ; Skip invalid windows
            if (!IsWindowValid(hwnd)) {
                DebugLog("WINDOWS", "Window " hwnd " failed validation", 5)
                return
            }
            validCount++

            ; Get window properties
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            if (w == 0 || h == 0) {
                DebugLog("WINDOWS", "Window " hwnd " has zero dimensions: " w "x" h, 4)
                continue
            }

            ; Special handling for plugin windows
            isPlugin := IsPluginWindow(hwnd)
            if (isPlugin) {
                pluginCount++
            }

            ; Force include plugin windows or check floating status
            if (isPlugin || IsWindowFloating(hwnd)) {
                allWindows.Push(Map(
                    "hwnd", hwnd,
                    "x", x, "y", y,
                    "width", w, "height", h,
                    "isPlugin", isPlugin,
                    "lastSeen", A_TickCount
                ))
                DebugLog("WINDOWS", "Added window " hwnd " (" w "x" h " at " x "," y ") - Plugin: " (isPlugin ? "Yes" : "No"), 5)
            } else {
                DebugLog("WINDOWS", "Skipped window " hwnd " (not floating)", 5)
            }
        }
        catch as e {
            DebugLog("WINDOWS", "Error processing window " hwnd ": " e.Message, 2)
            continue
        }
    }

    DebugLog("WINDOWS", "Window analysis: " windowCount " total, " validCount " valid, " allWindows.Length " candidates, " pluginCount " plugins", 3)

    ; Get current mouse position for monitor check
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)
    activeMonitor := MonitorGetFromPoint(mx, my)
    includedCount := 0
    excludedCount := 0

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
                DebugLog("WINDOWS", "Could not determine monitor for window " window["hwnd"] ", using primary", 2)
            }

            ; Check if window should be included based on floating mode
            includeWindow := false

            if (Config["SeamlessMonitorFloat"]) {
                ; In seamless mode, include all windows from all monitors
                includeWindow := true
                DebugLog("WINDOWS", "Window " window["hwnd"] " included (seamless mode)", 5)
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
                if (includeWindow) {
                    reason := winMonitor == monitor["Number"] ? "on current monitor" : (isTracked ? "already tracked" : "is plugin")
                    DebugLog("WINDOWS", "Window " window["hwnd"] " included (" reason ")", 5)
                } else {
                    DebugLog("WINDOWS", "Window " window["hwnd"] " excluded (wrong monitor: " winMonitor " vs " monitor["Number"] ")", 5)
                }
            }

            if (includeWindow) {
                includedCount++
                ; Apply margin constraints based on floating mode
                if (Config["SeamlessMonitorFloat"]) {
                    ; Use virtual desktop bounds for seamless floating
                    virtualBounds := GetVirtualDesktopBounds()
                    safeArea := GetSafeArea(virtualBounds)
                    window["x"] := Clamp(window["x"], safeArea["Left"] + Config["MinMargin"], safeArea["Right"] - window["width"] - Config["MinMargin"])
                    window["y"] := Clamp(window["y"], safeArea["Top"] + Config["MinMargin"], safeArea["Bottom"] - window["height"] - Config["MinMargin"])
                } else {
                    safeArea := GetSafeArea(Map("Left", mL, "Top", mT, "Right", mR, "Bottom", mB))
                    window["x"] := Clamp(window["x"], safeArea["Left"] + Config["MinMargin"], safeArea["Right"] - window["width"] - Config["MinMargin"])
                    window["y"] := Clamp(window["y"], safeArea["Top"] + Config["MinMargin"], safeArea["Bottom"] - window["height"] - Config["MinMargin"])
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
                newWin := Map(
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
                )
                
                WinList.Push(newWin)

                ; Add time-phasing echo for plugin windows
                if (window["isPlugin"] && g["FairyDustEnabled"]) {
                    TimePhasing.AddEcho(window["hwnd"])
                }
            } else {
                excludedCount++
            }
        }
        catch as e {
            DebugLog("WINDOWS", "Error processing window " window["hwnd"] " for inclusion: " e.Message, 2)
            continue
        }
    }

    DebugLog("WINDOWS", "Final result: " includedCount " included, " excludedCount " excluded from " allWindows.Length " candidates", 3)

    ; Clean up windows that are no longer valid
    CleanupStaleWindows()

    elapsed := EndPerfTimer("GetVisibleWindows")
    DebugLog("WINDOWS", "GetVisibleWindows completed in " elapsed "ms", 3)
    return WinList
}

CleanupStaleWindows() {
    global g
    DebugLog("CLEANUP", "Starting stale window cleanup", 4)
    threshold := 5000 ; 5 seconds
    cleaned := 0

    ; FIXED: Use proper loop without undefined variable 'i'
    windowsToRemove := []
    
    ; First pass: identify stale windows
    for index, win in g["Windows"] {
        if (A_TickCount - win["lastSeen"] > threshold && !SafeWinExist(win["hwnd"])) {
            DebugLog("CLEANUP", "Marking stale window " win["hwnd"] " for removal (last seen " (A_TickCount - win["lastSeen"]) "ms ago)", 3)
            windowsToRemove.Push(index)
            if (g["ManualWindows"].Has(win["hwnd"])) {
                RemoveManualWindowBorder(win["hwnd"])
            }
            cleaned++
        }
    }
    
    ; Second pass: remove stale windows (reverse order to maintain indices)
    Loop windowsToRemove.Length {
        index := windowsToRemove[windowsToRemove.Length - A_Index + 1]
        g["Windows"].RemoveAt(index)
    }
    
    if (cleaned > 0) {
        DebugLog("CLEANUP", "Cleaned up " cleaned " stale windows", 3)
    } else {
        DebugLog("CLEANUP", "No stale windows found", 4)
    }
}

class TimePhasing {
    static echoes := Map()
    static lastCleanup := 0

    static AddEcho(hwnd) {
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
    }

    static UpdateEchoes() {
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
    }

    static CleanupEffects() {
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

    ; Check for manual lock (window should not move by physics)
    isManuallyLocked := (win.Has("ManualLock") && A_TickCount < win["ManualLock"])
    if (isManuallyLocked) {
        win["vx"] := 0
        win["vy"] := 0
        win["targetX"] := win["x"]
        win["targetY"] := win["y"]
        return
    }

    ; Keep active window and recently moved windows still
    isActiveWindow := (win["hwnd"] == g["ActiveWindow"])
    isRecentlyMoved := (A_TickCount - g["LastUserMove"] < Config["UserMoveTimeout"])
    isCurrentlyFocused := (win["hwnd"] == WinExist("A"))

    if (isActiveWindow || isRecentlyMoved && isCurrentlyFocused) {
        win["vx"] := 0
        win["vy"] := 0
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
    spaceForce := CalculateSpaceSeekingForce(win, allWindows)
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

ShowTooltip(text) {
    global g, Config
    ToolTip(text, g["Monitor"]["CenterX"] - 100, g["Monitor"]["Top"] + 20)
    SetTimer(() => ToolTip(), -Config["TooltipDuration"])
}

GetCurrentMonitorInfo() {
    DebugLog("MONITOR", "Getting current monitor info", 4)
    static lastPos := [0, 0], lastMonitor := Map()
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)

    if (Abs(mx - lastPos[1]) < 50 && Abs(my - lastPos[2]) < 50 && lastMonitor.Count) {
        DebugLog("MONITOR", "Using cached monitor info (mouse position unchanged)", 5)
        return lastMonitor
    }

    lastPos := [mx, my]
    DebugLog("MONITOR", "Mouse position: " mx "," my, 4)
    
    if (monNum := MonitorGetFromPoint(mx, my)) {
        MonitorGet monNum, &L, &T, &R, &B
        lastMonitor := Map(
            "Left", L, "Right", R, "Top", T, "Bottom", B,
            "Width", R - L, "Height", B - T, "Number", monNum,
            "CenterX", (R + L) // 2, "CenterY", (B + T) // 2
        )
        DebugLog("MONITOR", "Current monitor #" monNum ": " L "," T " to " R "," B " (size: " (R-L) "x" (B-T) ")", 3)
        return lastMonitor
    }
    
    DebugLog("MONITOR", "Could not determine monitor from mouse position, falling back to primary", 2)
    return GetPrimaryMonitorCoordinates()
}

MonitorGetFromPoint(x, y) {
    DebugLog("MONITOR", "Finding monitor for point " x "," y, 5)
    try {
        Loop MonitorGetCount() {
            MonitorGet A_Index, &L, &T, &R, &B
            if (x >= L && x < R && y >= T && y < B) {
                DebugLog("MONITOR", "Point " x "," y " is on monitor #" A_Index, 5)
                return A_Index
            }
        }
        DebugLog("MONITOR", "Point " x "," y " is not on any monitor", 2)
    }
    catch as e {
        DebugLog("MONITOR", "Error finding monitor for point " x "," y ": " e.Message, 1)
    }
    return 0
}

GetVirtualDesktopBounds() {
    DebugLog("MONITOR", "Getting virtual desktop bounds for seamless floating", 3)
    global Config

    if (!Config["SeamlessMonitorFloat"]) {
        DebugLog("MONITOR", "Seamless floating disabled, returning current monitor bounds", 4)
        return GetCurrentMonitorInfo()
    }

    try {
        minLeft := 999999, maxRight := -999999
        minTop := 999999, maxBottom := -999999
        monitorCount := MonitorGetCount()

        DebugLog("MONITOR", "Processing " monitorCount " monitors for virtual desktop", 4)

        Loop monitorCount {
            MonitorGet A_Index, &L, &T, &R, &B
            DebugLog("MONITOR", "Monitor #" A_Index ": " L "," T " to " R "," B, 5)
            minLeft := Min(minLeft, L)
            maxRight := Max(maxRight, R)
            minTop := Min(minTop, T)
            maxBottom := Max(maxBottom, B)
        }

        bounds := Map(
            "Left", minLeft, "Right", maxRight, "Top", minTop, "Bottom", maxBottom,
            "Width", maxRight - minLeft, "Height", maxBottom - minTop, "Number", 0,
            "CenterX", (maxRight + minLeft) // 2, "CenterY", (maxBottom + minTop) // 2
        )
        
        DebugLog("MONITOR", "Virtual desktop bounds: " minLeft "," minTop " to " maxRight "," maxBottom " (size: " (maxRight-minLeft) "x" (maxBottom-minTop) ")", 3)
        return bounds
    }
    catch as e {
        DebugLog("MONITOR", "Error getting virtual desktop bounds: " e.Message ", falling back to primary", 1)
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
                return

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
            return

        overlapX := Max(0, Min(window["x"] + window["width"], other["x"] + other["width"]) - Max(window["x"], other["x"]))
        overlapY := Max(0, Min(window["y"] + window["height"], other["y"] + other["height"]) - Max(window["y"], other["y"]))

        if (overlapX > Config["Stabilization"]["OverlapTolerance"] && overlapY > Config["Stabilization"]["OverlapTolerance"])
            return true
    }
    return false
}
IsPluginWindow(hwnd) {
    DebugLog("PLUGIN", "Checking if window " hwnd " is a plugin", 5)
    
    try {
        winClass := WinGetClass("ahk_id " hwnd)
        title := WinGetTitle("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)

        DebugLog("PLUGIN", "Window " hwnd " - Class: '" winClass "', Title: '" title "', Process: '" processName "'", 5)

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
                DebugLog("PLUGIN", "Window " hwnd " is from DAW process: " processName, 4)
                break
            }
        }

        ; If it's from a DAW process, check plugin patterns
        if (isDAWProcess) {
            ; Check window class patterns
            for pattern in pluginClasses {
                if (InStr(winClass, pattern)) {
                    DebugLog("PLUGIN", "Window " hwnd " matches plugin class pattern: " pattern, 3)
                    return true
                }
            }

            ; Check window title patterns
            for pattern in pluginTitlePatterns {
                if (InStr(title, pattern)) {
                    DebugLog("PLUGIN", "Window " hwnd " matches plugin title pattern: " pattern, 3)
                    return true
                }
            }

            ; Check for small window dimensions typical of plugin UIs
            try {
                WinGetPos(,, &w, &h, "ahk_id " hwnd)
                if (w < 800 && h < 600) {
                    DebugLog("PLUGIN", "Window " hwnd " has plugin-like dimensions: " w "x" h, 4)
                    return true
                }
            }
            catch as e {
                DebugLog("PLUGIN", "Error getting dimensions for window " hwnd ": " e.Message, 2)
            }
        } else {
            ; For non-DAW processes, use basic patterns
            if (winClass ~= "i)(Vst|JS|Plugin|Float|Dock)") {
                DebugLog("PLUGIN", "Window " hwnd " matches basic plugin class pattern", 4)
                return true
            }
            if (title ~= "i)(VST|JS:|Plugin|FX)") {
                DebugLog("PLUGIN", "Window " hwnd " matches basic plugin title pattern", 4)
                return true
            }
        }

        DebugLog("PLUGIN", "Window " hwnd " is not a plugin", 5)
        return false
    }
    catch as e {
        DebugLog("PLUGIN", "Error checking plugin status for window " hwnd ": " e.Message, 1)
        return false
    }
}

IsWindowFloating(hwnd) {
    global Config
    DebugLog("FLOATING", "Checking if window " hwnd " should float", 5)

    ; Basic window existence check
    if (!SafeWinExist(hwnd)) {
        DebugLog("FLOATING", "Window " hwnd " does not exist", 4)
        return false
    }

    try {
        ; Skip minimized/maximized windows
        minMax := WinGetMinMax("ahk_id " hwnd)
        if (minMax != 0) {
            DebugLog("FLOATING", "Window " hwnd " is minimized/maximized (state: " minMax ")", 4)
            return false
        }

        ; Get window properties
        title := WinGetTitle("ahk_id " hwnd)
        if (title == "" || title == "Program Manager") {
            DebugLog("FLOATING", "Window " hwnd " has invalid title: '" title "'", 4)
            return false
        }

        winClass := WinGetClass("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)
        
        ; Get window styles
        style := WinGetStyle("ahk_id " hwnd)
        exStyle := WinGetExStyle("ahk_id " hwnd)

        DebugLog("FLOATING", "Window " hwnd " analysis - Class: '" winClass "', Process: '" processName "', Title: '" SubStr(title, 1, 30) "...'", 4)

        ; Allow more windows to float by default (less restrictive)
        if (title != "" && winClass != "WorkerW" && winClass != "Shell_TrayWnd" 
            && winClass != "Progman" && title != "Start" && !InStr(winClass, "TaskListThumbnailWnd")) {
            DebugLog("FLOATING", "Window " hwnd " passes basic floating criteria", 4)
            return true
        }

        ; Keep all the other checks as fallback
        ; 1. First check for forced processes (simplified)
        for pattern in Config["ForceFloatProcesses"] {
            if (processName ~= "i)^" pattern "$") {  ; Exact match with case insensitivity
                DebugLog("FLOATING", "Window " hwnd " matches forced float process: " pattern, 3)
                return true
            }
        }

        ; 2. Special cases that should always float
        if (winClass == "ConsoleWindowClass" || winClass == "CASCADIA_HOSTING_WINDOW_CLASS") {
            DebugLog("FLOATING", "Window " hwnd " is console/terminal window", 3)
            return true  ; CMD and Windows Terminal
        }

        ; 3. Plugin window detection (basic but effective)
        if (winClass ~= "i)(Vst|JS|Plugin|Float)") {
            DebugLog("FLOATING", "Window " hwnd " matches plugin class pattern", 3)
            return true
        }

        if (title ~= "i)(VST|JS:|Plugin|FX)") {
            DebugLog("FLOATING", "Window " hwnd " matches plugin title pattern", 3)
            return true
        }

        ; 4. Standard floating window checks
        if (exStyle & 0x80) { ; WS_EX_TOOLWINDOW
            DebugLog("FLOATING", "Window " hwnd " has tool window style", 4)
            return true
        }

        if (!(style & 0x10000000)) { ; WS_VISIBLE
            DebugLog("FLOATING", "Window " hwnd " is not visible", 4)
            return true
        }

        ; 5. Check class patterns from config
        for pattern in Config["FloatClassPatterns"] {
            if (winClass ~= "i)" pattern) {
                DebugLog("FLOATING", "Window " hwnd " matches config class pattern: " pattern, 3)
                return true
            }
        }

        ; 6. Check title patterns from config
        for pattern in Config["FloatTitlePatterns"] {
            if (title ~= "i)" pattern) {
                DebugLog("FLOATING", "Window " hwnd " matches config title pattern: " pattern, 3)
                return true
            }
        }

        ; 7. Final style check
        styleCheck := (style & Config["FloatStyles"]) != 0
        if (styleCheck) {
            DebugLog("FLOATING", "Window " hwnd " matches float styles", 4)
        } else {
            DebugLog("FLOATING", "Window " hwnd " does not qualify for floating", 5)
        }
        return styleCheck
    }
    catch as e {
        DebugLog("FLOATING", "Error checking floating status for window " hwnd ": " e.Message, 1)
        return false
    }
}



GetVisibleWindows(monitor) {
    global Config, g
    DebugLog("WINDOWS", "Getting visible windows for monitor", 4)
    StartPerfTimer("GetVisibleWindows")
    
    WinList := []
    allWindows := []
    windowCount := 0
    validCount := 0
    pluginCount := 0
    
    hwndList := WinGetList()
    DebugLog("WINDOWS", "Processing " hwndList.Length " total windows", 3)
    
    for hwnd in hwndList {
        windowCount++
        try {
            ; Skip invalid windows
            if (!IsWindowValid(hwnd)) {
                DebugLog("WINDOWS", "Window " hwnd " failed validation", 5)
                return
            }
            validCount++

            ; Get window properties
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            if (w == 0 || h == 0) {
                DebugLog("WINDOWS", "Window " hwnd " has zero dimensions: " w "x" h, 4)
                continue
            }

            ; Special handling for plugin windows
            isPlugin := IsPluginWindow(hwnd)
            if (isPlugin) {
                pluginCount++
            }

            ; Force include plugin windows or check floating status
            if (isPlugin || IsWindowFloating(hwnd)) {
                allWindows.Push(Map(
                    "hwnd", hwnd,
                    "x", x, "y", y,
                    "width", w, "height", h,
                    "isPlugin", isPlugin,
                    "lastSeen", A_TickCount
                ))
                DebugLog("WINDOWS", "Added window " hwnd " (" w "x" h " at " x "," y ") - Plugin: " (isPlugin ? "Yes" : "No"), 5)
            } else {
                DebugLog("WINDOWS", "Skipped window " hwnd " (not floating)", 5)
            }
        }
        catch as e {
            DebugLog("WINDOWS", "Error processing window " hwnd ": " e.Message, 2)
            continue
        }
    }

    DebugLog("WINDOWS", "Window analysis: " windowCount " total, " validCount " valid, " allWindows.Length " candidates, " pluginCount " plugins", 3)

    ; Get current mouse position for monitor check
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)
    activeMonitor := MonitorGetFromPoint(mx, my)
    includedCount := 0
    excludedCount := 0

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
                DebugLog("WINDOWS", "Could not determine monitor for window " window["hwnd"] ", using primary", 2)
            }

            ; Check if window should be included based on floating mode
            includeWindow := false

            if (Config["SeamlessMonitorFloat"]) {
                ; In seamless mode, include all windows from all monitors
                includeWindow := true
                DebugLog("WINDOWS", "Window " window["hwnd"] " included (seamless mode)", 5)
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
                if (includeWindow) {
                    reason := winMonitor == monitor["Number"] ? "on current monitor" : (isTracked ? "already tracked" : "is plugin")
                    DebugLog("WINDOWS", "Window " window["hwnd"] " included (" reason ")", 5)
                } else {
                    DebugLog("WINDOWS", "Window " window["hwnd"] " excluded (wrong monitor: " winMonitor " vs " monitor["Number"] ")", 5)
                }
            }

            if (includeWindow) {
                includedCount++
                ; Apply margin constraints based on floating mode
                if (Config["SeamlessMonitorFloat"]) {
                    ; Use virtual desktop bounds for seamless floating
                    virtualBounds := GetVirtualDesktopBounds()
                    safeArea := GetSafeArea(virtualBounds)
                    window["x"] := Clamp(window["x"], safeArea["Left"] + Config["MinMargin"], safeArea["Right"] - window["width"] - Config["MinMargin"])
                    window["y"] := Clamp(window["y"], safeArea["Top"] + Config["MinMargin"], safeArea["Bottom"] - window["height"] - Config["MinMargin"])
                } else {
                    safeArea := GetSafeArea(Map("Left", mL, "Top", mT, "Right", mR, "Bottom", mB))
                    window["x"] := Clamp(window["x"], safeArea["Left"] + Config["MinMargin"], safeArea["Right"] - window["width"] - Config["MinMargin"])
                    window["y"] := Clamp(window["y"], safeArea["Top"] + Config["MinMargin"], safeArea["Bottom"] - window["height"] - Config["MinMargin"])
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
                newWin := Map(
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
                )
                
                WinList.Push(newWin)

                ; Add time-phasing echo for plugin windows
                if (window["isPlugin"] && g["FairyDustEnabled"]) {
                    TimePhasing.AddEcho(window["hwnd"])
                }
            } else {
                excludedCount++
            }
        }
        catch as e {
            DebugLog("WINDOWS", "Error processing window " window["hwnd"] " for inclusion: " e.Message, 2)
            continue
        }
    }

    DebugLog("WINDOWS", "Final result: " includedCount " included, " excludedCount " excluded from " allWindows.Length " candidates", 3)

    ; Clean up windows that are no longer valid
    CleanupStaleWindows()

    elapsed := EndPerfTimer("GetVisibleWindows")
    DebugLog("WINDOWS", "GetVisibleWindows completed in " elapsed "ms", 3)
    return WinList
}

CleanupStaleWindows() {
    global g
    DebugLog("CLEANUP", "Starting stale window cleanup", 4)
    threshold := 5000 ; 5 seconds
    cleaned := 0

    ; FIXED: Use proper loop without undefined variable 'i'
    windowsToRemove := []
    
    ; First pass: identify stale windows
    for index, win in g["Windows"] {
        if (A_TickCount - win["lastSeen"] > threshold && !SafeWinExist(win["hwnd"])) {
            DebugLog("CLEANUP", "Marking stale window " win["hwnd"] " for removal (last seen " (A_TickCount - win["lastSeen"]) "ms ago)", 3)
            windowsToRemove.Push(index)
            if (g["ManualWindows"].Has(win["hwnd"])) {
                RemoveManualWindowBorder(win["hwnd"])
            }
            cleaned++
        }
    }
    
    ; Second pass: remove stale windows (reverse order to maintain indices)
    Loop windowsToRemove.Length {
        index := windowsToRemove[windowsToRemove.Length - A_Index + 1]
        g["Windows"].RemoveAt(index)
    }
    
    if (cleaned > 0) {
        DebugLog("CLEANUP", "Cleaned up " cleaned " stale windows", 3)
    } else {
        DebugLog("CLEANUP", "No stale windows found", 4)
    }
}

class TimePhasing {
    static echoes := Map()
    static lastCleanup := 0

    static AddEcho(hwnd) {
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
    }

    static UpdateEchoes() {
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
    }

    static CleanupEffects() {
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

    ; Check for manual lock (window should not move by physics)
    isManuallyLocked := (win.Has("ManualLock") && A_TickCount < win["ManualLock"])
    if (isManuallyLocked) {
        win["vx"] := 0
        win["vy"] := 0
        win["targetX"] := win["x"]
        win["targetY"] := win["y"]
        return
    }

    ; Keep active window and recently moved windows still
    isActiveWindow := (win["hwnd"] == g["ActiveWindow"])
    isRecentlyMoved := (A_TickCount - g["LastUserMove"] < Config["UserMoveTimeout"])
    isCurrentlyFocused := (win["hwnd"] == WinExist("A"))

    if (isActiveWindow || isRecentlyMoved && isCurrentlyFocused) {
        win["vx"] := 0
        win["vy"] := 0
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
    spaceForce := CalculateSpaceSeekingForce(win, allWindows)
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

ShowTooltip(text) {
    global g, Config
    ToolTip(text, g["Monitor"]["CenterX"] - 100, g["Monitor"]["Top"] + 20)
    SetTimer(() => ToolTip(), -Config["TooltipDuration"])
}

GetCurrentMonitorInfo() {
    DebugLog("MONITOR", "Getting current monitor info", 4)
    static lastPos := [0, 0], lastMonitor := Map()
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)

    if (Abs(mx - lastPos[1]) < 50 && Abs(my - lastPos[2]) < 50 && lastMonitor.Count) {
        DebugLog("MONITOR", "Using cached monitor info (mouse position unchanged)", 5)
        return lastMonitor
    }

    lastPos := [mx, my]
    DebugLog("MONITOR", "Mouse position: " mx "," my, 4)
    
    if (monNum := MonitorGetFromPoint(mx, my)) {
        MonitorGet monNum, &L, &T, &R, &B
        lastMonitor := Map(
            "Left", L, "Right", R, "Top", T, "Bottom", B,
            "Width", R - L, "Height", B - T, "Number", monNum,
            "CenterX", (R + L) // 2, "CenterY", (B + T) // 2
        )
        DebugLog("MONITOR", "Current monitor #" monNum ": " L "," T " to " R "," B " (size: " (R-L) "x" (B-T) ")", 3)
        return lastMonitor
    }
    
    DebugLog("MONITOR", "Could not determine monitor from mouse position, falling back to primary", 2)
    return GetPrimaryMonitorCoordinates()
}

MonitorGetFromPoint(x, y) {
    DebugLog("MONITOR", "Finding monitor for point " x "," y, 5)
    try {
        Loop MonitorGetCount() {
            MonitorGet A_Index, &L, &T, &R, &B
            if (x >= L && x < R && y >= T && y < B) {
                DebugLog("MONITOR", "Point " x "," y " is on monitor #" A_Index, 5)
                return A_Index
            }
        }
        DebugLog("MONITOR", "Point " x "," y " is not on any monitor", 2)
    }
    catch as e {
        DebugLog("MONITOR", "Error finding monitor for point " x "," y ": " e.Message, 1)
    }
    return 0
}

GetVirtualDesktopBounds() {
    DebugLog("MONITOR", "Getting virtual desktop bounds for seamless floating", 3)
    global Config

    if (!Config["SeamlessMonitorFloat"]) {
        DebugLog("MONITOR", "Seamless floating disabled, returning current monitor bounds", 4)
        return GetCurrentMonitorInfo()
    }

    try {
        minLeft := 999999, maxRight := -999999
        minTop := 999999, maxBottom := -999999
        monitorCount := MonitorGetCount()

        DebugLog("MONITOR", "Processing " monitorCount " monitors for virtual desktop", 4)

        Loop monitorCount {
            MonitorGet A_Index, &L, &T, &R, &B
            DebugLog("MONITOR", "Monitor #" A_Index ": " L "," T " to " R "," B, 5)
            minLeft := Min(minLeft, L)
            maxRight := Max(maxRight, R)
            minTop := Min(minTop, T)
            maxBottom := Max(maxBottom, B)
        }

        bounds := Map(
            "Left", minLeft, "Right", maxRight, "Top", minTop, "Bottom", maxBottom,
            "Width", maxRight - minLeft, "Height", maxBottom - minTop, "Number", 0,
            "CenterX", (maxRight + minLeft) // 2, "CenterY", (maxBottom + minTop) // 2
        )
        
        DebugLog("MONITOR", "Virtual desktop bounds: " minLeft "," minTop " to " maxRight "," maxBottom " (size: " (maxRight-minLeft) "x" (maxBottom-minTop) ")", 3)
        return bounds
    }
    catch as e {
        DebugLog("MONITOR", "Error getting virtual desktop bounds: " e.Message ", falling back to primary", 1)
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
                return

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
            return

        overlapX := Max(0, Min(window["x"] + window["width"], other["x"] + other["width"]) - Max(window["x"], other["x"]))
        overlapY := Max(0, Min(window["y"] + window["height"], other["y"] + other["height"]) - Max(window["y"], other["y"]))

        if (overlapX > Config["Stabilization"]["OverlapTolerance"] && overlapY > Config["Stabilization"]["OverlapTolerance"])
            return true
    }
    return false
}
IsPluginWindow(hwnd) {
    DebugLog("PLUGIN", "Checking if window " hwnd " is a plugin", 5)
    
    try {
        winClass := WinGetClass("ahk_id " hwnd)
        title := WinGetTitle("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)

        DebugLog("PLUGIN", "Window " hwnd " - Class: '" winClass "', Title: '" title "', Process: '" processName "'", 5)

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
                DebugLog("PLUGIN", "Window " hwnd " is from DAW process: " processName, 4)
                break
            }
        }

        ; If it's from a DAW process, check plugin patterns
        if (isDAWProcess) {
            ; Check window class patterns
            for pattern in pluginClasses {
                if (InStr(winClass, pattern)) {
                    DebugLog("PLUGIN", "Window " hwnd " matches plugin class pattern: " pattern, 3)
                    return true
                }
            }

            ; Check window title patterns
            for pattern in pluginTitlePatterns {
                if (InStr(title, pattern)) {
                    DebugLog("PLUGIN", "Window " hwnd " matches plugin title pattern: " pattern, 3)
                    return true
                }
            }

            ; Check for small window dimensions typical of plugin UIs
            try {
                WinGetPos(,, &w, &h, "ahk_id " hwnd)
                if (w < 800 && h < 600) {
                    DebugLog("PLUGIN", "Window " hwnd " has plugin-like dimensions: " w "x" h, 4)
                    return true
                }
            }
            catch as e {
                DebugLog("PLUGIN", "Error getting dimensions for window " hwnd ": " e.Message, 2)
            }
        } else {
            ; For non-DAW processes, use basic patterns
            if (winClass ~= "i)(Vst|JS|Plugin|Float|Dock)") {
                DebugLog("PLUGIN", "Window " hwnd " matches basic plugin class pattern", 4)
                return true
            }
            if (title ~= "i)(VST|JS:|Plugin|FX)") {
                DebugLog("PLUGIN", "Window " hwnd " matches basic plugin title pattern", 4)
                return true
            }
        }

        DebugLog("PLUGIN", "Window " hwnd " is not a plugin", 5)
        return false
    }
    catch as e {
        DebugLog("PLUGIN", "Error checking plugin status for window " hwnd ": " e.Message, 1)
        return false
    }
}

IsWindowFloating(hwnd) {
    global Config
    DebugLog("FLOATING", "Checking if window " hwnd " should float", 5)

    ; Basic window existence check
    if (!SafeWinExist(hwnd)) {
        DebugLog("FLOATING", "Window " hwnd " does not exist", 4)
        return false
    }

    try {
        ; Skip minimized/maximized windows
        minMax := WinGetMinMax("ahk_id " hwnd)
        if (minMax != 0) {
            DebugLog("FLOATING", "Window " hwnd " is minimized/maximized (state: " minMax ")", 4)
            return false
        }

        ; Get window properties
        title := WinGetTitle("ahk_id " hwnd)
        if (title == "" || title == "Program Manager") {
            DebugLog("FLOATING", "Window " hwnd " has invalid title: '" title "'", 4)
            return false
        }

        winClass := WinGetClass("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)
        
        ; Get window styles
        style := WinGetStyle("ahk_id " hwnd)
        exStyle := WinGetExStyle("ahk_id " hwnd)

        DebugLog("FLOATING", "Window " hwnd " analysis - Class: '" winClass "', Process: '" processName "', Title: '" SubStr(title, 1, 30) "...'", 4)

        ; Allow more windows to float by default (less restrictive)
        if (title != "" && winClass != "WorkerW" && winClass != "Shell_TrayWnd" 
            && winClass != "Progman" && title != "Start" && !InStr(winClass, "TaskListThumbnailWnd")) {
            DebugLog("FLOATING", "Window " hwnd " passes basic floating criteria", 4)
            return true
        }

        ; Keep all the other checks as fallback
        ; 1. First check for forced processes (simplified)
        for pattern in Config["ForceFloatProcesses"] {
            if (processName ~= "i)^" pattern "$") {  ; Exact match with case insensitivity
                DebugLog("FLOATING", "Window " hwnd " matches forced float process: " pattern, 3)
                return true
            }
        }

        ; 2. Special cases that should always float
        if (winClass == "ConsoleWindowClass" || winClass == "CASCADIA_HOSTING_WINDOW_CLASS") {
            DebugLog("FLOATING", "Window " hwnd " is console/terminal window", 3)
            return true  ; CMD and Windows Terminal
        }

        ; 3. Plugin window detection (basic but effective)
        if (winClass ~= "i)(Vst|JS|Plugin|Float)") {
            DebugLog("FLOATING", "Window " hwnd " matches plugin class pattern", 3)
            return true
        }

        if (title ~= "i)(VST|JS:|Plugin|FX)") {
            DebugLog("FLOATING", "Window " hwnd " matches plugin title pattern", 3)
            return true
        }

        ; 4. Standard floating window checks
        if (exStyle & 0x80) { ; WS_EX_TOOLWINDOW
            DebugLog("FLOATING", "Window " hwnd " has tool window style", 4)
            return true
        }

        if (!(style & 0x10000000)) { ; WS_VISIBLE
            DebugLog("FLOATING", "Window " hwnd " is not visible", 4)
            return true
        }

        ; 5. Check class patterns from config
        for pattern in Config["FloatClassPatterns"] {
            if (winClass ~= "i)" pattern) {
                DebugLog("FLOATING", "Window " hwnd " matches config class pattern: " pattern, 3)
                return true
            }
        }

        ; 6. Check title patterns from config
        for pattern in Config["FloatTitlePatterns"] {
            if (title ~= "i)" pattern) {
                DebugLog("FLOATING", "Window " hwnd " matches config title pattern: " pattern, 3)
                return true
            }
        }

        ; 7. Final style check
        styleCheck := (style & Config["FloatStyles"]) != 0
        if (styleCheck) {
            DebugLog("FLOATING", "Window " hwnd " matches float styles", 4)
        } else {
            DebugLog("FLOATING", "Window " hwnd " does not qualify for floating", 5)
        }
        return styleCheck
    }
    catch as e {
        DebugLog("FLOATING", "Error checking floating status for window " hwnd ": " e.Message, 1)
        return false
    }
}



GetVisibleWindows(monitor) {
    global Config, g
    DebugLog("WINDOWS", "Getting visible windows for monitor", 4)
    StartPerfTimer("GetVisibleWindows")
    
    WinList := []
    allWindows := []
    windowCount := 0
    validCount := 0
    pluginCount := 0
    
    hwndList := WinGetList()
    DebugLog("WINDOWS", "Processing " hwndList.Length " total windows", 3)
    
    for hwnd in hwndList {
        windowCount++
        try {
            ; Skip invalid windows
            if (!IsWindowValid(hwnd)) {
                DebugLog("WINDOWS", "Window " hwnd " failed validation", 5)
                return
            }
            validCount++

            ; Get window properties
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            if (w == 0 || h == 0) {
                DebugLog("WINDOWS", "Window " hwnd " has zero dimensions: " w "x" h, 4)
                continue
            }

            ; Special handling for plugin windows
            isPlugin := IsPluginWindow(hwnd)
            if (isPlugin) {
                pluginCount++
            }

            ; Force include plugin windows or check floating status
            if (isPlugin || IsWindowFloating(hwnd)) {
                allWindows.Push(Map(
                    "hwnd", hwnd,
                    "x", x, "y", y,
                    "width", w, "height", h,
                    "isPlugin", isPlugin,
                    "lastSeen", A_TickCount
                ))
                DebugLog("WINDOWS", "Added window " hwnd " (" w "x" h " at " x "," y ") - Plugin: " (isPlugin ? "Yes" : "No"), 5)
            } else {
                DebugLog("WINDOWS", "Skipped window " hwnd " (not floating)", 5)
            }
        }
        catch as e {
            DebugLog("WINDOWS", "Error processing window " hwnd ": " e.Message, 2)
            continue
        }
    }

    DebugLog("WINDOWS", "Window analysis: " windowCount " total, " validCount " valid, " allWindows.Length " candidates, " pluginCount " plugins", 3)

    ; Get current mouse position for monitor check
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)
    activeMonitor := MonitorGetFromPoint(mx, my)
    includedCount := 0
    excludedCount := 0

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
                DebugLog("WINDOWS", "Could not determine monitor for window " window["hwnd"] ", using primary", 2)
            }

            ; Check if window should be included based on floating mode
            includeWindow := false

            if (Config["SeamlessMonitorFloat"]) {
                ; In seamless mode, include all windows from all monitors
                includeWindow := true
                DebugLog("WINDOWS", "Window " window["hwnd"] " included (seamless mode)", 5)
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
                if (includeWindow) {
                    reason := winMonitor == monitor["Number"] ? "on current monitor" : (isTracked ? "already tracked" : "is plugin")
                    DebugLog("WINDOWS", "Window " window["hwnd"] " included (" reason ")", 5)
                } else {
                    DebugLog("WINDOWS", "Window " window["hwnd"] " excluded (wrong monitor: " winMonitor " vs " monitor["Number"] ")", 5)
                }
            }

            if (includeWindow) {
                includedCount++
                ; Apply margin constraints based on floating mode
                if (Config["SeamlessMonitorFloat"]) {
                    ; Use virtual desktop bounds for seamless floating
                    virtualBounds := GetVirtualDesktopBounds()
                    safeArea := GetSafeArea(virtualBounds)
                    window["x"] := Clamp(window["x"], safeArea["Left"] + Config["MinMargin"], safeArea["Right"] - window["width"] - Config["MinMargin"])
                    window["y"] := Clamp(window["y"], safeArea["Top"] + Config["MinMargin"], safeArea["Bottom"] - window["height"] - Config["MinMargin"])
                } else {
                    safeArea := GetSafeArea(Map("Left", mL, "Top", mT, "Right", mR, "Bottom", mB))
                    window["x"] := Clamp(window["x"], safeArea["Left"] + Config["MinMargin"], safeArea["Right"] - window["width"] - Config["MinMargin"])
                    window["y"] := Clamp(window["y"], safeArea["Top"] + Config["MinMargin"], safeArea["Bottom"] - window["height"] - Config["MinMargin"])
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
                newWin := Map(
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
                )
                
                WinList.Push(newWin)

                ; Add time-phasing echo for plugin windows
                if (window["isPlugin"] && g["FairyDustEnabled"]) {
                    TimePhasing.AddEcho(window["hwnd"])
                }
            } else {
                excludedCount++
            }
        }
        catch as e {
            DebugLog("WINDOWS", "Error processing window " window["hwnd"] " for inclusion: " e.Message, 2)
            continue
        }
    }

    DebugLog("WINDOWS", "Final result: " includedCount " included, " excludedCount " excluded from " allWindows.Length " candidates", 3)

    ; Clean up windows that are no longer valid
    CleanupStaleWindows()

    elapsed := EndPerfTimer("GetVisibleWindows")
    DebugLog("WINDOWS", "GetVisibleWindows completed in " elapsed "ms", 3)
    return WinList
}

CleanupStaleWindows() {
    global g
    DebugLog("CLEANUP", "Starting stale window cleanup", 4)
    threshold := 5000 ; 5 seconds
    cleaned := 0

    ; FIXED: Use proper loop without undefined variable 'i'
    windowsToRemove := []
    
    ; First pass: identify stale windows
    for index, win in g["Windows"] {
        if (A_TickCount - win["lastSeen"] > threshold && !SafeWinExist(win["hwnd"])) {
            DebugLog("CLEANUP", "Marking stale window " win["hwnd"] " for removal (last seen " (A_TickCount - win["lastSeen"]) "ms ago)", 3)
            windowsToRemove.Push(index)
            if (g["ManualWindows"].Has(win["hwnd"])) {
                RemoveManualWindowBorder(win["hwnd"])
            }
            cleaned++
        }
    }
    
    ; Second pass: remove stale windows (reverse order to maintain indices)
    Loop windowsToRemove.Length {
        index := windowsToRemove[windowsToRemove.Length - A_Index + 1]
        g["Windows"].RemoveAt(index)
    }
    
    if (cleaned > 0) {
        DebugLog("CLEANUP", "Cleaned up " cleaned " stale windows", 3)
    } else {
        DebugLog("CLEANUP", "No stale windows found", 4)
    }
}

class TimePhasing {
    static echoes := Map()
    static lastCleanup := 0

    static AddEcho(hwnd) {
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
    }

    static UpdateEchoes() {
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
    }

    static CleanupEffects() {
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

    ; Check for manual lock (window should not move by physics)
    isManuallyLocked := (win.Has("ManualLock") && A_TickCount < win["ManualLock"])
    if (isManuallyLocked) {
        win["vx"] := 0
        win["vy"] := 0
        win["targetX"] := win["x"]
        win["targetY"] := win["y"]
        return
    }

    ; Keep active window and recently moved windows still
    isActiveWindow := (win["hwnd"] == g["ActiveWindow"])
    isRecentlyMoved := (A_TickCount - g["LastUserMove"] < Config["UserMoveTimeout"])
    isCurrentlyFocused := (win["hwnd"] == WinExist("A"))

    if (isActiveWindow || isRecentlyMoved && isCurrentlyFocused) {
        win["vx"] := 0
        win["vy"] := 0
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
    spaceForce := CalculateSpaceSeekingForce(win, allWindows)
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

ShowTooltip(text) {
    global g, Config
    ToolTip(text, g["Monitor"]["CenterX"] - 100, g["Monitor"]["Top"] + 20)
    SetTimer(() => ToolTip(), -Config["TooltipDuration"])
}

GetCurrentMonitorInfo() {
    DebugLog("MONITOR", "Getting current monitor info", 4)
    static lastPos := [0, 0], lastMonitor := Map()
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)

    if (Abs(mx - lastPos[1]) < 50 && Abs(my - lastPos[2]) < 50 && lastMonitor.Count) {
        DebugLog("MONITOR", "Using cached monitor info (mouse position unchanged)", 5)
        return lastMonitor
    }

    lastPos := [mx, my]
    DebugLog("MONITOR", "Mouse position: " mx "," my, 4)
    
    if (monNum := MonitorGetFromPoint(mx, my)) {
        MonitorGet monNum, &L, &T, &R, &B
        lastMonitor := Map(
            "Left", L, "Right", R, "Top", T, "Bottom", B,
            "Width", R - L, "Height", B - T, "Number", monNum,
            "CenterX", (R + L) // 2, "CenterY", (B + T) // 2
        )
        DebugLog("MONITOR", "Current monitor #" monNum ": " L "," T " to " R "," B " (size: " (R-L) "x" (B-T) ")", 3)
        return lastMonitor
    }
    
    DebugLog("MONITOR", "Could not determine monitor from mouse position, falling back to primary", 2)
    return GetPrimaryMonitorCoordinates()
}

MonitorGetFromPoint(x, y) {
    DebugLog("MONITOR", "Finding monitor for point " x "," y, 5)
    try {
        Loop MonitorGetCount() {
            MonitorGet A_Index, &L, &T, &R, &B
            if (x >= L && x < R && y >= T && y < B) {
                DebugLog("MONITOR", "Point " x "," y " is on monitor #" A_Index, 5)
                return A_Index
            }
        }
        DebugLog("MONITOR", "Point " x "," y " is not on any monitor", 2)
    }
    catch as e {
        DebugLog("MONITOR", "Error finding monitor for point " x "," y ": " e.Message, 1)
    }
    return 0
}

GetVirtualDesktopBounds() {
    DebugLog("MONITOR", "Getting virtual desktop bounds for seamless floating", 3)
    global Config

    if (!Config["SeamlessMonitorFloat"]) {
        DebugLog("MONITOR", "Seamless floating disabled, returning current monitor bounds", 4)
        return GetCurrentMonitorInfo()
    }

    try {
        minLeft := 999999, maxRight := -999999
        minTop := 999999, maxBottom := -999999
        monitorCount := MonitorGetCount()

        DebugLog("MONITOR", "Processing " monitorCount " monitors for virtual desktop", 4)

        Loop monitorCount {
            MonitorGet A_Index, &L, &T, &R, &B
            DebugLog("MONITOR", "Monitor #" A_Index ": " L "," T " to " R "," B, 5)
            minLeft := Min(minLeft, L)
            maxRight := Max(maxRight, R)
            minTop := Min(minTop, T)
            maxBottom := Max(maxBottom, B)
        }

        bounds := Map(
            "Left", minLeft, "Right", maxRight, "Top", minTop, "Bottom", maxBottom,
            "Width", maxRight - minLeft, "Height", maxBottom - minTop, "Number", 0,
            "CenterX", (maxRight + minLeft) // 2, "CenterY", (maxBottom + minTop) // 2
        )
        
        DebugLog("MONITOR", "Virtual desktop bounds: " minLeft "," minTop " to " maxRight "," maxBottom " (size: " (maxRight-minLeft) "x" (maxBottom-minTop) ")", 3)
        return bounds
    }
    catch as e {
        DebugLog("MONITOR", "Error getting virtual desktop bounds: " e.Message ", falling back to primary", 1)
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
                return

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
            return

        overlapX := Max(0, Min(window["x"] + window["width"], other["x"] + other["width"]) - Max(window["x"], other["x"]))
        overlapY := Max(0, Min(window["y"] + window["height"], other["y"] + other["height"]) - Max(window["y"], other["y"]))

        if (overlapX > Config["Stabilization"]["OverlapTolerance"] && overlapY > Config["Stabilization"]["OverlapTolerance"])
            return true
    }
    return false
}
IsPluginWindow(hwnd) {
    DebugLog("PLUGIN", "Checking if window " hwnd " is a plugin", 5)
    
    try {
        winClass := WinGetClass("ahk_id " hwnd)
        title := WinGetTitle("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)

        DebugLog("PLUGIN", "Window " hwnd " - Class: '" winClass "', Title: '" title "', Process: '" processName "'", 5)

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
                DebugLog("PLUGIN", "Window " hwnd " is from DAW process: " processName, 4)
                break
            }
        }

        ; If it's from a DAW process, check plugin patterns
        if (isDAWProcess) {
            ; Check window class patterns
            for pattern in pluginClasses {
                if (InStr(winClass, pattern)) {
                    DebugLog("PLUGIN", "Window " hwnd " matches plugin class pattern: " pattern, 3)
                    return true
                }
            }

            ; Check window title patterns
            for pattern in pluginTitlePatterns {
                if (InStr(title, pattern)) {
                    DebugLog("PLUGIN", "Window " hwnd " matches plugin title pattern: " pattern, 3)
                    return true
                }
            }

            ; Check for small window dimensions typical of plugin UIs
            try {
                WinGetPos(,, &w, &h, "ahk_id " hwnd)
                if (w < 800 && h < 600) {
                    DebugLog("PLUGIN", "Window " hwnd " has plugin-like dimensions: " w "x" h, 4)
                    return true
                }
            }
            catch as e {
                DebugLog("PLUGIN", "Error getting dimensions for window " hwnd ": " e.Message, 2)
            }
        } else {
            ; For non-DAW processes, use basic patterns
            if (winClass ~= "i)(Vst|JS|Plugin|Float|Dock)") {
                DebugLog("PLUGIN", "Window " hwnd " matches basic plugin class pattern", 4)
                return true
            }
            if (title ~= "i)(VST|JS:|Plugin|FX)") {
                DebugLog("PLUGIN", "Window " hwnd " matches basic plugin title pattern", 4)
                return true
            }
        }

        DebugLog("PLUGIN", "Window " hwnd " is not a plugin", 5)
        return false
    }
    catch as e {
        DebugLog("PLUGIN", "Error checking plugin status for window " hwnd ": " e.Message, 1)
        return false
    }
}

IsWindowFloating(hwnd) {
    global Config
    DebugLog("FLOATING", "Checking if window " hwnd " should float", 5)

    ; Basic window existence check
    if (!SafeWinExist(hwnd)) {
        DebugLog("FLOATING", "Window " hwnd " does not exist", 4)
        return false
    }

    try {
        ; Skip minimized/maximized windows
        minMax := WinGetMinMax("ahk_id " hwnd)
        if (minMax != 0) {
            DebugLog("FLOATING", "Window " hwnd " is minimized/maximized (state: " minMax ")", 4)
            return false
        }

        ; Get window properties
        title := WinGetTitle("ahk_id " hwnd)
        if (title == "" || title == "Program Manager") {
            DebugLog("FLOATING", "Window " hwnd " has invalid title: '" title "'", 4)
            return false
        }

        winClass := WinGetClass("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)
        
        ; Get window styles
        style := WinGetStyle("ahk_id " hwnd)
        exStyle := WinGetExStyle("ahk_id " hwnd)

        DebugLog("FLOATING", "Window " hwnd " analysis - Class: '" winClass "', Process: '" processName "', Title: '" SubStr(title, 1, 30) "...'", 4)

        ; Allow more windows to float by default (less restrictive)
        if (title != "" && winClass != "WorkerW" && winClass != "Shell_TrayWnd" 
            && winClass != "Progman" && title != "Start" && !InStr(winClass, "TaskListThumbnailWnd")) {
            DebugLog("FLOATING", "Window " hwnd " passes basic floating criteria", 4)
            return true
        }

        ; Keep all the other checks as fallback
        ; 1. First check for forced processes (simplified)
        for pattern in Config["ForceFloatProcesses"] {
            if (processName ~= "i)^" pattern "$") {  ; Exact match with case insensitivity
                DebugLog("FLOATING", "Window " hwnd " matches forced float process: " pattern, 3)
                return true
            }
        }

        ; 2. Special cases that should always float
        if (winClass == "ConsoleWindowClass" || winClass == "CASCADIA_HOSTING_WINDOW_CLASS") {
            DebugLog("FLOATING", "Window " hwnd " is console/terminal window", 3)
            return true  ; CMD and Windows Terminal
        }

        ; 3. Plugin window detection (basic but effective)
        if (winClass ~= "i)(Vst|JS|Plugin|Float)") {
            DebugLog("FLOATING", "Window " hwnd " matches plugin class pattern", 3)
            return true
        }

        if (title ~= "i)(VST|JS:|Plugin|FX)") {
            DebugLog("FLOATING", "Window " hwnd " matches plugin title pattern", 3)
            return true
        }

        ; 4. Standard floating window checks
        if (exStyle & 0x80) { ; WS_EX_TOOLWINDOW
            DebugLog("FLOATING", "Window " hwnd " has tool window style", 4)
            return true
        }

        if (!(style & 0x10000000)) { ; WS_VISIBLE
            DebugLog("FLOATING", "Window " hwnd " is not visible", 4)
            return true
        }

        ; 5. Check class patterns from config
        for pattern in Config["FloatClassPatterns"] {
            if (winClass ~= "i)" pattern) {
                DebugLog("FLOATING", "Window " hwnd " matches config class pattern: " pattern, 3)
                return true
            }
        }

        ; 6. Check title patterns from config
        for pattern in Config["FloatTitlePatterns"] {
            if (title ~= "i)" pattern) {
                DebugLog("FLOATING", "Window " hwnd " matches config title pattern: " pattern, 3)
                return true
            }
        }

        ; 7. Final style check
        styleCheck := (style & Config["FloatStyles"]) != 0
        if (styleCheck) {
            DebugLog("FLOATING", "Window " hwnd " matches float styles", 4)
        } else {
            DebugLog("FLOATING", "Window " hwnd " does not qualify for floating", 5)
        }
        return styleCheck
    }
    catch as e {
        DebugLog("FLOATING", "Error checking floating status for window " hwnd ": " e.Message, 1)
        return false
    }
}



GetVisibleWindows(monitor) {
    global Config, g
    DebugLog("WINDOWS", "Getting visible windows for monitor", 4)
    StartPerfTimer("GetVisibleWindows")
    
    WinList := []
    allWindows := []
    windowCount := 0
    validCount := 0
    pluginCount := 0
    
    hwndList := WinGetList()
    DebugLog("WINDOWS", "Processing " hwndList.Length " total windows", 3)
    
    for hwnd in hwndList {
        windowCount++
        try {
            ; Skip invalid windows
            if (!IsWindowValid(hwnd)) {
                DebugLog("WINDOWS", "Window " hwnd " failed validation", 5)
                return
            }
            validCount++

            ; Get window properties
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            if (w == 0 || h == 0) {
                DebugLog("WINDOWS", "Window " hwnd " has zero dimensions: " w "x" h, 4)
                continue
            }

            ; Special handling for plugin windows
            isPlugin := IsPluginWindow(hwnd)
            if (isPlugin) {
                pluginCount++
            }

            ; Force include plugin windows or check floating status
            if (isPlugin || IsWindowFloating(hwnd)) {
                allWindows.Push(Map(
                    "hwnd", hwnd,
                    "x", x, "y", y,
                    "width", w, "height", h,
                    "isPlugin", isPlugin,
                    "lastSeen", A_TickCount
                ))
                DebugLog("WINDOWS", "Added window " hwnd " (" w "x" h " at " x "," y ") - Plugin: " (isPlugin ? "Yes" : "No"), 5)
            } else {
                DebugLog("WINDOWS", "Skipped window " hwnd " (not floating)", 5)
            }
        }
        catch as e {
            DebugLog("WINDOWS", "Error processing window " hwnd ": " e.Message, 2)
            continue
        }
    }

    DebugLog("WINDOWS", "Window analysis: " windowCount " total, " validCount " valid, " allWindows.Length " candidates, " pluginCount " plugins", 3)

    ; Get current mouse position for monitor check
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)
    activeMonitor := MonitorGetFromPoint(mx, my)
    includedCount := 0
    excludedCount := 0

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
                DebugLog("WINDOWS", "Could not determine monitor for window " window["hwnd"] ", using primary", 2)
            }

            ; Check if window should be included based on floating mode
            includeWindow := false

            if (Config["SeamlessMonitorFloat"]) {
                ; In seamless mode, include all windows from all monitors
                includeWindow := true
                DebugLog("WINDOWS", "Window " window["hwnd"] " included (seamless mode)", 5)
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
                if (includeWindow) {
                    reason := winMonitor == monitor["Number"] ? "on current monitor" : (isTracked ? "already tracked" : "is plugin")
                    DebugLog("WINDOWS", "Window " window["hwnd"] " included (" reason ")", 5)
                } else {
                    DebugLog("WINDOWS", "Window " window["hwnd"] " excluded (wrong monitor: " winMonitor " vs " monitor["Number"] ")", 5)
                }
            }

            if (includeWindow) {
                includedCount++
                ; Apply margin constraints based on floating mode
                if (Config["SeamlessMonitorFloat"]) {
                    ; Use virtual desktop bounds for seamless floating
                    virtualBounds := GetVirtualDesktopBounds()
                    safeArea := GetSafeArea(virtualBounds)
                    window["x"] := Clamp(window["x"], safeArea["Left"] + Config["MinMargin"], safeArea["Right"] - window["width"] - Config["MinMargin"])
                    window["y"] := Clamp(window["y"], safeArea["Top"] + Config["MinMargin"], safeArea["Bottom"] - window["height"] - Config["MinMargin"])
                } else {
                    safeArea := GetSafeArea(Map("Left", mL, "Top", mT, "Right", mR, "Bottom", mB))
                    window["x"] := Clamp(window["x"], safeArea["Left"] + Config["MinMargin"], safeArea["Right"] - window["width"] - Config["MinMargin"])
                    window["y"] := Clamp(window["y"], safeArea["Top"] + Config["MinMargin"], safeArea["Bottom"] - window["height"] - Config["MinMargin"])
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
                newWin := Map(
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
                )
                
                WinList.Push(newWin)

                ; Add time-phasing echo for plugin windows
                if (window["isPlugin"] && g["FairyDustEnabled"]) {
                    TimePhasing.AddEcho(window["hwnd"])
                }
            } else {
                excludedCount++
            }
        }
        catch as e {
            DebugLog("WINDOWS", "Error processing window " window["hwnd"] " for inclusion: " e.Message, 2)
            continue
        }
    }

    DebugLog("WINDOWS", "Final result: " includedCount " included, " excludedCount " excluded from " allWindows.Length " candidates", 3)

    ; Clean up windows that are no longer valid
    CleanupStaleWindows()

    elapsed := EndPerfTimer("GetVisibleWindows")
    DebugLog("WINDOWS", "GetVisibleWindows completed in " elapsed "ms", 3)
    return WinList
}

CleanupStaleWindows() {
    global g
    DebugLog("CLEANUP", "Starting stale window cleanup", 4)
    threshold := 5000 ; 5 seconds
    cleaned := 0

    ; FIXED: Use proper loop without undefined variable