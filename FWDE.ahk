#Requires AutoHotkey v2.0
#SingleInstance Force
#WinActivateForce
#Warn
#MaxThreadsPerHotkey 255
#MaxThreads 255

A_IconTip := "FWDE - Floating Windows Dynamic Equilibrium v2.0"
ProcessSetPriority("High")

; ===== CORE CONFIGURATION MODULE =====
class FWDEConfig {
    static Settings := Map(
        ; Physics Engine
        "AttractionForce", 0.0002,
        "RepulsionForce", 0.5,
        "EdgeRepulsionForce", 1.2,
        "Damping", 0.008,
        "MaxSpeed", 15.0,
        "MinSpeedThreshold", 0.2,
        "EnergyThreshold", 0.08,
        
        ; Spatial Parameters
        "MinMargin", 45,
        "MinGap", 25,
        "ManualGapBonus", 400,
        "OverlapTolerance", 5,
        
        ; Timing & Performance
        "PhysicsInterval", 8,
        "VisualInterval", 16,
        "StateUpdateInterval", 100,
        "UserMoveTimeout", 8000,
        "ManualLockDuration", 30000,
        
        ; Visual Feedback
        "ManualWindowColor", "0xFF4444",
        "ManualWindowAlpha", 200,
        "TooltipDuration", 12000,
        "Smoothing", 0.65
    )
    
    static WindowPatterns := Map(
        "FloatStyles", 0x00C00000 | 0x00040000 | 0x00080000 | 0x00020000 | 0x00010000,
        "FloatClasses", ["Vst.*", "JS.*", ".*Plugin.*", ".*Float.*", ".*Dock.*", "#32770", "ConsoleWindowClass", "CASCADIA_HOSTING_WINDOW_CLASS"],
        "FloatTitles", ["VST.*", "JS:.*", "Plugin", ".*FX.*", "Command Prompt", "cmd.exe", "Windows Terminal"],
        "ForceFloatProcesses", ["reaper.exe", "ableton.exe", "flstudio.exe", "cubase.exe", "studioone.exe", "bitwig.exe", "protools.exe", "cmd.exe", "conhost.exe", "WindowsTerminal.exe"]
    )
}

; ===== MONITOR MANAGEMENT MODULE =====
class MonitorManager {
    static Current := Map()
    
    static GetPrimary() {
        try {
            MonitorGet(MonitorGetPrimary(), &L, &T, &R, &B)
            return this.CreateMonitorMap(L, T, R, B, MonitorGetPrimary())
        } catch {
            return this.CreateMonitorMap(0, 0, A_ScreenWidth, A_ScreenHeight, 1)
        }
    }
    
