#Requires AutoHotkey v2.0
#SingleInstance Force
#WinActivateForce
#Warn
#MaxThreadsPerHotkey 255
#MaxThreads 255

A_IconTip := "FWDE - Floating Windows Dynamic Equilibrium v2.0"
ProcessSetPriority("High")

; Pre-allocate memory buffers
global g_NoiseBuffer := Buffer(1024)
global g_PhysicsBuffer := Buffer(4096)

; ===== DEBUG LOGGING SYSTEM =====
global DebugConfig := Map(
    "Enabled", true,
    "LogLevel", 3,  ; 0=Error, 1=Warning, 2=Info, 3=Debug, 4=Verbose
    "LogToFile", true,
    "LogToConsole", false,
    "MaxLogSize", 1048576,  ; 1MB
    "LogPath", A_ScriptDir "\FWDE_Debug.log",
    "PerformanceLogging", true,
    "PhysicsLogging", true,
    "WindowStateLogging", true
)

global DebugStats := Map(
    "StartTime", A_TickCount,
    "TotalFrames", 0,
    "PhysicsFrames", 0,
    "WindowMoves", 0,
    "Errors", 0,
    "Warnings", 0,
    "LastFPS", 0,
    "AvgFrameTime", 0,
    "PeakMemory", 0,
    "WindowCount", 0,
    "ActiveWindows", 0
)

; Debug logging function
DebugLog(level, category, message, data := "") {
    global DebugConfig, DebugStats
    
    if (!DebugConfig["Enabled"] || level > DebugConfig["LogLevel"])
        return
        
    levelNames := ["ERROR", "WARN", "INFO", "DEBUG", "VERBOSE"]
    levelName := (level < levelNames.Length) ? levelNames[level + 1] : "UNKNOWN"
    
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss.fff")
    logEntry := "[" timestamp "] [" levelName "] [" category "] " message
    
    if (data != "") {
        logEntry .= " | Data: " (IsObject(data) ? DebugObjectToString(data) : String(data))
    }
    
    ; Update stats
    if (level == 0) DebugStats["Errors"]++
    if (level == 1) DebugStats["Warnings"]++
    
    ; Log to file
    if (DebugConfig["LogToFile"]) {
        try {
            ; Check log file size
            if (FileExist(DebugConfig["LogPath"])) {
                fileSize := FileGetSize(DebugConfig["LogPath"])
                if (fileSize > DebugConfig["MaxLogSize"]) {
                    FileMove(DebugConfig["LogPath"], DebugConfig["LogPath"] ".old", 1)
                }
            }
            
            FileAppend(logEntry "`n", DebugConfig["LogPath"])
        } catch as e {
            ; Fallback: show critical errors in tooltip
            if (level == 0) {
                ToolTip("CRITICAL ERROR: " message, 10, 10)
                SetTimer(() => ToolTip(), -3000)
            }
        }
    }
    
    ; Log to console if available
    if (DebugConfig["LogToConsole"]) {
        FileAppend(logEntry "`n", "*")
    }
}

; Convert object to string for logging
DebugObjectToString(obj, depth := 0) {
    if (depth > 3) {
        return "[MAX_DEPTH]"
    }
    try {
        if (Type(obj) == "Map") {
            result := "{"
            count := 0
            for key, value in obj {
                if (count > 0) result .= ", "
                result .= key ": " DebugObjectToString(value, depth + 1)
                count++
                if (count > 10) {
                    result .= ", ..."
                    break
                }
            }
            result .= "}"
            return result
        } else if (Type(obj) == "Array") {
            result := "["
            for i, value in obj {
                if (i > 1) result .= ", "
                result .= DebugObjectToString(value, depth + 1)
                if (i > 10) {
                    result .= ", ..."
                    break
                }
            }
            result .= "]"
            return result
        } else {
            return String(obj)
        }
    } catch {
        return "[STRINGIFY_ERROR]"
    }
}

; Performance monitoring
DebugStartTimer(name) {
    global DebugTimers := Map()
    DebugTimers[name] := A_TickCount
    DebugLog(4, "PERF", "Timer started: " name)
}

DebugEndTimer(name) {
    global DebugTimers
    if (DebugTimers.Has(name)) {
        elapsed := A_TickCount - DebugTimers[name]
        DebugLog(4, "PERF", "Timer ended: " name " (" elapsed "ms)")
        DebugTimers.Delete(name)
        return elapsed
    }
    return 0
}

; Log system statistics
DebugLogStats() {
    global DebugStats
    
    uptime := (A_TickCount - DebugStats["StartTime"]) / 1000
    fps := DebugStats["TotalFrames"] / Max(1, uptime)
    
    DebugLog(2, "STATS", "System Stats", Map(
        "Uptime", Round(uptime, 2) . "s",
        "FPS", Round(fps, 2),
        "TotalFrames", DebugStats["TotalFrames"],
        "WindowMoves", DebugStats["WindowMoves"],
        "Errors", DebugStats["Errors"],
        "Warnings", DebugStats["Warnings"],
        "WindowCount", DebugStats["WindowCount"]
    ))
}

; Initialize debug logging
DebugLog(2, "INIT", "FWDE Debug System Initialized", Map(
    "Version", "2.0",
    "LogLevel", DebugConfig["LogLevel"],
    "PID", ProcessExist(),
    "ScriptPath", A_ScriptFullPath
))

; Core configuration following old version structure
global Config := Map(
    "MinMargin", 45,
    "MinGap", 80,
    "ManualGapBonus", 400,
    "AttractionForce", 0.00005,
    "RepulsionForce", 2.5,
    "ManualRepulsionMultiplier", 1.3,
    "EdgeRepulsionForce", 1.5,
    "UserMoveTimeout", 8000,
    "ManualLockDuration", 30000,
    "ResizeDelay", 22,
    "TooltipDuration", 12000,
    "SeamlessMonitorFloat", false,   ; Toggle for seamless multi-monitor floating
    "FloatStyles", 0x00C00000 | 0x00040000 | 0x00080000 | 0x00020000 | 0x00010000,
    "FloatClassPatterns", [
        "Vst.*", "JS.*", ".*Plugin.*", ".*Float.*", ".*Dock.*", "#32770",
        "ConsoleWindowClass", "CASCADIA_HOSTING_WINDOW_CLASS"
    ],
    "FloatTitlePatterns", [
        "VST.*", "JS:.*", "Plugin", ".*FX.*", "Command Prompt", "cmd.exe", "Windows Terminal"
    ],
    "ForceFloatProcesses", [
        "reaper.exe", "ableton.exe", "flstudio.exe", "cubase.exe", "studioone.exe",
        "bitwig.exe", "protools.exe", "cmd.exe", "conhost.exe", "WindowsTerminal.exe"
    ],
    "Damping", 0.015,
    "MaxSpeed", 8.0,
    "PhysicsTimeStep", 12,
    "VisualTimeStep", 20,
    "Smoothing", 0.4,
    "Stabilization", Map(
        "MinSpeedThreshold", 0.1,
        "EnergyThreshold", 0.08,
        "DampingBoost", 0.12,
        "OverlapTolerance", 5
    ),
    "ManualWindowColor", "0xFF4444",
    "ManualWindowAlpha", 200
)

; Global state following old version structure
global g := Map(
    "Monitor", Map(),  ; Will be initialized later
    "ArrangementActive", true,
    "LastUserMove", 0,
    "ActiveWindow", 0,
    "Windows", [],
    "PhysicsEnabled", true,
    "ManualWindows", Map(),
    "SystemEnergy", 0,
    "LastFocusCheck", 0,
    "ForceTransition", 0,
    "AllMonitors", [],
    "ActiveMonitorIndex", 1
)

