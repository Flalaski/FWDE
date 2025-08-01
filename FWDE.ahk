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
global SystemState := Map(      ; System state tracking for recovery
    "LastValidState", Map(),
    "ErrorCount", 0,
    "LastError", "",
    "RecoveryAttempts", 0,
    "MaxRecoveryAttempts", 3,
    "SystemHealthy", true,
    "FailedOperations", []
)

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
        RecordSystemError("SafeWinExist", e, hwnd)
        return 0
    }
}

; Enhanced error recording and recovery system
RecordSystemError(operation, error, context := "") {
    global SystemState
    
    SystemState["ErrorCount"]++
    SystemState["LastError"] := operation ": " error.Message
    
    errorRecord := Map(
        "Operation", operation,
        "Error", error.Message,
        "Context", String(context),
        "Timestamp", A_TickCount,
        "CallStack", error.Stack ?? "N/A"
    )
    
    SystemState["FailedOperations"].Push(errorRecord)
    
    ; Keep only last 50 errors to prevent memory bloat
    if (SystemState["FailedOperations"].Length > 50) {
        SystemState["FailedOperations"].RemoveAt(1)
    }
    
    DebugLog("ERROR", operation " failed: " error.Message " (Context: " String(context) ")", 1)
    
    ; Check if system health is degrading
    if (SystemState["ErrorCount"] > 10) {
        SystemState["SystemHealthy"] := false
        DebugLog("SYSTEM", "System health degraded - error count: " SystemState["ErrorCount"], 1)
    }
}

; System recovery mechanism
AttemptSystemRecovery() {
    global SystemState, g
    
    SystemState["RecoveryAttempts"]++
    DebugLog("RECOVERY", "Attempting system recovery #" SystemState["RecoveryAttempts"], 2)
    
    if (SystemState["RecoveryAttempts"] > SystemState["MaxRecoveryAttempts"]) {
        DebugLog("RECOVERY", "Max recovery attempts reached, entering safe mode", 1)
        EnterSafeMode()
        return false
    }
    
    try {
        ; Clear stale data
        CleanupStaleWindows()
        
        ; Reset physics state
        for win in g["Windows"] {
            win["vx"] := 0
            win["vy"] := 0
        }
        
        ; Clear movement caches
        global hwndPos, smoothPos, lastPositions, moveBatch
        hwndPos.Clear()
        smoothPos.Clear()
        lastPositions.Clear()
        moveBatch := []
        
        ; Reset error counters
        SystemState["ErrorCount"] := 0
        SystemState["SystemHealthy"] := true
        
        DebugLog("RECOVERY", "System recovery completed successfully", 2)
        return true
    }
    catch as e {
        DebugLog("RECOVERY", "Recovery failed: " e.Message, 1)
        return false
    }
}

; Safe mode operation with minimal functionality
EnterSafeMode() {
    global g, SystemState
    
    DebugLog("SYSTEM", "Entering safe mode - disabling advanced features", 1)
    
    ; Disable physics and advanced features
    g["PhysicsEnabled"] := false
    g["FairyDustEnabled"] := false
    g["ArrangementActive"] := false
    
    ; Stop all timers
    try {
        SetTimer(CalculateDynamicLayout, 0)
        SetTimer(ApplyWindowMovements, 0)
        SetTimer(UpdateScreenshotState, 0)
    }
    catch as e {
        DebugLog("SYSTEM", "Error stopping timers in safe mode: " e.Message, 1)
    }
    
    SystemState["SafeMode"] := true
    ShowTooltip("FWDE: System entered safe mode due to errors")
}

