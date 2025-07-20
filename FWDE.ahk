#Requires AutoHotkey v2.0
#SingleInstance Force
#WinActivateForce
#Warn
#MaxThreadsPerHotkey 22
A_IconTip := "Floating Windows - Dynamic Equilibrium"
#DllLoad "gdi32.dll"
#DllLoad "user32.dll"
#DllLoad "dwmapi.dll" ; Desktop Composition API
; This script is the brainchild of:
; Human: Flalaski, 
; AI: DeepSeek+Gemini+CoPilot, 
; Lots of back & forth, toss around, backups & redo's, 
; until finally I (the human) got this to do what I've been trying to find as a software. 
; Hope it's helpful! ♥
class NoiseAnimator {
    static permutations := [151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,190,6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,88,237,149,56,87,174,20,125,136,171,168,68,175,74,165,71,134,139,48,27,166,77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,102,143,54,65,25,63,161,1,216,80,73,209,76,132,187,208,89,18,169,200,196,135,130,116,188,159,86,164,100,109,198,173,186,3,64,52,217,226,250,124,123,5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,223,183,170,213,119,248,152,2,44,154,163,70,221,153,101,155,167,43,172,9,129,22,39,253,19,98,108,110,79,113,224,232,178,185,112,104,218,246,97,228,251,34,242,193,238,210,144,12,191,179,162,241,81,51,145,235,249,14,239,107,49,192,214,31,181,199,106,157,184,84,204,176,115,121,50,45,127,4,150,254,138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180]
    
    static grad3 := [[1,1,0],[-1,1,0],[1,-1,0],[-1,-1,0],[1,0,1],[-1,0,1],[1,0,-1],[-1,0,-1],[0,1,1],[0,-1,1],[0,1,-1],[0,-1,-1]]
    
    static F2 := 0.5*(Sqrt(3)-1)
    static G2 := (3-Sqrt(3))/6
    
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

SafeWinExist(hwnd) {
    try {
        return WinExist("ahk_id " hwnd)
    }
    catch {
        return 0
    }
}

IsWindowValid(hwnd) {
    try {
        if (!SafeWinExist(hwnd))
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

FindNonOverlappingPosition(window, otherWindows, monitor) {
    if (!IsOverlapping(window, otherWindows))
        return Map("x", window["x"], "y", window["y"])
    
    centerX := monitor["CenterX"] - window["width"]/2
    centerY := monitor["CenterY"] - window["height"]/2
    steps := 10
    stepSize := 50
    
    Loop steps {
        radius := A_Index * stepSize
        angles := 8 * A_Index
        
        Loop angles {
            angle := (A_Index - 1) * (2 * 3.14159 / angles)
            tryX := centerX + radius * Cos(angle)
            tryY := centerY + radius * Sin(angle)
            
            tryX := Max(monitor["Left"] + Config["MinMargin"], Min(tryX, monitor["Right"] - window["width"] - Config["MinMargin"]))
            tryY := Max(monitor["Top"] + Config["MinMargin"], Min(tryY, monitor["Bottom"] - window["height"] - Config["MinMargin"]))
            
            testPos := Map(
                "x", tryX,
                "y", tryY,
                "width", window["width"],
                "height", window["height"],
                "hwnd", window["hwnd"]
            )
            
            if (!IsOverlapping(testPos, otherWindows))
                return Map("x", tryX, "y", tryY)
        }
    }
    
    return Map("x", window["x"] + 20, "y", window["y"] + 20)
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

IsWindowFloating(hwnd) {
    global Config
    try {
        style := WinGetStyle("ahk_id " hwnd)
        return (style & Config["FloatStyles"]) == Config["FloatStyles"]
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
            if (!IsWindowValid(hwnd) || !IsWindowFloating(hwnd))
                continue
                
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            if (w == 0 || h == 0)
                continue
                
            allWindows.Push(Map(
                "hwnd", hwnd,
                "x", x, "y", y,
                "width", w, "height", h
            ))
        }
        catch {
            continue
        }
    }
    
    for window in allWindows {
        winCenterX := window["x"] + window["width"]/2
        winCenterY := window["y"] + window["height"]/2
        
        winMonitor := 0
        try {
            winMonitor := MonitorGetFromPoint(winCenterX, winCenterY)
            MonitorGet winMonitor, &mL, &mT, &mR, &mB
        }
        catch {
            continue
        }
        
        isTracked := false
        for trackedWin in g["Windows"] {
            if (trackedWin["hwnd"] == window["hwnd"]) {
                isTracked := true
                break
            }
        }
        
        if (winMonitor == monitor["Number"] || isTracked) {
            window["x"] := Max(mL + Config["MinMargin"], Min(window["x"], mR - window["width"] - Config["MinMargin"]))
            window["y"] := Max(mT + Config["MinMargin"], Min(window["y"], mB - window["height"] - Config["MinMargin"]))
            
            existingWin := 0
            for win in g["Windows"] {
                if (win["hwnd"] == window["hwnd"]) {
                    existingWin := win
                    break
                }
            }
            
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
                "monitor", winMonitor
            ))
        }
    }
    return WinList
}

class FairyDust {
    static particles := Map()
    static lastCleanup := 0
    static edgeWidth := 100

