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
                continue
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

    ; Use a while loop instead of for-loop with index to avoid 'i' variable issues
    index := g["Windows"].Length
    while (index >= 1) {
        win := g["Windows"][index]
        if (A_TickCount - win["lastSeen"] > threshold && !SafeWinExist(win["hwnd"])) {
            DebugLog("CLEANUP", "Removing stale window " win["hwnd"] " (last seen " (A_TickCount - win["lastSeen"]) "ms ago)", 3)
            g["Windows"].RemoveAt(index)
            if (g["ManualWindows"].Has(win["hwnd"])) {
                RemoveManualWindowBorder(win["hwnd"])
            }
            cleaned++
        }
        index--
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

ApplyWindowMovements() {
    global g, Config
    static lastUpdate := 0
    static lastPositions := Map()
    static smoothPos := Map()

    Critical

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

    for win in g["Windows"] {
        ; Prevent movement of locked windows by physics/arrangement
        isLocked := (win.Has("ManualLock") && A_TickCount < win["ManualLock"])
        if (isLocked) {
            DebugLog("MOVE", "Skipping locked window " win["hwnd"], 4)
            continue
        }

        if (win["hwnd"] == g["ActiveWindow"]) {
            DebugLog("MOVE", "Skipping active window " win["hwnd"], 4)
            continue
        }

        hwnd := win["hwnd"]
        newX := win.Has("targetX") ? win["targetX"] : win["x"]
        newY := win.Has("targetY") ? win["targetY"] : win["y"]

        if (!hwndPos.Has(hwnd)) {
            DebugLog("MOVE", "Window position not cached, skipping: " hwnd, 4)
            continue
        }

        if (!smoothPos.Has(hwnd))
            smoothPos[hwnd] := { x: hwndPos[hwnd].x, y: hwndPos[hwnd].y }

        ; Assign monitor bounds for edge enforcement
        try {
            if (Config["SeamlessMonitorFloat"]) {
                virtualBounds := GetVirtualDesktopBounds()
                safeArea := GetSafeArea(virtualBounds)
            } else {
                MonitorGet win["monitor"], &mL, &mT, &mR, &mB
                safeArea := GetSafeArea(Map(
                    "Left", mL, "Top", mT, "Right", mR, "Bottom", mB
                ))
            }
            monLeft := safeArea["Left"]
            monRight := safeArea["Right"] - win["width"]
            monTop := safeArea["Top"] + Config["MinMargin"]
            monBottom := safeArea["Bottom"] - Config["MinMargin"] - win["height"]
        } catch {
            monLeft := 0
            monRight := A_ScreenWidth - win["width"]
            monTop := Config["MinMargin"]
            monBottom := A_ScreenHeight - Config["MinMargin"] - win["height"]
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
        try MoveWindowAPI(move.hwnd, move.x, move.y)
    }

    ; Z-index ordering: smaller DAW plugin windows on top so they don't get lost
    ; Only reorder when layout changes significantly, not every frame
    ; Reduced frequency to prevent flashing
    static lastZOrderUpdate := 0
    static lastWindowCount := 0
    static lastPluginCount := 0

    ; Count DAW plugin windows
    pluginCount := 0
    for win in g["Windows"] {
        if (IsDAWPlugin(win)) {
            pluginCount++
        }
    }

    if (pluginCount > 1 &&
        (A_TickCount - lastZOrderUpdate > 5000 || pluginCount != lastPluginCount)) {
        OrderWindowsBySize()
        lastZOrderUpdate := A_TickCount
        lastWindowCount := g["Windows"].Length
        lastPluginCount := pluginCount
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

            newX := Max(mL + Config["MinMargin"] + 2,
                       Min(pos1["x"], mR - pos1["width"] - Config["MinMargin"] - 2))
            newY := Max(mT + Config["MinMargin"] + 2,
                       Min(pos1["y"], mB - pos1["height"] - Config["MinMargin"] - 2))

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
                        "Left", mL, 
                        "Right", mR
                    )
                    separationForce *= 1.5
                }

                pos1["vx"] += dx * separationForce / dist
                pos1["vy"] += dy * separationForce / dist
                pos2["vx"] -= dx * separationForce / dist
                pos2["vy"] -= dy * separationForce / dist
            }
        }
    }
}


