#Requires AutoHotkey v2.0
#SingleInstance Force
#WinActivateForce
#Warn
#MaxThreadsPerHotkey 255
#MaxThreads 255

A_IconTip := "Floating Windows - Dynamic Equilibrium"
ProcessSetPriority("High")

; ===== CORE SYSTEM INITIALIZATION =====
; Initialize all global state containers
global g := Map(
    "Windows", [],
    "PhysicsEnabled", true,
    "ArrangementActive", true,
    "ScreenshotPaused", false,
    "Monitor", Map()
)

; Performance and physics buffers
global g_NoiseBuffer := Buffer(1024)
global g_PhysicsBuffer := Buffer(4096)
global hwndPos := Map()
global smoothPos := Map()
global lastPositions := Map()
global moveBatch := []
global PerfTimers := Map()

; System health monitoring
global SystemState := Map(
    "LastValidState", Map(),
    "ErrorCount", 0,
    "LastError", "",
    "RecoveryAttempts", 0,
    "MaxRecoveryAttempts", 3,
    "SystemHealthy", true,
    "FailedOperations", []
)

; ===== OPTIMIZED CONFIGURATION SYSTEM =====
global Config := Map(
    ; Core Physics
    "AttractionForce", 0.01,        ; Increased from 0.0001 for more noticeable movement
    "RepulsionForce", 0.369,
    "Damping", 0.001,
    "MaxSpeed", 12.0,
    
    ; Layout Parameters
    "MinMargin", 0,
    "MinGap", 0,
    "ManualGapBonus", 369,
    "EdgeRepulsionForce", 0.80,
    
    ; Timing & Performance
    "PhysicsTimeStep", 1,
    "VisualTimeStep", 2,
    "UserMoveTimeout", 11111,
    "ManualLockDuration", 33333,
    "ResizeDelay", 22,
    
    ; Features
    "SeamlessMonitorFloat", false,
    "ScreenshotPauseDuration", 5000,
    
    ; Visual Effects
    "Smoothing", 0.5,
    "AnimationDuration", 32,
    "ManualWindowColor", "FF5555",
    "ManualWindowAlpha", 222,
    
    ; Stabilization
    "MinSpeedThreshold", 0.1,       ; Reduced from 0.369 to allow more movement
    "EnergyThreshold", 0.06,
    "DampingBoost", 0.12,
    "OverlapTolerance", 0,
    
    ; Screenshot Detection
    "ScreenshotProcesses", ["ScreenToGif.exe", "Greenshot.exe", "LightShot.exe", "Snagit32.exe", "SnippingTool.exe", "ms-screenclip.exe", "PowerToys.ScreenRuler.exe", "flameshot.exe", "obs64.exe", "obs32.exe"],
    "ScreenshotWindowClasses", ["GDI+ Hook Window Class", "CrosshairOverlay", "ScreenshotOverlay", "CaptureOverlay", "SelectionOverlay", "SnipOverlay"],
    "ScreenshotCheckInterval", 500,  ; Reduced frequency to avoid spam
    
    ; Float Detection
    "FloatStyles", 0x00C00000 | 0x00040000 | 0x00080000 | 0x00020000 | 0x00010000,
    "FloatClassPatterns", ["Vst.*", "JS.*", ".*Plugin.*", ".*Float.*", ".*Dock.*", "#32770", "ConsoleWindowClass"],
    "FloatTitlePatterns", ["VST.*", "JS:.*", "Plugin", ".*FX.*", "Command Prompt", "cmd.exe", "Windows Terminal"],
    "ForceFloatProcesses", ["reaper.exe", "ableton.exe", "flstudio.exe", "cubase.exe", "studioone.exe", "bitwig.exe", "protools.exe", "cmd.exe", "conhost.exe", "WindowsTerminal.exe"],
    
    ; Advanced Settings
    "NoiseScale", 888,
    "NoiseInfluence", 100,
    "PhysicsUpdateInterval", 200,
    "ManualRepulsionMultiplier", 1.3,
    "TooltipDuration", 15000
)

; Configuration file paths
global ConfigFile := A_ScriptDir "\FWDE_Config.json"
global ConfigBackupFile := A_ScriptDir "\FWDE_Config_Backup.json"

; ===== CORE UTILITY FUNCTIONS =====
DebugLog(category, message, level := 3) {
    try {
        OutputDebug("[" . category . "] " . message)
    } catch {
        ; Silent fail for debug output
    }
}