; Enhanced window validation with retry logic
IsWindowValid(hwnd) {
    DebugLog("VALIDATION", "Checking window validity for hwnd: " hwnd, 5)
    
    ; Retry mechanism for API calls
    maxRetries := 2
    retryCount := 0
    
    while (retryCount <= maxRetries) {
        try {
            if (!SafeWinExist(hwnd)) {
                DebugLog("VALIDATION", "Window " hwnd " does not exist", 4)
                return false
            }

            ; Enhanced error handling for window properties
            try {
                minMax := WinGetMinMax("ahk_id " hwnd)
                if (minMax != 0) {
                    DebugLog("VALIDATION", "Window " hwnd " is minimized/maximized (state: " minMax ")", 4)
                    return false
                }
            }
            catch as e {
                if (retryCount < maxRetries) {
                    retryCount++
                    Sleep(50)  ; Brief delay before retry
                    continue
                }
                RecordSystemError("IsWindowValid_MinMax", e, hwnd)
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
                if (retryCount < maxRetries) {
                    retryCount++
                    Sleep(50)
                    continue
                }
                RecordSystemError("IsWindowValid_Title", e, hwnd)
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
                if (retryCount < maxRetries) {
                    retryCount++
                    Sleep(50)
                    continue
                }
                RecordSystemError("IsWindowValid_Styles", e, hwnd)
                return false
            }

            DebugLog("VALIDATION", "Window " hwnd " is valid", 5)
            return true
            
        }
        catch as e {
            if (retryCount < maxRetries) {
                retryCount++
                DebugLog("VALIDATION", "Retry " retryCount " for window " hwnd " after error: " e.Message, 3)
                Sleep(100)  ; Longer delay for general errors
                continue
            }
            RecordSystemError("IsWindowValid_General", e, hwnd)
            return false
        }
    }
    
    return false
}

; CRITICAL FIX: Enhanced ApplyWindowMovements with comprehensive error handling
ApplyWindowMovements() {
    global Config, g, hwndPos, smoothPos, lastPositions, moveBatch
    
    if (!g["PhysicsEnabled"] || g["ScreenshotPaused"]) {
        return
    }
    
    StartPerfTimer("ApplyWindowMovements")
    
    try {
        ; Process batch movements with enhanced error handling
        processedCount := 0
        errorCount := 0
        
        for moveData in moveBatch {
            try {
                hwnd := moveData["hwnd"]
                targetX := moveData["x"]
                targetY := moveData["y"]
                
                ; Validate window still exists before moving
                if (!SafeWinExist(hwnd)) {
                    DebugLog("MOVEMENT", "Skipping movement for invalid window " hwnd, 4)
                    continue
                }
                
                ; Get current position for validation
                try {
                    WinGetPos(&currentX, &currentY, &currentW, &currentH, "ahk_id " hwnd)
                    
                    ; Skip if position hasn't changed significantly
                    if (Abs(currentX - targetX) < 1 && Abs(currentY - targetY) < 1) {
                        continue
                    }
                    
                    ; Perform the move with retry logic
                    if (MoveWindowAPI(hwnd, targetX, targetY)) {
                        processedCount++
                        
                        ; Update position cache
                        hwndPos[hwnd] := Map("x", targetX, "y", targetY)
                        lastPositions[hwnd] := Map("x", targetX, "y", targetY, "time", A_TickCount)
                        
                        DebugLog("MOVEMENT", "Successfully moved window " hwnd " to " targetX "," targetY, 5)
                    } else {
                        errorCount++
                        DebugLog("MOVEMENT", "Failed to move window " hwnd " to " targetX "," targetY, 2)
                    }
                }
                catch as e {
                    errorCount++
                    RecordSystemError("ApplyWindowMovements_WinGetPos", e, hwnd)
                    continue
                }
            }
            catch as e {
                errorCount++
                RecordSystemError("ApplyWindowMovements_ProcessBatch", e, moveData.Get("hwnd", "unknown"))
                continue
            }
        }
        
        ; Clear batch after processing
        moveBatch := []
        
        DebugLog("MOVEMENT", "Batch processed: " processedCount " successful, " errorCount " errors", 3)
        
        ; Check error rate and trigger recovery if needed
        if (errorCount > 0 && processedCount > 0) {
            errorRate := errorCount / (processedCount + errorCount)
            if (errorRate > 0.3) {  ; More than 30% error rate
                DebugLog("MOVEMENT", "High error rate detected: " Round(errorRate * 100) "%", 2)
                if (SystemState["SystemHealthy"]) {
                    AttemptSystemRecovery()
                }
            }
        }
    }
    catch as e {
        RecordSystemError("ApplyWindowMovements_Main", e)
        
        ; Emergency cleanup
        try {
            moveBatch := []
        }
        catch {
            ; If even this fails, we're in serious trouble
            DebugLog("MOVEMENT", "Emergency cleanup failed - system may be unstable", 1)
        }
    }
    
    EndPerfTimer("ApplyWindowMovements")
}

