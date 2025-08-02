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
    ; Core Physics - REFINED FOR SUBTLE MOVEMENT
    "AttractionForce", 0.0,             ; Removed center attraction completely
    "RepulsionForce", 0.12,             ; Increased repulsion between overlapping windows
    "SpreadingForce", 0.04,             ; NEW: Gentle force to spread out clustered windows
    "SpreadingRadius", 150,             ; NEW: Distance within which spreading force applies
    "Damping", 0.15,                    ; Increased damping for smoother movement
    "MaxSpeed", 3.0,                    ; Much slower maximum movement speed
    
    ; Layout Parameters
    "MinMargin", 20,                    ; Minimum margin from screen edges
    "MinGap", 25,                       ; Increased minimum gap between windows
    "PreferredGap", 60,                 ; NEW: Preferred spacing between windows
    "ManualGapBonus", 369,
    "EdgeRepulsionForce", 0.12,         ; Gentle edge repulsion
    
    ; Timing & Performance - OPTIMIZED FOR GENTLE PHYSICS
    "PhysicsTimeStep", 100,             ; Slower physics updates for gentler movement
    "VisualTimeStep", 16,               ; Keep visual updates smooth
    "UserMoveTimeout", 11111,
    "ManualLockDuration", 33333,
    "ResizeDelay", 22,
    
    ; Features
    "SeamlessMonitorFloat", false,
    "ScreenshotPauseDuration", 5000,
    
    ; Visual Effects
    "Smoothing", 0.7,                   ; Increased smoothing for gentle movement
    "AnimationDuration", 32,
    "ManualWindowColor", "FF5555",
    "ManualWindowAlpha", 222,
    
    ; Stabilization - TUNED FOR SUBTLE MOVEMENT
    "MinSpeedThreshold", 0.05,          ; Lower threshold to allow gentle movements
    "EnergyThreshold", 0.06,
    "DampingBoost", 0.12,
    "OverlapTolerance", 5,              ; Small tolerance to prevent micro-adjustments
    
    ; Screenshot Detection - OPTIMIZED
    "ScreenshotProcesses", ["ScreenToGif.exe", "Greenshot.exe", "LightShot.exe", "Snagit32.exe", "SnippingTool.exe", "ms-screenclip.exe", "PowerToys.ScreenRuler.exe", "flameshot.exe", "obs64.exe", "obs32.exe"],
    "ScreenshotWindowClasses", ["GDI+ Hook Window Class", "CrosshairOverlay", "ScreenshotOverlay", "CaptureOverlay", "SelectionOverlay", "SnipOverlay"],
    "ScreenshotCheckInterval", 1000,
    
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