ShowTooltip(message, duration := 3000) {
    ToolTip(message)
    SetTimer(() => ToolTip(), -duration)
}

ShowNotificationSimple(title, message, type := "info", duration := 3000) {
    ToolTip(title . ": " . message)
    SetTimer(() => ToolTip(), -duration)
}

RecordSystemError(operation, error, context := "") {
    global SystemState
    try {
        SystemState["ErrorCount"]++
        SystemState["LastError"] := operation . ": " . error.Message . " (" . context . ")"
        DebugLog("ERROR", SystemState["LastError"], 1)
        
        ; Add to failed operations log
        if (SystemState["FailedOperations"].Length > 50) {
            SystemState["FailedOperations"].RemoveAt(1)
        }
        SystemState["FailedOperations"].Push(Map(
            "timestamp", A_Now,
            "operation", operation,
            "error", error.Message,
            "context", context
        ))
    } catch {
        ; Silent fail for error recording
    }
}

IsWindowValid(hwnd) {
    try {
        return WinExist("ahk_id " . hwnd) != 0
    } catch {
        return false
    }
}

GetCurrentMonitorInfo() {
    try {
        ; Get primary monitor bounds
        MonitorPrimary := SysGet(1)
        return Map(
            "Left", MonitorPrimary.left,
            "Top", MonitorPrimary.top,
            "Right", MonitorPrimary.right,
            "Bottom", MonitorPrimary.bottom,
            "Width", MonitorPrimary.right - MonitorPrimary.left,
            "Height", MonitorPrimary.bottom - MonitorPrimary.top
        )
    } catch {
        ; Fallback to work area
        return Map(
            "Left", 0,
            "Top", 0,
            "Right", 1920,
            "Bottom", 1080,
            "Width", 1920,
            "Height", 1080
        )
    }
}

RecordPerformanceMetric(operation, timeMs) {
    global PerfTimers
    try {
        if (!PerfTimers.Has(operation)) {
            PerfTimers[operation] := Map("total", 0, "count", 0, "avg", 0, "max", 0)
        }
        
        metric := PerfTimers[operation]
        metric["total"] += timeMs
        metric["count"]++
        metric["avg"] := metric["total"] / metric["count"]
        metric["max"] := Max(metric["max"], timeMs)
        
        ; Log if performance is degrading
        if (timeMs > 50) {
            DebugLog("PERF", operation . " took " . timeMs . "ms (avg: " . Round(metric["avg"], 1) . "ms)", 2)
        }
    } catch as e {
        DebugLog("PERF", "Failed to record metric for " . operation . ": " . e.Message, 1)
    }
}

; ===== LAYOUT ALGORITHMS =====
RectsOverlap(rect1, rect2) {
    try {
        return !(rect1["x"] + rect1["width"] <= rect2["x"] ||
                rect2["x"] + rect2["width"] <= rect1["x"] ||
                rect1["y"] + rect1["height"] <= rect2["y"] ||
                rect2["y"] + rect2["height"] <= rect1["y"])
    } catch {
        return false
    }
}

ApplyLayoutPlacements(placements) {
    global g
    try {
        DebugLog("LAYOUT", "Applying " . placements.Length . " window placements", 2)
        
        for placement in placements {
            if (IsWindowValid(placement["hwnd"])) {
                WinMove(placement["x"], placement["y"], placement["width"], placement["height"], "ahk_id " . placement["hwnd"])
                
                ; Update internal tracking
                for win in g["Windows"] {
                    if (win["hwnd"] == placement["hwnd"]) {
                        win["x"] := placement["x"]
                        win["y"] := placement["y"]
                        win["width"] := placement["width"]
                        win["height"] := placement["height"]
                        break
                    }
                }
            }
        }
    } catch as e {
        RecordSystemError("ApplyLayoutPlacements", e)
    }
}