;;MANUAL WINDOW HANDLING
AddManualWindowBorder(hwnd) {
    global Config, g
    try {
        if (g["ManualWindows"].Has(hwnd))
            return

        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        borderThickness := 3
        borderColor := Config.Has("ManualWindowColor") ? Config["ManualWindowColor"] : "FF5555"
        borderAlpha := Config.Has("ManualWindowAlpha") ? Config["ManualWindowAlpha"] : 222

        borderGui := Gui("+ToolWindow -Caption +E0x20 +LastFound +AlwaysOnTop +E0x08000000")
        borderGui.Opt("+Owner" hwnd)
        borderGui.BackColor := "FFFFFF"
        WinSetTransColor("FFFFFF 255", borderGui.Hwnd)
        borderGui.Show("x" x-borderThickness " y" y-borderThickness " w" w+2*borderThickness " h" h+2*borderThickness " NA")

        borderGui.DestroyControls()

        ; Draw border using a Picture control with GDI+ (rectangle with only border, transparent fill)
        ; Create a bitmap with transparent fill and colored border
     
        try {
            bbStruct := Buffer(20, 0)
            NumPut("UInt", 1, bbStruct, 0)
            NumPut("Int", 1, bbStruct, 4)
            DllCall("dwmapi\DwmEnableBlurBehindWindow", "Ptr", borderGui.Hwnd, "Ptr", bbStruct.Ptr)
        }

        g["ManualWindows"][hwnd] := Map(
            "gui", borderGui,
            "expire", A_TickCount + Config["ManualLockDuration"]
        )
    } catch as Err {
        OutputDebug("Border Error: " Err.Message "`n" Err.What "`n" Err.Extra)
    }
}