    static AddTrail(hwnd) {
        if (!SafeWinExist(hwnd))
            return

        if (!this.particles.Has(hwnd)) {
            try {
                dustGui := Gui("+ToolWindow -Caption +E0x20 +AlwaysOnTop +LastFound +Disabled")
                dustGui.BackColor := "000000"
                WinSetTransparent(0)
                dustGui.Show("NA")

                try {
                    DllCall("dwmapi\DwmEnableBlurBehindWindow", "Ptr", dustGui.Hwnd, "Ptr", CreateBlurBehindStruct())
                }
                catch {
                }

                this.particles[hwnd] := {
                    points: [],
                    lastUpdate: 0,
                    gui: dustGui,
                    hwnd: dustGui.Hwnd,
                    noiseSeed: Random(1, 10000),
                    lastW: 0,
                    lastH: 0
                }
            }
            catch {
                return
            }
        }

        if (A_TickCount - this.particles[hwnd].lastUpdate < 1000)
            return
            
        try {
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            this.particles[hwnd].lastUpdate := A_TickCount
            
            points := []
            edgeSize := this.edgeWidth
            
            Loop Random(2, 5) {
                px := Random(0, w)
                if (px > edgeSize && px < w - edgeSize)
                    continue
                
                points.Push({
                    x: px,
                    y: Random(0, edgeSize),
                    life: Random(30, 60),
                    size: Random(1, 2),
                    color: Format("0x{:08X}", 0x30FFFFFF)
                })
            }
            
            Loop Random(2, 5) {
                px := Random(0, w)
                if (px > edgeSize && px < w - edgeSize)
                    continue
                
                points.Push({
                    x: px,
                    y: h - Random(0, edgeSize),
                    life: Random(30, 60),
                    size: Random(1, 2),
                    color: Format("0x{:08X}", 0x30FFFFFF)
                })
            }
            
            Loop Random(2, 5) {
                py := Random(0, h)
                if (py > edgeSize && py < h - edgeSize)
                    continue
                
                points.Push({
                    x: Random(0, edgeSize),
                    y: py,
                    life: Random(30, 60),
                    size: Random(1, 2),
                    color: Format("0x{:08X}", 0x30FFFFFF)
                })
            }
            
            Loop Random(2, 5) {
                py := Random(0, h)
                if (py > edgeSize && py < h - edgeSize)
                    continue
                
                points.Push({
                    x: w - Random(0, edgeSize),
                    y: py,
                    life: Random(30, 60),
                    size: Random(1, 2),
                    color: Format("0x{:08X}", 0x30FFFFFF)
                })
            }
            
            time := A_TickCount/2000
            for i, point in points {
                noiseX := NoiseAnimator.noise(point.x/50, time + i*10)
                noiseY := NoiseAnimator.noise(point.y/50, time + i*10 + 100)
                point.x += noiseX * 2 * Config["NoiseInfluence"]
                point.y += noiseY * 2 * Config["NoiseInfluence"]
            }
            
            this.particles[hwnd].points := points
        }
        catch {
            return
        }
        
        if (A_TickCount - this.lastCleanup > 1000) {
            this.CleanupEffects()
            this.lastCleanup := A_TickCount
        }
    }
    