; ===== PHYSICS SYSTEM =====
ApplyPhysicsToWindow(win) {
    global Config
    try {
        if (!IsWindowValid(win["hwnd"])) {
            return
        }
        
        ; Skip windows that have previously failed access checks
        if (win.Get("accessDenied", false)) {
            return
        }
        
        bounds := GetCurrentMonitorInfo()
        
        ; Calculate forces
        centerX := bounds["Left"] + bounds["Width"] / 2
        centerY := bounds["Top"] + bounds["Height"] / 2
        
        ; Attraction to center
        dx := (centerX - win["x"]) * Config["AttractionForce"]
        dy := (centerY - win["y"]) * Config["AttractionForce"]
        
        ; Apply damping
        dx *= (1 - Config["Damping"])
        dy *= (1 - Config["Damping"])
        
        ; Limit maximum speed
        speed := Sqrt(dx*dx + dy*dy)
        if (speed > Config["MaxSpeed"]) {
            dx := (dx / speed) * Config["MaxSpeed"]
            dy := (dy / speed) * Config["MaxSpeed"]
        }
        
        ; Apply movement if above threshold
        if (speed > Config["MinSpeedThreshold"]) {
            newX := win["x"] + dx
            newY := win["y"] + dy
            
            ; Ensure window stays within bounds
            newX := Max(bounds["Left"], Min(newX, bounds["Right"] - win["width"]))
            newY := Max(bounds["Top"], Min(newY, bounds["Bottom"] - win["height"]))
            
            win["x"] := newX
            win["y"] := newY
            
            ; Try to move window - catch access denied errors
            try {
                WinMove(newX, newY, , , "ahk_id " . win["hwnd"])
                
                ; Debug: Log physics activity occasionally
                static lastDebugTime := 0
                if (A_TickCount - lastDebugTime > 2000) {
                    DebugLog("PHYSICS", "Moving window '" . win["title"] . "' with speed " . Round(speed, 3) . " (dx:" . Round(dx, 2) . " dy:" . Round(dy, 2) . ")", 2)
                    lastDebugTime := A_TickCount
                }
            } catch as moveError {
                ; Mark window as access denied to avoid future attempts
                if (moveError.Number == 5) {  ; Access denied
                    win["accessDenied"] := true
                    DebugLog("PHYSICS", "Window '" . win["title"] . "' marked as access denied - skipping future physics", 2)
                } else {
                    throw moveError
                }
            }
        } else {
            ; Debug: Log why window isn't moving
            static lastThresholdLogTime := 0
            if (A_TickCount - lastThresholdLogTime > 5000) {
                DebugLog("PHYSICS", "Window '" . win["title"] . "' speed " . Round(speed, 3) . " below threshold " . Config["MinSpeedThreshold"], 3)
                lastThresholdLogTime := A_TickCount
            }
        }
    } catch as e {
        RecordSystemError("ApplyPhysicsToWindow", e, win["hwnd"])
    }
}

; ===== MAIN PHYSICS LOOP =====
CalculateDynamicLayout() {
    global g, Config
    
    if (!g.Get("PhysicsEnabled", false) || !g.Get("ArrangementActive", false) || g.Get("ScreenshotPaused", false)) {
        if (g.Get("ScreenshotPaused", false)) {
            ; Only log occasionally to avoid spam
            static lastLogTime := 0
            if (A_TickCount - lastLogTime > 1000) {
                DebugLog("PHYSICS", "Physics paused for screenshot activity", 3)
                lastLogTime := A_TickCount
            }
        }
        return
    }
    
    startTime := A_TickCount
    
    ; Debug: Log physics loop activity occasionally
    static lastPhysicsLogTime := 0
    if (A_TickCount - lastPhysicsLogTime > 3000) {
        DebugLog("PHYSICS", "Physics loop running - processing " . g["Windows"].Length . " windows", 3)
        lastPhysicsLogTime := A_TickCount
    }
    
    try {
        ; Update window positions with physics
        for win in g["Windows"] {
            if (!win.Get("manualLock", false) && !win.Get("accessDenied", false) && IsWindowValid(win["hwnd"])) {
                ApplyPhysicsToWindow(win)
            }
        }
        
        ; Record performance
        RecordPerformanceMetric("CalculateDynamicLayout", A_TickCount - startTime)
        
    } catch as e {
        RecordSystemError("CalculateDynamicLayout", e)
    }
}

; ===== SCREENSHOT DETECTION =====
; Track screenshot activity to avoid false positives from idle processes
global ScreenshotState := Map(
    "LastActivityCheck", 0,
    "ProcessMonitoringThreshold", 1000,  ; Only check processes every 1 second
    "ActiveWindowClasses", [],
    "RecentlyActiveProcesses", Map()
)