; ===== HELPER FUNCTIONS (enhanced from old version) =====
; Enhanced partition function for window management
PartitionWindows(windows, numPartitions) {
    DebugLog(3, "PARTITION", "Partitioning windows", Map("WindowCount", windows.Length, "Partitions", numPartitions))
    
    try {
        partitions := []
        partitionSize := Ceil(windows.Length / numPartitions)
        
        DebugLog(4, "PARTITION", "Partition size calculated", Map("PartitionSize", partitionSize))
        
        Loop numPartitions {
            startIdx := (A_Index - 1) * partitionSize + 1
            endIdx := Min(A_Index * partitionSize, windows.Length)
            
            partition := []
            Loop endIdx - startIdx + 1 {
                if (startIdx + A_Index - 1 <= windows.Length)
                    partition.Push(windows[startIdx + A_Index - 1])
            }
            partitions.Push(partition)
            
            DebugLog(4, "PARTITION", "Partition created", Map("Index", A_Index, "Size", partition.Length))
        }
        
        DebugLog(3, "PARTITION", "Partitioning complete", Map("PartitionsCreated", partitions.Length))
        return partitions
    } catch as e {
        DebugLog(0, "PARTITION", "Partitioning failed", Map("Error", e.message))
        return []
    }
}

; Enhanced distance calculation with size awareness
GetWindowDistance(win1, win2) {
    try {
        dx := win1["centerX"] - win2["centerX"]
        dy := win1["centerY"] - win2["centerY"]
        distance := Sqrt(dx*dx + dy*dy)
        
        DebugLog(4, "DISTANCE", "Window distance calculated", Map(
            "Win1", win1["hwnd"],
            "Win2", win2["hwnd"],
            "Distance", Round(distance, 2)
        ))
        
        return distance
    } catch as e {
        DebugLog(0, "DISTANCE", "Distance calculation failed", Map("Error", e.message))
        return 0
    }
}

; Enhanced overlap detection
CheckWindowOverlap(win1, win2, buffer := 0) {
    try {
        overlap := !(win1["x"] + win1["width"] + buffer < win2["x"] ||
                     win2["x"] + win2["width"] + buffer < win1["x"] ||
                     win1["y"] + win1["height"] + buffer < win2["y"] ||
                     win2["y"] + win2["height"] + buffer < win1["y"])
        
        if (overlap) {
            DebugLog(3, "OVERLAP", "Window overlap detected", Map(
                "Win1", win1["hwnd"],
                "Win2", win2["hwnd"],
                "Buffer", buffer
            ))
        }
        
        return overlap
    } catch as e {
        DebugLog(0, "OVERLAP", "Overlap check failed", Map("Error", e.message))
        return false
    }
}

; Enhanced bounds checking with virtual desktop support
IsWindowInBounds(win, monitor := "") {
    if (monitor == "") {
        if (Config["SeamlessMonitorFloat"]) {
            bounds := GetVirtualDesktopBounds()
        } else {
            global g
            bounds := g["Monitor"]
        }
    } else {
        bounds := monitor
    }
    
    return (win["x"] >= bounds["Left"] && 
            win["y"] >= bounds["Top"] && 
            win["x"] + win["width"] <= bounds["Right"] && 
            win["y"] + win["height"] <= bounds["Bottom"])
}
SafeWinExist(hwnd) {
    try {
        exists := WinExist("ahk_id " hwnd)
        if (!exists) {
            DebugLog(4, "WINDOW", "Window no longer exists", Map("HWND", hwnd))
        }
        return exists
    }
    catch as e {
        DebugLog(1, "WINDOW", "SafeWinExist error", Map("HWND", hwnd, "Error", e.message))
        return 0
    }
}

Lerp(a, b, t) {
    return a + (b - a) * t
}

EaseOutCubic(t) {
    return 1 - (1 - t) ** 3
}

SmoothStep(t) {
    return t * t * (3 - 2 * t)
}

ShowTooltip(text) {
    global g, Config
    
    DebugLog(3, "UI", "Showing tooltip", Map("Text", text))
    
    ; Use a safe position for tooltip
    if (g["Monitor"].Has("CenterX") && g["Monitor"].Has("Top")) {
        ToolTip(text, g["Monitor"]["CenterX"] - 100, g["Monitor"]["Top"] + 20)
    } else {
        ; Fallback to screen center if monitor info is not available
        DebugLog(1, "UI", "Using fallback tooltip position")
        ToolTip(text, A_ScreenWidth // 2 - 100, 50)
    }
    SetTimer(() => ToolTip(), -Config["TooltipDuration"])
}

GetCurrentMonitorInfo() {
    DebugStartTimer("GetCurrentMonitorInfo")
    
    static lastPos := [0, 0], lastMonitor := Map()
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)
    
    DebugLog(4, "MONITOR", "Getting current monitor info", Map("MouseX", mx, "MouseY", my))
    
    if (Abs(mx - lastPos[1]) < 50 && Abs(my - lastPos[2]) < 50 && lastMonitor.Count) {
        DebugLog(4, "MONITOR", "Using cached monitor info")
        DebugEndTimer("GetCurrentMonitorInfo")
        return lastMonitor
    }
    
    lastPos := [mx, my]
    if (monNum := MonitorGetFromPoint(mx, my)) {
        MonitorGet monNum, &L, &T, &R, &B
        lastMonitor := Map(
            "Left", L, "Right", R, "Top", T, "Bottom", B,
            "Width", R - L, "Height", B - T, "Number", monNum,
            "CenterX", (R + L) // 2, "CenterY", (B + T) // 2,
            "WorkLeft", L, "WorkTop", T + Config["MinMargin"],
            "WorkRight", R, "WorkBottom", B - Config["MinMargin"]
        )
        
        DebugLog(3, "MONITOR", "Monitor info retrieved", Map(
            "Monitor", monNum,
            "Bounds", L "," T "," R "," B,
            "Size", (R-L) "x" (B-T)
        ))
        
        DebugEndTimer("GetCurrentMonitorInfo")
        return lastMonitor
    }
    
    DebugLog(1, "MONITOR", "Falling back to primary monitor")
    result := GetPrimaryMonitorCoordinates()
    DebugEndTimer("GetCurrentMonitorInfo")
    return result
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
            "CenterX", (R + L) // 2, "CenterY", (B + T) // 2,
            "WorkLeft", L, "WorkTop", T + Config["MinMargin"],
            "WorkRight", R, "WorkBottom", B - Config["MinMargin"]
        )
    }
    catch {
        return Map(
            "Left", 0, "Right", A_ScreenWidth, "Top", 0, "Bottom", A_ScreenHeight,
            "Width", A_ScreenWidth, "Height", A_ScreenHeight, "Number", 1,
            "CenterX", A_ScreenWidth // 2, "CenterY", A_ScreenHeight // 2,
            "WorkLeft", 0, "WorkTop", Config["MinMargin"],
            "WorkRight", A_ScreenWidth, "WorkBottom", A_ScreenHeight - Config["MinMargin"]
        )
    }
}

GetVirtualDesktopBounds() {
    global Config
    
    if (!Config["SeamlessMonitorFloat"]) {
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
            "CenterX", (maxRight + minLeft) // 2, "CenterY", (maxBottom + minTop) // 2,
            "WorkLeft", minLeft, "WorkTop", minTop + Config["MinMargin"],
            "WorkRight", maxRight, "WorkBottom", maxBottom - Config["MinMargin"]
        )
    }
    catch {
        return GetPrimaryMonitorCoordinates()
    }
}

UpdateAllMonitors() {
    global g
    monitors := []
    try {
        monitorCount := MonitorGetCount()
        Loop monitorCount {
            MonitorGet(A_Index, &L, &T, &R, &B)
            monitors.Push(Map(
                "Left", L, "Top", T, "Right", R, "Bottom", B,
                "Width", R - L, "Height", B - T, "Number", A_Index,
                "CenterX", (R + L) // 2, "CenterY", (B + T) // 2,
                "WorkLeft", L, "WorkTop", T + Config["MinMargin"],
                "WorkRight", R, "WorkBottom", B - Config["MinMargin"],
                "Name", "Monitor " A_Index,
                "Active", A_Index == g["ActiveMonitorIndex"]
            ))
        }
    } catch {
        monitors.Push(GetPrimaryMonitorCoordinates())
    }
    g["AllMonitors"] := monitors
}