    static UpdateTrails() {
        for hwnd, data in this.particles.Clone() {
            try {
                if (!SafeWinExist(hwnd)) {
                    this.particles.Delete(hwnd)
                    try data.gui.Destroy()
                    continue
                }

                WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
                data.gui.Show("x" x " y" y " w" w " h" h " NA")

                try {
                    hdc := DllCall("GetDC", "Ptr", data.hwnd)
                    DllCall("gdi32\PatBlt", "Ptr", hdc,
                        "Int", 0, "Int", 0,
                        "Int", Max(w, data.lastW), "Int", Max(h, data.lastH),
                        "UInt", 0x00000042)
                    
                    for i, particle in data.points {
                        particle.life--
                        if (particle.life > 0) {
                            px := Floor(particle.x)
                            py := Floor(particle.y)
                            alpha := Round(0xFF * (particle.life/60))
                            color := 0xFFFFFF | (alpha << 24)
                            
                            brush := DllCall("gdi32\CreateSolidBrush", "UInt", color, "Ptr")
                            oldBrush := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", brush, "Ptr")
                            DllCall("gdi32\Ellipse", "Ptr", hdc, 
                                "Int", px-particle.size, "Int", py-particle.size, 
                                "Int", px+particle.size, "Int", py+particle.size)
                            DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", oldBrush, "Ptr")
                            DllCall("gdi32\DeleteObject", "Ptr", brush)
                        }
                    }
                    
                    DllCall("ReleaseDC", "Ptr", data.hwnd, "Ptr", hdc)
                }

                data.lastW := w
                data.lastH := h
            }
            catch {
                this.particles.Delete(hwnd)
                try data.gui.Destroy()
                continue
            }
        }
    }
    