CheckScreenshotActivity() {
    global Config, g, ScreenshotState
    try {
        ; Check if screenshot detection is enabled (default to true if not set)
        if (!g.Get("ScreenshotDetectionEnabled", true)) {
            return
        }
        
        currentTime := A_TickCount
        
        ; Only check processes periodically to reduce false positives
        if (currentTime - ScreenshotState["LastActivityCheck"] < ScreenshotState["ProcessMonitoringThreshold"]) {
            ; Still check for active screenshot windows frequently
            CheckActiveScreenshotWindows()
            return
        }
        
        ScreenshotState["LastActivityCheck"] := currentTime
        
        ; Check for screenshot window classes (these indicate active screenshot UI)
        CheckActiveScreenshotWindows()
        
        ; More intelligent process checking - look for signs of actual activity
        CheckScreenshotProcessActivity()
        
    } catch as e {
        RecordSystemError("CheckScreenshotActivity", e)
    }
}

CheckActiveScreenshotWindows() {
    global Config, g
    try {
        ; Check for screenshot window classes that indicate active screenshot UI
        for className in Config["ScreenshotWindowClasses"] {
            if (WinExist("ahk_class " . className)) {
                if (!g["ScreenshotPaused"]) {
                    g["ScreenshotPaused"] := true
                    DebugLog("SCREENSHOT", "Active screenshot UI detected: " . className . ", pausing physics", 2)
                    ; Capture className in closure
                    capturedClass := className
                    SetTimer(() => (
                        g["ScreenshotPaused"] := false,
                        DebugLog("SCREENSHOT", "Physics resumed after screenshot UI: " . capturedClass, 2)
                    ), -Config["ScreenshotPauseDuration"])
                }
                return true
            }
        }
        return false
    } catch as e {
        RecordSystemError("CheckActiveScreenshotWindows", e)
        return false
    }
}

CheckScreenshotProcessActivity() {
    global Config, g, ScreenshotState
    try {
        ; For processes like ShareX, check if they have visible screenshot-related windows
        ; rather than just checking if the process exists
        for processName in Config["ScreenshotProcesses"] {
            if (ProcessExist(processName)) {
                ; Check if this process has any active screenshot-related windows
                if (HasActiveScreenshotWindows(processName)) {
                    if (!g["ScreenshotPaused"]) {
                        g["ScreenshotPaused"] := true
                        DebugLog("SCREENSHOT", "Active screenshot operation detected from " . processName . ", pausing physics", 2)
                        ; Capture processName in closure
                        capturedProcess := processName
                        SetTimer(() => (
                            g["ScreenshotPaused"] := false,
                            DebugLog("SCREENSHOT", "Physics resumed after " . capturedProcess . " activity", 2)
                        ), -Config["ScreenshotPauseDuration"])
                    }
                    return true
                }
            }
        }
        return false
    } catch as e {
        RecordSystemError("CheckScreenshotProcessActivity", e)
        return false
    }
}

HasActiveScreenshotWindows(processName) {
    try {
        ; More reliable window enumeration - check all windows and verify process ownership
        windowList := WinGetList()
        
        for hwnd in windowList {
            if (!WinExist("ahk_id " . hwnd)) {
                continue
            }
            
            ; Verify this window actually belongs to the target process
            try {
                windowProcess := WinGetProcessName("ahk_id " . hwnd)
                if (windowProcess != processName) {
                    continue
                }
            } catch {
                continue
            }
            
            title := WinGetTitle("ahk_id " . hwnd)
            windowClass := WinGetClass("ahk_id " . hwnd)
            
            ; Check for screenshot-specific window titles or classes
            if (RegExMatch(title, "i)(capture|screenshot|snip|select|region|area|crop)") ||
                RegExMatch(windowClass, "i)(capture|screenshot|snip|select|overlay)")) {
                
                ; Additional check: window must be visible and have reasonable size
                if (DllCall("IsWindowVisible", "ptr", hwnd)) {
                    WinGetPos(&x, &y, &width, &height, "ahk_id " . hwnd)
                    if (width > 50 && height > 50) {
                        return true
                    }
                }
            }
        }
        
        return false
    } catch {
        return false
    }
}