; Enhanced MoveWindowAPI with retry logic and error handling
MoveWindowAPI(hwnd, x, y) {
    maxRetries := 3
    retryCount := 0
    
    while (retryCount <= maxRetries) {
        try {
            ; Validate window exists before attempting move
            if (!SafeWinExist(hwnd)) {
                DebugLog("MOVE_API", "Window " hwnd " no longer exists", 4)
                return false
            }
            
            ; Use Windows API for reliable movement
            result := DllCall("user32.dll\SetWindowPos", 
                "Ptr", hwnd,
                "Ptr", 0,
                "Int", Round(x),
                "Int", Round(y),
                "Int", 0,
                "Int", 0,
                "UInt", 0x0001 | 0x0004)  ; SWP_NOSIZE | SWP_NOZORDER
            
            if (result) {
                DebugLog("MOVE_API", "Successfully moved window " hwnd " to " Round(x) "," Round(y), 5)
                return true
            } else {
                lastError := DllCall("kernel32.dll\GetLastError", "UInt")
                DebugLog("MOVE_API", "SetWindowPos failed for window " hwnd " - Error: " lastError, 2)
                
                if (retryCount < maxRetries) {
                    retryCount++
                    Sleep(25)  ; Brief delay before retry
                    continue
                } else {
                    RecordSystemError("MoveWindowAPI_SetWindowPos", Map("Message", "API Error " lastError), hwnd)
                    return false
                }
            }
        }
        catch as e {
            if (retryCount < maxRetries) {
                retryCount++
                DebugLog("MOVE_API", "Retry " retryCount " for window " hwnd " after error: " e.Message, 3)
                Sleep(50)
                continue
            } else {
                RecordSystemError("MoveWindowAPI_Exception", e, hwnd)
                return false
            }
        }
    }
    
    return false
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
    errorCount := 0
    
    try {
        hwndList := WinGetList()
        DebugLog("WINDOWS", "Processing " hwndList.Length " total windows", 3)
        
        for hwnd in hwndList {
            windowCount++
            try {
                ; Enhanced window validation with error handling
                if (!IsWindowValid(hwnd)) {
                    DebugLog("WINDOWS", "Window " hwnd " failed validation", 5)
                    continue
                }
                validCount++

                ; Get window properties with retry logic
                windowData := GetWindowProperties(hwnd)
                if (!windowData) {
                    errorCount++
                    continue
                }

                ; Special handling for plugin windows
                isPlugin := IsPluginWindow(hwnd)
                if (isPlugin) {
                    pluginCount++
                }

                ; Force include plugin windows or check floating status
                if (isPlugin || IsWindowFloating(hwnd)) {
                    windowData["isPlugin"] := isPlugin
                    windowData["lastSeen"] := A_TickCount
                    allWindows.Push(windowData)
                    DebugLog("WINDOWS", "Added window " hwnd " (" windowData["width"] "x" windowData["height"] " at " windowData["x"] "," windowData["y"] ") - Plugin: " (isPlugin ? "Yes" : "No"), 5)
                } else {
                    DebugLog("WINDOWS", "Skipped window " hwnd " (not floating)", 5)
                }
            }
            catch as e {
                errorCount++
                RecordSystemError("GetVisibleWindows_ProcessWindow", e, hwnd)
                continue
            }
        }

        DebugLog("WINDOWS", "Window analysis: " windowCount " total, " validCount " valid, " allWindows.Length " candidates, " pluginCount " plugins, " errorCount " errors", 3)

        ; Process windows for inclusion with enhanced error handling
        WinList := ProcessWindowsForInclusion(allWindows, monitor)

    }
    catch as e {
        RecordSystemError("GetVisibleWindows_Main", e)
        
        ; Return empty list on critical failure
        WinList := []
    }

    ; Clean up windows that are no longer valid
    try {
        CleanupStaleWindows()
    }
    catch as e {
        RecordSystemError("GetVisibleWindows_Cleanup", e)
    }

    elapsed := EndPerfTimer("GetVisibleWindows")
    DebugLog("WINDOWS", "GetVisibleWindows completed in " elapsed "ms", 3)
    return WinList
}