    static CreateMonitorMap(L, T, R, B, Number) {
        return Map(
            "Left", L, "Top", T, "Right", R, "Bottom", B,
            "Width", R - L, "Height", B - T, "Number", Number,
            "CenterX", (R + L) // 2, "CenterY", (B + T) // 2,
            "WorkLeft", L, "WorkTop", T + FWDEConfig.Settings["MinMargin"],
            "WorkRight", R, "WorkBottom", B - FWDEConfig.Settings["MinMargin"]
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
    
    static Update() {
        this.Current := this.GetPrimary()
    }
}

; ===== WINDOW DETECTION & CLASSIFICATION MODULE =====
class WindowClassifier {
    static IsFloating(hwnd) {
        if (!this.SafeExists(hwnd))
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
            if (this.IsForceFloatProcess(processName))
                return true
            if (this.IsConsoleWindow(winClass))
                return true
            if (this.IsPluginWindow(winClass, title))
                return true
            if (this.HasFloatingStyle(style, exStyle))
                return true
            if (this.MatchesPatterns(winClass, title))
                return true
                
            return false
        } catch {
            return false
        }
    }
    
    static SafeExists(hwnd) {
        try {
            return WinExist("ahk_id " hwnd)
        } catch {
            return false
        }
    }
    
    static IsForceFloatProcess(processName) {
        for pattern in FWDEConfig.WindowPatterns["ForceFloatProcesses"] {
            if (processName ~= "i)^" pattern "$")
                return true
        }
        return false
    }
    
    static IsConsoleWindow(winClass) {
        return winClass == "ConsoleWindowClass" || winClass == "CASCADIA_HOSTING_WINDOW_CLASS"
    }
    
    static IsPluginWindow(winClass, title) {
        return (winClass ~= "i)(Vst|JS|Plugin|Float)") || (title ~= "i)(VST|JS:|Plugin|FX)")
    }
    
    static HasFloatingStyle(style, exStyle) {
        return (exStyle & 0x80) || (!(style & 0x10000000)) || (style & FWDEConfig.WindowPatterns["FloatStyles"])
    }
    
    static MatchesPatterns(winClass, title) {
        for pattern in FWDEConfig.WindowPatterns["FloatClasses"] {
            if (winClass ~= "i)" pattern)
                return true
        }
        for pattern in FWDEConfig.WindowPatterns["FloatTitles"] {
            if (title ~= "i)" pattern)
                return true
        }
        return false
    }
}

; ===== WINDOW DATA STRUCTURE =====
class WindowData {
    static Create(hwnd, x, y, w, h, existing := 0) {
        winMonitor := MonitorManager.GetFromPoint(x + w/2, y + h/2)
        if (!winMonitor)
            winMonitor := MonitorManager.Current["Number"]
            
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
}

; ===== PHYSICS ENGINE MODULE =====
class PhysicsEngine {
    static CalculateForces(win, allWindows, activeHwnd, lastUserMove) {
        ; Skip locked or active windows
        if (this.IsLocked(win) || win["hwnd"] == activeHwnd)
            return this.StopMovement(win)
            
        ; Skip recently moved windows
        if (A_TickCount - lastUserMove < FWDEConfig.Settings["UserMoveTimeout"] && win["hwnd"] == WinExist("A"))
            return this.StopMovement(win)

        monitor := MonitorManager.Current
        forces := this.CalculateAllForces(win, allWindows, monitor)
        
        ; Apply forces with damping
        damping := 1 - FWDEConfig.Settings["Damping"]
        win["vx"] := (win["vx"] * damping + forces["x"])
        win["vy"] := (win["vy"] * damping + forces["y"])
        
        ; Speed limiting and stabilization
        this.ApplySpeedLimits(win)
        this.UpdateTargetPosition(win, monitor)
    }
    
    static CalculateAllForces(win, allWindows, monitor) {
        forces := Map("x", 0, "y", 0)
        
        ; Center attraction (weak)
        centerForce := this.CalculateCenterAttraction(win, monitor)
        forces["x"] += centerForce["x"]
        forces["y"] += centerForce["y"]
        
        ; Edge repulsion
        edgeForce := this.CalculateEdgeRepulsion(win, monitor)
        forces["x"] += edgeForce["x"]
        forces["y"] += edgeForce["y"]
        
        ; Inter-window forces
        for other in allWindows {
            if (other == win || other["hwnd"] == WinExist("A"))
                continue
                
            interForce := this.CalculateInterWindowForce(win, other)
            forces["x"] += interForce["x"]
            forces["y"] += interForce["y"]
        }
        
        return forces
    }
    
    static CalculateCenterAttraction(win, monitor) {
        dx := monitor["CenterX"] - win["centerX"]
        dy := monitor["CenterY"] - win["centerY"]
        dist := Max(Sqrt(dx*dx + dy*dy), 1)
        
        if (dist > 150) {
            strength := Min(0.3, dist / 2000) * FWDEConfig.Settings["AttractionForce"]
            return Map("x", dx * strength, "y", dy * strength)
        }
        return Map("x", 0, "y", 0)
    }
    
    static CalculateEdgeRepulsion(win, monitor) {
        force := Map("x", 0, "y", 0)
        edgeBuffer := 60
        strength := FWDEConfig.Settings["EdgeRepulsionForce"]
        
        ; Left edge
        if (win["x"] < monitor["Left"] + edgeBuffer)
            force["x"] += (monitor["Left"] + edgeBuffer - win["x"]) * strength * 0.02
        ; Right edge
        if (win["x"] + win["width"] > monitor["Right"] - edgeBuffer)
            force["x"] -= (win["x"] + win["width"] - (monitor["Right"] - edgeBuffer)) * strength * 0.02
        ; Top edge
        if (win["y"] < monitor["WorkTop"] + edgeBuffer)
            force["y"] += (monitor["WorkTop"] + edgeBuffer - win["y"]) * strength * 0.02
        ; Bottom edge
        if (win["y"] + win["height"] > monitor["WorkBottom"] - edgeBuffer)
            force["y"] -= (win["y"] + win["height"] - (monitor["WorkBottom"] - edgeBuffer)) * strength * 0.02
            
        return force
    }
    