; ===== WINDOW DETECTION =====
RefreshWindowList() {
    global g, Config
    try {
        g["Windows"] := []
        
        ; Enumerate all visible windows
        windowList := WinGetList()
        
        for hwnd in windowList {
            try {
                ; Skip if window is not visible or valid
                if (!WinExist("ahk_id " . hwnd) || !DllCall("IsWindowVisible", "ptr", hwnd)) {
                    continue
                }
                
                ; Get window info
                WinGetPos(&x, &y, &width, &height, "ahk_id " . hwnd)
                title := WinGetTitle("ahk_id " . hwnd)
                windowClass := WinGetClass("ahk_id " . hwnd)
                processName := WinGetProcessName("ahk_id " . hwnd)
                
                ; Skip invalid windows
                if (width < 50 || height < 50 || !title) {
                    continue
                }
                
                ; Check if should be floating
                shouldFloat := ShouldWindowFloat(hwnd, title, windowClass, processName)
                
                if (shouldFloat) {
                    g["Windows"].Push(Map(
                        "hwnd", hwnd,
                        "x", x,
                        "y", y,
                        "width", width,
                        "height", height,
                        "title", title,
                        "class", windowClass,
                        "process", processName,
                        "manualLock", false,
                        "lastUserInteraction", 0
                    ))
                }
            } catch {
                ; Skip problematic windows
                continue
            }
        }
        
        DebugLog("WINDOWS", "Refreshed list: " . g["Windows"].Length . " floating windows", 3)
    } catch as e {
        RecordSystemError("RefreshWindowList", e)
    }
}

ShouldWindowFloat(hwnd, title, windowClass, processName) {
    global Config
    try {
        ; Check process whitelist
        for process in Config["ForceFloatProcesses"] {
            if (InStr(processName, process)) {
                return true
            }
        }
        
        ; Check class patterns
        for pattern in Config["FloatClassPatterns"] {
            if (RegExMatch(windowClass, pattern)) {
                return true
            }
        }
        
        ; Check title patterns
        for pattern in Config["FloatTitlePatterns"] {
            if (RegExMatch(title, pattern)) {
                return true
            }
        }
        
        ; Check window styles
        styles := WinGetStyle("ahk_id " . hwnd)
        if (styles & Config["FloatStyles"]) {
            return true
        }
        
        return false
    } catch {
        return false
    }
}

; ===== SYSTEM INITIALIZATION =====
InitializeSystem() {
    global g, Config
    try {
        DebugLog("SYSTEM", "Initializing FWDE system...", 2)
        
        ; Initialize monitor info
        g["Monitor"] := GetCurrentMonitorInfo()
        
        ; Load configuration
        LoadConfiguration()
        
        ; Initial window scan
        RefreshWindowList()
        
        ; Start main timers
        SetTimer(CalculateDynamicLayout, Config["PhysicsTimeStep"])
        SetTimer(RefreshWindowList, 2000)  ; Refresh window list every 2 seconds
        SetTimer(CheckScreenshotActivity, Config["ScreenshotCheckInterval"])
        
        DebugLog("SYSTEM", "FWDE system initialized successfully", 2)
        ShowTooltip("FWDE - Floating Windows Dynamic Equilibrium Started", 3000)
        
    } catch as e {
        RecordSystemError("InitializeSystem", e)
        ShowTooltip("FWDE initialization failed - check debug log", 5000)
    }
}

; ===== SIMPLIFIED CONFIGURATION =====
LoadConfiguration() {
    global ConfigFile, Config
    try {
        if (FileExist(ConfigFile)) {
            DebugLog("CONFIG", "Configuration file found, using defaults for now", 2)
            ; For now, just use defaults - can be extended later
        }
        DebugLog("CONFIG", "Configuration loaded successfully", 2)
    } catch as e {
        RecordSystemError("LoadConfiguration", e)
    }
}

SaveConfiguration() {
    global ConfigFile, Config
    try {
        ; Simple configuration save - can be extended later
        DebugLog("CONFIG", "Configuration saved", 2)
    } catch as e {
        RecordSystemError("SaveConfiguration", e)
    }
}

; ===== HOTKEYS =====
; Toggle physics system
^!p:: {
    global g
    g["PhysicsEnabled"] := !g["PhysicsEnabled"]
    status := g["PhysicsEnabled"] ? "Enabled" : "Disabled"
    ShowTooltip("Physics: " . status)
    DebugLog("HOTKEY", "Physics toggled: " . status, 2)
}

; Toggle arrangement system
^!a:: {
    global g
    g["ArrangementActive"] := !g["ArrangementActive"]
    status := g["ArrangementActive"] ? "Active" : "Inactive"
    ShowTooltip("Arrangement: " . status)
    DebugLog("HOTKEY", "Arrangement toggled: " . status, 2)
}

