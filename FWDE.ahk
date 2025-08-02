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
    "Monitor", Config["SeamlessMonitorFloat"] ? GetVirtualDesktopBounds() : GetCurrentMonitorInfo(),
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
    partitions := []
    partitionSize := Ceil(windows.Length / numPartitions)
    
    Loop numPartitions {
        startIdx := (A_Index - 1) * partitionSize + 1
        endIdx := Min(A_Index * partitionSize, windows.Length)
        
        partition := []
        Loop endIdx - startIdx + 1 {
            if (startIdx + A_Index - 1 <= windows.Length)
                partition.Push(windows[startIdx + A_Index - 1])
        }
        partitions.Push(partition)
    }
    
    return partitions
}

; Enhanced distance calculation with size awareness
GetWindowDistance(win1, win2) {
    dx := win1["centerX"] - win2["centerX"]
    dy := win1["centerY"] - win2["centerY"]
    return Sqrt(dx*dx + dy*dy)
}

; Enhanced overlap detection
CheckWindowOverlap(win1, win2, buffer := 0) {
    return !(win1["x"] + win1["width"] + buffer < win2["x"] ||
             win2["x"] + win2["width"] + buffer < win1["x"] ||
             win1["y"] + win1["height"] + buffer < win2["y"] ||
             win2["y"] + win2["height"] + buffer < win1["y"])
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
        return WinExist("ahk_id " hwnd)
    }
    catch {
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
            "CenterX", (R + L) // 2, "CenterY", (B + T) // 2,
            "WorkLeft", L, "WorkTop", T + Config["MinMargin"],
            "WorkRight", R, "WorkBottom", B - Config["MinMargin"]
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
    
    if (!SafeWinExist(hwnd))
        return false
        
    try {
        if (WinGetMinMax("ahk_id " hwnd) != 0)
            return false
            
        title := WinGetTitle("ahk_id " hwnd)
        if (!title || title == "Program Manager")
            return false
            
        winClass := WinGetClass("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)
        style := WinGetStyle("ahk_id " hwnd)
        exStyle := WinGetExStyle("ahk_id " hwnd)

        ; Priority checks
        if (IsForceFloatProcess(processName))
            return true
        if (IsConsoleWindow(winClass))
            return true
        if (IsPluginWindow(winClass, title))
            return true
        if (HasFloatingStyle(style, exStyle))
            return true
        if (MatchesPatterns(winClass, title))
            return true
            
        return false
    } catch {
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
    winMonitor := MonitorGetFromPoint(x + w/2, y + h/2)
    if (!winMonitor) {
        global g
        winMonitor := g["ActiveMonitorIndex"]
    }
        
    return Map(
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
}

; ===== PHYSICS ENGINE (functional style from old version) =====
; ===== PHYSICS ENGINE (enhanced with old version sophistication) =====
ApplyStabilization(win) {
    global Config
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

    ; Keep active window and recently moved windows still
    isActiveWindow := (win["hwnd"] == g["ActiveWindow"])
    isRecentlyMoved := (A_TickCount - g["LastUserMove"] < Config["UserMoveTimeout"])
    isCurrentlyFocused := (win["hwnd"] == WinExist("A"))
    isManuallyLocked := (win.Has("ManualLock") && A_TickCount < win["ManualLock"])
    
    if (isActiveWindow || isRecentlyMoved && isCurrentlyFocused || isManuallyLocked) {
        win["vx"] := 0
        win["vy"] := 0
        win["targetX"] := win["x"]
        win["targetY"] := win["y"]
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
        monitor := g["Monitor"]
        mL := monitor["Left"]
        mT := monitor["Top"]
        mR := monitor["Right"]
        mB := monitor["Bottom"]
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
        
        ; Smaller windows get proportionally larger interaction zones
        sizeBonus := Max(1, 200 / Min(win["width"], win["height"]))
        interactionRange *= sizeBonus
        
        if (dist < interactionRange * 1.2) {  ; Expanded repulsion zone
            ; Close range: much stronger repulsion to prevent prolonged overlap
            repulsionForce := Config["RepulsionForce"] * (interactionRange * 1.2 - dist) / (interactionRange * 1.2)
            repulsionForce *= (other.Has("IsManual") ? Config["ManualRepulsionMultiplier"] : 1)
            
            ; Progressive force scaling - stronger when closer
            proximityMultiplier := 1 + (1 - dist / (interactionRange * 1.2)) * 2
            
            vx += dx * repulsionForce * proximityMultiplier / dist * 0.6
            vy += dy * repulsionForce * proximityMultiplier / dist * 0.6
        } else if (dist < interactionRange * 3) {  
            ; Medium range: gentle attraction for stable clustering
            attractionForce := Config["AttractionForce"] * 0.012 * (dist - interactionRange) / interactionRange
            
            vx -= dx * attractionForce / dist * 0.04
            vy -= dy * attractionForce / dist * 0.04
        }
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
}

; ===== MOVEMENT APPLICATION (enhanced with old version sophistication) =====
ApplyWindowMovements() {
    global g, Config
    static smoothPos := Map(), lastPositions := Map()
    
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
    
    for win in g["Windows"] {
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
            ; Boundary enforcement (from old version)
            monitor := g["Monitor"]
            if (Config["SeamlessMonitorFloat"]) {
                virtualBounds := GetVirtualDesktopBounds()
                monLeft := virtualBounds["Left"]
                monTop := virtualBounds["Top"]
                monRight := virtualBounds["Right"] - win["width"]
                monBottom := virtualBounds["Bottom"] - win["height"]
            } else {
                monLeft := monitor["Left"]
                monTop := monitor["Top"] + Config["MinMargin"]
                monRight := monitor["Right"] - win["width"]
                monBottom := monitor["Bottom"] - Config["MinMargin"] - win["height"]
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
    for movement in movementBatch {
        MoveWindowAPI(movement["hwnd"], movement["x"], movement["y"])
    }
    
    LeaveCriticalSection()
}

; Direct Windows API movement function (from old version)
MoveWindowAPI(hwnd, x, y) {
    try {
        ; Use SetWindowPos for immediate, smooth movement
        DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", 0, "Int", 0, "UInt", 0x0001 | 0x0004 | 0x0010)
    } catch {
        ; Fallback to WinMove if API fails
        try {
            WinMove(x, y, , , "ahk_id " hwnd)
        }
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
    WinList := []
    existingMap := Map()
    
    ; Create lookup for existing windows
    for win in g["Windows"] {
        existingMap[win["hwnd"]] := win
    }
    
    ; Scan all windows
    for hwnd in WinGetList() {
        try {
            if (!IsWindowFloating(hwnd))
                continue
                
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            if (w <= 0 || h <= 0)
                continue
                
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
                ; In traditional mode, only include windows on current monitor or already tracked
                isTracked := false
                for trackedWin in g["Windows"] {
                    if (trackedWin["hwnd"] == hwnd) {
                        isTracked := true
                        break
                    }
                }
                includeWindow := (winMonitor == monitor["Number"] || isTracked)
            }
            
            if (includeWindow) {
                ; Find existing window data if available
                existing := existingMap.Has(hwnd) ? existingMap[hwnd] : 0
                
                ; Create window data
                winData := CreateWindowData(hwnd, x, y, w, h, existing)
                winData["monitor"] := winMonitor
                
                WinList.Push(winData)
            }
        }
        catch {
            continue
        }
    }
    
    return WinList
}

; ===== MAIN FUNCTIONS (from old version structure) =====
CalculateDynamicLayout() {
    global g, Config
    static forceMultipliers := Map("normal", 1.0, "chaos", 0.6)
    static lastState := "normal"
    static transitionTime := 300
    static lastFocusCheck := 0

    ; Update active window detection periodically
    if (A_TickCount - g["LastFocusCheck"] > 250) {
        try {
            focusedWindow := WinExist("A")
            if (focusedWindow && focusedWindow != g["ActiveWindow"]) {
                ; Check if the focused window is one of our managed windows
                for win in g["Windows"] {
                    if (win["hwnd"] == focusedWindow) {
                        g["ActiveWindow"] := focusedWindow
                        g["LastUserMove"] := A_TickCount
                        break
                    }
                }
            }
            
            ; Clear active window if timeout expired and it's no longer focused
            if (g["ActiveWindow"] != 0 && 
                A_TickCount - g["LastUserMove"] > Config["UserMoveTimeout"] && 
                focusedWindow != g["ActiveWindow"]) {
                g["ActiveWindow"] := 0
            }
        }
        g["LastFocusCheck"] := A_TickCount
    }

    ; Dynamic force adjustment based on system energy
    currentEnergy := 0
    for win in g["Windows"] {
        CalculateWindowForces(win, g["Windows"])
        currentEnergy += win["vx"]**2 + win["vy"]**2
    }
    g["SystemEnergy"] := Lerp(g["SystemEnergy"], currentEnergy, 0.1)

    ; State machine for natural motion transitions
    newState := (g["SystemEnergy"] > Config["Stabilization"]["EnergyThreshold"] * 2) ? "chaos" : "normal"
    
    if (newState != lastState) {
        transitionTime := (newState == "chaos") ? 200 : 800
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
        win["vx"] *= currentMultiplier
        win["vy"] *= currentMultiplier
        
        maxSpeed := Config["MaxSpeed"] * 1.5
        win["vx"] := Min(Max(win["vx"], -maxSpeed), maxSpeed)
        win["vy"] := Min(Max(win["vy"], -maxSpeed), maxSpeed)
    }
    
    lastState := newState
}

UpdateWindowStates() {
    global g, Config
    try {
        ; Update monitor tracking
        UpdateAllMonitors()
        
        ; Use virtual desktop bounds if seamless floating is enabled
        if (Config["SeamlessMonitorFloat"]) {
            currentMonitor := GetVirtualDesktopBounds()
        } else {
            currentMonitor := GetCurrentMonitorInfo()
        }
        
        g["Monitor"] := currentMonitor
        g["Windows"] := GetVisibleWindows(currentMonitor)
        
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
            "ManualWindows", Map(),
            "SystemEnergy", 0,
            "LastFocusCheck", 0,
            "ForceTransition", 0,
            "AllMonitors", [],
            "ActiveMonitorIndex", 1
        )
    }
}

; ===== CONTROL FUNCTIONS (enhanced with old version features) =====
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

ToggleSeamlessMonitorFloat() {
    global Config, g
    Config["SeamlessMonitorFloat"] := !Config["SeamlessMonitorFloat"]
    
    if (Config["SeamlessMonitorFloat"]) {
        g["Monitor"] := GetVirtualDesktopBounds()
        ShowTooltip("Seamless Multi-Monitor Floating: ON - Windows can float across all monitors")
    } else {
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
            ShowTooltip("Window not managed by FWDE")
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
        }
    }
    catch {
        ShowTooltip("Error: Could not lock/unlock window")
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
; Initialize monitor tracking
MonitorManager.Update()

; Start main timers
SetTimer(UpdateWindowStates, Config["PhysicsTimeStep"])
SetTimer(ApplyWindowMovements, Config["VisualTimeStep"])
SetTimer(UpdateManualBorders, Config["VisualTimeStep"])

; Initial update
UpdateWindowStates()

; Show initialization message
monitorInfo := MonitorManager.GetMonitorInfo()
ShowTooltip("FWDE v2.0 Initialized`n" . monitorInfo)

; ===== CLEANUP ON EXIT =====
OnExit(*) {
    global g
    ; Stop all timers
    SetTimer(UpdateWindowStates, 0)
    SetTimer(ApplyWindowMovements, 0)
    SetTimer(UpdateManualBorders, 0)
    
    ; Clean up manual borders
    for hwnd in g["ManualWindows"]
        RemoveManualWindowBorder(hwnd)
}