; Helper to create a border-only bitmap for Picture control
CreateBorderBitmap(w, h, thickness, color, alpha) {
    ; Returns a GDI+ bitmap with transparent fill and colored border
    ; This is a stub for illustration; you may need a GDI+ library for full implementation.
    ; If you use gdip.ahk, you can use Gdip_DrawRectangle with a transparent fill.
    ; For now, return an empty string to avoid breaking the script.
    return ""
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

    ; Pause arrangement/physics timers while dragging
    SetTimer(CalculateDynamicLayout, 0)
    SetTimer(ApplyWindowMovements, 0)

    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " winID)
        winCenterX := x + w/2
        winCenterY := y + h/2
        monNum := MonitorGetFromPoint(winCenterX, winCenterY)
        MonitorGet monNum, &mL, &mT, &mR, &mB

        for win in g["Windows"] {
            if (win["hwnd"] == winID) {
                win["ManualLock"] := A_TickCount + Config["ManualLockDuration"]
                win["IsManual"] := true
                win["vx"] := 0
                win["vy"] := 0
                win["monitor"] := monNum
                AddManualWindowBorder(winID)
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

            newX := Max(mL + Config["MinMargin"], Min(newX, mR - w - Config["MinMargin"]))
            newY := Max(mT + Config["MinMargin"], Min(newY, mB - h - Config["MinMargin"]))

            try WinMove(newX, newY,,, "ahk_id " winID)

            for win in g["Windows"] {
                if (win["hwnd"] == winID) {
                    win["x"] := newX
                    win["y"] := newY
                    win["targetX"] := newX
                    win["targetY"] := newY
                    win["lastMove"] := A_TickCount
                    break
                }
            }

            Sleep(1)
        }
    }
    catch {
    }
    isDragging := false
    g["ActiveWindow"] := 0
    DllCall("winmm\timeEndPeriod", "UInt", 1)

    ; Resume arrangement/physics timers after dragging
    if (g["ArrangementActive"]) {
        SetTimer(CalculateDynamicLayout, Config["PhysicsTimeStep"])
        SetTimer(ApplyWindowMovements, Config["VisualTimeStep"])
    }
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
        SetTimer(TimePhasing.UpdateEchoes.Bind(TimePhasing), Config["VisualTimeStep"])
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
            if (targetWin.Has("IsManual"))
                targetWin.Delete("IsManual")
            g["ActiveWindow"] := 0
            RemoveManualWindowBorder(focusedWindow)
            ShowTooltip("Window UNLOCKED - will move with physics")
        } else {
            ; Lock the window
            targetWin["ManualLock"] := A_TickCount + Config["ManualLockDuration"]
            targetWin["IsManual"] := true
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

    ; Debug: Show initial state
    ShowTooltip("Optimize started - checking " g["Windows"].Length " windows...")
    Sleep(1000)  ; Brief pause to see the message

    if (g["Windows"].Length <= 1) {
        ShowTooltip("Not enough windows to optimize (found " g["Windows"].Length " windows)")
        return
    }

    ; Get current monitor info based on floating mode
    if (Config["SeamlessMonitorFloat"]) {
        monitor := GetVirtualDesktopBounds()
    } else {
        monitor := GetCurrentMonitorInfo()
    }
    
    if (!monitor.Count) {
        ShowTooltip("Could not get monitor information")
        return
    }
    
    safeArea := GetSafeArea(monitor)
    
    ; Debug: Show safe area info
    OutputDebug("Safe area: " safeArea["Left"] "," safeArea["Top"] " to " safeArea["Right"] "," safeArea["Bottom"])

    ; Create a copy of windows for repositioning
    windowsToPlace := []
    lockedCount := 0
    activeCount := 0
    
    for win in g["Windows"] {
        ; Skip locked or active windows
        isLocked := (win.Has("ManualLock") && A_TickCount < win["ManualLock"])
        isActive := (win["hwnd"] == g["ActiveWindow"])
        
        if (isLocked) {
            lockedCount++
        } else if (isActive) {
            activeCount++
        } else {
            windowsToPlace.Push(win)
        }
    }

    ; Debug: Show window categorization
    OutputDebug("Windows: " g["Windows"].Length " total, " windowsToPlace.Length " to place, " lockedCount " locked, " activeCount " active")

    if (windowsToPlace.Length == 0) {
        ShowTooltip("All windows are locked or active - nothing to optimize (locked: " lockedCount ", active: " activeCount ")")
        return
    }

    ; Sort windows by area (largest first) for better packing
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
    optimizedPositions := PackWindowsOptimally(windowsToPlace, safeArea)

    ; Apply optimized positions
    repositionedCount := 0
    for i, win in windowsToPlace {
        if (optimizedPositions.Has(i)) {
            newPos := optimizedPositions[i]
            
            ; Debug: Show position changes
            oldX := win["x"], oldY := win["y"]
            OutputDebug("Moving window " win["hwnd"] " from " oldX "," oldY " to " newPos["x"] "," newPos["y"])
            
            win["targetX"] := newPos["x"]
            win["targetY"] := newPos["y"]
            ; Add some velocity toward the target for smooth movement
            win["vx"] := (newPos["x"] - win["x"]) * 0.2  ; Increased from 0.1 for more noticeable movement
            win["vy"] := (newPos["y"] - win["y"]) * 0.2
            repositionedCount++
        }
    }

    ; Always show result, even if 0
    resultMsg := "Optimization complete: " repositionedCount " windows repositioned"
    if (repositionedCount == 0) {



        resultMsg .= " (all windows already optimally placed)"
    }
    ShowTooltip(resultMsg)
}

