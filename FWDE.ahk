#Requires AutoHotkey v2.0
#SingleInstance Force
#WinActivateForce
#Warn
#MaxThreadsPerHotkey 255
#MaxThreads 255
A_IconTip := "Floating Windows - Dynamic Equilibrium"
ProcessSetPriority("High")


#DllLoad "gdi32.dll"
#DllLoad "user32.dll"
#DllLoad "dwmapi.dll" ; Desktop Composition API



; Pre-allocate memory buffers
global g_NoiseBuffer := Buffer(1024)
global g_PhysicsBuffer := Buffer(4096)

/*
    FWDE.ahk - Floating Windows Dynamic Equilibrium

    Purpose:
    -----------
    This script provides a dynamic, physics-based window arrangement system for Windows OS,
    primarily targeting creative and DAW (Digital Audio Workstation) workflows, but adaptable to any use case.
    It enables windows (especially plugin windows) to "float" and arrange themselves naturally,
    avoiding overlaps and clustering, with smooth, animated movement and multi-monitor support.

    Key Features:
    -------------
    - Physics-based window movement and arrangement, with configurable attraction, repulsion, and damping.
    - Seamless multi-monitor floating: windows can move freely across all monitors (toggle with Ctrl+Alt+M).
    - Special handling for DAW/plugin windows, including detection by class, title, and process.
    - Manual window locking/unlocking (Ctrl+Alt+L) with visible border overlays.
    - Space optimization: auto-pack windows to maximize usable screen area (Ctrl+Alt+O).
    - Visual effects: "Fairy Dust" time-phasing echoes for plugin windows.
    - Real-time response to user window moves/resizes, with intelligent re-integration into the floating system.
    - Z-order management to keep small plugin windows visible above larger ones.
    - Highly configurable via the `Config` map at the top of the script.

    Structure:
    ----------
    - Global configuration and state maps.
    - Utility functions for window/monitor management, physics, and arrangement.
    - Classes for noise animation and time-phasing effects.
    - Main logic for window detection, force calculation, and movement application.
    - Manual window handling (locking, borders, etc).
    - Hotkeys for toggling features and optimizing layout.
    - Event/message handlers for window move/resize.
    - Helper functions for packing, scoring, and collision resolution.

    Usage:
    ------
    - Run the script with AutoHotkey v2.
    - Use the provided hotkeys to toggle features and optimize your workspace.
    - The script will automatically manage floating windows, keeping them organized and visible.

    Author(s):
    ----------
    - Human: Flalaski
    - AI: DeepSeek, Gemini, GitHub Copilot
    - Iterative collaboration and refinement for a robust, creative window management tool.
*/


; NEW FEATURE: Seamless Multi-Monitor Floating
; Toggle with Ctrl+Alt+M to allow windows to float freely across all monitors
; When enabled, windows are no longer confined to the current monitor boundaries