    static CalculateInterWindowForce(win1, win2) {
        dx := win1["centerX"] - win2["centerX"]
        dy := win1["centerY"] - win2["centerY"]
        dist := Max(Sqrt(dx*dx + dy*dy), 1)
        
        ; Dynamic interaction range
        avgSize := Sqrt((win1["area"] + win2["area"]) / 2)
        interactionRange := avgSize / 3
        
        if (dist < interactionRange * 1.5) {
            ; Close: repulsion
            strength := FWDEConfig.Settings["RepulsionForce"] * (interactionRange * 1.5 - dist) / (interactionRange * 1.5)
            multiplier := 1 + (1 - dist / (interactionRange * 1.5)) * 3
            
            return Map(
                "x", dx * strength * multiplier / dist * 0.8,
                "y", dy * strength * multiplier / dist * 0.8
            )
        } else if (dist < interactionRange * 4) {
            ; Medium: weak attraction
            strength := FWDEConfig.Settings["AttractionForce"] * 0.02
            return Map(
                "x", -dx * strength / dist * 0.06,
                "y", -dy * strength / dist * 0.06
            )
        }
        
        return Map("x", 0, "y", 0)
    }
    
    static ApplySpeedLimits(win) {
        maxSpeed := FWDEConfig.Settings["MaxSpeed"]
        win["vx"] := Min(Max(win["vx"], -maxSpeed), maxSpeed)
        win["vy"] := Min(Max(win["vy"], -maxSpeed), maxSpeed)
        
        ; Progressive stabilization
        minSpeed := FWDEConfig.Settings["MinSpeedThreshold"]
        if (Abs(win["vx"]) < minSpeed && Abs(win["vy"]) < minSpeed) {
            win["vx"] *= 0.85
            win["vy"] *= 0.85
        }
    }
    
    static UpdateTargetPosition(win, monitor) {
        win["targetX"] := win["x"] + win["vx"]
        win["targetY"] := win["y"] + win["vy"]
        
        ; Boundary constraints
        win["targetX"] := Max(monitor["Left"], Min(win["targetX"], monitor["Right"] - win["width"]))
        win["targetY"] := Max(monitor["WorkTop"], Min(win["targetY"], monitor["WorkBottom"] - win["height"]))
    }
    
    static IsLocked(win) {
        return win.Has("ManualLock") && A_TickCount < win["ManualLock"]
    }
    
    static StopMovement(win) {
        win["vx"] := 0
        win["vy"] := 0
        win["targetX"] := win["x"]
        win["targetY"] := win["y"]
    }
}

; ===== MOVEMENT & RENDERING MODULE =====
class MovementEngine {
    static SmoothPositions := Map()
    static LastPositions := Map()
    
    static ApplyMovements(windows) {
        for win in windows {
            if (PhysicsEngine.IsLocked(win) || win["hwnd"] == WindowManager.State["ActiveWindow"])
                continue
                
            this.SmoothMove(win)
        }
    }
    
    static SmoothMove(win) {
        hwnd := win["hwnd"]
        
        if (!this.SmoothPositions.Has(hwnd))
            this.SmoothPositions[hwnd] := Map("x", win["x"], "y", win["y"])
        if (!this.LastPositions.Has(hwnd))
            this.LastPositions[hwnd] := Map("x", win["x"], "y", win["y"])
            
        ; Smooth interpolation
        alpha := FWDEConfig.Settings["Smoothing"]
        smooth := this.SmoothPositions[hwnd]
        smooth["x"] += (win["targetX"] - smooth["x"]) * alpha
        smooth["y"] += (win["targetY"] - smooth["y"]) * alpha
        
        ; Apply movement if significant change
        if (Abs(smooth["x"] - this.LastPositions[hwnd]["x"]) >= 0.5 || 
            Abs(smooth["y"] - this.LastPositions[hwnd]["y"]) >= 0.5) {
            
            try {
                WinMove(Round(smooth["x"]), Round(smooth["y"]), , , "ahk_id " hwnd)
                this.LastPositions[hwnd]["x"] := smooth["x"]
                this.LastPositions[hwnd]["y"] := smooth["y"]
                win["x"] := smooth["x"]
                win["y"] := smooth["y"]
                win["centerX"] := smooth["x"] + win["width"]/2
                win["centerY"] := smooth["y"] + win["height"]/2
            }
        }
    }
    