; Calculate space-seeking force to move windows toward less crowded areas
CalculateSpaceSeekingForce(win, allWindows) {
    winCenterX := win["x"] + win["width"]/2
    winCenterY := win["y"] + win["height"]/2
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
    bestDirection := FindLeastCrowdedDirection(win, allWindows, 0, 0, A_ScreenWidth, A_ScreenHeight)

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
    searchDistance := 200  ; How far to look ahead

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
    influenceRadius := 150

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

; ====== REQUIRED HELPER FUNCTIONS ======
MoveWindowAPI(hwnd, x, y, w := "", h := "") {
    if (w == "" || h == "")
        WinGetPos(,, &w, &h, "ahk_id " hwnd)
    return DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", 0x0014)
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

; Add missing hotkey for dragging windows
~LButton::DragWindow()

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

UpdateWindowStates() {
    global g, Config
    try {
        ; Use virtual desktop bounds if seamless floating is enabled
        if (Config["SeamlessMonitorFloat"]) {
            currentMonitor := GetVirtualDesktopBounds()
        } else {
            currentMonitor := GetCurrentMonitorInfo()
        }

        g["Monitor"] := currentMonitor
        g["Windows"] := GetVisibleWindows(currentMonitor)
        ClearManualFlags()
        if (g["ArrangementActive"] && g["PhysicsEnabled"])
            CalculateDynamicLayout()
    }
    catch {
        ; Initialize with appropriate monitor bounds
        initialMonitor := Config["SeamlessMonitorFloat"] ? GetVirtualDesktopBounds() : GetCurrentMonitorInfo()
        g := Map(
            "Monitor", initialMonitor,
            "ArrangementActive", true,
            "LastUserMove", 0,
            "ActiveWindow", 0,
            "Windows", [],
            "PhysicsEnabled", true,
            "FairyDustEnabled", true,
            "ManualWindows", Map(),
            "SystemEnergy", 0
        )
    }
}

; Missing function implementation
CalculateDynamicLayout() {
    global g, Config
    if (!g["ArrangementActive"] || !g["PhysicsEnabled"])
        return

    ; Calculate physics for each window
    for win in g["Windows"] {
        CalculateWindowForces(win, g["Windows"])
        ApplyStabilization(win)
    }
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

        ; Store original height if not already stored
        if (!win.Has("origHeight"))
            win["origHeight"] := win["height"]

        bestPos := FindBestPosition(win, placedWindows, monitor, gridSize, gridCols, gridRows)
        if (bestPos.Count > 0) {
            ; If window would float below the screen, shrink its height
            if (bestPos["y"] + win["height"] > monitor["Bottom"] - Config["MinMargin"]) {
                newHeight := Max(80, monitor["Bottom"] - Config["MinMargin"] - bestPos["y"])
                win["height"] := newHeight
            } else if (win.Has("origHeight") && win["height"] != win["origHeight"]) {
                ; Restore original height if space allows
                win["height"] := win["origHeight"]
            }
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
        "gaps"          ; Fill gaps between existing windows
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
                tempHeight := Max(99, monitor["Bottom"] - Config["MinMargin"] - pos["y"])
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
            ; Top edge
            posX := useableLeft
            while (posX <= useableRight) {
                candidates.Push(Map("x", posX, "y", useableTop))
                posX += 60
            }
            ; Left edge
            posY := useableTop
            while (posY <= useableBottom) {
                candidates.Push(Map("x", useableLeft, "y", posY))
                posY += 60
            }
            ; Right edge
            posY := useableTop
            while (posY <= useableBottom) {
                candidates.Push(Map("x", useableRight, "y", posY))
                posY += 60
            }
            ; Bottom edge
            posX := useableLeft
            while (posX <= useableRight) {
                candidates.Push(Map("x", posX, "y", useableBottom))
                posX += 60
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
        case "grid":
            ; Grid-based placement with larger steps
            stepX := 80
            stepY := 80
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
    }
    
    ; Optimize: Remove duplicate positions
    unique := Map()
    for pos in candidates {
        posKey := pos["x"] "," pos["y"]
        if !unique.Has(posKey)
            unique[posKey] := pos
    }
    
    ; Convert Map to Array manually since v2 Maps don't have Values() method
    result := []
    for posKey, pos in unique {
        result.Push(pos)
    }
    return result
}

; Returns a Map with the usable area (monitor minus all taskbars)
GetSafeArea(monitor) {
    left := monitor["Left"]
    top := monitor["Top"]
    right := monitor["Right"]
    bottom := monitor["Bottom"]
    ; Shrink area for each overlapping taskbar
    for rect in GetTaskbarRects() {
        ; Only consider taskbars that overlap this monitor
        if (rect.right <= left || rect.left >= right || rect.bottom <= top || rect.top >= bottom)
            continue
        ; Top taskbar
        if (rect.top == top && rect.left <= right && rect.right >= left)
            top := Max(top, rect.bottom)
        ; Bottom taskbar
        if (rect.bottom == bottom && rect.left <= right && rect.right >= left)
            bottom := Min(bottom, rect.top)
        ; Left taskbar
        if (rect.left == left && rect.top <= bottom && rect.bottom >= top)
            left := Max(left, rect.right)
        ; Right taskbar
        if (rect.right == right && rect.top <= bottom && rect.bottom >= top)
            right := Min(right, rect.left)
    }
    return Map(
        "Left", left,
        "Top", top,
        "Right", right,
        "Bottom", bottom,
        "Width", right - left,
        "Height", bottom - top,
        "CenterX", (right + left) // 2,
        "CenterY", (bottom + top) // 2
    )
}

GetTaskbarRects() {
    ; Returns an array of all taskbar rectangles (supports multi-monitor/taskbar mods)
    rects := []
    ; Helper for v2: get work area as a Map
    SysGetWorkArea() {
        l := SysGet(48)  ; MONITORINFOF_PRIMARY left
        t := SysGet(49)  ; MONITORINFOF_PRIMARY top
        r := SysGet(50)  ; MONITORINFOF_PRIMARY right
        b := SysGet(51)  ; MONITORINFOF_PRIMARY bottom
        return Map("Left", l, "Top", t, "Right", r, "Bottom", b)
    }
    ; Standard Windows taskbar(s)
    for hwnd in WinGetList("ahk_class Shell_TrayWnd") {
        if !SafeWinExist(hwnd)
            continue
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        if (w > 0 && h > 0)
            rects.Push({ left: x, top: y, right: x + w, bottom: y + h })
    }
    ; RetroBar (alternative taskbar)
    for hwnd in WinGetList("ahk_class RetroBarWnd") {
        if !SafeWinExist(hwnd)
            continue
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        if (w > 0 && h > 0)
            rects.Push({ left: x, top: y, right: x + w, bottom: y + h })
    }
    for hwnd in WinGetList("ahk_exe RetroBar.exe") {
        if !SafeWinExist(hwnd)
            continue
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        if (w > 0 && h > 0)
            rects.Push({ left: x, top: y, right: x + w, bottom: y + h })
    }
    ; ExplorerPatcher/TaskbarX/other mods (common classes)
    for hwnd in WinGetList("ahk_class MSTaskSwWClass") {
        wa := SysGetWorkArea()
        sw := SysGet(78)  ; SM_CXSCREEN
        sh := SysGet(79)  ; SM_CYSCREEN
        if (wa && wa.Has("Right") && wa.Has("Bottom") && wa.Has("Left") && wa.Has("Top")) {
            ; If SysGet succeeded
            if (wa["Right"] < sw || wa["Bottom"] < sh) {
                ; Bottom or right taskbar
                if (wa["Bottom"] < sh)
                    rects.Push({ left: 0, top: wa["Bottom"], right: sw, bottom: sh })
                if (wa["Right"] < sw)
                    rects.Push({ left: wa["Right"], top: 0, right: sw, bottom: sh })
            }
            if (wa["Left"] > 0)
                rects.Push({ left: 0, top: 0, right: wa["Left"], bottom: sh })
            if (wa["Top"] > 0)
                rects.Push({ left: 0, top: 0, right: sw, bottom: wa["Top"] })
        } else {
            ; Default fallback: bottom 44px
            rects.Push({ left: 0, top: A_ScreenHeight - 44, right: A_ScreenWidth, bottom: A_ScreenHeight })
        }
    }
    return rects
}

GetPrimaryMonitorCoordinates() {
    try {
        monNum := MonitorGetPrimary()
        MonitorGet monNum, &L, &T, &R, &B
        return Map(
            "Left", L,
            "Top", T,
            "Right", R,
            "Bottom", B,
            "Width", R - L,
            "Height", B - T,
            "Number", monNum,
            "CenterX", (R + L) // 2,
            "CenterY", (B + T) // 2
        )
    } catch {
        ; Fallback to screen size if MonitorGetPrimary fails
        return Map(
            "Left", 0,
            "Top", 0,
            "Right", A_ScreenWidth,
            "Bottom", A_ScreenHeight,
            "Width", A_ScreenWidth,
            "Height", A_ScreenHeight,
            "Number", 1,
            "CenterX", A_ScreenWidth // 2,
            "CenterY", A_ScreenHeight // 2
        )
    }
}

;HOTKEYS

^!Space::ToggleArrangement()      ; Ctrl+Alt+Space to toggle
^!P::TogglePhysics()              ; Ctrl+Alt+P for physics
^!F::ToggleTimePhasing()          ; Ctrl+Alt+F for time phasing effects
^!M::ToggleSeamlessMonitorFloat() ; Ctrl+Alt+M for seamless multi-monitor floating
^!O::OptimizeWindowPositions()    ; Ctrl+Alt+O to optimize space utilization
^!L::ToggleWindowLock()           ; Ctrl+Alt+L to lock/unlock active window
^!D::DebugWindowManagement()       ; Ctrl+Alt+D to show debug info
^!U::UpdateConfig()               ; Ctrl+Alt+U to update configuration

SetTimer(UpdateWindowStates, Config["PhysicsTimeStep"])
SetTimer(ApplyWindowMovements, Config["VisualTimeStep"])
SetTimer(TimePhasing.UpdateEchoes.Bind(TimePhasing), Config["VisualTimeStep"])
UpdateWindowStates()

OnMessage(0x0003, WindowMoveHandler)
OnMessage(0x0005, WindowSizeHandler)

OnExit(*) {
    for hwnd in g["ManualWindows"]
        RemoveManualWindowBorder(hwnd)
    TimePhasing.CleanupEffects()
    DllCall("winmm\timeEndPeriod", "UInt", 1)
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
        MonitorGet monNum, &mL, &mT, &mR, &mB

        for win in g["Windows"] {
            if (win["hwnd"] == hwnd) {
                ; Remove manual lock and border when window is moved manually
                if (win.Has("ManualLock"))
                    win.Delete("ManualLock")
                if (win.Has("IsManual"))
                    win.Delete("IsManual")
                RemoveManualWindowBorder(hwnd)
                win["vx"] := 0
                win["vy"] := 0
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
                ; Remove manual lock and border when window is resized manually
                if (win.Has("ManualLock"))
                    win.Delete("ManualLock")
                if (win.Has("IsManual"))
                    win.Delete("IsManual")
                RemoveManualWindowBorder(hwnd)
                win["vx"] := 0
                win["vy"] := 0
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

UpdateConfig() {
    global Config
    ; Simple configuration update function
    ShowTooltip("Configuration updated - Current settings applied")
    
    ; You can add specific config updates here if needed
    ; For example:
    ; Config["AttractionForce"] := 0.0001
    ; Config["RepulsionForce"] := 0.369
    
    ; Force window state refresh
    if (g.Has("ArrangementActive") && g["ArrangementActive"]) {
        UpdateWindowStates()
    }
}

DebugWindowManagement() {
    global g, Config
    
    try {
        allWindows := WinGetList()
        debugText := ""
        count := 0
        floatingCount := 0
        managedCount := g["Windows"].Length

        debugText .= "=================`n"
        debugText .= "FWDE Debug Info:`n"
        debugText .= "Arrangement Active: " (g["ArrangementActive"] ? "Yes" : "No") "`n"
        debugText .= "Physics Enabled: " (g["PhysicsEnabled"] ? "Yes" : "No") "`n"
        debugText .= "Seamless Monitor Float: " (Config["SeamlessMonitorFloat"] ? "Yes" : "No") "`n"
        debugText .= "Managed Windows: " managedCount "`n`n"

        for hwnd in allWindows {
            try {
                if (!IsWindowValid(hwnd))
                    continue
                    
                isFloating := IsWindowFloating(hwnd)
                winClass := WinGetClass("ahk_id " hwnd)
                title := WinGetTitle("ahk_id " hwnd)
                
                if (title == "" || StrLen(title) > 50)
                    title := SubStr(title, 1, 50) "..."

                debugText .= "Window: " title "`n"
                debugText .= "  Class: " winClass "`n"
                debugText .= "  Floating: " (isFloating ? "Yes" : "No") "`n"

                if (isFloating) {
                    floatingCount++
                    ; Check if it's in our managed list
                    isManaged := false
                    for win in g["Windows"] {
                        if (win["hwnd"] == hwnd) {
                            isManaged := true
                            debugText .= "  Managed: Yes`n"
                            break
                        }
                    }
                    if (!isManaged)
                        debugText .= "  Managed: No`n"
                }
                debugText .= "`n"
            }
            catch as e {
                debugText .= "Error processing window: " e.Message "`n"
            }
            count++
            if (count >= 10)    ; Limit to first 10 windows for debug output
                break
        }

        debugText .= "=================`n"
        debugText .= "Total Windows Checked: " count "`n"
        debugText .= "Total Floating Windows: " floatingCount "`n"
        debugText .= "Currently Managed: " managedCount "`n"

        ; Show debug info in a message box for now
        MsgBox(debugText, "FWDE Debug Information", "OK")
        
    }
    catch as e {
        MsgBox("Debug error: " e.Message, "FWDE Debug Error", "OK")
    }
}