; Helper function to get window properties with error handling
GetWindowProperties(hwnd) {
    maxRetries := 2
    retryCount := 0
    
    while (retryCount <= maxRetries) {
        try {
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            if (w == 0 || h == 0) {
                DebugLog("WINDOWS", "Window " hwnd " has zero dimensions: " w "x" h, 4)
                return false
            }
            
            return Map(
                "hwnd", hwnd,
                "x", x, "y", y,
                "width", w, "height", h
            )
        }
        catch as e {
            if (retryCount < maxRetries) {
                retryCount++
                Sleep(25)
                continue
            } else {
                RecordSystemError("GetWindowProperties", e, hwnd)
                return false
            }
        }
    }
    
    return false
}

; Helper function to process windows for inclusion
ProcessWindowsForInclusion(allWindows, monitor) {
    global Config, g
    WinList := []
    includedCount := 0
    excludedCount := 0
    
    try {
        ; Get current mouse position for monitor check
        CoordMode "Mouse", "Screen"
        MouseGetPos(&mx, &my)
        activeMonitor := MonitorGetFromPoint(mx, my)

        for window in allWindows {
            try {
                winCenterX := window["x"] + window["width"]/2
                winCenterY := window["y"] + window["height"]/2

                ; Determine which monitor the window is on with error handling
                winMonitor := MonitorGetFromPoint(winCenterX, winCenterY)
                if (!winMonitor) {
                    winMonitor := MonitorGetPrimary()
                    DebugLog("WINDOWS", "Could not determine monitor for window " window["hwnd"] ", using primary", 2)
                }

                ; Get monitor bounds with error handling
                try {
                    MonitorGet winMonitor, &mL, &mT, &mR, &mB
                }
                catch as e {
                    RecordSystemError("ProcessWindowsForInclusion_MonitorGet", e, winMonitor)
                    ; Use screen bounds as fallback
                    mL := 0
                    mT := 0
                    mR := A_ScreenWidth
                    mB := A_ScreenHeight
                }

                ; Check if window should be included based on floating mode
                includeWindow := ShouldIncludeWindow(window, monitor, winMonitor)

                if (includeWindow) {
                    includedCount++
                    
                    ; Apply constraints and create window entry
                    processedWindow := CreateProcessedWindowEntry(window, winMonitor, mL, mT, mR, mB)
                    if (processedWindow) {
                        WinList.Push(processedWindow)

                        ; Add time-phasing echo for plugin windows
                        if (window["isPlugin"] && g["FairyDustEnabled"]) {
                            try {
                                TimePhasing.AddEcho(window["hwnd"])
                            }
                            catch as e {
                                RecordSystemError("ProcessWindowsForInclusion_TimePhasing", e, window["hwnd"])
                            }
                        }
                    }
                } else {
                    excludedCount++
                }
            }
            catch as e {
                RecordSystemError("ProcessWindowsForInclusion_ProcessWindow", e, window.Get("hwnd", "unknown"))
                continue
            }
        }

        DebugLog("WINDOWS", "Final result: " includedCount " included, " excludedCount " excluded from " allWindows.Length " candidates", 3)
    }
    catch as e {
        RecordSystemError("ProcessWindowsForInclusion_Main", e)
    }
    
    return WinList
}

; Helper function to determine if window should be included
ShouldIncludeWindow(window, monitor, winMonitor) {
    global Config, g
    
    try {
        if (Config["SeamlessMonitorFloat"]) {
            ; In seamless mode, include all windows from all monitors
            DebugLog("WINDOWS", "Window " window["hwnd"] " included (seamless mode)", 5)
            return true
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
            return includeWindow
        }
    }
    catch as e {
        RecordSystemError("ShouldIncludeWindow", e, window.Get("hwnd", "unknown"))
        return false
    }
}

; Helper function to create processed window entry
CreateProcessedWindowEntry(window, winMonitor, mL, mT, mR, mB) {
    global Config, g
    
    try {
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
            "lastZOrder", existingWin ? existingWin.Get("lastZOrder", -1) : -1
        )
        
        return newWin
    }
    catch as e {
        RecordSystemError("CreateProcessedWindowEntry", e, window.Get("hwnd", "unknown"))
        return false
    }
}

; ...existing code...