    static Cleanup(hwnd) {
        this.SmoothPositions.Delete(hwnd)
        this.LastPositions.Delete(hwnd)
    }
}

; ===== VISUAL FEEDBACK MODULE =====
class VisualFeedback {
    static ManualBorders := Map()
    
    static ShowTooltip(text) {
        monitor := MonitorManager.Current
        ToolTip(text, monitor["CenterX"] - 120, monitor["Top"] + 30)
        SetTimer(() => ToolTip(), -FWDEConfig.Settings["TooltipDuration"])
    }
    
    static AddManualBorder(hwnd) {
        try {
            if (this.ManualBorders.Has(hwnd))
                return
                
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            borderGui := Gui("+ToolWindow -Caption +E0x20 +LastFound +AlwaysOnTop")
            borderGui.Opt("+Owner" hwnd)
            borderGui.BackColor := FWDEConfig.Settings["ManualWindowColor"]
            borderGui.Show("x" x-3 " y" y-3 " w" w+6 " h" h+6 " NA")
            
            this.ManualBorders[hwnd] := Map(
                "gui", borderGui,
                "expire", A_TickCount + FWDEConfig.Settings["ManualLockDuration"]
            )
        }
    }
    
    static RemoveManualBorder(hwnd) {
        try {
            if (this.ManualBorders.Has(hwnd)) {
                this.ManualBorders[hwnd]["gui"].Destroy()
                this.ManualBorders.Delete(hwnd)
            }
        }
    }
    
    static UpdateBorders() {
        for hwnd, data in this.ManualBorders.Clone() {
            try {
                if (A_TickCount > data["expire"]) {
                    this.RemoveManualBorder(hwnd)
                    continue
                }
                
                if (WinExist("ahk_id " hwnd)) {
                    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
                    data["gui"].Show("x" x-3 " y" y-3 " w" w+6 " h" h+6 " NA")
                } else {
                    this.RemoveManualBorder(hwnd)
                }
            }
        }
    }
    
    static Cleanup() {
        for hwnd in this.ManualBorders.Clone()
            this.RemoveManualBorder(hwnd)
    }
}

; ===== MAIN WINDOW MANAGER =====
class WindowManager {
    static State := Map(
        "ArrangementActive", true,
        "PhysicsEnabled", true,
        "ActiveWindow", 0,
        "LastUserMove", 0,
        "Windows", [],
        "LastFocusCheck", 0
    )
    
    static Initialize() {
        MonitorManager.Update()
        this.UpdateWindowList()
        this.StartTimers()
        VisualFeedback.ShowTooltip("FWDE Initialized - Floating Windows Active")
    }
    
    static StartTimers() {
        SetTimer(() => this.PhysicsUpdate(), FWDEConfig.Settings["PhysicsInterval"])
        SetTimer(() => this.VisualUpdate(), FWDEConfig.Settings["VisualInterval"])
        SetTimer(() => this.StateUpdate(), FWDEConfig.Settings["StateUpdateInterval"])
    }
    
    static StopTimers() {
        SetTimer(() => this.PhysicsUpdate(), 0)
        SetTimer(() => this.VisualUpdate(), 0)
        SetTimer(() => this.StateUpdate(), 0)
    }
    
    static PhysicsUpdate() {
        if (!this.State["PhysicsEnabled"])
            return
            
        for win in this.State["Windows"] {
            PhysicsEngine.CalculateForces(win, this.State["Windows"], 
                this.State["ActiveWindow"], this.State["LastUserMove"])
        }
    }
    
    static VisualUpdate() {
        if (!this.State["ArrangementActive"])
            return
            
        MovementEngine.ApplyMovements(this.State["Windows"])
        VisualFeedback.UpdateBorders()
    }
    
    static StateUpdate() {
        this.UpdateActiveWindow()
        this.UpdateWindowList()
    }
    
    static UpdateActiveWindow() {
        if (A_TickCount - this.State["LastFocusCheck"] > 300) {
            try {
                focusedWindow := WinExist("A")
                if (focusedWindow && focusedWindow != this.State["ActiveWindow"]) {
                    for win in this.State["Windows"] {
                        if (win["hwnd"] == focusedWindow) {
                            this.State["ActiveWindow"] := focusedWindow
                            this.State["LastUserMove"] := A_TickCount
                            break
                        }
                    }
                }
                
                ; Clear active if timeout
                if (this.State["ActiveWindow"] && 
                    A_TickCount - this.State["LastUserMove"] > FWDEConfig.Settings["UserMoveTimeout"] && 
                    focusedWindow != this.State["ActiveWindow"]) {
                    this.State["ActiveWindow"] := 0
                }
            }
            this.State["LastFocusCheck"] := A_TickCount
        }
    }
    