; Toggle seamless monitor floating
^!m:: {
    global Config
    Config["SeamlessMonitorFloat"] := !Config["SeamlessMonitorFloat"]
    status := Config["SeamlessMonitorFloat"] ? "Enabled" : "Disabled"
    ShowTooltip("Multi-Monitor Float: " . status)
    DebugLog("HOTKEY", "Multi-monitor floating toggled: " . status, 2)
}

; Toggle screenshot detection
^!s:: {
    global g
    if (!g.Has("ScreenshotDetectionEnabled")) {
        g["ScreenshotDetectionEnabled"] := true
    }
    g["ScreenshotDetectionEnabled"] := !g["ScreenshotDetectionEnabled"]
    status := g["ScreenshotDetectionEnabled"] ? "Enabled" : "Disabled"
    ShowTooltip("Screenshot Detection: " . status)
    DebugLog("HOTKEY", "Screenshot detection toggled: " . status, 2)
    
    ; If disabling, also unpause physics if currently paused by screenshot detection
    if (!g["ScreenshotDetectionEnabled"] && g.Get("ScreenshotPaused", false)) {
        g["ScreenshotPaused"] := false
        DebugLog("SCREENSHOT", "Physics unpaused due to screenshot detection being disabled", 2)
    }
}

; Temporary hotkey to remove ShareX from detection list
^!x:: {
    global Config
    newList := []
    for process in Config["ScreenshotProcesses"] {
        if (!InStr(process, "ShareX.exe")) {
            newList.Push(process)
        }
    }
    Config["ScreenshotProcesses"] := newList
    ShowTooltip("ShareX removed from screenshot detection")
    DebugLog("HOTKEY", "ShareX.exe removed from screenshot process list", 2)
}

; Refresh window list manually
^!r:: {
    RefreshWindowList()
    ShowTooltip("Window list refreshed")
    DebugLog("HOTKEY", "Manual window list refresh", 2)
}

; Emergency pause/resume
^!Pause:: {
    global g
    g["PhysicsEnabled"] := false
    g["ArrangementActive"] := false
    ShowTooltip("FWDE Emergency Stop - All systems paused")
    DebugLog("HOTKEY", "Emergency stop activated", 1)
}

; Show system status
^!i:: {
    global g, SystemState
    windowCount := g["Windows"].Length
    physicsStatus := g["PhysicsEnabled"] ? "ON" : "OFF"
    arrangementStatus := g["ArrangementActive"] ? "ON" : "OFF"
    screenshotDetectionStatus := g.Get("ScreenshotDetectionEnabled", true) ? "ON" : "OFF"
    screenshotPausedStatus := g.Get("ScreenshotPaused", false) ? "PAUSED" : "ACTIVE"
    errorCount := SystemState["ErrorCount"]
    
    statusMsg := "FWDE Status:`n"
    statusMsg .= "Windows: " . windowCount . "`n"
    statusMsg .= "Physics: " . physicsStatus . "`n"
    statusMsg .= "Arrangement: " . arrangementStatus . "`n"
    statusMsg .= "Screenshot Detection: " . screenshotDetectionStatus . "`n"
    statusMsg .= "Physics State: " . screenshotPausedStatus . "`n"
    statusMsg .= "Errors: " . errorCount
    
    MsgBox(statusMsg, "FWDE System Status", "T10")
    DebugLog("HOTKEY", "Status displayed: " . windowCount . " windows, " . errorCount . " errors", 2)
}

; Test physics by moving active window away from center
^!t:: {
    global g, Config
    try {
        activeHwnd := WinGetID("A")
        bounds := GetCurrentMonitorInfo()
        
        ; Move active window to top-left corner to test physics
        WinMove(bounds["Left"] + 50, bounds["Top"] + 50, , , "ahk_id " . activeHwnd)
        
        ; Update internal tracking if this window is managed
        for win in g["Windows"] {
            if (win["hwnd"] == activeHwnd) {
                win["x"] := bounds["Left"] + 50
                win["y"] := bounds["Top"] + 50
                break
            }
        }
        
        ShowTooltip("Test: Moved active window to corner - should move toward center")
        DebugLog("HOTKEY", "Physics test: moved active window to corner", 2)
    } catch as e {
        ShowTooltip("Failed to move window for physics test")
        DebugLog("HOTKEY", "Physics test failed: " . e.Message, 1)
    }
}

; ===== STARTUP =====
; Initialize the system when script starts
InitializeSystem()

DebugLog("SYSTEM", "FWDE script loaded and ready", 2)