    static CleanupEffects() {
        for hwnd, data in this.particles.Clone() {
            if (!this.particles.Has(hwnd))
                continue
                
            try {
                if (!SafeWinExist(hwnd) || data.points.Length == 0) {
                    try data.gui.Destroy()
                    this.particles.Delete(hwnd)
                }
            }
            catch {
                this.particles.Delete(hwnd)
                try data.gui.Destroy()
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

CalculateWindowForces(win) {
    global g, Config
    
    if (win["hwnd"] == g["ActiveWindow"] || (win.Has("ManualLock") && A_TickCount < win["ManualLock"])) {
        win["vx"] := 0
        win["vy"] := 0
        return
    }

    try {
        MonitorGet win["monitor"], &mL, &mT, &mR, &mB
    }
    catch {
        mL := 0
        mT := 0
        mR := A_ScreenWidth
        mB := A_ScreenHeight
    }
    
    monLeft := mL + Config["MinMargin"]
    monRight := mR - Config["MinMargin"] - win["width"]
    monTop := mT + Config["MinMargin"]
    monBottom := mB - Config["MinMargin"] - win["height"]

    prev_vx := win.Has("vx") ? win["vx"] : 0
    prev_vy := win.Has("vy") ? win["vy"] : 0
    
    wx := win["x"] + win["width"]/2
    wy := win["y"] + win["height"]/2
    dx := (mL + mR)/2 - wx
    dy := (mT + mB)/2 - wy
    dist := Sqrt(dx*dx + dy*dy)
    
    if (dist > 50) {
        attractionScale := Min(1, dist/300)
        vx := prev_vx * Config["Smoothing"] + dx * Config["AttractionForce"] * win["mass"] / dist * (1 - Config["Smoothing"]) * attractionScale
        vy := prev_vy * Config["Smoothing"] + dy * Config["AttractionForce"] * win["mass"] / dist * (1 - Config["Smoothing"]) * attractionScale
    } else {
        vx := prev_vx * Config["Smoothing"]
        vy := prev_vy * Config["Smoothing"]
    }
    
    if (win["x"] < monLeft + 50) {
        push := (monLeft + 50 - win["x"]) * 0.1
        vx += push
    }
    
    if (win["x"] > monRight - 50) {
        push := (win["x"] - (monRight - 50)) * 0.1
        vx -= push
    }
    
    if (win["y"] < monTop + 50) {
        push := (monTop + 50 - win["y"]) * 0.1
        vy += push
    }
    
    if (win["y"] > monBottom - 50) {
        push := (win["y"] - (monBottom - 50)) * 0.1
        vy -= push
    }
    
    for other in g["Windows"] {
        if (other == win || other["hwnd"] == g["ActiveWindow"])
            continue
            
        overlapX := Max(0, Min(win["x"] + win["width"], other["x"] + other["width"]) - Max(win["x"], other["x"]))
        overlapY := Max(0, Min(win["y"] + win["height"], other["y"] + other["height"]) - Max(win["y"], other["y"]))
        
        if (overlapX > 5 && overlapY > 5) {
            force := Config["RepulsionForce"] * (other.Has("IsManual") ? Config["ManualRepulsionMultiplier"] : 1)
            force *= (overlapX * overlapY) / 5000
            dx := wx - (other["x"] + other["width"]/2)
            dy := wy - (other["y"] + other["height"]/2)
            dist := Max(Sqrt(dx*dx + dy*dy), 1)
            vx += dx * force / dist * 0.2
            vy += dy * force / dist * 0.2
        }
    }
    
    win["vx"] := vx
    win["vy"] := vy
    
    ; Apply the new stabilization logic
    ApplyStabilization(win)
    
    win["targetX"] := win["x"] + win["vx"]
    win["targetY"] := win["y"] + win["vy"]
    
    win["targetX"] := Max(monLeft, Min(win["targetX"], monRight))
    win["targetY"] := Max(monTop, Min(win["targetY"], monBottom))
    ; === Velocity Clamp ===
win["vx"] := Min(Max(win["vx"], -0.5), 0.5)  ; Hard speed limit
win["vy"] := Min(Max(win["vy"], -0.5), 0.5)

; === Instant Freeze ===
if (Abs(win["vx"]) < 0.2 && Abs(win["vy"]) < 0.2) {
    win["vx"] := 0
    win["vy"] := 0
}
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

; ====== COMPLETE PHYSICS STABILIZATION MODULE ======
ApplyWindowMovements() {
    global g, Config
    static lastUpdate := 0
    static positionHistory := Map()

    ; Initialize frame timing
    now := A_TickCount
    frameTime := now - lastUpdate
    lastUpdate := now

    for win in g["Windows"] {
        if (win["hwnd"] == g["ActiveWindow"])
            continue

        ; Safely get monitor bounds
        try {
            MonitorGet win["monitor"], &mL, &mT, &mR, &mB
            monLeft := mL + Config["MinMargin"]
            monRight := mR - Config["MinMargin"] - win["width"]
            monTop := mT + Config["MinMargin"]
            monBottom := mB - Config["MinMargin"] - win["height"]
        } catch {
            monLeft := Config["MinMargin"]
            monRight := A_ScreenWidth - Config["MinMargin"] - win["width"]
            monTop := Config["MinMargin"]
            monBottom := A_ScreenHeight - Config["MinMargin"] - win["height"]
        }

        ; Initialize position history
        if !positionHistory.Has(win["hwnd"]) {
            positionHistory[win["hwnd"]] := []
            Loop 3
                positionHistory[win["hwnd"]].Push({x: win["x"], y: win["y"]})
        }

        ; Calculate target position (with error checking)
        newX := win.Has("targetX") ? win["targetX"] : win["x"]
        newY := win.Has("targetY") ? win["targetY"] : win["y"]

        ; Apply aggressive stabilization
        newX := Round(newX)  ; Quantize to whole pixels
        newY := Round(newY)

        ; Enforce minimum movement threshold
        if (Abs(newX - win["x"]) < 1.5 && Abs(newY - win["y"]) < 1.5) {
            newX := win["x"]  ; Freeze micro-movements
            newY := win["y"]
        }

        ; Clamp to monitor bounds
        newX := Max(monLeft, Min(newX, monRight))
        newY := Max(monTop, Min(newY, monBottom))

        ; Update position history
        positionHistory[win["hwnd"]].RemoveAt(1)
        positionHistory[win["hwnd"]].Push({x: newX, y: newY})

        ; Only move if significant change
        if (Abs(newX - win["x"]) >= 1 || Abs(newY - win["y"]) >= 1) {
            try {
                MoveWindowAPI(win["hwnd"], newX, newY)
                win["x"] := newX
                win["y"] := newY
            }
        }
    }

    if (g["FairyDustEnabled"])
        FairyDust.UpdateTrails()
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
    static transitionTime := 300  ; Default transition time

    ; Dynamic force adjustment
    currentEnergy := 0
    for win in g["Windows"] {
        CalculateWindowForces(win)
        currentEnergy += win["vx"]**2 + win["vy"]**2
    }
    g["SystemEnergy"] := Lerp(g["SystemEnergy"], currentEnergy, 0.1)

    ; State machine for force adjustment
    newState := (g["SystemEnergy"] > Config["Stabilization"]["EnergyThreshold"]) ? "chaos" : "normal"
    
    if (newState != lastState) {
        transitionTime := (newState == "chaos") ? 300 : 500  ; Faster entry to chaos, slower recovery
        g["ForceTransition"] := A_TickCount + transitionTime
    }

    ; Smooth force transition
    if (A_TickCount < g["ForceTransition"]) {
        t := (g["ForceTransition"] - A_TickCount) / transitionTime
        currentMultiplier := Lerp(forceMultipliers[newState], forceMultipliers[lastState], t)
    } else {
        currentMultiplier := forceMultipliers[newState]
    }

    ; Apply adjusted forces
    for win in g["Windows"] {
        win["vx"] *= currentMultiplier
        win["vy"] *= currentMultiplier
        win["vx"] := Min(Max(win["vx"], -Config["MaxSpeed"]), Config["MaxSpeed"])
        win["vy"] := Min(Max(win["vy"], -Config["MaxSpeed"]), Config["MaxSpeed"])
    }

    ; Collision resolution
    if (g["Windows"].Length > 1) {
        g["Windows"] := ResolveCollisions(g["Windows"])
    }

    lastState := newState
}


AddManualWindowBorder(hwnd) {
    global Config
    try {
        Gui("ManualBorder_" hwnd, "+ToolWindow -Caption +E0x20 +LastFound +AlwaysOnTop")
        Gui.BackColor := Config["ManualWindowColor"]
        WinSetTransColor(Config["ManualWindowColor"] " " Config["ManualWindowAlpha"])
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        Gui.Show("x" x-2 " y" y-2 " w" w+4 " h" h+4 " NA")
        try {
            DllCall("dwmapi\DwmEnableBlurBehindWindow", "Ptr", Gui.Hwnd, "Ptr", CreateBlurBehindStruct())
        }
        catch {
        }
        g["ManualWindows"][hwnd] := A_TickCount + Config["ManualLockDuration"]
    }
}

RemoveManualWindowBorder(hwnd) {
    try {
        Gui("ManualBorder_" hwnd).Destroy()
        g["ManualWindows"].Delete(hwnd)
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

ToggleFairyDust() {
    global g
    g["FairyDustEnabled"] := !g["FairyDustEnabled"]
    if (!g["FairyDustEnabled"]) {
        FairyDust.CleanupEffects()
        SetTimer(FairyDust.UpdateTrails.Bind(FairyDust), 0)
    } else {
        SetTimer(FairyDust.UpdateTrails.Bind(FairyDust), Config["VisualTimeStep"])
    }
    ShowTooltip("Fairy Dust Effects: " (g["FairyDustEnabled"] ? "ON" : "OFF"))
}

OptimizeWindowPositions() {
    global g
    UpdateWindowStates()
    CalculateDynamicLayout()
    ShowTooltip("Optimized window positions")
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
                win["ManualLock"] := A_TickCount + Config["ManualLockDuration"]
                win["IsManual"] := true
                win["vx"] := 0
                win["vy"] := 0
                win["monitor"] := monNum
                AddManualWindowBorder(hwnd)
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
                win["ManualLock"] := A_TickCount + Config["ManualLockDuration"]
                win["IsManual"] := true
                win["vx"] := 0
                win["vy"] := 0
                win["monitor"] := monNum
                AddManualWindowBorder(hwnd)
                break
            }
        }
    }
    catch {
        return
    }
    
    SetTimer(UpdateWindowStates, -Config["ResizeDelay"])
}

GetTaskbarRect() {
    hwnd := WinExist("ahk_class Shell_TrayWnd")
    if (hwnd) {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        return { left: x, top: y, right: x + w, bottom: y + h }
    }
    hwnd := WinExist("ahk_class RetroBarWnd")
    if (!hwnd)
        hwnd := WinExist("ahk_exe RetroBar.exe")
    if (hwnd) {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        return { left: x, top: y, right: x + w, bottom: y + h }
    }
    return { left: 0, top: A_ScreenHeight - 44, right: A_ScreenWidth, bottom: A_ScreenHeight }
}


UpdateWindowStates() {
    global g, Config
    try {
        currentMonitor := GetCurrentMonitorInfo()
        g["Monitor"] := currentMonitor
        g["Windows"] := GetVisibleWindows(currentMonitor)
        ClearManualFlags()
        if (g["ArrangementActive"] && g["PhysicsEnabled"])
            CalculateDynamicLayout()
    }
    catch {
        g := Map(
            "Monitor", GetCurrentMonitorInfo(),
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

global Config := Map(
    "MinMargin", 23,
    "MinGap", 0,
    "ManualGapBonus", 369,
    "AttractionForce", .32,
    "RepulsionForce", .28,
    "ManualRepulsionMultiplier", 1.3,
    "EdgeRepulsionForce", 1.80,
    "UserMoveTimeout", 11111,
    "ManualLockDuration", 11,
    "ResizeDelay", 111,
    "TooltipDuration", 15000,
    "FloatStyles", 0x40000|0x20000|0x800000,
    "Damping", 0.92,    ; Lower = less friction (0.001-0.01)
    "MaxSpeed", 1.5,    ; Limits maximum velocity
    "PhysicsTimeStep", 20,  ; Lower = more frequent physics updates (1ms is max)
    "VisualTimeStep", 16,   ; Lower = smoother visuals (try 16-33ms for 60-30fps)
    "Smoothing", 0.99,  ; Higher = smoother but more lag (0.9-0.99)
    "Stabilization", Map(
        "MinSpeedThreshold", 0.4,  ; Lower values high-DPI (0.05-0.15) ~ Higher values (0.2-0.5)  low-performance systems
        "EnergyThreshold", 0.03,     ; Lower values (0.05-0.1): Early stabilization, prevents overshooting
        "DampingBoost", 0.18,       ; 0.01-0.05: Subtle braking (smooth stops) ~ 0.1+: Strong braking (quick stops but may feel robotic)
        "OverlapTolerance", 4      ; Small values (5-10): Strict spacing (prevents all overlap) ~ Large (30+): Loose grouping (windows can temporarily overlap)
    ),
    "ManualWindowColor", "FF5555",
    "ManualWindowAlpha", 222,
    "NoiseScale", 8,
    "NoiseInfluence", 100,
    "AnimationDuration", 32,    ; Higher = longer animations (try 16-32)
    "PhysicsUpdateInterval", 200,
)

global g := Map(
    "Monitor", GetCurrentMonitorInfo(),
    "ArrangementActive", true,
    "LastUserMove", 0,
    "ActiveWindow", 0,
    "Windows", [],
    "PhysicsEnabled", true,
    "FairyDustEnabled", true,
    "ManualWindows", Map(),
    "SystemEnergy", 1
)
;HOTKEYS

^!Space::ToggleArrangement()      ; Ctrl+Alt+Space to toggle
^!LButton::DragWindow()           ; Ctrl+Alt+LeftMouse to drag
^!P::TogglePhysics()              ; Ctrl+Alt+P for physics
^!F::ToggleFairyDust()            ; Ctrl+Alt+F for effects
^!O::OptimizeWindowPositions()    ; Ctrl+Alt+O to optimize

SetTimer(UpdateWindowStates, Config["PhysicsTimeStep"])
SetTimer(ApplyWindowMovements, Config["VisualTimeStep"])
SetTimer(FairyDust.UpdateTrails.Bind(FairyDust), Config["VisualTimeStep"])
UpdateWindowStates()

OnMessage(0x0003, WindowMoveHandler)
OnMessage(0x0005, WindowSizeHandler)

OnExit(*) {
    for hwnd in g["ManualWindows"]
        RemoveManualWindowBorder(hwnd)
    FairyDust.CleanupEffects()
    DllCall("winmm\timeEndPeriod", "UInt", 1)
}

; ====== REQUIRED HELPER FUNCTIONS ======
MoveWindowAPI(hwnd, x, y, w := "", h := "") {
    if (w == "" || h == "")
        WinGetPos(,, &w, &h, "ahk_id " hwnd)
    return DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", 0x0014)
}






; This script is the brainchild of:
; Human: Flalaski, 
; AI: DeepSeek+Gemini+CoPilot, 
; Lots of back & forth, toss around, backups & redo's, 
; until finally I (the human) got this to do what I've been trying to find as a software. 
; Hope it's helpful! ♥