    static UpdateWindowList() {
        newWindows := []
        existingMap := Map()
        
        ; Create lookup for existing windows
        for win in this.State["Windows"] {
            existingMap[win["hwnd"]] := win
        }
        
        ; Scan all windows
        for hwnd in WinGetList() {
            if (!WindowClassifier.IsFloating(hwnd))
                continue
                
            try {
                WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
                if (w <= 0 || h <= 0)
                    continue
                    
                ; Check if on current monitor
                winCenterX := x + w/2
                winCenterY := y + h/2
                winMonitor := MonitorManager.GetFromPoint(winCenterX, winCenterY)
                if (!winMonitor)
                    winMonitor := MonitorManager.Current["Number"]
                    
                if (winMonitor == MonitorManager.Current["Number"]) {
                    existing := existingMap.Has(hwnd) ? existingMap[hwnd] : 0
                    newWindows.Push(WindowData.Create(hwnd, x, y, w, h, existing))
                }
            }
        }
        
        ; Clean up removed windows
        for win in this.State["Windows"] {
            found := false
            for newWin in newWindows {
                if (newWin["hwnd"] == win["hwnd"]) {
                    found := true
                    break
                }
            }
            if (!found) {
                MovementEngine.Cleanup(win["hwnd"])
                VisualFeedback.RemoveManualBorder(win["hwnd"])
            }
        }
        
        this.State["Windows"] := newWindows
    }
    
    ; ===== CONTROL METHODS =====
    static ToggleArrangement() {
        this.State["ArrangementActive"] := !this.State["ArrangementActive"]
        if (this.State["ArrangementActive"]) {
            this.StartTimers()
            VisualFeedback.ShowTooltip("Window Arrangement: ON")
        } else {
            this.StopTimers()
            VisualFeedback.ShowTooltip("Window Arrangement: OFF")
        }
    }
    
    static TogglePhysics() {
        this.State["PhysicsEnabled"] := !this.State["PhysicsEnabled"]
        status := this.State["PhysicsEnabled"] ? "ON" : "OFF"
        VisualFeedback.ShowTooltip("Physics Engine: " status)
    }
    
    static ToggleWindowLock() {
        try {
            focusedWindow := WinExist("A")
            if (!focusedWindow) {
                VisualFeedback.ShowTooltip("No active window to lock/unlock")
                return
            }
            
            ; Find target window
            targetWin := 0
            for win in this.State["Windows"] {
                if (win["hwnd"] == focusedWindow) {
                    targetWin := win
                    break
                }
            }
            
            if (!targetWin) {
                VisualFeedback.ShowTooltip("Window not managed by FWDE")
                return
            }
            
            ; Toggle lock
            isLocked := PhysicsEngine.IsLocked(targetWin)
            if (isLocked) {
                if (targetWin.Has("ManualLock"))
                    targetWin.Delete("ManualLock")
                this.State["ActiveWindow"] := 0
                VisualFeedback.RemoveManualBorder(focusedWindow)
                VisualFeedback.ShowTooltip("Window UNLOCKED - Physics Active")
            } else {
                targetWin["ManualLock"] := A_TickCount + FWDEConfig.Settings["ManualLockDuration"]
                this.State["ActiveWindow"] := focusedWindow
                this.State["LastUserMove"] := A_TickCount
                PhysicsEngine.StopMovement(targetWin)
                VisualFeedback.AddManualBorder(focusedWindow)
                VisualFeedback.ShowTooltip("Window LOCKED - Position Fixed")
            }
        }
    }
    
    static Shutdown() {
        this.StopTimers()
        VisualFeedback.Cleanup()
    }
}

; ===== HOTKEYS & INITIALIZATION =====
^!Space::WindowManager.ToggleArrangement()    ; Ctrl+Alt+Space
^!P::WindowManager.TogglePhysics()            ; Ctrl+Alt+P  
^!L::WindowManager.ToggleWindowLock()         ; Ctrl+Alt+L

; Initialize system
WindowManager.Initialize()

; Cleanup on exit
OnExit((*) => WindowManager.Shutdown())