global Config := Map(
    "MinMargin", 42,
    "MinGap", 21,
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

global g := Map(
    "Monitor", Config["SeamlessMonitorFloat"] ? GetVirtualDesktopBounds() : GetCurrentMonitorInfo(),
    "ArrangementActive", true,
    "LastUserMove", 0,
    "ActiveWindow", 0,
    "Windows", [],
    "PhysicsEnabled", true,
    "FairyDustEnabled", true,
    "ManualWindows", Map(),
    "SystemEnergy", 1
)

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

        ; Extended DAW/plugin detection
        pluginClasses := [
            "VST", "VSTPlugin", "AudioUnit", "AU", "RTAS", "AAX",
            "ReaperVSTPlugin", "FL_Plugin", "StudioOnePlugin",
            "CubaseVST", "LogicAU", "ProToolsAAX", "Ableton",
            "Bitwig", "Reason", "Cakewalk", "Mixcraft", "Tracktion", "Waveform",
            "Qt5QWindowIcon", "Qt6QWindowIcon",
            "Vst", "JS", "Plugin", "Float", "Dock"
        ]

        pluginTitlePatterns := [
            "VST", "AU", "JS:", "Plugin", "Synth", "Effect", "EQ", "Compressor",
            "Reverb", "Delay", "Filter", "Oscillator", "Sampler", "Drum", "FX",
            "Kontakt", "Massive", "Serum", "Sylenth", "Omnisphere", "Nexus",
            "FabFilter", "Waves", "iZotope", "Native Instruments", "Arturia",
            "U-He", "TAL-", "Valhalla", "SoundToys", "Plugin Alliance",
            "Bitwig", "Reason", "Cakewalk", "Mixcraft", "Tracktion", "Waveform"
        ]

        dawProcesses := [
            "reaper", "ableton", "flstudio", "cubase", "studioone", "bitwig", "protools",
            "reason", "cakewalk", "mixcraft", "tracktion", "waveform"
        ]
        isDAWProcess := false
        for daw in dawProcesses {
            if (InStr(processName, daw)) {
                isDAWProcess := true
                break
            }
        }

        if (isDAWProcess) {
            for pattern in pluginClasses {
                if (InStr(winClass, pattern))
                    return true
            }
            for pattern in pluginTitlePatterns {
                if (InStr(title, pattern))
                    return true
            }
            try {
                WinGetPos(,, &w, &h, "ahk_id " hwnd)
                if (w < 800 && h < 600)
                    return true
            }
        } else {
            if (winClass ~= "i)(Vst|JS|Plugin|Float|Dock|Bitwig|Reason|Cakewalk|Mixcraft|Tracktion|Waveform)")
                return true
            if (title ~= "i)(VST|JS:|Plugin|FX|Bitwig|Reason|Cakewalk|Mixcraft|Tracktion|Waveform)")
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
        OutputDebug("Window Check - Class: " winClass " | Process: " processName " | Title: " title)

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

                ; Find existing window data if available
                existingWin := 0
                for win in g["Windows"] {
                    if (win["hwnd"] == window["hwnd"]) {
                        existingWin := win
                        break
                    }
                }

                ; Create window entry with physics properties
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
                    "monitor", winMonitor,
                    "isPlugin", window["isPlugin"],
                    "lastSeen", window["lastSeen"],
                    "lastZOrder", existingWin ? existingWin.Get("lastZOrder", -1) : -1  ; Cache z-order state
                ))

                ; Add time-phasing echo for plugin windows
                if (window["isPlugin"] && g["FairyDustEnabled"]) {
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
        if (isLocked)
            continue

        if (win["hwnd"] == g["ActiveWindow"])
            continue

        hwnd := win["hwnd"]
        newX := win.Has("targetX") ? win["targetX"] : win["x"]
        newY := win.Has("targetY") ? win["targetY"] : win["y"]

        if (!hwndPos.Has(hwnd))
            continue

        if (!smoothPos.Has(hwnd))
            smoothPos[hwnd] := { x: hwndPos[hwnd].x, y: hwndPos[hwnd].y }

        ; Assign monitor bounds for edge enforcement
        try {
            if (Config["SeamlessMonitorFloat"]) {
                virtualBounds := GetVirtualDesktopBounds()
                monLeft := virtualBounds["Left"]
                monTop := virtualBounds["Top"] + Config["MinMargin"]
                monRight := virtualBounds["Right"] - win["width"]
                monBottom := virtualBounds["Bottom"] - Config["MinMargin"] - win["height"]
            } else {
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

    ; Update active window detection periodically
    if (A_TickCount - lastFocusCheck > 250) {  ; Check every 250ms
        try {
            focusedWindow := WinExist("A")
            if (focusedWindow && focusedWindow != g["ActiveWindow"]) {
                ; Check if the focused window is one of our managed windows
                for win in g["Windows"] {
                    if (win["hwnd"] == focusedWindow) {
                        g["ActiveWindow"] := focusedWindow
                        g["LastUserMove"] := A_TickCount  ; Reset timeout when focus changes
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
    global Config

    ; More aggressive but gentle collision resolution for overlapping windows
    for i, win1 in windows {
        for j, win2 in windows {
            if (i >= j)
                continue

            ; Check for overlap with smaller tolerance for quicker separation
            overlapX := Max(0, Min(win1["x"] + win1["width"], win2["x"] + win2["width"]) - Max(win1["x"], win2["x"]))
            overlapY := Max(0, Min(win1["y"] + win1["height"], win2["y"] + win2["height"]) - Max(win1["y"], win2["y"]))

            if (overlapX > 2 && overlapY > 2) {  ; Reduced from 5 for quicker response
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

                ; Progressive force based on overlap severity
                separationForce := (overlapX + overlapY) * 0.02 * (1 + overlapRatio * 3)  ; Increased base force and scaling

                ; Small window bonus for faster separation
                if (win1["width"] < 300 || win1["height"] < 200 || win2["width"] < 300 || win2["height"] < 200) {
                    separationForce *= 1.5
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
        bmpW := w + 2*borderThickness
        bmpH := h + 2*borderThickness
        borderGui.AddPicture("x0 y0 w" bmpW " h" bmpH " BackgroundTrans", "*GDI+ " CreateBorderBitmap(bmpW, bmpH, borderThickness, borderColor, borderAlpha))

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

; --- GDI+ support warning and fallback for missing Gdip.ahk ---
; Place this at the top of your script, outside any function or class.
; AutoHotkey v2 does not support #If for conditional includes, so use a runtime check.
global GdipAvailable := false
if FileExist(A_ScriptDir "\Gdip.ahk") {
    try {
        #Include %A_ScriptDir%\Gdip.ahk
        GdipAvailable := true
    } catch {
        MsgBox "Failed to load Gdip.ahk. Border overlays will be disabled."
        GdipAvailable := false
    }
} else {
    MsgBox "Warning: Gdip.ahk not found in script directory. Border overlays will be disabled."
    GdipAvailable := false
}

; --- Refactored CreateBorderBitmap with fallback ---
CreateBorderBitmap(w, h, thickness, color, alpha) {
    global GdipAvailable
    if !GdipAvailable
        return "" ; No border if GDI+ is not available
    static gdipInit := false
    static pToken := 0
    if !gdipInit {
        pToken := Gdip_Startup()
        if !pToken
            return ""
        gdipInit := true
    }
    pBitmap := Gdip_CreateBitmap(w, h)
    G := Gdip_GraphicsFromImage(pBitmap)
    Gdip_SetSmoothingMode(G, 4)
    ARGB := "0x" Format("{:02X}", alpha) color
    pPen := Gdip_CreatePen(ARGB, thickness)
    Gdip_DrawRectangle(G, pPen, thickness//2, thickness//2, w-thickness, h-thickness)
    Gdip_DeletePen(pPen)
    Gdip_DeleteGraphics(G)
    hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap)
    Gdip_DisposeImage(pBitmap)
    return hBitmap
}

RemoveManualWindowBorder(hwnd) {
    global g
    try {
        if g["ManualWindows"].Has(hwnd) {
            g["ManualWindows"][hwnd]["gui"].Destroy()
            g["ManualWindows"].Delete(hwnd)
        }
    } catch as err {
        ; ignore
    }
}

MoveWindowAPI(hwnd, x, y, w := "", h := "") {
    if (w == "" || h == "")
        WinGetPos(,, &w, &h, "ahk_id " hwnd)
    return DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", 0x0014)
}

GeneratePositionCandidates(window, otherWindows, monitor, strategy) {
    ; Simple grid-based candidate generator for demonstration
    candidates := []
    step := 40
    left := monitor["Left"] + 10
    top := monitor["Top"] + 10
    right := monitor["Right"] - window["width"] - 10
    bottom := monitor["Bottom"] - window["height"] - 10
    for y, yval in Range(top, bottom, step) {
        for x, xval in Range(left, right, step) {
            candidates.Push(Map("x", xval, "y", yval))
        }
    }
    return candidates
}
; Helper for range iteration
Range(start, stop, step) {
    arr := []
    if step = 0
        return arr
    if step > 0 {
        val := start
        while val <= stop {
            arr.Push(val)
            val += step
        }
    } else {
        val := start
        while val >= stop {
            arr.Push(val)
            val += step
        }
    }
    return arr
}

FindBestPosition(window, placedWindows, monitor, gridSize, gridCols, gridRows) {
    ; Try to find a non-overlapping position in a grid
    left := monitor["Left"] + 10
    top := monitor["Top"] + 10
    right := monitor["Right"] - window["width"] - 10
    bottom := monitor["Bottom"] - window["height"] - 10
    for y, yval in Range(top, bottom, gridSize) {
        for x, xval in Range(left, right, gridSize) {
            candidate := Map("x", xval, "y", yval)
            overlap := false
            for placed in placedWindows {
                if !(xval + window["width"] < placed["x"] || xval > placed["x"] + placed["width"] ||
                      yval + window["height"] < placed["y"] || yval > placed["y"] + placed["height"]) {
                    overlap := true
                    break
                }
            }
            if !overlap
                return candidate
        }
    }
    return Map() ; fallback: no position found
}

CalculateSpaceSeekingForce(win, allWindows) {
    ; For now, return an empty map (no-op)
    return Map()
}