; ===== MONITOR MANAGEMENT MODULE (Enhanced with old version compatibility) =====
class MonitorManager {
    static Current := Map()
    static AllMonitors := []
    static ActiveMonitorIndex := 1
    
    static GetPrimary() {
        try {
            MonitorGet(MonitorGetPrimary(), &L, &T, &R, &B)
            return this.CreateMonitorMap(L, T, R, B, MonitorGetPrimary())
        } catch {
            return this.CreateMonitorMap(0, 0, A_ScreenWidth, A_ScreenHeight, 1)
        }
    }
    
    static GetAllMonitors() {
        monitors := []
        try {
            monitorCount := MonitorGetCount()
            Loop monitorCount {
                MonitorGet(A_Index, &L, &T, &R, &B)
                monitors.Push(this.CreateMonitorMap(L, T, R, B, A_Index))
            }
        } catch {
            monitors.Push(this.GetPrimary())
        }
        return monitors
    }
    
    static CreateMonitorMap(L, T, R, B, Number) {
        global Config
        return Map(
            "Left", L, "Top", T, "Right", R, "Bottom", B,
            "Width", R - L, "Height", B - T, "Number", Number,
            "CenterX", (R + L) // 2, "CenterY", (B + T) // 2,
            "WorkLeft", L, "WorkTop", T + Config["MinMargin"],
            "WorkRight", R, "WorkBottom", B - Config["MinMargin"],
            "Name", "Monitor " Number,
            "Active", false
        )
    }
    
    static GetFromPoint(x, y) {
        try {
            Loop MonitorGetCount() {
                MonitorGet(A_Index, &L, &T, &R, &B)
                if (x >= L && x < R && y >= T && y < B)
                    return A_Index
            }
        }
        return 0
    }
    
    static GetMouseMonitor() {
        MouseGetPos(&mouseX, &mouseY)
        return this.GetFromPoint(mouseX, mouseY)
    }
    
    static Update() {
        global g
        this.AllMonitors := this.GetAllMonitors()
        g["AllMonitors"] := this.AllMonitors
        
        if (this.ActiveMonitorIndex <= this.AllMonitors.Length) {
            this.Current := this.AllMonitors[this.ActiveMonitorIndex]
            this.Current["Active"] := true
            g["ActiveMonitorIndex"] := this.ActiveMonitorIndex
        } else {
            mouseMonitor := this.GetMouseMonitor()
            if (mouseMonitor > 0 && mouseMonitor <= this.AllMonitors.Length) {
                this.ActiveMonitorIndex := mouseMonitor
                this.Current := this.AllMonitors[mouseMonitor]
                this.Current["Active"] := true
                g["ActiveMonitorIndex"] := mouseMonitor
            } else {
                this.ActiveMonitorIndex := 1
                this.Current := this.AllMonitors[1]
                this.Current["Active"] := true
                g["ActiveMonitorIndex"] := 1
            }
        }
    }
    
    static SwitchToMonitor(monitorNumber) {
        if (monitorNumber > 0 && monitorNumber <= this.AllMonitors.Length) {
            this.ActiveMonitorIndex := monitorNumber
            this.Update()
            ShowTooltip("Switched to " this.Current["Name"] 
                . " (" this.Current["Width"] "x" this.Current["Height"] ")")
            return true
        }
        return false
    }
    
    static CycleToNextMonitor() {
        nextMonitor := this.ActiveMonitorIndex + 1
        if (nextMonitor > this.AllMonitors.Length)
            nextMonitor := 1
        return this.SwitchToMonitor(nextMonitor)
    }
    
    static GetMonitorInfo() {
        info := "Monitor Status:`n"
        for i, monitor in this.AllMonitors {
            status := (i == this.ActiveMonitorIndex) ? " [ACTIVE]" : ""
            info .= "Monitor " i ": " monitor["Width"] "x" monitor["Height"] 
                 . " at (" monitor["Left"] "," monitor["Top"] ")" status "`n"
        }
        return info
    }
}