GetMonitorInfoForWindow(x, y) {
    try {
        ; Get monitor count
        monitorCount := SysGet(80)  ; SM_CMONITORS
        
        ; Check each monitor to find which one contains the window
        loop monitorCount {
            monitor := SysGet(A_Index)
            if (x >= monitor.left && x < monitor.right && y >= monitor.top && y < monitor.bottom) {
                return Map(
                    "Left", monitor.left,
                    "Top", monitor.top,
                    "Right", monitor.right,
                    "Bottom", monitor.bottom,
                    "Width", monitor.right - monitor.left,
                    "Height", monitor.bottom - monitor.top
                )
            }
        }
        
        ; If not found on any monitor, use primary monitor
        return GetCurrentMonitorInfo()
    } catch {
        ; Fallback to primary monitor
        return GetCurrentMonitorInfo()
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
ApplyPhysicsToWindow(win, allWindows) {
    global Config
    try {
        ; Skip windows that have previously failed access checks
        if (win.Get("accessDenied", false)) {
            return
        }
        
        ; Initialize force accumulators
        totalForceX := 0
        totalForceY := 0
        hasForces := false
        
        ; Cache monitor bounds calculation - only recalculate if window moved significantly
        if (!win.Has("cachedBounds") || !win.Has("lastBoundsCheck") || A_TickCount - win["lastBoundsCheck"] > 1000) {
            if (Config["SeamlessMonitorFloat"]) {
                win["cachedBounds"] := GetCurrentMonitorInfo()
            } else {
                win["cachedBounds"] := GetMonitorInfoForWindow(win["x"] + win["width"]/2, win["y"] + win["height"]/2)
            }
            win["lastBoundsCheck"] := A_TickCount
        }
        
        bounds := win["cachedBounds"]
        
        ; Calculate repulsion and spreading forces from other windows
        for otherWin in allWindows {
            if (otherWin["hwnd"] == win["hwnd"]) {
                continue
            }
            
            ; Check for overlap or close proximity
            overlapInfo := CalculateOverlap(win, otherWin)
            
            ; Apply strong repulsion for overlaps
            if (overlapInfo["hasOverlap"]) {
                repulsionStrength := Config["RepulsionForce"] * (1 + overlapInfo["overlapArea"] / (win["width"] * win["height"]))
                
                dx := overlapInfo["separationX"] * repulsionStrength
                dy := overlapInfo["separationY"] * repulsionStrength
                
                totalForceX += dx
                totalForceY += dy
                hasForces := true
            }
            ; Apply gentle spreading force for windows that are too close
            else if (overlapInfo["distance"] < Config["SpreadingRadius"]) {
                ; Calculate spreading force that gets stronger as windows get closer
                spreadingStrength := Config["SpreadingForce"] * (1 - overlapInfo["distance"] / Config["SpreadingRadius"])
                
                ; Prefer moving to achieve the preferred gap
                if (overlapInfo["distance"] < Config["PreferredGap"]) {
                    spreadingStrength *= 2.0  ; Stronger force to reach preferred spacing
                }
                
                dx := overlapInfo["separationX"] * spreadingStrength
                dy := overlapInfo["separationY"] * spreadingStrength
                
                totalForceX += dx
                totalForceY += dy
                hasForces := true
            }
        }
        
        ; Add gentle edge repulsion to keep windows on screen
        edgeForceX := 0
        edgeForceY := 0
        
        ; Left edge
        if (win["x"] < bounds["Left"] + Config["MinMargin"]) {
            edgeForceX += (bounds["Left"] + Config["MinMargin"] - win["x"]) * Config["EdgeRepulsionForce"]
        }
        ; Right edge
        if (win["x"] + win["width"] > bounds["Right"] - Config["MinMargin"]) {
            edgeForceX -= (win["x"] + win["width"] - bounds["Right"] + Config["MinMargin"]) * Config["EdgeRepulsionForce"]
        }
        ; Top edge
        if (win["y"] < bounds["Top"] + Config["MinMargin"]) {
            edgeForceY += (bounds["Top"] + Config["MinMargin"] - win["y"]) * Config["EdgeRepulsionForce"]
        }
        ; Bottom edge
        if (win["y"] + win["height"] > bounds["Bottom"] - Config["MinMargin"]) {
            edgeForceY -= (win["y"] + win["height"] - bounds["Bottom"] + Config["MinMargin"]) * Config["EdgeRepulsionForce"]
        }
        
        totalForceX += edgeForceX
        totalForceY += edgeForceY
        
        ; Apply damping for smooth movement
        totalForceX *= (1 - Config["Damping"])
        totalForceY *= (1 - Config["Damping"])
        
        ; Limit maximum speed for stability
        speed := Sqrt(totalForceX*totalForceX + totalForceY*totalForceY)
        if (speed > Config["MaxSpeed"]) {
            totalForceX := (totalForceX / speed) * Config["MaxSpeed"]
            totalForceY := (totalForceY / speed) * Config["MaxSpeed"]
            speed := Config["MaxSpeed"]
        }
        
        ; Only move if there's meaningful force and it's above threshold
        if (speed > Config["MinSpeedThreshold"]) {
            newX := win["x"] + totalForceX
            newY := win["y"] + totalForceY
            
            ; Ensure window stays within bounds
            newX := Max(bounds["Left"], Min(newX, bounds["Right"] - win["width"]))
            newY := Max(bounds["Top"], Min(newY, bounds["Bottom"] - win["height"]))
            
            ; Apply smoothing to reduce jitter
            if (win.Has("targetX") && win.Has("targetY")) {
                newX := win["targetX"] + (newX - win["targetX"]) * Config["Smoothing"]
                newY := win["targetY"] + (newY - win["targetY"]) * Config["Smoothing"]
            }
            
            win["targetX"] := newX
            win["targetY"] := newY
            win["x"] := newX
            win["y"] := newY
            
            ; Try to move window
            try {
                WinMove(Round(newX), Round(newY), , , "ahk_id " . win["hwnd"])
                
                ; Mark that physics moved this window
                win["lastPhysicsMove"] := A_TickCount
                
                ; Debug: Log only significant movements
                static lastDebugTime := 0
                if (A_TickCount - lastDebugTime > 10000 && speed > 1.0) {
                    DebugLog("PHYSICS", "Adjusting window '" . win["title"] . "' (speed:" . Round(speed, 2) . ")", 3)
                    lastDebugTime := A_TickCount
                }
            } catch as moveError {
                if (moveError.Number == 5) {
                    win["accessDenied"] := true
                    DebugLog("PHYSICS", "Window '" . win["title"] . "' marked as access denied", 2)
                } else {
                    throw moveError
                }
            }
        }
        
    } catch as e {
        RecordSystemError("ApplyPhysicsToWindow", e, win["hwnd"])
    }
}

; Calculate overlap and separation vector between two windows
CalculateOverlap(win1, win2) {
    ; Calculate centers
    center1X := win1["x"] + win1["width"] / 2
    center1Y := win1["y"] + win1["height"] / 2
    center2X := win2["x"] + win2["width"] / 2
    center2Y := win2["y"] + win2["height"] / 2
    
    ; Calculate distance between centers
    dx := center1X - center2X
    dy := center1Y - center2Y
    distance := Sqrt(dx*dx + dy*dy)
    
    ; Check for actual overlap
    hasOverlap := RectsOverlap(
        Map("x", win1["x"], "y", win1["y"], "width", win1["width"], "height", win1["height"]),
        Map("x", win2["x"], "y", win2["y"], "width", win2["width"], "height", win2["height"])
    )
    
    ; Calculate overlap area if overlapping
    overlapArea := 0
    if (hasOverlap) {
        overlapLeft := Max(win1["x"], win2["x"])
        overlapTop := Max(win1["y"], win2["y"])
        overlapRight := Min(win1["x"] + win1["width"], win2["x"] + win2["width"])
        overlapBottom := Min(win1["y"] + win1["height"], win2["y"] + win2["height"])
        
        if (overlapRight > overlapLeft && overlapBottom > overlapTop) {
            overlapArea := (overlapRight - overlapLeft) * (overlapBottom - overlapTop)
        }
    }
    
    ; Calculate separation unit vector (direction to move win1 away from win2)
    separationX := 0
    separationY := 0
    if (distance > 0) {
        separationX := dx / distance
        separationY := dy / distance
    } else {
        ; Windows are at same position, use random direction
        angle := Random(0, 360) * 3.14159 / 180
        separationX := Cos(angle)
        separationY := Sin(angle)
    }
    
    return Map(
        "hasOverlap", hasOverlap,
        "distance", distance,
        "overlapArea", overlapArea,
        "separationX", separationX,
        "separationY", separationY
    )
}

; ===== MAIN PHYSICS LOOP =====
CalculateDynamicLayout() {
    global g, Config
    
    if (!g.Get("PhysicsEnabled", false) || !g.Get("ArrangementActive", false) || g.Get("ScreenshotPaused", false)) {
        if (g.Get("ScreenshotPaused", false)) {
            ; Only log occasionally to avoid spam
            static lastLogTime := 0
            if (A_TickCount - lastLogTime > 5000) {
                DebugLog("PHYSICS", "Physics paused for screenshot activity", 3)
                lastLogTime := A_TickCount
            }
        }
        return
    }
    
    startTime := A_TickCount
    
    ; Debug: Log physics loop activity occasionally
    static lastPhysicsLogTime := 0
    if (A_TickCount - lastPhysicsLogTime > 10000) {
        DebugLog("PHYSICS", "Physics processing " . g["Windows"].Length . " windows", 3)
        lastPhysicsLogTime := A_TickCount
    }
    
    try {
        ; Collect valid windows efficiently
        validWindows := []
        
        ; First pass: collect valid windows and cache window validity
        for win in g["Windows"] {
            if (!win.Get("manualLock", false) && !win.Get("accessDenied", false)) {
                ; Cache validity check to avoid repeated calls
                if (!win.Has("lastValidityCheck") || A_TickCount - win["lastValidityCheck"] > 1000) {
                    win["isValid"] := IsWindowValid(win["hwnd"])
                    win["lastValidityCheck"] := A_TickCount
                }
                
                if (win.Get("isValid", false)) {
                    validWindows.Push(win)
                }
            }
        }
        
        ; Second pass: apply physics to each valid window, considering all other windows
        for win in validWindows {
            ApplyPhysicsToWindow(win, validWindows)
        }
        
        ; Record performance with better threshold
        elapsedTime := A_TickCount - startTime
        if (elapsedTime > 20) {  ; Reduced threshold to catch performance issues earlier
            RecordPerformanceMetric("CalculateDynamicLayout", elapsedTime)
        }
        
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
        startTime := A_TickCount
        oldWindowCount := g["Windows"].Length
        
        ; Preserve existing window data when refreshing
        existingWindows := Map()
        for win in g["Windows"] {
            existingWindows[win["hwnd"]] := win
        }
        
        g["Windows"] := []
        
        ; Enumerate all visible windows
        windowList := WinGetList()
        processedCount := 0
        
        for hwnd in windowList {
            try {
                ; Skip if window is not visible or valid - quick check first
                if (!DllCall("IsWindowVisible", "ptr", hwnd)) {
                    continue
                }
                
                ; Only check WinExist if window passed visibility test
                if (!WinExist("ahk_id " . hwnd)) {
                    continue
                }
                
                ; Get window info in batch for efficiency
                WinGetPos(&x, &y, &width, &height, "ahk_id " . hwnd)
                
                ; Quick size filter before getting expensive window properties
                if (width < 50 || height < 50) {
                    continue
                }
                
                ; Get window properties only for potentially valid windows
                title := WinGetTitle("ahk_id " . hwnd)
                if (!title) {
                    continue
                }
                
                windowClass := WinGetClass("ahk_id " . hwnd)
                processName := WinGetProcessName("ahk_id " . hwnd)
                
                ; Check if should be floating
                shouldFloat := ShouldWindowFloat(hwnd, title, windowClass, processName)
                
                if (shouldFloat) {
                    ; Create window object, preserving existing data if available
                    if (existingWindows.Has(hwnd)) {
                        win := existingWindows[hwnd]
                        ; Update position and basic properties
                        
                        ; Check if window was manually moved by user
                        if (Abs(win["x"] - x) > 5 || Abs(win["y"] - y) > 5) {
                            ; Window moved significantly - check if it was user-initiated
                            if (!win.Get("accessDenied", false) && A_TickCount - win.Get("lastPhysicsMove", 0) > 1000) {
                                ; Likely user move - set manual lock temporarily
                                win["manualLock"] := true
                                win["lastUserInteraction"] := A_TickCount
                                
                                static lastManualMoveLog := 0
                                if (A_TickCount - lastManualMoveLog > 5000) {
                                    DebugLog("USER", "Manual move detected for '" . title . "' - temporarily locking", 2)
                                    lastManualMoveLog := A_TickCount
                                }
                            }
                        }
                        
                        win["x"] := x
                        win["y"] := y
                        win["width"] := width
                        win["height"] := height
                        win["title"] := title
                        win["class"] := windowClass
                        win["process"] := processName
                    } else {
                        ; New window
                        win := Map(
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
                        )
                    }
                    
                    ; Release manual lock after timeout
                    if (win.Get("manualLock", false) && A_TickCount - win.Get("lastUserInteraction", 0) > Config["ManualLockDuration"]) {
                        win["manualLock"] := false
                    }
                    
                    g["Windows"].Push(win)
                    processedCount++
                }
            } catch {
                ; Skip problematic windows
                continue
            }
        }
        
        elapsedTime := A_TickCount - startTime
        
        ; Only log if there's a significant change or performance issue
        if (g["Windows"].Length != oldWindowCount || elapsedTime > 100) {
            DebugLog("WINDOWS", "Refreshed: " . g["Windows"].Length . " floating windows (" . elapsedTime . "ms)", 3)
        }
        
        ; Record performance if slow
        if (elapsedTime > 50) {
            RecordPerformanceMetric("RefreshWindowList", elapsedTime)
        }
        
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
        
        ; Start main timers with gentle intervals
        SetTimer(CalculateDynamicLayout, Config["PhysicsTimeStep"])
        SetTimer(RefreshWindowList, 3000)  ; Check for new windows every 3 seconds
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
    global g, SystemState, PerfTimers
    windowCount := g["Windows"].Length
    physicsStatus := g["PhysicsEnabled"] ? "ON" : "OFF"
    arrangementStatus := g["ArrangementActive"] ? "ON" : "OFF"
    screenshotDetectionStatus := g.Get("ScreenshotDetectionEnabled", true) ? "ON" : "OFF"
    screenshotPausedStatus := g.Get("ScreenshotPaused", false) ? "PAUSED" : "ACTIVE"
    errorCount := SystemState["ErrorCount"]
    
    ; Get performance metrics
    physicsPerf := PerfTimers.Has("CalculateDynamicLayout") ? Round(PerfTimers["CalculateDynamicLayout"]["avg"], 1) . "ms avg" : "No data"
    windowListPerf := PerfTimers.Has("RefreshWindowList") ? Round(PerfTimers["RefreshWindowList"]["avg"], 1) . "ms avg" : "No data"
    
    statusMsg := "FWDE Status:`n"
    statusMsg .= "Windows: " . windowCount . "`n"
    statusMsg .= "Physics: " . physicsStatus . "`n"
    statusMsg .= "Arrangement: " . arrangementStatus . "`n"
    statusMsg .= "Screenshot Detection: " . screenshotDetectionStatus . "`n"
    statusMsg .= "Physics State: " . screenshotPausedStatus . "`n"
    statusMsg .= "Errors: " . errorCount . "`n"
    statusMsg .= "Physics Performance: " . physicsPerf . "`n"
    statusMsg .= "Window List Performance: " . windowListPerf
    
    MsgBox(statusMsg, "FWDE System Status", "T10")
    DebugLog("HOTKEY", "Status displayed: " . windowCount . " windows, " . errorCount . " errors, physics: " . physicsPerf, 2)
}

; Show detailed performance metrics  
^!+i:: {
    global PerfTimers
    
    perfMsg := "FWDE Performance Metrics:`n`n"
    
    for operation, metrics in PerfTimers {
        perfMsg .= operation . ":`n"
        perfMsg .= "  Count: " . metrics["count"] . "`n"
        perfMsg .= "  Average: " . Round(metrics["avg"], 1) . "ms`n"
        perfMsg .= "  Maximum: " . metrics["max"] . "ms`n"
        perfMsg .= "  Total: " . Round(metrics["total"]/1000, 1) . "s`n`n"
    }
    
    if (PerfTimers.Count == 0) {
        perfMsg .= "No performance data available yet."
    }
    
    MsgBox(perfMsg, "FWDE Performance Details", "T15")
    DebugLog("HOTKEY", "Performance metrics displayed", 2)
}

; Test physics by creating overlap with active window
^!t:: {
    global g, Config
    try {
        activeHwnd := WinGetID("A")
        
        ; Get current window position
        WinGetPos(&currentX, &currentY, &currentWidth, &currentHeight, "ahk_id " . activeHwnd)
        
        ; Find another floating window to test overlap with
        testWindow := ""
        for win in g["Windows"] {
            if (win["hwnd"] != activeHwnd && !win.Get("accessDenied", false)) {
                testWindow := win
                break
            }
        }
        
        if (testWindow) {
            ; Move active window to overlap with the test window
            targetX := testWindow["x"] + 20  ; Slight offset to create overlap
            targetY := testWindow["y"] + 20
            
            WinMove(targetX, targetY, , , "ahk_id " . activeHwnd)
            
            ; Update internal tracking if this window is managed
            for win in g["Windows"] {
                if (win["hwnd"] == activeHwnd) {
                    win["x"] := targetX
                    win["y"] := targetY
                    win["lastPhysicsMove"] := A_TickCount - 2000  ; Mark as old move so it won't be seen as user move
                    break
                }
            }
            
            ShowTooltip("Test: Created overlap between windows - they should gently separate")
            DebugLog("HOTKEY", "Physics test: created overlap between windows", 2)
        } else {
            ShowTooltip("Test: No other floating windows found for overlap test")
        }
    } catch as e {
        ShowTooltip("Failed to create overlap for physics test")
        DebugLog("HOTKEY", "Physics test failed: " . e.Message, 1)
    }
}

; ===== STARTUP =====
; Initialize the system when script starts
InitializeSystem()

DebugLog("SYSTEM", "FWDE script loaded and ready", 2)