; ===== WINDOW DETECTION & CLASSIFICATION (functional style) =====
IsWindowFloating(hwnd) {
    global Config
    
    DebugLog(4, "CLASSIFY", "Checking if window is floating", Map("HWND", hwnd))
    
    if (!SafeWinExist(hwnd)) {
        DebugLog(4, "CLASSIFY", "Window does not exist", Map("HWND", hwnd))
        return false
    }
        
    try {
        if (WinGetMinMax("ahk_id " hwnd) != 0) {
            DebugLog(4, "CLASSIFY", "Window is minimized/maximized", Map("HWND", hwnd))
            return false
        }
            
        title := WinGetTitle("ahk_id " hwnd)
        if (!title || title == "Program Manager") {
            DebugLog(4, "CLASSIFY", "Window has no title or is Program Manager", Map("HWND", hwnd, "Title", title))
            return false
        }
            
        winClass := WinGetClass("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)
        style := WinGetStyle("ahk_id " hwnd)
        exStyle := WinGetExStyle("ahk_id " hwnd)

        DebugLog(4, "CLASSIFY", "Window classification data", Map(
            "HWND", hwnd,
            "Title", title,
            "Class", winClass,
            "Process", processName,
            "Style", Format("0x{:X}", style),
            "ExStyle", Format("0x{:X}", exStyle)
        ))

        ; Priority checks
        if (IsForceFloatProcess(processName)) {
            DebugLog(3, "CLASSIFY", "Window classified as force float process", Map("HWND", hwnd, "Process", processName))
            return true
        }
        if (IsConsoleWindow(winClass)) {
            DebugLog(3, "CLASSIFY", "Window classified as console", Map("HWND", hwnd, "Class", winClass))
            return true
        }
        if (IsPluginWindow(winClass, title)) {
            DebugLog(3, "CLASSIFY", "Window classified as plugin", Map("HWND", hwnd))
            return true
        }
        if (HasFloatingStyle(style, exStyle)) {
            DebugLog(3, "CLASSIFY", "Window has floating style", Map("HWND", hwnd))
            return true
        }
        if (MatchesPatterns(winClass, title)) {
            DebugLog(3, "CLASSIFY", "Window matches floating patterns", Map("HWND", hwnd))
            return true
        }
        
        DebugLog(4, "CLASSIFY", "Window not classified as floating", Map("HWND", hwnd))
        return false
    } catch as e {
        DebugLog(0, "CLASSIFY", "Error classifying window", Map("HWND", hwnd, "Error", e.message))
        return false
    }
}

IsForceFloatProcess(processName) {
    global Config
    for pattern in Config["ForceFloatProcesses"] {
        if (processName ~= "i)^" pattern "$")
            return true
    }
    return false
}

IsConsoleWindow(winClass) {
    return winClass == "ConsoleWindowClass" || winClass == "CASCADIA_HOSTING_WINDOW_CLASS"
}

IsPluginWindow(winClass, title) {
    return (winClass ~= "i)(Vst|JS|Plugin|Float)") || (title ~= "i)(VST|JS:|Plugin|FX)")
}

HasFloatingStyle(style, exStyle) {
    global Config
    return (exStyle & 0x80) || (!(style & 0x10000000)) || (style & Config["FloatStyles"])
}

MatchesPatterns(winClass, title) {
    global Config
    for pattern in Config["FloatClassPatterns"] {
        if (winClass ~= "i)" pattern)
            return true
    }
    for pattern in Config["FloatTitlePatterns"] {
        if (title ~= "i)" pattern)
            return true
    }
    return false
}

; ===== WINDOW DATA CREATION =====
CreateWindowData(hwnd, x, y, w, h, existing := 0) {
    DebugLog(4, "WINDOW_DATA", "Creating window data", Map(
        "HWND", hwnd,
        "Position", x "," y,
        "Size", w "x" h,
        "HasExisting", existing ? true : false
    ))
    
    try {
        winMonitor := MonitorGetFromPoint(x + w/2, y + h/2)
        if (!winMonitor) {
            global g
            winMonitor := g["ActiveMonitorIndex"]
            DebugLog(1, "WINDOW_DATA", "Could not determine window monitor, using active", Map("HWND", hwnd))
        }
        
        windowData := Map(
            "hwnd", hwnd,
            "x", x, "y", y, "width", w, "height", h,
            "centerX", x + w/2, "centerY", y + h/2,
            "area", w * h, "mass", (w * h) / 100000,
            "vx", existing ? existing["vx"] : 0,
            "vy", existing ? existing["vy"] : 0,
            "targetX", x, "targetY", y,
            "lastMove", existing ? existing["lastMove"] : 0,
            "lastSeen", A_TickCount,
            "monitor", winMonitor,
            "energy", 0
        )
        
        DebugLog(3, "WINDOW_DATA", "Window data created successfully", Map(
            "HWND", hwnd,
            "Monitor", winMonitor,
            "Mass", Round(windowData["mass"], 4)
        ))
        
        return windowData
    } catch as e {
        DebugLog(0, "WINDOW_DATA", "Failed to create window data", Map("HWND", hwnd, "Error", e.message))
        return Map()
    }
}

; ===== PHYSICS ENGINE (enhanced with old version sophistication) =====
ApplyStabilization(win) {
    global Config
    static velocityBuffers := Map()
    
    DebugStartTimer("ApplyStabilization")
    
    try {
        ; Initialize velocity buffer if needed
        if (!velocityBuffers.Has(win["hwnd"])) {
            velocityBuffers[win["hwnd"]] := []
            DebugLog(4, "PHYSICS", "Initialized velocity buffer", Map("HWND", win["hwnd"]))
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
        
        if (DebugConfig["PhysicsLogging"]) {
            DebugLog(4, "PHYSICS", "Stabilization data", Map(
                "HWND", win["hwnd"],
                "AvgSpeed", Round(avgSpeed, 4),
                "BufferSize", buf.Length
            ))
        }
        
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
                
                DebugLog(4, "PHYSICS", "Applied gradual stop", Map("HWND", win["hwnd"], "StopFactor", Round(stopFactor, 4)))
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
            
            DebugLog(3, "PHYSICS", "Window snapped to target", Map("HWND", win["hwnd"]))
        }
        
        DebugEndTimer("ApplyStabilization")
    } catch as e {
        DebugLog(0, "PHYSICS", "Stabilization error", Map("HWND", win["hwnd"], "Error", e.message))
        DebugEndTimer("ApplyStabilization")
    }
}

CalculateWindowForces(win, allWindows) {
    global g, Config

    DebugStartTimer("CalculateWindowForces")
    
    try {
        ; Keep active window and recently moved windows still
        isActiveWindow := (win["hwnd"] == g["ActiveWindow"])
        isRecentlyMoved := (A_TickCount - g["LastUserMove"] < Config["UserMoveTimeout"])
        isCurrentlyFocused := (win["hwnd"] == WinExist("A"))
        isManuallyLocked := (win.Has("ManualLock") && A_TickCount < win["ManualLock"])
        
        if (DebugConfig["PhysicsLogging"]) {
            DebugLog(4, "PHYSICS", "Window force calculation state", Map(
                "HWND", win["hwnd"],
                "IsActive", isActiveWindow,
                "IsRecentlyMoved", isRecentlyMoved,
                "IsCurrentlyFocused", isCurrentlyFocused,
                "IsManuallyLocked", isManuallyLocked
            ))
        }
        
        if (isActiveWindow || isRecentlyMoved && isCurrentlyFocused || isManuallyLocked) {
            win["vx"] := 0
            win["vy"] := 0
            win["targetX"] := win["x"]
            win["targetY"] := win["y"]
            
            DebugLog(4, "PHYSICS", "Window locked in place", Map("HWND", win["hwnd"]))
            DebugEndTimer("CalculateWindowForces")
            return
        }

        ; Get monitor bounds based on seamless float setting
        if (Config["SeamlessMonitorFloat"]) {
            virtualBounds := GetVirtualDesktopBounds()
            mL := virtualBounds["Left"]
            mT := virtualBounds["Top"] 
            mR := virtualBounds["Right"]
            mB := virtualBounds["Bottom"]
        } else {
            ; Use the window's own monitor bounds instead of global monitor
            winMonitorNum := win["monitor"]
            winMonitorBounds := Map()
            
            ; Find the monitor bounds for this window
            if (winMonitorNum > 0 && winMonitorNum <= g["AllMonitors"].Length) {
                winMonitorBounds := g["AllMonitors"][winMonitorNum]
            } else {
                ; Fallback to primary monitor if window monitor is invalid
                winMonitorBounds := GetPrimaryMonitorCoordinates()
            }
            
            mL := winMonitorBounds["Left"]
            mT := winMonitorBounds["Top"]
            mR := winMonitorBounds["Right"]
            mB := winMonitorBounds["Bottom"]
        }

        monLeft := mL
        monRight := mR - win["width"]
        monTop := mT + Config["MinMargin"]
        monBottom := mB - Config["MinMargin"] - win["height"]

        prev_vx := win.Has("vx") ? win["vx"] : 0
        prev_vy := win.Has("vy") ? win["vy"] : 0
        
        wx := win["x"] + win["width"]/2
        wy := win["y"] + win["height"]/2
        
        ; Center attraction (from old version with enhanced equilibrium)
        dx := (mL + mR)/2 - wx
        dy := (mT + mB)/2 - wy
        centerDist := Sqrt(dx*dx + dy*dy)
        
        if (DebugConfig["PhysicsLogging"]) {
            DebugLog(4, "PHYSICS", "Center attraction calculation", Map(
                "HWND", win["hwnd"],
                "CenterDistance", Round(centerDist, 2),
                "CenterDelta", Round(dx, 2) . "," . Round(dy, 2)
            ))
        }
        
        ; Enhanced center attraction for better equilibrium
        if (centerDist > 100) {  ; Reduced threshold for earlier attraction
            attractionScale := Min(0.25, centerDist/1200)  ; Stronger attraction
            vx := prev_vx * 0.98 + dx * Config["AttractionForce"] * 0.08 * attractionScale
            vy := prev_vy * 0.98 + dy * Config["AttractionForce"] * 0.08 * attractionScale
        } else {
            vx := prev_vx * 0.995  ; Slightly more damping near center
            vy := prev_vy * 0.995
        }
        
        ; Edge repulsion (soft boundaries)
        edgeBuffer := 50
        if (win["x"] < monLeft + edgeBuffer) {
            push := (monLeft + edgeBuffer - win["x"]) * Config["EdgeRepulsionForce"] * 0.01
            vx += push
        }
        if (win["x"] > monRight - edgeBuffer) {
            push := (win["x"] - (monRight - edgeBuffer)) * Config["EdgeRepulsionForce"] * 0.01
            vx -= push
        }
        if (win["y"] < monTop + edgeBuffer) {
            push := (monTop + edgeBuffer - win["y"]) * Config["EdgeRepulsionForce"] * 0.01
            vy += push
        }
        if (win["y"] > monBottom - edgeBuffer) {
            push := (win["y"] - (monBottom - edgeBuffer)) * Config["EdgeRepulsionForce"] * 0.01
            vy -= push
        }
        
        ; Enhanced inter-window forces (from old version logic)
        interactionCount := 0
        for other in allWindows {
            if (other == win || other["hwnd"] == g["ActiveWindow"])
                continue
            
            otherX := other["x"] + other["width"]/2
            otherY := other["y"] + other["height"]/2
            dx := wx - otherX
            dy := wy - otherY
            dist := Max(Sqrt(dx*dx + dy*dy), 1)
            
            ; Dynamic interaction range based on window sizes
            interactionRange := Sqrt(win["width"] * win["height"] + other["width"] * other["height"]) / 4
            
            if (dist < interactionRange * 1.2) {
                interactionCount++
                
                if (DebugConfig["PhysicsLogging"]) {
                    DebugLog(4, "PHYSICS", "Window interaction", Map(
                        "HWND1", win["hwnd"],
                        "HWND2", other["hwnd"],
                        "Distance", Round(dist, 2),
                        "InteractionRange", Round(interactionRange, 2),
                        "Type", "Repulsion"
                    ))
                }
                
                ; Close range: much stronger repulsion to prevent prolonged overlap
                repulsionForce := Config["RepulsionForce"] * (interactionRange * 1.2 - dist) / (interactionRange * 1.2)
                repulsionForce *= (other.Has("IsManual") ? Config["ManualRepulsionMultiplier"] : 1)
                
                ; Progressive force scaling - stronger when closer
                proximityMultiplier := 1 + (1 - dist / (interactionRange * 1.2)) * 2
                
                vx += dx * repulsionForce * proximityMultiplier / dist * 0.6
                vy += dy * repulsionForce * proximityMultiplier / dist * 0.6
            } else if (dist < interactionRange * 3) {  
                if (DebugConfig["PhysicsLogging"]) {
                    DebugLog(4, "PHYSICS", "Window interaction", Map(
                        "HWND1", win["hwnd"],
                        "HWND2", other["hwnd"],
                        "Distance", Round(dist, 2),
                        "Type", "Attraction"
                    ))
                }
                
                ; Medium range: gentle attraction for stable clustering
                attractionForce := Config["AttractionForce"] * 0.012 * (dist - interactionRange) / interactionRange
                
                vx -= dx * attractionForce / dist * 0.04
                vy -= dy * attractionForce / dist * 0.04
            }
        }
        
        if (DebugConfig["PhysicsLogging"]) {
            DebugLog(3, "PHYSICS", "Force calculation complete", Map(
                "HWND", win["hwnd"],
                "FinalVelocity", Round(vx, 4) . "," . Round(vy, 4),
                "Interactions", interactionCount
            ))
        }
        
        ; Apply stabilization
        ApplyStabilization(win)
        
        ; Enhanced speed limits for floating feel
        maxSpeed := Config["MaxSpeed"] * 2.0
        vx := Min(Max(vx, -maxSpeed), maxSpeed)
        vy := Min(Max(vy, -maxSpeed), maxSpeed)
        
        ; Progressive stabilization based on speed
        if (Abs(vx) < 0.15 && Abs(vy) < 0.15) {
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
    } catch as e {
        DebugLog(0, "PHYSICS", "Force calculation error", Map("HWND", win["hwnd"], "Error", e.message))
        DebugEndTimer("CalculateWindowForces")
    }
}

; ===== MOVEMENT APPLICATION (enhanced with old version sophistication) =====
ApplyWindowMovements() {
    global g, Config
    static smoothPos := Map(), lastPositions := Map()
    
    DebugStartTimer("ApplyWindowMovements")
    DebugStats["TotalFrames"]++
    
    try {
        EnterCriticalSection()  ; Performance optimization from old version
        
        ; Check frames per second and adjust smoothing accordingly
        static lastFrameTime := 0
        currentTime := A_TickCount
        frameTime := currentTime - lastFrameTime
        lastFrameTime := currentTime
        
        ; Adaptive alpha based on frame rate (from old version)
        targetFrameTime := 16  ; 60 FPS
        frameTimeRatio := Min(2.0, frameTime / targetFrameTime)
        baseAlpha := Config["Smoothing"]
        adaptiveAlpha := baseAlpha * frameTimeRatio
        
        movementBatch := []
        movementThreshold := 0.5  ; Minimum movement to update
        
        windowsProcessed := 0
        windowsMoved := 0
        
        for win in g["Windows"] {
            windowsProcessed++
            hwnd := win["hwnd"]
            
            ; Skip locked or active windows
            if ((win.Has("ManualLock") && A_TickCount < win["ManualLock"]) || 
                win["hwnd"] == g["ActiveWindow"])
                continue
            
            ; Initialize smooth position tracking
            if (!smoothPos.Has(hwnd)) {
                smoothPos[hwnd] := Map("x", win["x"], "y", win["y"])
                lastPositions[hwnd] := Map("x", win["x"], "y", win["y"])
            }
            
            pos := smoothPos[hwnd]
            lastPos := lastPositions[hwnd]
            
            ; Enhanced smoothing with position prediction
            dx := win["targetX"] - pos["x"]
            dy := win["targetY"] - pos["y"]
            
            ; Apply different alpha values for different movement phases
            movementSpeed := Sqrt(dx*dx + dy*dy)
            
            if (movementSpeed > 5) {
                ; Fast movement - less smoothing for responsiveness
                currentAlpha := Min(0.35, adaptiveAlpha * 1.5)
            } else if (movementSpeed > 1) {
                ; Medium movement - balanced smoothing
                currentAlpha := adaptiveAlpha
            } else {
                ; Slow movement - more smoothing for stability
                currentAlpha := adaptiveAlpha * 0.7
            }
            
            ; Apply smoothing
            newX := pos["x"] + dx * currentAlpha
            newY := pos["y"] + dy * currentAlpha
            
            ; Movement threshold check (from old version)
            deltaX := Abs(newX - lastPos["x"])
            deltaY := Abs(newY - lastPos["y"])
            
            if (deltaX > movementThreshold || deltaY > movementThreshold) {
                windowsMoved++
                
                if (DebugConfig["WindowStateLogging"]) {
                    DebugLog(4, "MOVEMENT", "Window movement batched", Map(
                        "HWND", hwnd,
                        "From", Round(lastPos["x"], 1) . "," . Round(lastPos["y"], 1),
                        "To", Round(newX, 1) . "," . Round(newY, 1),
                        "Delta", Round(deltaX, 2) . "," . Round(deltaY, 2)
                    ))
                }
                
                ; Boundary enforcement (from old version)
                if (Config["SeamlessMonitorFloat"]) {
                    virtualBounds := GetVirtualDesktopBounds()
                    monLeft := virtualBounds["Left"]
                    monTop := virtualBounds["Top"]
                    monRight := virtualBounds["Right"] - win["width"]
                    monBottom := virtualBounds["Bottom"] - win["height"]
                } else {
                    ; Use the window's own monitor bounds instead of global monitor
                    winMonitorNum := win["monitor"]
                    winMonitorBounds := Map()
                    
                    ; Find the monitor bounds for this window
                    if (winMonitorNum > 0 && winMonitorNum <= g["AllMonitors"].Length) {
                        winMonitorBounds := g["AllMonitors"][winMonitorNum]
                    } else {
                        ; Fallback to primary monitor if window monitor is invalid
                        winMonitorBounds := GetPrimaryMonitorCoordinates()
                    }
                    
                    monLeft := winMonitorBounds["Left"]
                    monTop := winMonitorBounds["Top"] + Config["MinMargin"]
                    monRight := winMonitorBounds["Right"] - win["width"]
                    monBottom := winMonitorBounds["Bottom"] - Config["MinMargin"] - win["height"]
                }
                
                newX := Max(monLeft, Min(newX, monRight))
                newY := Max(monTop, Min(newY, monBottom))
                
                ; Batch movement for performance
                movementBatch.Push(Map("hwnd", hwnd, "x", Round(newX), "y", Round(newY)))
                
                ; Update tracking
                pos["x"] := newX
                pos["y"] := newY
                lastPos["x"] := newX
                lastPos["y"] := newY
                
                ; Update window object
                win["x"] := newX
                win["y"] := newY
                win["centerX"] := newX + win["width"]/2
                win["centerY"] := newY + win["height"]/2
            }
        }
        
        ; Execute batched movements (from old version approach)
        movementsExecuted := 0
        for movement in movementBatch {
            if (MoveWindowAPI(movement["hwnd"], movement["x"], movement["y"])) {
                movementsExecuted++
            }
        }
        
        DebugStats["WindowMoves"] += movementsExecuted
        
        if (DebugConfig["PerformanceLogging"] && movementBatch.Length > 0) {
            DebugLog(3, "MOVEMENT", "Movement batch complete", Map(
                "WindowsProcessed", windowsProcessed,
                "WindowsMoved", windowsMoved,
                "MovementsBatched", movementBatch.Length,
                "MovementsExecuted", movementsExecuted
            ))
        }
        
        LeaveCriticalSection()
        DebugEndTimer("ApplyWindowMovements")
    } catch as e {
        DebugLog(0, "MOVEMENT", "Movement application error", Map("Error", e.message))
        LeaveCriticalSection()
        DebugEndTimer("ApplyWindowMovements")
    }
}

; Direct Windows API movement function (from old version)
MoveWindowAPI(hwnd, x, y) {
    try {
        ; Use SetWindowPos for immediate, smooth movement
        result := DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", 0, "Int", 0, "UInt", 0x0001 | 0x0004 | 0x0010)
        
        if (!result) {
            DebugLog(1, "MOVEMENT", "SetWindowPos failed", Map("HWND", hwnd, "Position", x "," y))
            ; Fallback to WinMove if API fails
            try {
                WinMove(x, y, , , "ahk_id " hwnd)
                DebugLog(3, "MOVEMENT", "Fallback WinMove succeeded", Map("HWND", hwnd))
                return true
            } catch as e2 {
                DebugLog(0, "MOVEMENT", "Both SetWindowPos and WinMove failed", Map("HWND", hwnd, "Error", e2.message))
                return false
            }
        }
        
        return true
    } catch as e {
        DebugLog(0, "MOVEMENT", "MoveWindowAPI error", Map("HWND", hwnd, "Error", e.message))
        return false
    }
}

; Critical section functions for performance (from old version)
EnterCriticalSection() {
    ; Placeholder for critical section entry
    ; In practice, this would use Windows API or be optimized differently
}

LeaveCriticalSection() {
    ; Placeholder for critical section exit
}

; ===== VISUAL FEEDBACK (functional style) =====
AddManualWindowBorder(hwnd) {
    global g, Config
    try {
        if (g["ManualWindows"].Has(hwnd))
            return
            
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        borderGui := Gui("+ToolWindow -Caption +E0x20 +LastFound +AlwaysOnTop")
        borderGui.Opt("+Owner" hwnd)
        borderGui.BackColor := Config["ManualWindowColor"]
        borderGui.Show("x" x-3 " y" y-3 " w" w+6 " h" h+6 " NA")
        
        g["ManualWindows"][hwnd] := Map(
            "gui", borderGui,
            "expire", A_TickCount + Config["ManualLockDuration"]
        )
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
    global g
    for hwnd, data in g["ManualWindows"].Clone() {
        try {
            if (A_TickCount > data["expire"]) {
                RemoveManualWindowBorder(hwnd)
                continue
            }
            
            if (WinExist("ahk_id " hwnd)) {
                WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
                data["gui"].Show("x" x-3 " y" y-3 " w" w+6 " h" h+6 " NA")
            } else {
                RemoveManualWindowBorder(hwnd)
            }
        }
    }
}

; ===== WINDOW LIST MANAGEMENT (from old version) =====
GetVisibleWindows(monitor) {
    global Config, g
    
    DebugStartTimer("GetVisibleWindows")
    
    try {
        WinList := []
        existingMap := Map()
        
        ; Create lookup for existing windows
        for win in g["Windows"] {
            existingMap[win["hwnd"]] := win
        }
        
        DebugLog(3, "WINDOW_LIST", "Starting window scan", Map(
            "ExistingWindows", existingMap.Count,
            "SeamlessMode", Config["SeamlessMonitorFloat"]
        ))
        
        ; Scan all windows
        allWindows := WinGetList()
        windowsScanned := 0
        windowsIncluded := 0
        windowsSkipped := 0
        
        for hwnd in allWindows {
            windowsScanned++
            
            try {
                if (!IsWindowFloating(hwnd)) {
                    windowsSkipped++
                    continue
                }
                    
                WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
                if (w <= 0 || h <= 0) {
                    DebugLog(4, "WINDOW_LIST", "Window has invalid size", Map("HWND", hwnd, "Size", w "x" h))
                    windowsSkipped++
                    continue
                }
                    
                ; Determine which monitor this window belongs to
                winCenterX := x + w/2
                winCenterY := y + h/2
                winMonitor := MonitorGetFromPoint(winCenterX, winCenterY)
                if (!winMonitor)
                    winMonitor := g["ActiveMonitorIndex"]
                
                ; Check if window should be included based on floating mode
                includeWindow := false
                
                if (Config["SeamlessMonitorFloat"]) {
                    ; In seamless mode, include all windows from all monitors
                    includeWindow := true
                } else {
                    ; In traditional mode, include all windows but keep them on their respective monitors
                    ; Always include floating windows regardless of which monitor they're on
                    includeWindow := true
                }
                
                if (includeWindow) {
                    windowsIncluded++
                    
                    ; Find existing window data if available
                    existing := existingMap.Has(hwnd) ? existingMap[hwnd] : 0
                    
                    ; Create window data
                    winData := CreateWindowData(hwnd, x, y, w, h, existing)
                    winData["monitor"] := winMonitor
                    
                    WinList.Push(winData)
                    
                    if (DebugConfig["WindowStateLogging"]) {
                        DebugLog(4, "WINDOW_LIST", "Window included", Map(
                            "HWND", hwnd,
                            "Position", x "," y,
                            "Size", w "x" h,
                            "Monitor", winMonitor,
                            "IsExisting", existing ? true : false
                        ))
                    }
                }
            }
            catch as e {
                DebugLog(1, "WINDOW_LIST", "Error processing window", Map("HWND", hwnd, "Error", e.message))
                windowsSkipped++
                continue
            }
        }
        
        DebugStats["WindowCount"] := windowsIncluded
        DebugStats["ActiveWindows"] := windowsIncluded
        
        DebugLog(2, "WINDOW_LIST", "Window scan complete", Map(
            "WindowsScanned", windowsScanned,
            "WindowsIncluded", windowsIncluded,
            "WindowsSkipped", windowsSkipped,
            "FinalCount", WinList.Length
        ))
        
        DebugEndTimer("GetVisibleWindows")
        return WinList
    } catch as e {
        DebugLog(0, "WINDOW_LIST", "GetVisibleWindows failed", Map("Error", e.message))
        DebugEndTimer("GetVisibleWindows")
        return []
    }
}

; ===== MAIN FUNCTIONS (from old version structure) =====
CalculateDynamicLayout() {
    global g, Config
    static forceMultipliers := Map("normal", 1.0, "chaos", 0.6)
    static lastState := "normal"
    static transitionTime := 300
    static lastFocusCheck := 0

    DebugStartTimer("CalculateDynamicLayout")
    DebugStats["PhysicsFrames"]++

    try {
        ; Update active window detection periodically
        if (A_TickCount - g["LastFocusCheck"] > 250) {
            try {
                focusedWindow := WinExist("A")
                if (focusedWindow && focusedWindow != g["ActiveWindow"]) {
                    ; Check if the focused window is one of our managed windows
                    windowFound := false
                    for win in g["Windows"] {
                        if (win["hwnd"] == focusedWindow) {
                            g["ActiveWindow"] := focusedWindow
                            g["LastUserMove"] := A_TickCount
                            windowFound := true
                            
                            DebugLog(3, "FOCUS", "Active window changed", Map(
                                "NewActive", focusedWindow,
                                "WindowManaged", true
                            ))
                            break
                        }
                    }
                    
                    if (!windowFound) {
                        DebugLog(4, "FOCUS", "Focused window not managed", Map("HWND", focusedWindow))
                    }
                }
                
                ; Clear active window if timeout expired and it's no longer focused
                if (g["ActiveWindow"] != 0 && 
                    A_TickCount - g["LastUserMove"] > Config["UserMoveTimeout"] && 
                    focusedWindow != g["ActiveWindow"]) {
                    g["ActiveWindow"] := 0
                }
            } catch as e {
                DebugLog(1, "FOCUS", "Focus check error", Map("Error", e.message))
            }
            g["LastFocusCheck"] := A_TickCount
        }

        ; Dynamic force adjustment based on system energy
        currentEnergy := 0
        for win in g["Windows"] {
            CalculateWindowForces(win, g["Windows"])
            currentEnergy += win["vx"]**2 + win["vy"]**2
        }
        
        oldEnergy := g["SystemEnergy"]
        g["SystemEnergy"] := Lerp(g["SystemEnergy"], currentEnergy, 0.1)
        
        if (DebugConfig["PhysicsLogging"]) {
            DebugLog(4, "PHYSICS", "System energy update", Map(
                "OldEnergy", Round(oldEnergy, 4),
                "CurrentEnergy", Round(currentEnergy, 4),
                "SmoothedEnergy", Round(g["SystemEnergy"], 4)
            ))
        }

        ; State machine for natural motion transitions
        newState := (g["SystemEnergy"] > Config["Stabilization"]["EnergyThreshold"] * 2) ? "chaos" : "normal"
        
        if (newState != lastState) {
            transitionTime := (newState == "chaos") ? 200 : 800
            g["ForceTransition"] := A_TickCount + transitionTime
            
            DebugLog(2, "PHYSICS", "State transition", Map(
                "FromState", lastState,
                "ToState", newState,
                "TransitionTime", transitionTime
            ))
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
            win["vx"] *= currentMultiplier
            win["vy"] *= currentMultiplier
            
            maxSpeed := Config["MaxSpeed"] * 1.5
            win["vx"] := Min(Max(win["vx"], -maxSpeed), maxSpeed)
            win["vy"] := Min(Max(win["vy"], -maxSpeed), maxSpeed)
        }
        
        lastState := newState
    } catch as e {
        DebugLog(0, "PHYSICS", "CalculateDynamicLayout error", Map("Error", e.message))
        DebugEndTimer("CalculateDynamicLayout")
    }
}

UpdateWindowStates() {
    global g, Config
    
    DebugStartTimer("UpdateWindowStates")
    
    try {
        ; Update monitor tracking
        UpdateAllMonitors()
        
        DebugLog(4, "UPDATE", "Monitor tracking updated", Map("MonitorCount", g["AllMonitors"].Length))
        
        ; Use virtual desktop bounds if seamless floating is enabled
        if (Config["SeamlessMonitorFloat"]) {
            currentMonitor := GetVirtualDesktopBounds()
            g["Monitor"] := currentMonitor
            g["Windows"] := GetVisibleWindows(currentMonitor)
            
            DebugLog(3, "UPDATE", "Using virtual desktop bounds", Map(
                "Bounds", currentMonitor["Left"] "," currentMonitor["Top"] "," currentMonitor["Right"] "," currentMonitor["Bottom"]
            ))
        } else {
            ; In non-seamless mode, don't change monitor bounds based on mouse
            ; Keep the current monitor bounds stable
            if (!g["Monitor"].Has("Left")) {
                g["Monitor"] := GetPrimaryMonitorCoordinates()
                DebugLog(2, "UPDATE", "Initialized primary monitor coordinates")
            }
            g["Windows"] := GetVisibleWindows(g["Monitor"])
        }
        
        DebugLog(3, "UPDATE", "Window states updated", Map(
            "WindowCount", g["Windows"].Length,
            "ArrangementActive", g["ArrangementActive"],
            "PhysicsEnabled", g["PhysicsEnabled"]
        ))
        
        if (g["ArrangementActive"] && g["PhysicsEnabled"])
            CalculateDynamicLayout()
            
        DebugEndTimer("UpdateWindowStates")
    }
    catch as e {
        DebugLog(0, "UPDATE", "UpdateWindowStates error", Map("Error", e.message))
        
        ; Initialize with appropriate monitor bounds
        initialMonitor := Config["SeamlessMonitorFloat"] ? GetVirtualDesktopBounds() : GetCurrentMonitorInfo()
        g := Map(
            "Monitor", initialMonitor,
            "ArrangementActive", true,
            "LastUserMove", 0,
            "ActiveWindow", 0,
            "Windows", [],
            "PhysicsEnabled", true,
            "ManualWindows", Map(),
            "SystemEnergy", 0,
            "LastFocusCheck", 0,
            "ForceTransition", 0,
            "AllMonitors", [],
            "ActiveMonitorIndex", 1
        )
        
        DebugLog(1, "UPDATE", "Reinitialized global state after error")
        DebugEndTimer("UpdateWindowStates")
    }
}

; ===== CONTROL FUNCTIONS (enhanced with old version features) =====
ToggleArrangement() {
    global g
    
    DebugLog(2, "CONTROL", "Toggling arrangement", Map("CurrentState", g["ArrangementActive"]))
    
    g["ArrangementActive"] := !g["ArrangementActive"]
    if (g["ArrangementActive"]) {
        UpdateWindowStates()
        SetTimer(CalculateDynamicLayout, Config["PhysicsTimeStep"])
        SetTimer(ApplyWindowMovements, Config["VisualTimeStep"])
        ShowTooltip("Window Arrangement: ON")
        
        DebugLog(2, "CONTROL", "Arrangement enabled", Map(
            "PhysicsInterval", Config["PhysicsTimeStep"],
            "VisualInterval", Config["VisualTimeStep"]
        ))
    } else {
        SetTimer(CalculateDynamicLayout, 0)
        SetTimer(ApplyWindowMovements, 0)
        ShowTooltip("Window Arrangement: OFF")
        
        DebugLog(2, "CONTROL", "Arrangement disabled")
    }
}

TogglePhysics() {
    global g
    
    DebugLog(2, "CONTROL", "Toggling physics", Map("CurrentState", g["PhysicsEnabled"]))
    
    g["PhysicsEnabled"] := !g["PhysicsEnabled"]
    if (g["PhysicsEnabled"]) {
        SetTimer(CalculateDynamicLayout, Config["PhysicsTimeStep"])
        ShowTooltip("Physics Engine: ON")
        DebugLog(2, "CONTROL", "Physics enabled")
    } else {
        SetTimer(CalculateDynamicLayout, 0)
        ShowTooltip("Physics Engine: OFF")
        DebugLog(2, "CONTROL", "Physics disabled")
    }
}

ToggleSeamlessMonitorFloat() {
    global Config, g
    
    DebugLog(2, "CONTROL", "Toggling seamless monitor float", Map("CurrentState", Config["SeamlessMonitorFloat"]))
    
    Config["SeamlessMonitorFloat"] := !Config["SeamlessMonitorFloat"]
    
    if (Config["SeamlessMonitorFloat"]) {
        g["Monitor"] := GetVirtualDesktopBounds()
        ShowTooltip("Seamless Multi-Monitor Floating: ON - Windows can float across all monitors")
        DebugLog(2, "CONTROL", "Seamless mode enabled", Map("VirtualBounds", g["Monitor"]["Width"] "x" g["Monitor"]["Height"]))
    } else {
        g["Monitor"] := GetCurrentMonitorInfo()
        ShowTooltip("Seamless Multi-Monitor Floating: OFF - Windows confined to current monitor")
        DebugLog(2, "CONTROL", "Seamless mode disabled", Map("MonitorBounds", g["Monitor"]["Width"] "x" g["Monitor"]["Height"]))
    }
    
    ; Force update of all window states to apply new boundaries
    if (g["ArrangementActive"]) {
        UpdateWindowStates()
    }
}

ToggleWindowLock() {
    global g, Config
    
    DebugLog(3, "CONTROL", "Attempting to toggle window lock")
    
    try {
        focusedWindow := WinExist("A")
        if (!focusedWindow) {
            ShowTooltip("No active window to lock/unlock")
            DebugLog(1, "CONTROL", "No active window for lock toggle")
            return
        }
        
        DebugLog(3, "CONTROL", "Lock toggle for window", Map("HWND", focusedWindow))
        
        ; Find the window in our managed windows
        targetWin := 0
        for win in g["Windows"] {
            if (win["hwnd"] == focusedWindow) {
                targetWin := win
                break
            }
        }
        
        if (!targetWin) {
            ShowTooltip("Window not managed by FWDE")
            DebugLog(1, "CONTROL", "Window not managed", Map("HWND", focusedWindow))
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
            ShowTooltip("Window UNLOCKED - Physics Active")
            
            DebugLog(2, "CONTROL", "Window unlocked", Map("HWND", focusedWindow))
        } else {
            ; Lock the window
            targetWin["ManualLock"] := A_TickCount + Config["ManualLockDuration"]
            g["ActiveWindow"] := focusedWindow
            g["LastUserMove"] := A_TickCount
            ; Stop the window's movement immediately
            targetWin["vx"] := 0
            targetWin["vy"] := 0
            targetWin["targetX"] := targetWin["x"]
            targetWin["targetY"] := targetWin["y"]
            AddManualWindowBorder(focusedWindow)
            ShowTooltip("Window LOCKED - Position Fixed")
            
            DebugLog(2, "CONTROL", "Window locked", Map(
                "HWND", focusedWindow,
                "LockDuration", Config["ManualLockDuration"]
            ))
        }
    }
    catch as e {
        ShowTooltip("Error: Could not lock/unlock window")
        DebugLog(0, "CONTROL", "Lock toggle error", Map("Error", e.message))
    }
}

ShowMonitorStatus() {
    global g
    info := MonitorManager.GetMonitorInfo()
    activeWindows := g["Windows"].Length
    info .= "`nTotal Managed Windows: " activeWindows
    ShowTooltip(info)
}

MoveWindowToMonitor(targetMonitor) {
    global g
    try {
        focusedWindow := WinExist("A")
        if (!focusedWindow) {
            ShowTooltip("No active window to move")
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
            ShowTooltip("Window not managed by FWDE")
            return
        }
        
        if (targetMonitor > 0 && targetMonitor <= g["AllMonitors"].Length) {
            targetMonitorData := g["AllMonitors"][targetMonitor]
            
            ; Calculate new position (center of target monitor)
            newX := targetMonitorData["CenterX"] - targetWin["width"]/2
            newY := targetMonitorData["CenterY"] - targetWin["height"]/2
            
            ; Move window
            WinMove(newX, newY, , , "ahk_id " focusedWindow)
            
            ; Update window data
            targetWin["x"] := newX
            targetWin["y"] := newY
            targetWin["centerX"] := newX + targetWin["width"]/2
            targetWin["centerY"] := newY + targetWin["height"]/2
            targetWin["monitor"] := targetMonitor
            
            ShowTooltip("Moved window to Monitor " targetMonitor)
        }
    }
}

; ===== HOTKEYS (enhanced from old version) =====
^!Space::ToggleArrangement()                    ; Ctrl+Alt+Space - Toggle arrangement
^!P::TogglePhysics()                           ; Ctrl+Alt+P - Toggle physics  
^!L::ToggleWindowLock()                        ; Ctrl+Alt+L - Lock/unlock window
^!M::ToggleSeamlessMonitorFloat()              ; Ctrl+Alt+M - Toggle seamless multi-monitor floating

; Debug hotkeys
^!D::DebugLogStats()                           ; Ctrl+Alt+D - Log current statistics
^!+D::{                                        ; Ctrl+Alt+Shift+D - Toggle debug level
    global DebugConfig
    DebugConfig["LogLevel"] := Mod(DebugConfig["LogLevel"] + 1, 5)
    ShowTooltip("Debug Level: " DebugConfig["LogLevel"])
    DebugLog(2, "DEBUG", "Debug level changed", Map("NewLevel", DebugConfig["LogLevel"]))
}

; Enhanced monitor management hotkeys
^!I::ShowMonitorStatus()                       ; Ctrl+Alt+I - Show monitor info
^!1::MonitorManager.SwitchToMonitor(1)         ; Ctrl+Alt+1 - Switch to monitor 1
^!2::MonitorManager.SwitchToMonitor(2)         ; Ctrl+Alt+2 - Switch to monitor 2
^!3::MonitorManager.SwitchToMonitor(3)         ; Ctrl+Alt+3 - Switch to monitor 3
^!4::MonitorManager.SwitchToMonitor(4)         ; Ctrl+Alt+4 - Switch to monitor 4

; Move window to monitor hotkeys  
^!+1::MoveWindowToMonitor(1)                   ; Ctrl+Alt+Shift+1 - Move window to monitor 1
^!+2::MoveWindowToMonitor(2)                   ; Ctrl+Alt+Shift+2 - Move window to monitor 2
^!+3::MoveWindowToMonitor(3)                   ; Ctrl+Alt+Shift+3 - Move window to monitor 3
^!+4::MoveWindowToMonitor(4)                   ; Ctrl+Alt+Shift+4 - Move window to monitor 4

; ===== INITIALIZATION (following old version pattern) =====
DebugLog(2, "INIT", "Starting FWDE initialization")

; Initialize monitor tracking
MonitorManager.Update()
DebugLog(3, "INIT", "Monitor manager initialized")

; Initialize the global monitor state properly
if (Config["SeamlessMonitorFloat"]) {
    g["Monitor"] := GetVirtualDesktopBounds()
    DebugLog(2, "INIT", "Initialized with virtual desktop bounds")
} else {
    g["Monitor"] := GetCurrentMonitorInfo()
    DebugLog(2, "INIT", "Initialized with current monitor bounds")
}

; Start main timers
SetTimer(UpdateWindowStates, Config["PhysicsTimeStep"])
SetTimer(ApplyWindowMovements, Config["VisualTimeStep"])
SetTimer(UpdateManualBorders, Config["VisualTimeStep"])

; Start periodic stats logging
SetTimer(DebugLogStats, 30000)  ; Every 30 seconds

DebugLog(2, "INIT", "Main timers started", Map(
    "PhysicsInterval", Config["PhysicsTimeStep"],
    "VisualInterval", Config["VisualTimeStep"]
))

; Initial update
UpdateWindowStates()
DebugLog(2, "INIT", "Initial window state update complete")

; Show initialization message
monitorInfo := MonitorManager.GetMonitorInfo()
ShowTooltip("FWDE v2.0 Initialized`n" . monitorInfo)

DebugLog(2, "INIT", "FWDE initialization complete", Map(
    "Version", "2.0",
    "MonitorCount", g["AllMonitors"].Length,
    "InitialWindowCount", g["Windows"].Length
))

; ===== CLEANUP ON EXIT =====
OnExit(*) {
    global g
    
    DebugLog(2, "CLEANUP", "Starting FWDE cleanup")
    
    ; Stop all timers
    SetTimer(UpdateWindowStates, 0)
    SetTimer(ApplyWindowMovements, 0)
    SetTimer(UpdateManualBorders, 0)
    SetTimer(DebugLogStats, 0)
    
    ; Clean up manual borders
    for hwnd in g["ManualWindows"]
        RemoveManualWindowBorder(hwnd)
    
    ; Log final statistics
    DebugLogStats()
    
    DebugLog(2, "CLEANUP", "FWDE cleanup complete", Map(
        "Uptime", Round((A_TickCount - DebugStats["StartTime"]) / 1000, 2) . "s",
        "TotalFrames", DebugStats["TotalFrames"],
        "TotalMoves", DebugStats["WindowMoves"],
        "Errors", DebugStats["Errors"]
    ))
}