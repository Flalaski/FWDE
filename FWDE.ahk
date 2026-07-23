#Requires AutoHotkey v2.0
; --- Dropdown/Menu Detection ---
IsDropdownOrMenuWindow(hwnd) {
    try {
        if (!SafeWinExist(hwnd))
            return false
        winClass := WinGetClass("ahk_id " hwnd)
        style := WinGetStyle("ahk_id " hwnd)
        exStyle := WinGetExStyle("ahk_id " hwnd)
        title := WinGetTitle("ahk_id " hwnd)
        ; Common menu/dropdown classes
        menuClasses := ["#32768", "DV2ControlHost", "DropDown", "ComboLBox", "Menu", "Popup", "ContextMenu"]
        for pattern in menuClasses {
            if (winClass ~= "i)" pattern)
                return true
        }
        ; Heuristic: WS_POPUP, not WS_CAPTION, small, no title
        if ((style & 0x80000000) && !(style & 0x00C00000) && (exStyle & 0x8) && title == "") {
            WinGetPos(,, &w, &h, "ahk_id " hwnd)
            if (w < 600 && h < 600)
                return true
        }
        return false
    }
    catch as e {
        return false
    }
}

; Returns hwnd of any open dropdown/menu, or 0 if none
GetOpenDropdownMenuParent() {
    for hwnd in WinGetList() {
        if (IsDropdownOrMenuWindow(hwnd)) {
            ; Try to get owner/parent
            parent := DllCall("GetWindow", "Ptr", hwnd, "UInt", 4, "Ptr") ; GW_OWNER=4
            if (parent && SafeWinExist(parent))
                return parent
        }
    }
    return 0
}
#Warn
#MaxThreadsPerHotkey 255
#MaxThreads 255
ProcessSetPriority("High")
#DllLoad "gdi32.dll"
#DllLoad "user32.dll"
; Pre-allocate memory buffers
#DllLoad "dwmapi.dll" ; Desktop Composition API

global DebugMode := true

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
    "MinMargin", 0,  ; Allow windows right to screen edges
    "MinGap", 0,
    "SeedDiagonalStep", 61,      ; Base diagonal step used to de-stack similar windows
    "SeedDiagonalMaxSteps", 18,   ; Maximum number of diagonal steps to try per seed
    "SeedJitterRange", 31,        ; Per-window variance so same-size windows don't line up
    "ManualGapBonus", 0,
    "AttractionForce", 0.00045,   ; Center-seeking pull strength
    "RepulsionForce", 13.31,        ; Strong push to keep windows clearly separated
    "CollisionOverlapThreshold", 100,   ; Higher = only significant overlaps trigger separation (stops bouncing)
    "RepulsionRangeMultiplier", 3.069,   ; Wider repulsion envelope for earlier reaction
    "RepulsionImpulseScale", 4.32,      ; Strong per-step push for rapid overlap release
    "SmallWindowReferenceDim", 1200,   ; Reference dimension for small-window classification
    "MaxSmallWindowRepulsionBoost", 1.6,
    "PairSeparationBase", 0.08,        ; Base overlap separation force
    "PairSeparationOverlapScale", 0.1,
    "PairSmallWindowBoost", 3.0,
    "SmallWindowThresholdW", 614,
    "SmallWindowThresholdH", 591,
    "UserMoveTimeout", 523,        ; How long to keep focused window still after interaction (ms)
    "ManualLockDuration", 33333,     ; How long manual window locks last (ms) - about 33 seconds
    "ResizeDelay", 20,
    "TooltipDuration", 6767,
    "ParameterHelpTooltipDuration", 2200,
    "MultimonitorExpanse", false,   ; Toggle for multi-monitor expanse (seamless floating)
    "FloatStyles",  0x00C00000 | 0x00040000 | 0x00080000 | 0x00020000 | 0x00010000,
    "FloatClassPatterns", [
        "Vst.*",         ; VST plugins
        "JS.*",          ; JS plugins
        ".*Plugin.*",    ; Generic plugin windows
        ".*Float.*",     ; Windows with "Float" in class
        ".*Dock.*",      ; Dockable windows
        "#32770",        ; Dialog boxes
        "ConsoleWindowClass",  ; CMD/Console windows
        "TextToSpeechWndClass", ; <-- Added for speak.exe main window
        "MozillaWindowClass",  ; Firefox browser
        "Chrome_WidgetWin_1",  ; Chrome browser
        "ApplicationFrameWindow", ; Edge/UWP apps
        "SunAwtFrame",          ; Java applications
        "Notepad",              ; Notepad
        "Notepad++",            ; Notepad++
        "Code.exe",             ; VS Code
        "Cursor.exe",           ; Cursor
        "devenv.exe",           ; Visual Studio
        "XamlExplorerHost",     ; XAML applications
        "CabinetWClass",        ; File Explorer
        "OpusApp",              ; Microsoft Word
        "XLMAIN",               ; Microsoft Excel
        "PPTFrameClass",        ; Microsoft PowerPoint
        "rctrl_renwnd32",       ; Microsoft Outlook
        "TaskManagerWindow",    ; Task Manager
        "RegEdit_RegEdit",      ; Registry Editor
        "MMCMainFrame",         ; MMC snap-ins (Event Viewer, Services, etc.)
        "CalcFrame",            ; Classic Calculator
        "TApplication",         ; Delphi applications
        "wxWindowClassNR"       ; wxWidgets applications
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
        "WindowsTerminal.exe", ; Windows Terminal
        "DTDEMO.exe",       ; Dectalk TTS
        "speak.exe",     ; legacy speak.exe
        "speak",         ; legacy speak
        "speak.EXE",     ; <-- Added for uppercase variant
        "firefox.exe",   ; Firefox browser
        "chrome.exe",    ; Chrome browser
        "msedge.exe",    ; Edge browser
        "code.exe",      ; VS Code
        "cursor.exe",    ; Cursor editor
        "notepad.exe",   ; Notepad
        "notepad++.exe", ; Notepad++
        "devenv.exe",    ; Visual Studio
        "explorer.exe",  ; File Explorer
        "winword.exe",   ; Microsoft Word
        "excel.exe",     ; Microsoft Excel
        "powerpnt.exe",  ; Microsoft PowerPoint
        "outlook.exe"    ; Microsoft Outlook
    ],
    "Damping", 0.216,    ; 1.0 = no damping, 0.0 = full stop (use 0.001-1.0)
    "MaxSpeed", 120.0,    ; Limits maximum velocity
    "PhysicsTimeStep", 16,  ; ~60 Hz physics — AHK rounds <10-15ms to nearest multiple anyway
    "VisualTimeStep", 16,   ; ~60 Hz visual updates — matches typical display refresh rate
    "Stabilization", Map(
        "MinSpeedThreshold", 0.369,  ; Lower values high-DPI (0.05-0.15) ~ Higher values (0.2-0.5)  low-performance systems
        "EnergyThreshold", 0.06,     ; Lower values (0.05-0.1): Early stabilization, prevents overshooting
        "DampingBoost", 0.12,       ; 0.01-0.05: Subtle braking (smooth stops) ~ 0.1+: Strong braking (quick stops but may feel robotic)
        "OverlapTolerance", 120     ; Generous overlap tolerance for natural settling without bouncing
    ),
    "ManualWindowColor", "FF5555",
    "NoiseScale", 5550,
    "NoiseInfluence", 503,
    "ManualRepulsionMultiplier", 1.0,
    "DesktopIconRepulsion", false,       ; OFF by default — users opt in via Ctrl+Alt+I
    "DesktopIconMargin", 0,              ; Extra padding around each icon rect (0 = icon edges only)
    "DesktopIconRepulsionForce", 0.112358,     ; Multiplier for icon→window repulsion strength
    "MaxIconSpeed", 75.0,       ; Max per-frame velocity from icon repulsion (px/frame — undamped)
    "DesktopIconPhysics", true,  ; Treat icons as individual physics bodies (mass, velocity, inter-icon forces)
    "DesktopIconSpring", 0.008,  ; Spring constant pulling icons back to grid anchor (0=static, 0.01=snappy)
    "DesktopIconDamping", 0.65,  ; Icon velocity damping (0=no damping, 1=instant stop)
    "DesktopIconInterRepel", 0.4, ; Inter-icon repulsion strength multiplier
    "DesktopIconInterRepelRange", 0.7, ; Inter-icon repulsion range multiplier (0.5=never at default 145px spacing, 1.0=always active, 0.7=only when pushed ~40px toward neighbor)
)

global DefaultConfig := CloneMapDeep(Config)
global ParamSettingsGui := 0
global ParamControlRefs := Map()
global ParamSpecs := []
global UserConfigPath := A_ScriptDir "\\FWDE_Config.json"
global ParamSliderHwndToPath := Map()
global ParamSliderDblClickHooked := false
global ParamHoverControlToPath := Map()
global ParamHoverHooked := false
global ParamHoverLastPath := ""

global g := Map(
    "Monitor", Config["MultimonitorExpanse"] ? GetVirtualDesktopBounds() : GetCurrentMonitorInfo(),
    "ArrangementActive", true,  ; Arrangement ON by default
    "LastUserMove", 0,
    "ActiveWindow", 0,
    "Windows", [],
    "PhysicsEnabled", true,
    "SnapInProgress", Map(),  ; Track windows currently being snapped by Windows
    "ManualWindows", Map(),
    "SystemEnergy", 1,
    "InternalMoveDepth", 0,
    "LastInternalMoveTick", 0,
    "LastWMMoveHeavy", 0,     ; Throttle for heavy work in WindowMoveHandler
    "DragActive", false,      ; Set by WindowMoveHandler during real drags
    "_dragThreadActive", false,  ; DragWindow() thread-health flag (timestamp-based)
    "_dragThreadStart", 0,       ; TickCount when drag thread began
    "_hbPhysics", A_TickCount,   ; Heartbeat: last CalculateDynamicLayout tick
    "_hbVisual", A_TickCount,    ; Heartbeat: last ApplyWindowMovements tick
    "_hbWindowList", A_TickCount, ; Heartbeat: last UpdateWindowStates tick
    "_hbWatchdog", A_TickCount,  ; Heartbeat: last HealthMonitor tick
    "_snapOldestTick", 0,        ; TickCount of oldest SnapInProgress entry
    "_recoveryCount", 0,         ; Count of auto-recoveries performed
    "_dragFailsafeCount", 0,     ; Count of drag-thread force-resets
    "_snapFailsafeCount", 0,     ; Count of SnapInProgress force-clears
    "_draggedHwnd", 0,           ; Cached drag handle, recomputed each physics tick
    "_menuParent", 0,            ; Cached open-menu parent, recomputed each physics tick
    "_iconZones", [],            ; Clustered icon zones: [{left,top,right,bottom},...]
    "_iconZonesLive", false,     ; true = real ListView data, false = virtual fallback
    "ForceTransition", 0,         ; TickCount when smooth transition ends (set by state machine)
    "_perfOn", false,            ; Performance profiling toggle (Ctrl+Alt+F)
    "_perfFreq", 0,              ; QPC frequency (cached on first use)
    "_perfData", Map(),          ; key → [total_us, call_count]
    "DesktopIconRects", [],   ; Cached desktop icon obstacle rectangles
    "DesktopIconLastRefresh", A_TickCount  ; TickCount of last icon position scan — pre-set to prevent early scan race
)

; --- Crash-safe debug log ---
; Accumulates timestamped text. On an unhandled error, the entire log is copied
; to clipboard automatically so you can paste it into a bug report or DM.
global g_DebugLog := []
global g_Crashed := false

; Protected entries (startup) are never trimmed — preserved for crash reporting
global g_DebugProtected := 0

; Helper wrapper to avoid language server false positives with SetTimer's parameter signature
SetTimerEx(Func, Period) {
    SetTimer(Func, Period)
}

DebugLog(msg, values*) {
    global g_DebugLog, g_DebugProtected
    timestamp := Format("{:04}-{:02}-{:02} {:02}:{:02}:{:02}.{:03}",
        A_YYYY, A_MM, A_DD, A_Hour, A_Min, A_Sec, A_MSec)
    entry := timestamp " | " Format(msg, values*)
    g_DebugLog.Push(entry)
    ; Keep log trimmed — protect startup entries, only trim older unprotected entries
    ; g_DebugProtected is set once after startup phase ends (see CalculateDynamicLayout)
    if (g_DebugProtected > 0 && g_DebugLog.Length > 2000) {
        ; Trim oldest unprotected entries, keeping the protected block intact
        excess := g_DebugLog.Length - 2000
        trimEnd := Min(excess, g_DebugProtected)
        if (trimEnd > 0) {
            Loop trimEnd
                g_DebugLog.RemoveAt(g_DebugProtected + 1)
        }
    } else if (g_DebugProtected == 0 && g_DebugLog.Length > 2000) {
        ; Before protection is set, trim from front as usual
        g_DebugLog.RemoveAt(1)
    }
}

; --- Debug persistence: writes to disk file, then clipboard ---
; The file at FWDE_debug.log in the script's directory is the authoritative dump.
; Clipboard is a convenience copy — if it fails, the file still has everything.
global g_DebugFilePath := A_ScriptDir "\FWDE_debug.log"

_ClipPut(text) {
    ; Win32 CF_UNICODETEXT — copies directly from AHK's native UTF-16 buffer.
    ; Retries up to 5 times if clipboard is locked by another process.
    Loop 5 {
        size := (StrLen(text) + 1) * 2
        hMem := DllCall("GlobalAlloc", "UInt", 0x0042, "UPtr", size, "Ptr")
        if (!hMem) {
            if (A_Index < 5) {
                Sleep(50)
                continue
            }
            return _ClipPutFallback(text)
        }
        pMem := DllCall("GlobalLock", "Ptr", hMem, "Ptr")
        if (!pMem) {
            DllCall("GlobalFree", "Ptr", hMem)
            if (A_Index < 5) {
                Sleep(50)
                continue
            }
            return _ClipPutFallback(text)
        }
        DllCall("RtlMoveMemory", "Ptr", pMem, "Ptr", StrPtr(text), "UPtr", size)
        DllCall("GlobalUnlock", "Ptr", hMem)
        if (!DllCall("OpenClipboard", "Ptr", A_ScriptHwnd)) {
            DllCall("GlobalFree", "Ptr", hMem)
            if (A_Index < 5) {
                Sleep(50)
                continue
            }
            return _ClipPutFallback(text)
        }
        DllCall("EmptyClipboard")
        if (!DllCall("SetClipboardData", "UInt", 13, "Ptr", hMem)) {
            DllCall("CloseClipboard")
            DllCall("GlobalFree", "Ptr", hMem)
            if (A_Index < 5) {
                Sleep(50)
                continue
            }
            return _ClipPutFallback(text)
        }
        DllCall("CloseClipboard")
        return true
    }
    return _ClipPutFallback(text)
}

_ClipPutFallback(text) {
    try {
        A_Clipboard := text
        return true
    }
    return false
}

_WriteDebugFile(text) {
    global g_DebugFilePath
    try {
        if (FileExist(g_DebugFilePath))
            FileDelete(g_DebugFilePath)
        FileAppend(text, g_DebugFilePath, "UTF-8")
    }
}

; Register crash handler — copies the full debug log to clipboard when an
; unhandled error terminates the script, so you don't lose diagnostics.
OnError(ErrorHandler, -1)  ; priority -1 = run after other handlers

ErrorHandler(exception, mode) {
    global g_DebugLog, g_Crashed
    g_Crashed := true
    if (mode != 0)  ; not a throw — it's an unhandled error
        return
    ; Append the crash details
    g_DebugLog.Push("")
    g_DebugLog.Push("======  CRASH  ======")
    g_DebugLog.Push("Message: " exception.Message)
    g_DebugLog.Push("File:    " exception.File)
    g_DebugLog.Push("Line:    " exception.Line)
    g_DebugLog.Push("Stack:")
    for frame in exception.Stack {
        g_DebugLog.Push("  " frame.File " :: " frame.Function " (line " frame.Line ")")
    }
    g_DebugLog.Push("=====================")
    CopyLogToClipboard()
}

CopyLogToClipboard() {
    global g_DebugLog
    text := "=== FWDE CRASH DUMP — " A_Now " ==="
         . "`n" A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec "`n`n"
         . JoinLog(g_DebugLog, "`n")
    ; File is authoritative — always write first, before attempting clipboard
    _WriteDebugFile(text)
    ; Aggressive retry: crash path — try up to 15 times with 100ms delays.
    ; Clipboard may be locked by the app that triggered the crash.
    Loop 15 {
        if (_ClipPut(text)) {
            ToolTip("⚠️ FWDE crashed! Log: " g_DebugFilePath, 10, 10)
            SetTimerEx(() => ToolTip(), -8000)
            return
        }
        Sleep(100)
    }
    ; Final fallback: try A_Clipboard directly
    try A_Clipboard := text
    ToolTip("⚠️ FWDE crashed! Log: " g_DebugFilePath, 10, 10)
    SetTimerEx(() => ToolTip(), -8000)
}

DumpDebugLog(auto := false) {
    global g_DebugLog, g, g_DebugFilePath
    text := "FWDE Debug Log — " A_Now "`n" A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec "`n`n"
    text .= "Entries: " g_DebugLog.Length "`n`n"
    text .= JoinLog(g_DebugLog, "`n")
    if (g["_perfOn"] && g["_perfData"].Count > 0)
        text .= "`n`n" _PerfReport()
    ; File is authoritative — always write it first
    _WriteDebugFile(text)
    ; Win32 clipboard via CF_UNICODETEXT
    clipOk := _ClipPut(text)
    ; Self-verification: read back file
    fileVerify := ""
    try fileVerify := FileRead(g_DebugFilePath, "UTF-8")
    fileLen := StrLen(fileVerify)
    textLen := StrLen(text)
    if (!auto) {
        ToolTip("📋 " g_DebugLog.Length " entries, " textLen " chars"
            . "`nFile: " (textLen = fileLen ? "✓" : "✗ MISMATCH(" fileLen ")") "  Win32: " (clipOk ? "✓" : "✗")
            . "`n" g_DebugFilePath, 10, 10)
        SetTimerEx(() => ToolTip(), -6000)
    }
    DebugLog("DumpDebugLog — {} entries, text={} file={} clip={} (auto={})",
        g_DebugLog.Length, textLen, fileLen, clipOk ? "ok" : "FAIL", auto)
}

; --- Auto-dump debug log every 15 seconds so user can always retrieve it ---
DumpDebugLogPeriodic() {
    static lastAutoDump := 0
    if (A_TickCount - lastAutoDump > 60000) {
        lastAutoDump := A_TickCount
        DumpDebugLog(true)
    }
}

JoinLog(arr, delim) {
    s := ""
    for i, entry in arr {
        s .= (i > 1 ? delim : "") entry
    }
    return s
}

; --- High-resolution timer management (prevents "only updates while mouse is held" feel) ---
; Windows timers are typically ~15.6ms unless the process requests higher resolution.
; We keep high-res enabled while arrangement is active, and use ref-counting so DragWindow()
; doesn't accidentally disable it for the whole system when arrangement is still running.
global g_TimerResolutionRefs := 0

AcquireHighResTimer() {
    global g_TimerResolutionRefs
    if (g_TimerResolutionRefs <= 0) {
        g_TimerResolutionRefs := 0
        try DllCall("winmm\timeBeginPeriod", "UInt", 1)
    }
    g_TimerResolutionRefs += 1
}

ReleaseHighResTimer() {
    global g_TimerResolutionRefs
    if (g_TimerResolutionRefs <= 0)
        return
    g_TimerResolutionRefs -= 1
    if (g_TimerResolutionRefs <= 0) {
        g_TimerResolutionRefs := 0
        try DllCall("winmm\timeEndPeriod", "UInt", 1)
    }
}

; --- Drag state helper: only treat as "dragging" when a managed window is under the cursor ---
GetDraggedManagedWindow() {
    global g
    if (!GetKeyState("LButton", "P"))
        return 0
    ; Only treat as dragging when the WM_MOVE handler confirmed real movement
    if (!g.Has("DragActive") || !g["DragActive"])
        return 0
    MouseGetPos(,, &hoverHwnd)
    ; MouseGetPos often returns child controls (title bar, toolbar, etc.)
    ; that aren't in g["Windows"]. Use GetAncestor(GA_ROOT=2) to get the
    ; top-level window in a single safe call.
    try {
        root := DllCall("GetAncestor", "Ptr", hoverHwnd, "UInt", 2, "Ptr")
    } catch {
        root := 0
    }
    for win in g["Windows"] {
        if (win["hwnd"] == hoverHwnd || (root && win["hwnd"] == root))
            return win["hwnd"]
    }
    return 0
}

; --- Ensure arrangement timers start if ArrangementActive is true ---
if (g["ArrangementActive"])
    AcquireHighResTimer()
; Start physics and visual timers
SetTimerEx(CalculateDynamicLayout, Config["PhysicsTimeStep"]), SetTimerEx(ApplyWindowMovements, Config["VisualTimeStep"])

; --- Deferred startup: prime the desktop icon cache after shell initialization ---
; Desktop ListView may not exist yet at script start (shell still initializing).
; Defer by 2.5s to give Progman/WorkerW windows time to materialize.
; If icon repulsion is OFF, the scan is a no-op cost anyway.
SetTimerEx(DoStartupIconScan, -2500)

DoStartupIconScan() {
    global g, DebugMode
    fresh := GetDesktopIconRects()
    if (fresh.Length > 0)
        g["DesktopIconRects"] := fresh
    g["DesktopIconLastRefresh"] := A_TickCount
    count := g["DesktopIconRects"].Length
    DebugLog("Startup — desktop icon scan: {} obstacles", count)
    if (DebugMode) {
        SetTimerEx(() => ToolTip(), -4000)
        ToolTip("FWDE: Desktop icon scan — " count " obstacles detected", 10, 40)
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

SafeMonitorGet(monNum, &mL, &mT, &mR, &mB) {
    ; Always initialize bounds so callers never read unset locals.
    mL := 0
    mT := 0
    mR := A_ScreenWidth
    mB := A_ScreenHeight

    resolvedMon := monNum
    if (!resolvedMon)
        resolvedMon := MonitorGetPrimary()

    try {
        MonitorGet resolvedMon, &tmpL, &tmpT, &tmpR, &tmpB
        if (IsSet(tmpL) && IsSet(tmpT) && IsSet(tmpR) && IsSet(tmpB)) {
            mL := tmpL
            mT := tmpT
            mR := tmpR
            mB := tmpB
            return resolvedMon
        }
    }
    catch {
    }

    ; Retry on primary monitor if the requested monitor disappeared.
    try {
        resolvedMon := MonitorGetPrimary()
        MonitorGet resolvedMon, &tmpL, &tmpT, &tmpR, &tmpB
        if (IsSet(tmpL) && IsSet(tmpT) && IsSet(tmpR) && IsSet(tmpB)) {
            mL := tmpL
            mT := tmpT
            mR := tmpR
            mB := tmpB
            return resolvedMon
        }
    }
    catch {
    }

    return 0
}

; Like SafeMonitorGet but returns the work area (screen minus all AppBars: taskbar,
; RetroBar, any docked panel) for the given monitor.  MonitorGetWorkArea is a Windows
; API call that handles every taskbar position (top / bottom / left / right) and every
; taskbar replacement that registers itself as an AppBar (RetroBar does this).
; Falls back to full monitor bounds when the call fails.
SafeMonitorGetWorkArea(monNum, &mL, &mT, &mR, &mB) {
    mL := 0
    mT := 0
    mR := A_ScreenWidth
    mB := A_ScreenHeight

    resolvedMon := monNum
    if (!resolvedMon)
        resolvedMon := MonitorGetPrimary()

    try {
        MonitorGetWorkArea resolvedMon, &tmpL, &tmpT, &tmpR, &tmpB
        if (IsSet(tmpL) && IsSet(tmpT) && IsSet(tmpR) && IsSet(tmpB)) {
            mL := tmpL
            mT := tmpT
            mR := tmpR
            mB := tmpB
            return resolvedMon
        }
    }
    catch {
    }

    ; Retry on primary if the requested monitor disappeared.
    try {
        resolvedMon := MonitorGetPrimary()
        MonitorGetWorkArea resolvedMon, &tmpL, &tmpT, &tmpR, &tmpB
        if (IsSet(tmpL) && IsSet(tmpT) && IsSet(tmpR) && IsSet(tmpB)) {
            mL := tmpL
            mT := tmpT
            mR := tmpR
            mB := tmpB
            return resolvedMon
        }
    }
    catch {
    }

    ; Last resort: full monitor bounds (at least not garbage values).
    return SafeMonitorGet(monNum, &mL, &mT, &mR, &mB)
}

IsFullscreenWindow(hwnd) {
    try {
        if (!SafeWinExist(hwnd))
            return false

        ; Get window position and size
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        if (w == 0 || h == 0)
            return false

        ; Get monitor bounds for the window
        winCenterX := x + w/2
        winCenterY := y + h/2
        monNum := MonitorGetFromPoint(winCenterX, winCenterY)
        if (!monNum) {
            ; Fallback to primary monitor
            monNum := MonitorGetPrimary()
        }

        SafeMonitorGet(monNum, &mL, &mT, &mR, &mB)

        ; Check window properties
        winClass := WinGetClass("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)
        title := WinGetTitle("ahk_id " hwnd)
        
        ; Skip normal browser windows and common applications that should be manageable
        ; These are NOT considered fullscreen even if they cover the screen
        manageableClasses := [
            "MozillaWindowClass",        ; Firefox
            "Chrome_WidgetWin_1",        ; Chrome
            "ApplicationFrameWindow",    ; Edge/UWP apps
            "SunAwtFrame",              ; Java applications
            "Notepad",                  ; Notepad
            "Notepad++",                ; Notepad++
            "Code.exe",                 ; VS Code
            "Cursor.exe",               ; Cursor
            "devenv.exe",               ; Visual Studio
            "XamlExplorerHost",         ; XAML applications
            "CabinetWClass",            ; File Explorer
            "WorkerW",                  ; Desktop windows
            "Progman"                   ; Program Manager
        ]
        
        manageableProcesses := [
            "firefox.exe", "chrome.exe", "msedge.exe", "code.exe", "cursor.exe",
            "notepad.exe", "notepad++.exe", "devenv.exe", "explorer.exe",
            "winword.exe", "excel.exe", "powerpnt.exe", "outlook.exe"
        ]
        
        ; Check if this is a manageable window (not fullscreen)
        for pattern in manageableClasses {
            if (winClass == pattern)
                return false  ; This is a manageable window, not fullscreen
        }
        
        for pattern in manageableProcesses {
            if (InStr(processName, pattern))
                return false  ; This is a manageable process, not fullscreen
        }

        ; Check for actual fullscreen indicators
        try {
            style := WinGetStyle("ahk_id " hwnd)
            exStyle := WinGetExStyle("ahk_id " hwnd)
            
            ; Check for WS_POPUP style (common in fullscreen apps)
            isPopup := (style & 0x80000000) != 0
            
            ; Check for WS_EX_TOPMOST (many fullscreen apps use this)
            isTopmost := (exStyle & 0x8) != 0
            
            ; True fullscreen applications
            fullscreenClasses := [
                "UnityWndClass",      ; Unity games
                "UnrealWindow",       ; Unreal Engine games
                "Valve001",           ; Source games
                "SDL_app",            ; SDL applications
                "GLUT",               ; OpenGL applications
                "d3d",                ; DirectX applications
                "D3D"                 ; DirectX applications
            ]
            
            fullscreenProcesses := [
                "steam.exe", "steamwebhelper.exe",
                "vlc.exe", "mpc-hc.exe", "potplayer.exe",
                "obs64.exe", "obs32.exe", "streamlabs obs.exe"
            ]
            
            ; Check for actual fullscreen class patterns
            for pattern in fullscreenClasses {
                if (winClass == pattern)
                    return true
            }
            
            ; Check for actual fullscreen process patterns
            for pattern in fullscreenProcesses {
                if (InStr(processName, pattern))
                    return true
            }
            
            ; Check for fullscreen style combinations
            if (isPopup && isTopmost) {
                return true
            }
        }
        catch {
            ; If we can't get style info, continue with size-based detection
        }

        ; Check if window covers the entire monitor AND has fullscreen characteristics
        tolerance := 50  ; Increased tolerance for normal windows
        coversWidth := (w >= (mR - mL - tolerance))
        coversHeight := (h >= (mB - mT - tolerance))
        atOrigin := (x <= mL + tolerance && y <= mT + tolerance)

        ; Only consider it fullscreen if it covers the monitor AND has suspicious characteristics
        if (coversWidth && coversHeight && atOrigin) {
            ; Additional check: if it looks like a normal window (has titlebar, etc.), don't consider it fullscreen
            if (title != "" && !InStr(title, "Full Screen") && !InStr(title, "Fullscreen")) {
                ; Check if it has normal window characteristics
                if (style & 0x00C00000) {  ; WS_CAPTION (has titlebar)
                    return false  ; It's a normal window that happens to be large
                }
            }
            return true
        }

        return false
    }
    catch {
        return false
    }
}

IsWindowValid(hwnd) {
    try {
        if (!SafeWinExist(hwnd))
            return false

        ; Skip fullscreen windows completely
        if (IsFullscreenWindow(hwnd))
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
    SetTimerEx(() => ToolTip(), -Config["TooltipDuration"])
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
    ; Get the combined bounds of all monitors for multimonitor expanse
    global Config

    if (!Config["MultimonitorExpanse"]) {
        ; Return current monitor bounds if multimonitor expanse is disabled
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

    ; Fallback: use seeded diagonal offsets so same-size windows don't bury each other.
    seedOffset := GetSeededDiagonalOffset(window)
    fallbackX := Clamp(window["x"] + seedOffset["dx"], monitor["Left"] + Config["MinMargin"], monitor["Right"] - window["width"] - Config["MinMargin"])
    fallbackY := Clamp(window["y"] + seedOffset["dy"], monitor["Top"] + Config["MinMargin"], monitor["Bottom"] - window["height"] - Config["MinMargin"])
    return Map("x", fallbackX, "y", fallbackY)
}

GetWindowPlacementSeed(window) {
    hwndPart := (window.Has("hwnd") && IsInteger(window["hwnd"])) ? Integer(window["hwnd"]) : 0
    widthPart := window.Has("width") ? Integer(window["width"]) : 0
    heightPart := window.Has("height") ? Integer(window["height"]) : 0
    return Abs(hwndPart + widthPart * 37 + heightPart * 53)
}

GetSeededDiagonalOffset(window) {
    global Config

    seed := GetWindowPlacementSeed(window)
    directionIndex := Mod(seed, 4) + 1
    directions := [[-1, -1], [1, -1], [-1, 1], [1, 1]]
    direction := directions[directionIndex]

    maxSteps := Max(1, Config["SeedDiagonalMaxSteps"])
    baseStep := Max(1, Config["SeedDiagonalStep"])
    jitterRange := Max(0, Config["SeedJitterRange"])
    stepCount := Mod(seed // 4, maxSteps) + 1
    jitter := (jitterRange > 0) ? (Mod(seed // 17, jitterRange * 2 + 1) - jitterRange) : 0
    magnitude := baseStep * stepCount + jitter

    return Map("dx", direction[1] * magnitude, "dy", direction[2] * magnitude)
}

GetSeededPairDirection(win1, win2) {
    seed := Abs(Integer(win1["hwnd"]) * 31 + Integer(win2["hwnd"]) * 17)
    directions := [[-1, -1], [1, -1], [-1, 1], [1, 1]]
    return directions[Mod(seed, 4) + 1]
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
                break
            }
        }

        ; If it's from a DAW process, check plugin patterns
        if (isDAWProcess) {
            ; Check window class patterns
            for pattern in pluginClasses {
                if (InStr(winClass, pattern))
                    return true
            }

            ; Check window title patterns
            for pattern in pluginTitlePatterns {
                if (InStr(title, pattern))
                    return true
            }

            ; Check for small window dimensions typical of plugin UIs
            try {
                WinGetPos(,, &w, &h, "ahk_id " hwnd)
                if (w < 800 && h < 600)
                    return true
            }
        } else {
            ; For non-DAW processes, use basic patterns
            if (winClass ~= "i)(Vst|JS|Plugin|Float|Dock)")
                return true
            if (title ~= "i)(VST|JS:|Plugin|FX)")
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

    ; Skip fullscreen windows completely
    if (IsFullscreenWindow(hwnd))
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
        ; OutputDebug("Window Check - Class: " winClass " | Process: " processName " | Title: " title)

        ; 1. First check for forced processes (extension-insensitive match)
        procNoExt := StrLower(StrReplace(processName, ".exe", ""))
        for pattern in Config["ForceFloatProcesses"] {
            patNoExt := StrLower(StrReplace(pattern, ".exe", ""))
            if (procNoExt == patNoExt) {
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
    pi := _PerfStart()
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
            resolvedMon := SafeMonitorGet(winMonitor, &mL, &mT, &mR, &mB)
            if (resolvedMon)
                winMonitor := resolvedMon
            ; Check if window should be included based on floating mode
            includeWindow := false

            if (Config["MultimonitorExpanse"]) {
                ; In multimonitor expanse mode, include all windows from all monitors
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
                ; Find existing window data if available
                existingWin := 0
                for win in g["Windows"] {
                    if (win["hwnd"] == window["hwnd"]) {
                        existingWin := win
                        break
                    }
                }
                
                ; CRITICAL: Check if window is manually locked BEFORE applying any position constraints
                ; User-placed windows should NEVER have their position modified
                isManuallyLocked := (existingWin && existingWin.Has("ManualLock") && A_TickCount < existingWin["ManualLock"])
                ; Check if this window is the active window - CRITICAL: Never move the active window
                isActiveWindow := (window["hwnd"] == g["ActiveWindow"])
                ; Check if currently being dragged - CRITICAL: Never move during drag
                ; Only protect the window being actively dragged by the user from physics (briefly after drag end)
                ; NOTE: `window` is a fresh Map built above; drag state lives on `existingWin` (g["Windows"]).
                isBeingDragged := (existingWin && existingWin.Has("JustDragged") && A_TickCount - existingWin["JustDragged"] < 150)
                
                ; Only apply position constraints if window is NOT manually locked and NOT being actively dragged
                if (!isManuallyLocked && !isBeingDragged) {
                    ; IMPORTANT: Do not hard-clamp x/y during state collection.
                    ; Hard clamping here can create discontinuities (teleports) once ApplyWindowMovements starts
                    ; steering toward these clamped coordinates, potentially pushing non-overlapping windows into overlap.
                    ; Bounds are enforced gently later via edge forces + movement smoothing.
                } else {
                    ; Use EXISTING window position for manually locked or active windows
                    ; This ensures user-placed windows stay exactly where the user put them
                    if (existingWin) {
                        window["x"] := existingWin["x"]
                        window["y"] := existingWin["y"]
                    }
                }

                ; Create window entry with physics properties
                ; CRITICAL: Preserve ManualLock and other critical state from existing window
                winEntry := Map(
                    "hwnd", window["hwnd"],
                    "x", window["x"], "y", window["y"],
                    "width", window["width"], "height", window["height"],
                    "area", window["width"] * window["height"],
                    "mass", window["width"] * window["height"] / 100000,
                    "lastMove", existingWin ? existingWin["lastMove"] : 0,
                    "vx", existingWin ? existingWin["vx"] : 0,
                    "vy", existingWin ? existingWin["vy"] : 0,
                    "targetX", existingWin ? existingWin["targetX"] : window["x"],
                    "targetY", existingWin ? existingWin["targetY"] : window["y"],
                    "monitor", winMonitor,
                    "isPlugin", window["isPlugin"],
                    "lastSeen", window["lastSeen"],
                )
                
                ; Preserve ManualLock and IsManual flags - CRITICAL for user-placed windows
                if (existingWin) {
                    if (existingWin.Has("ManualLock"))
                        winEntry["ManualLock"] := existingWin["ManualLock"]
                    if (existingWin.Has("IsManual"))
                        winEntry["IsManual"] := existingWin["IsManual"]
                    if (existingWin.Has("JustDragged"))
                        winEntry["JustDragged"] := existingWin["JustDragged"]
                        
                    ; CRITICAL: For manually locked or active windows, preserve their exact x/y target positions
                    ; This prevents physics from moving them away from user placement
                    if ((isManuallyLocked || isActiveWindow) && existingWin.Has("targetX") && existingWin.Has("targetY")) {
                        winEntry["targetX"] := existingWin["targetX"]
                        winEntry["targetY"] := existingWin["targetY"]
                        ; Also preserve x/y from existing window to keep it exact
                        winEntry["x"] := existingWin["x"]
                        winEntry["y"] := existingWin["y"]
                    }
                }
                
                WinList.Push(winEntry)
            }
        }
        catch {
            continue
        }
    }

    ; Clean up windows that are no longer valid
    CleanupStaleWindows()

    _PerfEnd("GVW", pi)
    return WinList
}

; --- Desktop Icon Detection ---
; Generates desktop icon obstacle rectangles for physics repulsion.
; NEVER sends window messages to Explorer (crashes Win11 shell).
; Strategy: find the desktop SysListView32 via safe kernel calls → GetWindowRect →
; compute grid from known icon spacing. Caches result permanently — one probe, then pure math.
; If the ListView is unreachable, falls back to virtual-screen geometry.
; Returns an array of Maps with x, y, width, height (screen coordinates).

_GetClassNameSafe(hwnd) {
    if (!hwnd)
        return ""
    clsBuf := Buffer(256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Ptr", clsBuf, "Int", 255)
    return StrGet(clsBuf)
}

; Find a SysListView32 under hParent using only GetWindow (reads linked list, zero messages)
_FindLV(hParent) {
    if (!hParent)
        return 0
    hChild := DllCall("GetWindow", "Ptr", hParent, "UInt", 5, "Ptr")
    loop 100 {
        if (!hChild)
            break
        if (_GetClassNameSafe(hChild) = "SysListView32")
            return hChild
        hGrand := DllCall("GetWindow", "Ptr", hChild, "UInt", 5, "Ptr")
        loop 50 {
            if (!hGrand)
                break
            if (_GetClassNameSafe(hGrand) = "SysListView32")
                return hGrand
            hGrand := DllCall("GetWindow", "Ptr", hGrand, "UInt", 2, "Ptr")
        }
        hChild := DllCall("GetWindow", "Ptr", hChild, "UInt", 2, "Ptr")
    }
    return 0
}

; Find desktop ListView through any available safe path (zero messages).
; Includes a lightweight internal retry: the desktop shell may not be ready on first
; attempt, especially during startup or after session unlock / virtual-desktop switches.
_FindDesktopLV() {
    loop 2 {  ; One immediate attempt, one retry after 200ms
        ; Try Progman
        hProgman := DllCall("FindWindow", "Str", "Progman", "Ptr", 0, "Ptr")
        if (hProgman) {
            result := _FindLV(hProgman)
            if (result)
                return result
        }
        ; Try WorkerW windows
        hWorkerW := DllCall("FindWindow", "Str", "WorkerW", "Ptr", 0, "Ptr")
        while (hWorkerW) {
            result := _FindLV(hWorkerW)
            if (result)
                return result
            hWorkerW := DllCall("GetWindow", "Ptr", hWorkerW, "UInt", 2, "Ptr")
        }
        ; Try COM Shell.Application
        try {
            shell := ComObject("Shell.Application")
            for w in shell.Windows {
                try {
                    hwnd := w.HWND
                    if (hwnd) {
                        result := _FindLV(hwnd)
                        if (result)
                            return result
                    }
                }
            }
        }

        if (A_Index < 2)
            Sleep(200)
    }
    return 0
}

; Multi-strategy rect reader for desktop ListView.
; Strategy 1: GetWindowRect (kernel call, safe).
; Strategy 2: GetClientRect + ClientToScreen (kernel calls, safe).
; Returns true if a plausible rect was obtained (w≥200, h≥100).
_TryGetListViewRect(hListView, &lvLeft, &lvTop, &lvRight, &lvBottom) {
    lvLeft := 0, lvTop := 0, lvRight := 0, lvBottom := 0

    ; Strategy 1: GetWindowRect
    lvRect := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", hListView, "Ptr", lvRect)
    lvLeft := NumGet(lvRect, 0, "Int")
    lvTop := NumGet(lvRect, 4, "Int")
    lvRight := NumGet(lvRect, 8, "Int")
    lvBottom := NumGet(lvRect, 12, "Int")
    lvW := lvRight - lvLeft
    lvH := lvBottom - lvTop
    if (lvW >= 200 && lvH >= 100)
        return true

    ; Strategy 2: GetClientRect + ClientToScreen
    clRect := Buffer(16, 0)
    DllCall("GetClientRect", "Ptr", hListView, "Ptr", clRect)
    clW := NumGet(clRect, 8, "Int")
    clH := NumGet(clRect, 12, "Int")
    if (clW < 200 || clH < 100)
        return false

    ptBuf := Buffer(8, 0)
    NumPut("Int", 0, ptBuf, 0)
    NumPut("Int", 0, ptBuf, 4)
    DllCall("ClientToScreen", "Ptr", hListView, "Ptr", ptBuf)
    lvLeft := NumGet(ptBuf, 0, "Int")
    lvTop := NumGet(ptBuf, 4, "Int")
    lvRight := lvLeft + clW
    lvBottom := lvTop + clH
    DebugLog("IconGrid — GetWindowRect failed ({}×{}), GetClientRect gave {}×{}", lvW, lvH, clW, clH)
    return true
}

; Build icon grid from known parameters — pure math, zero Explorer interaction.
; When lightweight=true, strips per-icon physics fields (vx/vy/mass/anchor) since
; ProcessIconPhysics is skipped for >50 icons — only zone-repulsion fields needed.
_BuildIconGrid(lvLeft, lvTop, lvRight, lvBottom, iconCount, spX, spY, margin, lightweight := false, verbose := false) {
    rects := []
    lvWidth := lvRight - lvLeft
    if (lvWidth <= 0)
        lvWidth := A_ScreenWidth
    cols := Max(1, Floor(lvWidth / spX))
    gIconW := 72 + margin * 2
    gIconH := 68 + margin * 2
    found := 0
    loop iconCount {
        idx := A_Index - 1
        row := idx // cols
        col := Mod(idx, cols)
        screenX := lvLeft + col * spX - margin
        screenY := lvTop + row * spY - margin
        if (screenX < -10000 || screenY < -10000 || screenX > 50000 || screenY > 50000)
            continue
        if (lightweight) {
            ; Zone-repulsion only: skip physics fields to reduce memory 62%
            rects.Push(Map(
                "x", screenX, "y", screenY, "width", gIconW, "height", gIconH
            ))
        } else {
            rects.Push(Map(
                "x", screenX, "y", screenY, "width", gIconW, "height", gIconH,
                "anchorX", screenX, "anchorY", screenY,
                "vx", 0.0, "vy", 0.0,
                "mass", gIconW * gIconH / 100000.0
            ))
        }
        if (verbose && found < 5)
            DebugLog("IconGrid — [{}] col={} row={} screen=({},{}) {}×{}", idx, col, row, screenX, screenY, gIconW, gIconH)
        found++
    }
    return rects
}

GetDesktopIconRects() {
    global Config, DebugMode
    pd := _PerfStart()
    Critical
    rects := []

    if (!Config["DesktopIconRepulsion"])
        return rects

    ; --- Persistent grid cache ---
    ; Once we have valid params, never touch Explorer again. Grid doesn't change
    ; unless the user rearranges icons — which is rare. Cache survives forever.
    static s_cached := false
    static s_lvLeft, s_lvTop, s_lvRight, s_lvBottom
    static s_iconCount, s_spX, s_spY, s_margin
    static s_retryTick := 0  ; Next A_TickCount when we should retry LV detection

    margin := Config["DesktopIconMargin"]

    ; Rebuild if margin changed (user adjusted the slider)
    if (s_cached && s_margin != margin)
        s_cached := false

    ; Periodic retry: if not cached, try LV detection every 30 seconds
    if (!s_cached && s_retryTick > 0 && A_TickCount < s_retryTick) {
        ; Use pre-set fallback values (defined below)
        spX := 145, spY := 95
        goto UseFallback
    }

    if (s_cached) {
        return _BuildIconGrid(s_lvLeft, s_lvTop, s_lvRight, s_lvBottom, s_iconCount, s_spX, s_spY, margin, s_iconCount > 50)
    }

    ; --- First run / retry: establish the grid ---
    spX := 145
    spY := 95

    hListView := _FindDesktopLV()
    lvOk := false
    
    if (hListView)
        lvOk := _TryGetListViewRect(hListView, &lvLeft, &lvTop, &lvRight, &lvBottom)
    
    if (lvOk) {
        lvWidth := lvRight - lvLeft
        lvHeight := lvBottom - lvTop
        DebugLog("IconGrid — LV at ({},{})–({},{}), using spacing {}×{}", lvLeft, lvTop, lvRight, lvBottom, spX, spY)

        iconCount := 0
        try iconCount := SendMessage(0x1004, 0, 0, , "ahk_id " hListView)
        if (iconCount <= 0 || iconCount > 500) {
            if (lvWidth <= 0)
                lvWidth := A_ScreenWidth
            if (lvHeight <= 0)
                lvHeight := A_ScreenHeight
            cols := Max(1, Floor(lvWidth / spX))
            rows := Max(1, Floor(lvHeight / spY))
            iconCount := Min(cols * rows, 200)
            DebugLog("IconGrid — SendMessage unavailable, estimated {} icons ({}×{} grid)", iconCount, cols, rows)
        } else {
            DebugLog("IconGrid — ListView reports {} icons", iconCount)
        }

        s_cached := true
        s_lvLeft := lvLeft
        s_lvTop := lvTop
        s_lvRight := lvRight
        s_lvBottom := lvBottom
        s_iconCount := iconCount
        s_spX := spX
        s_spY := spY
        s_margin := margin

        lightweight := (iconCount > 50)
        result := _BuildIconGrid(lvLeft, lvTop, lvRight, lvBottom, iconCount, spX, spY, margin, lightweight, !lightweight)
        DebugLog("IconGrid — {} obstacles ({}weight), {}×{} spacing, lv=({},{})–({},{})",
            result.Length, lightweight ? "light" : "full", spX, spY, lvLeft, lvTop, lvRight, lvBottom)
        if (DebugMode)
            ToolTip("FWDE: " result.Length " desktop icons ✓", 10, 40)
        g["_iconZones"] := ClusterIconZones(result, 60)
        g["_iconZonesLive"] := true
        DebugLog("IconZones — {} zones from {} icons (live)", g["_iconZones"].Length, result.Length)
        _PerfEnd("GDR", pd)
        return result
    }

    UseFallback:
    ; No valid ListView — fall back to primary monitor work area
    try {
        primaryMon := MonitorGetPrimary()
        MonitorGetWorkArea primaryMon, &waL, &waT, &waR, &waB
    } catch {
        waL := 0
        waT := 0
        waR := A_ScreenWidth
        waB := A_ScreenHeight
    }
    lvLeft := waL
    lvTop := waT
    lvRight := waR
    lvBottom := waB
    waWidth := waR - waL
    waHeight := waB - waT
    cols := Max(1, Floor(waWidth / spX))
    rows := Max(1, Floor(waHeight / spY))
    iconCount := Min(cols * rows, 200)
    DebugLog("IconGrid — no ListView, using primary work area ({},{})–({},{}), {} icons ({}×{} grid)",
        lvLeft, lvTop, lvRight, lvBottom, iconCount, cols, rows)
    s_retryTick := A_TickCount + 30000
    s_cached := false

    lightweight := (iconCount > 50)
    result := _BuildIconGrid(lvLeft, lvTop, lvRight, lvBottom, iconCount, spX, spY, margin, lightweight, !lightweight)
    DebugLog("IconGrid — {} obstacles ({}weight), {}×{} spacing, lv=({},{})–({},{})",
        result.Length, lightweight ? "light" : "full", spX, spY, lvLeft, lvTop, lvRight, lvBottom)
    if (DebugMode)
        ToolTip("FWDE: " result.Length " desktop icons ✓", 10, 40)

    ; Virtual fallback zones
    iconH := 68 + margin * 2
    g["_iconZones"] := SplitVirtualGridIntoZones(lvLeft, lvTop, iconCount, cols, spX, spY, iconH)
    g["_iconZonesLive"] := false
    DebugLog("IconZones — {} zones from {} icons (not live)", g["_iconZones"].Length, result.Length)
    _PerfEnd("GDR", pd)
    return result
}

; ═══════════════════════════════════════════════════════════════════════════════
;  ICON ZONE CLUSTERING — groups icon rects into separate rectangular zones
;  based on spatial proximity. Gaps between clusters become free window space.
;  For the virtual fallback grid, splits columns into logical groups.
; ═══════════════════════════════════════════════════════════════════════════════

; Cluster icons using BFS flood-fill. Two icons are connected if their
; expanded rects (icon ± gapThreshold) overlap. Returns array of zone rects.
ClusterIconZones(iconRects, gapThreshold := 0) {
    n := iconRects.Length
    if (n == 0)
        return []

    visited := Map()
    zones := []

    for i, icon in iconRects {
        if (visited.Has(i))
            continue

        queue := [i]
        visited[i] := true
        zMinX := 999999.0, zMaxX := -999999.0
        zMinY := 999999.0, zMaxY := -999999.0

        while (queue.Length > 0) {
            idx := queue.RemoveAt(1)
            r := iconRects[idx]
            rx := r["x"] - gapThreshold
            ry := r["y"] - gapThreshold
            rr := r["x"] + r["width"] + gapThreshold
            rb := r["y"] + r["height"] + gapThreshold

            zMinX := Min(zMinX, r["x"])
            zMaxX := Max(zMaxX, r["x"] + r["width"])
            zMinY := Min(zMinY, r["y"])
            zMaxY := Max(zMaxY, r["y"] + r["height"])

            for j, other in iconRects {
                if (visited.Has(j))
                    continue
                ox := other["x"] - gapThreshold
                oy := other["y"] - gapThreshold
                or_ := other["x"] + other["width"] + gapThreshold
                ob := other["y"] + other["height"] + gapThreshold
                if (rx < or_ && rr > ox && ry < ob && rb > oy) {
                    visited[j] := true
                    queue.Push(j)
                }
            }
        }
        zones.Push(Map("left", zMinX, "top", zMinY, "right", zMaxX, "bottom", zMaxY))
    }
    return zones
}

; For virtual fallback grids, build left-biased zones reflecting typical
; desktop icon placement. Main zone on the left; optional right zone only
; if enough icons exist beyond the midpoint plus a gap.
SplitVirtualGridIntoZones(lvLeft, lvTop, iconCount, cols, spX, spY, iconH) {
    filledRows := Ceil(iconCount / cols)
    zoneBottom := lvTop + filledRows * spY

    ; Real desktop icons cluster in the top-left, spanning ~5-7 columns.
    ; A fixed realistic width leaves the right majority of screen free.
    realisticCols := 6
    zoneWidth := realisticCols * spX  ; ~870px on standard 145px spacing
    return [Map("left", lvLeft, "top", lvTop, "right", lvLeft + zoneWidth, "bottom", zoneBottom)]
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

; --- Icon physics: treats desktop icons as individual physics bodies ---
; Icons repel each other, spring back to their grid anchors, and recoil when windows push them.
; This runs every physics tick, independent of window forces.
ProcessIconPhysics(icons, windows) {
    global Config
    pi := _PerfStart()

    iconCount := icons.Length
    if (iconCount == 0)
        return

    static iconPhysLogTick := 0, interRepelFireCount := 0, interRepelLogTick := 0
    totalIconV := 0.0
    maxIconV := 0.0

    ; --- Inter-icon repulsion ---
    ; Each icon repels nearby icons (same formula as window repulsion, scaled down)
    for i, icon in icons {
        ix := icon["x"] + icon["width"] / 2
        iy := icon["y"] + icon["height"] / 2

        for j, other in icons {
            if (j <= i)
                continue

            ox := other["x"] + other["width"] / 2
            oy := other["y"] + other["height"] / 2
            dx := ix - ox
            dy := iy - oy
            if (Abs(dx) < 0.5 && Abs(dy) < 0.5) {
                dx := (Mod(i * 37 + j * 13, 17) - 8) / 8.0
                dy := (Mod(i * 53 + j * 7, 17) - 8) / 8.0
            }
            dist := Max(Sqrt(dx*dx + dy*dy), 1)

            ; Inter-icon repulsion range: only activates when icons are pushed
            ; closer than their natural grid spacing (145px center-to-center).
            iconRange := Sqrt(icon["width"] * icon["height"] + other["width"] * other["height"]) / 2.0
            repelRange := iconRange * Config["RepulsionRangeMultiplier"] * Config["DesktopIconInterRepelRange"]

            if (dist < repelRange) {
                repelForce := Config["RepulsionForce"] * Config["DesktopIconInterRepel"] * (repelRange - dist) / repelRange
                forceX := dx * repelForce / dist * Config["RepulsionImpulseScale"] * 0.3
                forceY := dy * repelForce / dist * Config["RepulsionImpulseScale"] * 0.3

                icon["vx"] += forceX / Max(icon["mass"], 0.001)
                icon["vy"] += forceY / Max(icon["mass"], 0.001)
                other["vx"] -= forceX / Max(other["mass"], 0.001)
                other["vy"] -= forceY / Max(other["mass"], 0.001)
                interRepelFireCount++
            }
        }
    }
    if (A_TickCount - interRepelLogTick > 15000) {
        interRepelLogTick := A_TickCount
        DebugLog("IconPhys — inter-icon repulsion fired {} times this cycle", interRepelFireCount)
        interRepelFireCount := 0
    }

    ; --- Window recoil: Newton's 3rd law for icon←window repulsion ---
    ; When the window force calc pushes a window away from an icon, the icon
    ; should feel equal-and-opposite recoil (like icons are light objects being bumped)
    static recoilFireCount := 0, recoilLogTick := 0
    for win in windows {
        wx := win["x"] + win["width"] / 2
        wy := win["y"] + win["height"] / 2
        wMass := win["width"] * win["height"] / 100000.0

        for icon in icons {
            iconCX := icon["x"] + icon["width"] / 2
            iconCY := icon["y"] + icon["height"] / 2
            dxi := wx - iconCX
            dyi := wy - iconCY
            distIcon := Max(Sqrt(dxi*dxi + dyi*dyi), 1)

            iconRange := Sqrt(win["width"] * win["height"] + icon["width"] * icon["height"]) / 4.0
            sizeBonus := Max(1.0, 200.0 / Max(Min(win["width"], win["height"]), 1))
            iconRange *= sizeBonus
            iconRepelRange := iconRange * Config["RepulsionRangeMultiplier"]

            if (distIcon < iconRepelRange) {
                ; The window gets pushed by this icon — icon gets opposite recoil
                repelForce := Config["RepulsionForce"] * Config["DesktopIconRepulsionForce"] * (iconRepelRange - distIcon) / iconRepelRange
                recoilScale := 0.15  ; Icons are light — they feel 15% of the force
                icon["vx"] -= dxi * repelForce * recoilScale / distIcon / Max(icon["mass"], 0.001)
                icon["vy"] -= dyi * repelForce * recoilScale / distIcon / Max(icon["mass"], 0.001)
                recoilFireCount++
            }
        }
    }
    if (A_TickCount - recoilLogTick > 15000) {
        recoilLogTick := A_TickCount
        DebugLog("IconPhys — window recoil fired {} times this cycle", recoilFireCount)
        recoilFireCount := 0
    }

    ; --- Spring anchor + damping + position update ---
    springK := Config["DesktopIconSpring"]
    dampingF := Config["DesktopIconDamping"]
    iconSpeedLimit := Config["MaxIconSpeed"] * 0.5  ; Icons move at half the max window speed

    for icon in icons {
        ; Spring force pulling toward anchor
        dxAnchor := icon["anchorX"] - icon["x"]
        dyAnchor := icon["anchorY"] - icon["y"]
        icon["vx"] += dxAnchor * springK
        icon["vy"] += dyAnchor * springK

        ; Damping
        icon["vx"] *= dampingF
        icon["vy"] *= dampingF

        ; Speed clamp
        icon["vx"] := Min(Max(icon["vx"], -iconSpeedLimit), iconSpeedLimit)
        icon["vy"] := Min(Max(icon["vy"], -iconSpeedLimit), iconSpeedLimit)

        ; Update position
        icon["x"] += icon["vx"]
        icon["y"] += icon["vy"]

        ; Clamp to reasonable bounds
        icon["x"] := Min(Max(icon["x"], icon["anchorX"] - 200), icon["anchorX"] + 200)
        icon["y"] := Min(Max(icon["y"], icon["anchorY"] - 200), icon["anchorY"] + 200)

        totalIconV += Abs(icon["vx"]) + Abs(icon["vy"])
        maxIconV := Max(maxIconV, Abs(icon["vx"]))
        maxIconV := Max(maxIconV, Abs(icon["vy"]))
    }

    if (A_TickCount - iconPhysLogTick > 15000) {
        iconPhysLogTick := A_TickCount
        DebugLog("IconPhys — {} icons processed, totalV={:.1f}, maxV={:.1f}", iconCount, totalIconV, maxIconV)
    }
    _PerfEnd("PIP", pi)
}

CalculateWindowForces(win, allWindows) {
    global g, Config
    pf := _PerfStart()

    ; Use cached menu parent (computed once per tick in CalculateDynamicLayout)
    menuParent := g.Has("_menuParent") ? g["_menuParent"] : 0
    if (menuParent && win["hwnd"] == menuParent) {
        win["vx"] := 0
        win["vy"] := 0
        return
    }

    ; Use cached drag state (computed once per tick in CalculateDynamicLayout)
    draggedHwnd := g["_draggedHwnd"]
    isDraggedWindow := (draggedHwnd != 0 && win["hwnd"] == draggedHwnd)
    
    if (isDraggedWindow) {
        ; For the dragged window, skip its own physics calculations
        ; but allow it to apply forces to other windows in the allWindows loop
        win["vx"] := 0
        win["vy"] := 0
        ; Don't return - we need to continue to apply forces from this window to others
    }

    ; Keep active window and recently moved windows still
    ; CRITICAL: The active window should NEVER be affected by physics (unless dragging)
    isActiveWindow := (win["hwnd"] == g["ActiveWindow"])
    isRecentlyMoved := (A_TickCount - g["LastUserMove"] < Config["UserMoveTimeout"])
    isCurrentlyFocused := (win["hwnd"] == WinExist("A"))
    isManuallyLocked := (win.Has("ManualLock") && A_TickCount < win["ManualLock"])
    wasJustUnlocked := (win.Has("LockLostAt") && (A_TickCount - win["LockLostAt"]) < 100)
    isBeingSnapped := g["SnapInProgress"].Has(win["hwnd"]) && A_TickCount < g["SnapInProgress"][win["hwnd"]]

    ; Protected windows: no physics
    isProtected := (isManuallyLocked || isActiveWindow || (isRecentlyMoved && isCurrentlyFocused) || isBeingSnapped || wasJustUnlocked) && !isDraggedWindow
    if (isProtected) {
        win["vx"] := 0
        win["vy"] := 0
        return
    }
    
    ; Clean up LockLostAt marker after transition period
    if (wasJustUnlocked) {
        win.Delete("LockLostAt")
    }
    
    ; Check if window has any actual collisions
    hasCollision := false
    for other in allWindows {
        if (other == win)
            continue
        
        overlapX := Max(0, Min(win["x"] + win["width"], other["x"] + other["width"]) - Max(win["x"], other["x"]))
        overlapY := Max(0, Min(win["y"] + win["height"], other["y"] + other["height"]) - Max(win["y"], other["y"]))
        
        if (overlapX > Config["CollisionOverlapThreshold"] && overlapY > Config["CollisionOverlapThreshold"]) {
            hasCollision := true
            break
        }
    }
    
    if (Config["MultimonitorExpanse"]) {
        ; Use virtual desktop bounds for multimonitor expanse
        virtualBounds := GetVirtualDesktopBounds()
        mL := virtualBounds["Left"]
        mT := virtualBounds["Top"]
        mR := virtualBounds["Right"]
        mB := virtualBounds["Bottom"]
    } else {
        ; Work area already excludes the taskbar on any side (top/bottom/left/right)
        ; for both native Windows taskbar and AppBar replacements like RetroBar.
        SafeMonitorGetWorkArea(win["monitor"], &mL, &mT, &mR, &mB)
    }

    monLeft := mL
    monRight := mR - win["width"]
    monTop := mT + Config["MinMargin"]
    monBottom := mB - Config["MinMargin"] - win["height"]

    ; Check if window is out of bounds
    isOutOfBounds := (win["x"] < monLeft || win["x"] > monRight || win["y"] < monTop || win["y"] > monBottom)
    
    ; Check if nearby windows are close enough to exert force even without direct overlap.
    ; This prevents the physics loop from appearing "asleep" until the mouse drag injects motion.
    wx := win["x"] + win["width"]/2
    wy := win["y"] + win["height"]/2
    hasNearbyInfluence := false
    for other in allWindows {
        if (other == win)
            continue

        otherX := other["x"] + other["width"]/2
        otherY := other["y"] + other["height"]/2
        dxProbe := wx - otherX
        dyProbe := wy - otherY
        distProbe := Max(Sqrt(dxProbe*dxProbe + dyProbe*dyProbe), 1)

        probeRange := Sqrt(win["width"] * win["height"] + other["width"] * other["height"]) / 2.5
        probeRange *= Max(1.0, 200.0 / Max(Min(win["width"], win["height"]), 1))

        if (distProbe < probeRange * 3) {
            hasNearbyInfluence := true
            break
        }
    }

    ; Only sleep physics for truly isolated windows that are already settled.
    if (!hasCollision && !isOutOfBounds && !hasNearbyInfluence && Abs(win["vx"]) < 0.1 && Abs(win["vy"]) < 0.1) {
        win["vx"] := 0
        win["vy"] := 0
        ; Clear target position so window stays exactly where it is
        if (win.Has("targetX"))
            win.Delete("targetX")
        if (win.Has("targetY"))
            win.Delete("targetY")
        return
    }

    prev_vx := win.Has("vx") ? win["vx"] : 0
    prev_vy := win.Has("vy") ? win["vy"] : 0

    ; Very weak gravitational pull toward center (space-like)
    dx := (mL + mR)/2 - wx
    dy := (mT + mB)/2 - wy
    centerDist := Sqrt(dx*dx + dy*dy)

    ; Gentle center attraction with distance falloff - stronger for equilibrium
    if (centerDist > 100) {  ; Reduced threshold for earlier attraction
        attractionScale := Min(0.25, centerDist/1200)  ; Stronger attraction (was 0.15 and /1500)
        ; Use Config["Damping"] as base; Electron apps get slightly less damping
        dampingFactor := IsElectronApp(win["hwnd"]) ? Min(1.0, Config["Damping"] + (1.0 - Config["Damping"]) * 0.15) : Config["Damping"]
        vx := prev_vx * dampingFactor + dx * Config["AttractionForce"] * 0.08 * attractionScale  ; Increased from 0.05
        vy := prev_vy * dampingFactor + dy * Config["AttractionForce"] * 0.08 * attractionScale
    } else {
        ; Use Config["Damping"]; slightly more damping near center for settling
        dampingFactor := IsElectronApp(win["hwnd"]) ? Min(1.0, Config["Damping"] + (1.0 - Config["Damping"]) * 0.10) : Config["Damping"]
        vx := prev_vx * dampingFactor  ; Slightly more damping near center
        vy := prev_vy * dampingFactor
    }

    ; Space-seeking behavior: move toward empty areas when crowded (reduced for less jumpiness)
    spaceForce := CalculateSpaceSeekingForce(win, allWindows)
    if (spaceForce.Count > 0) {
        vx += spaceForce["vx"] * 0.005  ; Much smaller force to reduce jumpiness
        vy += spaceForce["vy"] * 0.005
    }

    ; Soft edge boundaries (like invisible force fields)
    edgeBuffer := 5  ; Reduced to allow windows closer to edges
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

    ; Use cached drag state (computed once per tick)
    draggedHwnd := g["_draggedHwnd"]
    isDraggingManaged := (draggedHwnd != 0)
    
    for other in allWindows {
        if (other == win)
            continue
        
        ; Skip maximized and fullscreen windows - they should never be affected
        try {
            if (WinGetMinMax("ahk_id " other["hwnd"]) != 0 || IsFullscreenWindow(other["hwnd"]))
                continue
        } catch {
            continue
        }
            
        ; Keep active windows as force sources so neighboring windows still react,
        ; while the active window itself remains protected elsewhere.

        ; Calculate distance between window centers
        otherX := other["x"] + other["width"]/2
        otherY := other["y"] + other["height"]/2
        dx := wx - otherX
        dy := wy - otherY

        ; Break perfect overlaps with a tiny seeded diagonal direction.
        if (Abs(dx) < 0.5 && Abs(dy) < 0.5) {
            dir := GetSeededPairDirection(win, other)
            dx := dir[1]
            dy := dir[2]
        }

        dist := Max(Sqrt(dx*dx + dy*dy), 1)

        ; Dynamic interaction range based on window sizes
        interactionRange := Sqrt(win["width"] * win["height"] + other["width"] * other["height"]) / 2.5  ; Increased for wider gaps

        ; Smaller windows get proportionally larger interaction zones
        sizeBonus := Max(1.0, 200.0 / Max(Min(win["width"], win["height"]), 1))  ; Boost for small windows
        interactionRange *= sizeBonus

        repulsionRange := interactionRange * Config["RepulsionRangeMultiplier"]

        ; Small windows should separate more decisively to keep visible edges.
        minDimPair := Min(win["width"], win["height"], other["width"], other["height"])
        smallWindowBoost := Config["SmallWindowReferenceDim"] / Max(minDimPair, 1)
        smallWindowBoost := Min(Max(1.0, smallWindowBoost), Config["MaxSmallWindowRepulsionBoost"])

        if (dist < repulsionRange) {
            ; Close range: much stronger repulsion to prevent prolonged overlap
            repulsionForce := Config["RepulsionForce"] * (repulsionRange - dist) / repulsionRange
            repulsionForce *= (other.Has("IsManual") ? Config["ManualRepulsionMultiplier"] : 1)
            repulsionForce *= smallWindowBoost

            proximityMultiplier := 1 + (1 - dist / repulsionRange) * 2  ; Wider proximity boost

            vx += dx * repulsionForce * proximityMultiplier / dist * Config["RepulsionImpulseScale"]
            vy += dy * repulsionForce * proximityMultiplier / dist * Config["RepulsionImpulseScale"]
        } else if (dist < interactionRange * 3) {  ; Reduced attraction range for tighter equilibrium
            ; Medium range: gentle attraction for stable clustering
            attractionForce := Config["AttractionForce"] * 0.012 * (dist - interactionRange) / interactionRange  ; Increased from 0.005

            vx -= dx * attractionForce / dist * 0.04  ; Increased from 0.02
            vy -= dy * attractionForce / dist * 0.04
        }
    }

    ; Space-like momentum with equilibrium-seeking damping
    dampingFactor := IsElectronApp(win["hwnd"]) ? Min(1.0, Config["Damping"] + (1.0 - Config["Damping"]) * 0.12) : Config["Damping"]
    vx *= dampingFactor
    vy *= dampingFactor

    ; Floating speed limits (balanced for equilibrium)
    maxFloatSpeed := Config["MaxSpeed"] * 2.0
    vx := Min(Max(vx, -maxFloatSpeed), maxFloatSpeed)
    vy := Min(Max(vy, -maxFloatSpeed), maxFloatSpeed)

    ; Progressive stabilization based on speed
    if (Abs(vx) < 0.15 && Abs(vy) < 0.15) {
        stabFactor := IsElectronApp(win["hwnd"]) ? Min(1.0, Config["Damping"] + (1.0 - Config["Damping"]) * 0.25) : Max(0.85, Config["Damping"])
        vx *= stabFactor
        vy *= stabFactor
    }

    win["vx"] := vx
    win["vy"] := vy

    ; Calculate target position
    win["targetX"] := win["x"] + win["vx"]
    win["targetY"] := win["y"] + win["vy"]

    _PerfEnd("CWF", pf)

    ; Apply bounds
    win["targetX"] := Max(monLeft, Min(win["targetX"], monRight))
    win["targetY"] := Max(monTop, Min(win["targetY"], monBottom))
}

SmoothStep(t) {
    return t * t * (3 - 2 * t)
}

ApplyWindowMovements() {
    global g, Config
    static lastUpdate := 0
    static lastPositions := Map()
    static smoothPos := Map()
    ; Throttled ApplyMovements logging — aggregate per-second instead of per-tick
    static _awmLastLog := 0, _awmTicks := 0, _awmTotalMoves := 0

    try {  ; Wrap entire timer body — any exception would silently kill this timer in AHK v2

    p := _PerfStart()

    g["_hbVisual"] := A_TickCount  ; HealthMonitor heartbeat

    ; Suspend movement for parent windows if a dropdown/menu is open
    ; Use cached menu parent (computed once per tick in CalculateDynamicLayout)
    menuParent := g.Has("_menuParent") ? g["_menuParent"] : 0

    Critical

    ; Keep physics running during drag to allow dragged window to push other windows
    ; The dragged window itself will be protected from movement in the loop below

    now := A_TickCount
    frameTime := now - lastUpdate
    lastUpdate := now

    ; Cache all window positions at the start (kernel-only, no messages)
    hwndPos := Map()
    for win in g["Windows"] {
        if (menuParent && win["hwnd"] == menuParent)
            continue
        hwnd := win["hwnd"]
        try {
            wrBuf := Buffer(16, 0)
            if (DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", wrBuf)) {
                wl := NumGet(wrBuf, 0, "Int")
                wt := NumGet(wrBuf, 4, "Int")
                wr := NumGet(wrBuf, 8, "Int")
                wb := NumGet(wrBuf, 12, "Int")
                hwndPos[hwnd] := { x: wl, y: wt, w: wr - wl, h: wb - wt }
            }
        } catch {
            continue
        }
    }

    moveBatch := []

    ; Use cached drag state (computed once per tick in CalculateDynamicLayout)
    draggedHwnd := g["_draggedHwnd"]
    isDragging := (draggedHwnd != 0)
    
    for win in g["Windows"] {
        ; Skip maximized and fullscreen windows - they should never be moved
        try {
            if (WinGetMinMax("ahk_id " win["hwnd"]) != 0 || IsFullscreenWindow(win["hwnd"]))
                continue
        } catch {
            continue
        }
        
        ; === ICON ZONE BARRIER: unconditional, runs before all protections ===
        ; Treats icon zones as "pillars" — isolated obstacles with free space
        ; on ALL four sides. Windows are pushed to the shortest valid side
        ; that clears the zone, whether that's right, left, down, or up.
        if (Config["DesktopIconRepulsion"] && g["_iconZones"].Length > 0) {
            try {
                ; Use GetWindowRect (kernel call, no messages) instead of
                ; WinGetPos (sends WM_GETMINMAXINFO — can block Electron apps)
                winRect := Buffer(16, 0)
                if (!DllCall("GetWindowRect", "Ptr", win["hwnd"], "Ptr", winRect))
                    continue
                zx := NumGet(winRect, 0, "Int")
                zy := NumGet(winRect, 4, "Int")
                zw := NumGet(winRect, 8, "Int") - zx
                zh := NumGet(winRect, 12, "Int") - zy
                if (zw <= 0 || zh <= 0)
                    continue
                zxR := zx + zw
                zyB := zy + zh

                ; Screen bounds — use virtual desktop for multimonitor expanse,
                ; otherwise per-monitor work area
                if (Config["MultimonitorExpanse"]) {
                    vb := GetVirtualDesktopBounds()
                    bzL := vb["Left"]
                    bzT := vb["Top"]
                    bzR := vb["Right"]
                    bzB := vb["Bottom"]
                } else {
                    SafeMonitorGetWorkArea(win["monitor"], &bzL, &bzT, &bzR, &bzB)
                }
                maxX := bzR - zw
                maxY := bzB - zh

                ; Union of all overlapping icon zones into one pillar rect
                pLeft := 999999.0, pRight := -999999.0
                pTop := 999999.0, pBottom := -999999.0
                anyOverlap := false
                for zone in g["_iconZones"] {
                    if (zone["left"] < zxR && zone["right"] > zx && zone["top"] < zyB && zone["bottom"] > zy) {
                        pLeft := Min(pLeft, zone["left"])
                        pRight := Max(pRight, zone["right"])
                        pTop := Min(pTop, zone["top"])
                        pBottom := Max(pBottom, zone["bottom"])
                        anyOverlap := true
                    }
                }

                if (anyOverlap) {
                    ; Build list of candidate exit pushes: [newX, newY, dist]
                    candidates := []

                    ; Push RIGHT: window's left edge at pillar's right edge
                    nxR := pRight
                    nyR := zy
                    distR := nxR - zx  ; + means moving right
                    if (nxR <= maxX && nyR >= bzT && nyR <= maxY)
                        candidates.Push(Map("x", nxR, "y", nyR, "dist", Abs(distR), "dir", "R"))

                    ; Push LEFT: window's right edge at pillar's left edge
                    nxL := pLeft - zw
                    nyL := zy
                    distL := zx - nxL  ; + means moving left
                    if (nxL >= bzL && nyL >= bzT && nyL <= maxY)
                        candidates.Push(Map("x", nxL, "y", nyL, "dist", Abs(distL), "dir", "L"))

                    ; Push DOWN: window's top edge at pillar's bottom edge
                    nxD := zx
                    nyD := pBottom
                    distD := nyD - zy  ; + means moving down
                    if (nyD <= maxY && nxD >= bzL && nxD <= maxX)
                        candidates.Push(Map("x", nxD, "y", nyD, "dist", Abs(distD), "dir", "D"))

                    ; Push UP: window's bottom edge at pillar's top edge
                    nxU := zx
                    nyU := pTop - zh
                    distU := zy - nyU  ; + means moving up
                    if (nyU >= bzT && nxU >= bzL && nxU <= maxX)
                        candidates.Push(Map("x", nxU, "y", nyU, "dist", Abs(distU), "dir", "U"))

                    if (candidates.Length > 0) {
                        ; Pick the candidate with the smallest displacement
                        best := candidates[1]
                        for c in candidates {
                            if (c["dist"] < best["dist"])
                                best := c
                        }
                        zx := best["x"]
                        zy := best["y"]
                    } else {
                        ; No valid full-clear direction — window is too large
                        ; to fit around the pillar. Push to whichever side
                        ; has the most room, clamping to screen bounds.
                        roomRight := bzR - pRight
                        roomLeft  := pLeft - bzL
                        roomDown  := bzB - pBottom
                        roomUp   := pTop - bzT
                        if (roomRight >= roomLeft && roomRight >= roomDown && roomRight >= roomUp) {
                            zx := Min(pRight, maxX)
                        } else if (roomLeft >= roomRight && roomLeft >= roomDown && roomLeft >= roomUp) {
                            zx := Max(pLeft - zw, bzL)
                        } else if (roomDown >= roomUp) {
                            zy := Min(pBottom, maxY)
                        } else {
                            zy := Max(pTop - zh, bzT)
                        }
                        zx := Max(bzL, Min(zx, maxX))
                        zy := Max(bzT, Min(zy, maxY))
                    }

                    MoveWindowAPI(win["hwnd"], zx, zy)
                    win["x"] := zx
                    win["y"] := zy
                    win["targetX"] := zx
                    win["targetY"] := zy
                    win["vx"] := 0
                    win["vy"] := 0
                    static zLogTick := 0
                    if (A_TickCount - zLogTick > 2000) {
                        zLogTick := A_TickCount
                        DebugLog("IconBarrier — pushed win=0x{:X} to ({:.0f},{:.0f})", win["hwnd"], zx, zy)
                    }
                    ; Skip normal pipeline — barrier already moved the window.
                    continue
                }
            } catch {
                ; Barrier error — fall through
            }
        }

        ; CRITICAL: Never move the active window when not dragging
        ; When dragging, never move the window being dragged
        if ((win["hwnd"] == g["ActiveWindow"] && !isDragging) || win["hwnd"] == draggedHwnd)
            continue
        
        isManuallyLocked := (win.Has("ManualLock") && A_TickCount < win["ManualLock"])
        if (isManuallyLocked)
            continue
        
        isBeingSnapped := g["SnapInProgress"].Has(win["hwnd"]) && A_TickCount < g["SnapInProgress"][win["hwnd"]]
        if (isBeingSnapped)
            continue

        ; Safely get monitor bounds
        try {
            if (Config["MultimonitorExpanse"]) {
                ; Use virtual desktop bounds for multimonitor expanse
                virtualBounds := GetVirtualDesktopBounds()
                monLeft := virtualBounds["Left"]
                monTop := virtualBounds["Top"] + Config["MinMargin"]
                monRight := virtualBounds["Right"] - win["width"]
                monBottom := virtualBounds["Bottom"] - Config["MinMargin"] - win["height"]
            } else {
                ; Work area already excludes the taskbar on any side (top/bottom/left/right)
                ; for both native Windows taskbar and AppBar replacements like RetroBar.
                SafeMonitorGetWorkArea(win["monitor"], &mL, &mT, &mR, &mB)
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

        hwnd := win["hwnd"]
        newX := win.Has("targetX") ? win["targetX"] : win["x"]
        newY := win.Has("targetY") ? win["targetY"] : win["y"]

        if (!hwndPos.Has(hwnd))
            continue

        ; Clear smoothing state for windows that were just dragged to prevent lag
        if (win.Has("JustDragged") && A_TickCount - win["JustDragged"] < 100) {
            if (smoothPos.Has(hwnd)) {
                smoothPos.Delete(hwnd)
            }
            if (lastPositions.Has(hwnd)) {
                lastPositions.Delete(hwnd)
            }
            win.Delete("JustDragged")
        }

        ; Skip processing if window is already at its target position
        ; This prevents unnecessary micro-adjustments for stable windows
        currentX := hwndPos[hwnd].x
        currentY := hwndPos[hwnd].y

        ; --- External move resync (prevents snap-back / sudden rearranging jumps) ---
        ; If a window was moved by the user/OS/app without our state tracking catching up,
        ; immediately sync physics state to the real position and clear momentum.
        ; This keeps the system behaving like a continuous flow instead of teleporting toward stale targets.
        stateX := win.Has("x") ? win["x"] : currentX
        stateY := win.Has("y") ? win["y"] : currentY
        if (Abs(currentX - stateX) > 12 || Abs(currentY - stateY) > 12) {
            ; If we *didn't* just move it ourselves very recently, treat this as authoritative external movement.
            if (!lastPositions.Has(hwnd) || Abs(currentX - lastPositions[hwnd].x) > 6 || Abs(currentY - lastPositions[hwnd].y) > 6) {
                win["x"] := currentX
                win["y"] := currentY
                win["targetX"] := currentX
                win["targetY"] := currentY
                win["vx"] := 0
                win["vy"] := 0
                smoothPos[hwnd] := { x: currentX, y: currentY }
                lastPositions[hwnd] := { x: currentX, y: currentY }
                continue
            }
        }

        if (Abs(newX - currentX) < 0.5 && Abs(newY - currentY) < 0.5) {
            ; Clear smoothing state for windows at target to prevent accumulated drift
            if (smoothPos.Has(hwnd)) {
                smoothPos.Delete(hwnd)
            }
            continue
        }

        if (!smoothPos.Has(hwnd)) {
            ; Initialize smoothPos with current position to prevent jumping
            smoothPos[hwnd] := { x: hwndPos[hwnd].x, y: hwndPos[hwnd].y }
            ; Also initialize lastPositions to prevent immediate movement
            if (!lastPositions.Has(hwnd))
                lastPositions[hwnd] := { x: hwndPos[hwnd].x, y: hwndPos[hwnd].y }
        }

        ; Increase smoothing for less jitter
        ; Use less smoothing for Electron apps to make them more responsive
        alpha := IsElectronApp(hwnd) ? 0.45 : 0.18  ; Higher alpha = more responsive movement
        smoothPos[hwnd].x := smoothPos[hwnd].x + (newX - smoothPos[hwnd].x) * alpha
        smoothPos[hwnd].y := smoothPos[hwnd].y + (newY - smoothPos[hwnd].y) * alpha

        ; Gentle boundary enforcement (soft collision with edges)
        edgeBuffer := 10  ; Reduced to allow windows closer to edges
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
        ; Only hard clamp when far off-screen; otherwise let the soft boundary forces resolve smoothly.
        if (smoothPos[hwnd].x < monLeft - 200 || smoothPos[hwnd].x > monRight + 200)
            smoothPos[hwnd].x := Max(monLeft, Min(smoothPos[hwnd].x, monRight))
        if (smoothPos[hwnd].y < monTop - 200 || smoothPos[hwnd].y > monBottom + 200)
            smoothPos[hwnd].y := Max(monTop, Min(smoothPos[hwnd].y, monBottom))

        if (!lastPositions.Has(hwnd))
            lastPositions[hwnd] := { x: hwndPos[hwnd].x, y: hwndPos[hwnd].y }

        ; Increase threshold to avoid micro-movements and reduce jumpiness
        if (Abs(smoothPos[hwnd].x - lastPositions[hwnd].x) >= 1.5 || Abs(smoothPos[hwnd].y - lastPositions[hwnd].y) >= 1.5) {
            moveBatch.Push({ hwnd: hwnd, x: smoothPos[hwnd].x, y: smoothPos[hwnd].y })
            lastPositions[hwnd].x := smoothPos[hwnd].x
            lastPositions[hwnd].y := smoothPos[hwnd].y
            win["x"] := smoothPos[hwnd].x
            win["y"] := smoothPos[hwnd].y
        }
    }
    ; Throttled: accumulate every call (even zero-move ticks for accuracy),
    ; flush a single summary line once per second instead of per-tick.
    _awmTicks += 1
    if (moveBatch.Length > 0)
        _awmTotalMoves += moveBatch.Length
    if (A_TickCount - _awmLastLog >= 1000) {
        DebugLog("ApplyMovements — {} moves across {} ticks (avg {:.1f}/tick)",
            _awmTotalMoves, _awmTicks, _awmTicks > 0 ? _awmTotalMoves / _awmTicks : 0)
        _awmLastLog := A_TickCount
        _awmTicks := 0
        _awmTotalMoves := 0
    }
    _PerfEnd("AWM", p)

    for move in moveBatch {
        try MoveWindowAPI(move.hwnd, move.x, move.y)
    }
    } catch as e {
        DebugLog("ApplyWindowMovements timer crashed: {}", e.Message)
        ; Any exception in the movement loop is caught to prevent
        ; the AHK v2 timer from silently stopping forever.
    }
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

            ; Work area already excludes the taskbar on any side (top/bottom/left/right)
            ; for both native Windows taskbar and AppBar replacements like RetroBar.
            SafeMonitorGetWorkArea(pos1["monitor"], &mL, &mT, &mR, &mB)

            newX := Max(mL + Config["MinMargin"],
                       Min(pos1["x"], mR - pos1["width"] - Config["MinMargin"]))
            newY := Max(mT + Config["MinMargin"],
                       Min(pos1["y"], mB - pos1["height"] - Config["MinMargin"]))

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
                    SafeMonitorGetWorkArea(pos["monitor"], &mL, &mT, &mR, &mB)
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
    global g, Config, g_DebugProtected
    static forceMultipliers := Map("normal", 1.0, "chaos", 0.6)
    static lastState := "normal"
    static transitionTime := 300
    static lastFocusCheck := 0

    try {  ; Wrap entire timer body — any exception would silently kill this timer in AHK v2

    p := _PerfStart()

    g["_hbPhysics"] := A_TickCount  ; HealthMonitor heartbeat

    ; One-time diagnostic: confirm physics loop is alive with window + icon counts
    static diagLogged := false
    if (!diagLogged && g["Windows"].Length > 0) {
        diagLogged := true
        DebugLog("PhysicsLoop — {} windows tracked, {} icon obstacles loaded", g["Windows"].Length, g["DesktopIconRects"].Length)
        ; Lock in protected entries — startup logs will never be trimmed
        g_DebugProtected := g_DebugLog.Length
    }

    ; Cache expensive per-tick values ONCE so child functions don't recompute N times
    ; menuParent: would be called N+2 times otherwise (each iterates ALL system windows!)
    ; draggedHwnd: would be called N+4 times (each does GetKeyState+MouseGetPos+DllCall)
    menuParent := GetOpenDropdownMenuParent()
    g["_menuParent"] := menuParent

    try {
        g["_draggedHwnd"] := GetDraggedManagedWindow()
    } catch {
        g["_draggedHwnd"] := 0
    }

    ; Desktop icon grid is cached permanently — no periodic refresh needed
    ; (Grid doesn't change unless user rearranges icons, which requires script restart)

    ; Keep physics calculations running during drag to allow dragged window to push other windows
    ; The dragged window itself will be protected from movement in CalculateWindowForces and ApplyWindowMovements

    ; Update active window detection periodically
    if (A_TickCount - lastFocusCheck > 250) {  ; Check every 250ms
        try {
            focusedWindow := WinExist("A")
            isManagedWindow := false
            if (focusedWindow) {
                ; Check if the focused window is one of our managed windows
                for win in g["Windows"] {
                    if (win["hwnd"] == focusedWindow) {
                        isManagedWindow := true
                        break
                    }
                }
                
                ; CRITICAL: If this is a managed window, it should IMMEDIATELY become the active window
                ; The currently active window should NEVER be affected by physics or arrangement
                if (isManagedWindow && focusedWindow != g["ActiveWindow"]) {
                    g["ActiveWindow"] := focusedWindow
                    g["LastUserMove"] := A_TickCount  ; Reset timeout when focus changes
                }
            }

            ; Use cached drag state (computed once per tick)
            draggedCheck := g["_draggedHwnd"]
            if (!isManagedWindow && g["ActiveWindow"] != 0 && draggedCheck == 0) {
                g["ActiveWindow"] := 0
            }

            ; Clear active window ONLY if timeout expired and it's no longer focused
            ; CRITICAL: Never clear ActiveWindow until the full UserMoveTimeout has elapsed
            ; This ensures user-placed windows stay exactly where placed until timeout
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
        if (menuParent && win["hwnd"] == menuParent) {
            win["vx"] := 0
            win["vy"] := 0
            continue
        }
        try {
            CalculateWindowForces(win, g["Windows"])
            currentEnergy += win["vx"]**2 + win["vy"]**2
        } catch as e {
            DebugLog("CalculateDynamicLayout — force calc failed for window 0x{:X}: {}", win["hwnd"], e.Message)
            ; Skip this window if force calculation fails — don't crash the timer
            win["vx"] := 0
            win["vy"] := 0
        }
    }
    g["SystemEnergy"] := Lerp(g["SystemEnergy"], currentEnergy, 0.1)

    ; Normalise energy to window count for consistent state detection
    normEnergy := g["SystemEnergy"] / Max(g["Windows"].Length, 1) / 10000

    ; --- Icon physics: treat icons as individual bodies (if enabled) ---
    ; Zone repulsion in CalculateWindowForces already provides O(1) obstacle
    ; behaviour per window. Per-icon physics (O(n²) inter-icon + O(n×w) recoil)
    ; is only viable for real desktop icons (~20-50). The virtual fallback grid
    ; can produce 200 bodies — skipping prevents ~21k ops/tick performance hit.
    if (Config["DesktopIconPhysics"] && Config["DesktopIconRepulsion"] && g["DesktopIconRects"].Length > 0
        && g["DesktopIconRects"].Length <= 50) {
        ProcessIconPhysics(g["DesktopIconRects"], g["Windows"])
    }

    ; State machine for natural motion transitions
    newState := (normEnergy > Config["Stabilization"]["EnergyThreshold"] * 2) ? "chaos" : "normal"

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

    ; Use cached drag state (computed once per tick)
    draggedCheck := g["_draggedHwnd"]
    if (draggedCheck != 0) {
        currentMultiplier := 1.0
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

    ; Limit-cycle detection: if energy is stable for >3s with no drag, force-settle
    ; Prevents indefinite oscillation (one window bouncing between force sources)
    static settleEnergy := 0.0
    static settleTick := 0
    if (normEnergy > 0.001 && normEnergy < 0.5 && g["_draggedHwnd"] == 0 && g["Windows"].Length > 1) {
        if (Abs(normEnergy - settleEnergy) < 0.0005) {
            if (settleTick == 0)
                settleTick := A_TickCount
            else if (A_TickCount - settleTick > 3000) {
                ; Energy hasn't changed meaningfully in 3s — force-settle all windows
                for win in g["Windows"] {
                    win["vx"] := 0
                    win["vy"] := 0
                }
                ; Drop energy measurement so state can transition to normal
                g["SystemEnergy"] := 1.0
                DebugLog("Settle — limit cycle detected, zeroed velocities (energy was {:.4f})", normEnergy)
                settleTick := 0
                settleEnergy := 0.0
            }
        } else {
            settleEnergy := normEnergy
            settleTick := 0
        }
    } else {
        settleEnergy := 0.0
        settleTick := 0
    }

    ; Gentle collision resolution (no rigid partitioning)
    ; Skip when system is settled (low energy, no drag) — saves ~2.5N² pair checks
    if (g["Windows"].Length > 1 && (g["SystemEnergy"] > 0.5 || g["_draggedHwnd"] != 0)) {
        ResolveFloatingCollisions(g["Windows"])
    }

    ; Periodic tick log (every ~30 ticks ≈ 0.5s at 16ms) — shows engine is alive
    static tickCounter := 0
    tickCounter += 1
    if (Mod(tickCounter, 30) == 0) {
        dh := g["_draggedHwnd"]
        DebugLog("Physics tick — {} windows, energy={:.4f}, state={}, dragHwnd=0x{:X}"
            , g["Windows"].Length, normEnergy
            , newState
            , dh ? dh : 0)
    }

    lastState := newState
    _PerfEnd("CDL", p)
    } catch as crashErr {
        DebugLog("CDL crashed: {} [{}:{}]", crashErr.Message, crashErr.What, crashErr.Line)
        ; Any exception in the physics loop is caught to prevent
        ; the AHK v2 timer from silently stopping forever.
    }
}

; New floating collision system with chain-effect propagation
; Runs multiple iterative passes so that when window A pushes B,
; B's accumulated velocity causes it to push C in the same tick,
; creating a realistic chain reaction through window clusters.
; Every overlapping pair gets a guaranteed seeded diagonal bias
; to prevent corner/edge stuckness from perfect symmetry.
ResolveFloatingCollisions(windows) {
    global Config, g
    pr := _PerfStart()
    
    ; Use cached drag state (computed once per tick in CalculateDynamicLayout)
    draggedHwnd := g["_draggedHwnd"]
    isDragging := (draggedHwnd != 0)

    ; Number of chain-propagation passes (reduced from 5 to 3 — primary
    ; separation is handled by CalculateWindowForces repulsion)
    chainPasses := 3
    
    ; Pass weights redistributed to sum to 1.0 over 3 passes
    passWeights := [0.40, 0.35, 0.25]
    
    ; Pre-compute protection state for all windows (doesn't change across passes)
    protection := Map()
    for win in windows {
        try {
            if (WinGetMinMax("ahk_id " win["hwnd"]) != 0 || IsFullscreenWindow(win["hwnd"])) {
                protection[win["hwnd"]] := "skip"
                continue
            }
        } catch {
            protection[win["hwnd"]] := "skip"
            continue
        }
        
        isManuallyLocked := (win.Has("ManualLock") && A_TickCount < win["ManualLock"])
        isActive := (win["hwnd"] == g["ActiveWindow"])
        isBeingSnapped := g["SnapInProgress"].Has(win["hwnd"]) && A_TickCount < g["SnapInProgress"][win["hwnd"]]
        
        if (isManuallyLocked || (isActive && !isDragging) || isBeingSnapped)
            protection[win["hwnd"]] := "protected"
        else
            protection[win["hwnd"]] := "free"
    }
    
    ; Pre-compute per-pair diagonal un-stick directions (deterministic, seeded)
    ; so every overlapping pair has a guaranteed escape vector.
    pairBias := Map()
    for i, win1 in windows {
        for j, win2 in windows {
            if (i >= j)
                continue
            dir := GetSeededPairDirection(win1, win2)
            key := win1["hwnd"] "_" win2["hwnd"]
            pairBias[key] := dir
        }
    }
    
    ; Multi-pass chain propagation
    loop chainPasses {
        passIdx := A_Index
        passWeight := passWeights[passIdx]
        
        anyChanges := false
        
        for i, win1 in windows {
            if (protection[win1["hwnd"]] == "skip")
                continue
            
            isProtected1 := (protection[win1["hwnd"]] == "protected")
            
            ; Apply a virtual position offset based on accumulated velocity
            ; so subsequent passes can detect new collisions caused by prior pushes.
            probeX1 := win1["x"] + win1["vx"] * 0.3
            probeY1 := win1["y"] + win1["vy"] * 0.3
                
            for j, win2 in windows {
                if (i >= j)
                    continue
                
                if (protection[win2["hwnd"]] == "skip")
                    continue
                
                isProtected2 := (protection[win2["hwnd"]] == "protected")
                
                ; No need to process if both windows are protected.
                if (isProtected1 && isProtected2)
                    continue
                
                ; Use probed positions for chain-aware overlap detection
                probeX2 := win2["x"] + win2["vx"] * 0.3
                probeY2 := win2["y"] + win2["vy"] * 0.3

                ; Check for overlap using probed positions
                overlapX := Max(0, Min(probeX1 + win1["width"], probeX2 + win2["width"]) - Max(probeX1, probeX2))
                overlapY := Max(0, Min(probeY1 + win1["height"], probeY2 + win2["height"]) - Max(probeY1, probeY2))

                if (overlapX > Config["CollisionOverlapThreshold"] && overlapY > Config["CollisionOverlapThreshold"]) {
                    centerX1 := probeX1 + win1["width"]/2
                    centerY1 := probeY1 + win1["height"]/2
                    centerX2 := probeX2 + win2["width"]/2
                    centerY2 := probeY2 + win2["height"]/2

                    dx := centerX1 - centerX2
                    dy := centerY1 - centerY2

                    ; --- GUARANTEED DIAGONAL UN-STICK ---
                    ; When centers are near-identical OR the separation vector is tiny
                    ; (corner/edge stuck), inject the seeded diagonal direction as a
                    ; floor bias. This prevents any perfect-overlap deadlock.
                    biasKey := win1["hwnd"] "_" win2["hwnd"]
                    bias := pairBias[biasKey]
                    
                    ; Blend in diagonal bias: stronger when dx/dy are small (stuck),
                    ; weaker when the natural separation direction is already clear.
                    centerDist := Sqrt(dx*dx + dy*dy)
                    if (centerDist < 10.0) {
                        ; Heavily stuck: diagonal bias dominates
                        blendRatio := 1.0 - (centerDist / 10.0)
                        dx := dx * (1.0 - blendRatio) + bias[1] * blendRatio * 10.0
                        dy := dy * (1.0 - blendRatio) + bias[2] * blendRatio * 10.0
                    } else {
                        ; Lightly add ~15% diagonal bias to prevent re-sticking
                        dx := dx + bias[1] * 2.0
                        dy := dy + bias[2] * 2.0
                    }

                    dist := Max(Sqrt(dx*dx + dy*dy), 1)

                    ; Stronger separation for small windows or high overlap
                    overlapArea := overlapX * overlapY
                    avgSize := (win1["width"] * win1["height"] + win2["width"] * win2["height"]) / 2
                    overlapRatio := overlapArea / Max(avgSize, 1)

                    ; Base separation force with a guaranteed minimum floor
                    ; so even tiny overlaps get a meaningful push.
                    baseForce := (overlapX + overlapY) * Config["PairSeparationBase"]
                    scaledForce := baseForce * (1 + overlapRatio * Config["PairSeparationOverlapScale"])
                    
                    ; Minimum force floor: never push weaker than this regardless of overlap size.
                    ; This prevents cranked forces from producing near-zero pushes on small overlaps.
                    minForce := Config["PairSeparationBase"] * 80.0
                    separationForce := Max(scaledForce, minForce)
                    separationForce *= passWeight

                    ; Small window boost
                    if (win1["width"] < Config["SmallWindowThresholdW"] || win1["height"] < Config["SmallWindowThresholdH"] || win2["width"] < Config["SmallWindowThresholdW"] || win2["height"] < Config["SmallWindowThresholdH"]) {
                        separationForce *= Config["PairSmallWindowBoost"]
                    }

                    if (!isProtected1) {
                        win1["vx"] += dx * separationForce / dist
                        win1["vy"] += dy * separationForce / dist
                        anyChanges := true
                    }
                    if (!isProtected2) {
                        win2["vx"] -= dx * separationForce / dist
                        win2["vy"] -= dy * separationForce / dist
                        anyChanges := true
                    }
                }
            }
        }
        
        ; Early exit if no windows received force this pass (chain settled)
        if (!anyChanges)
            break
    }
    _PerfEnd("RFC", pr)
}


;;MANUAL WINDOW HANDLING
AddManualWindowBorder(hwnd) {
    global Config, g
    try {
        ; Skip if already exists
        if (g["ManualWindows"].Has(hwnd))
            return

        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)

        ; Create a single visible red border GUI around the window
        ; Use solid red (FF0000) with high opacity
        borderGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20000000")
        borderGui.BackColor := "FF0000"  ; Solid red
        
        ; Show border extending 5px outside window on all sides
        borderGui.Show("x" x-5 " y" y-5 " w" w+10 " h" h+10 " NA")
        
        ; Set to near-opaque so it's clearly visible
        WinSetTransparent(200, borderGui.Hwnd)

        ; Store reference
        g["ManualWindows"][hwnd] := Map(
            "gui", borderGui,
            "expire", A_TickCount + Config["ManualLockDuration"]
        )

    } catch as Err {
        OutputDebug("Border Error: " Err.Message "`n" Err.What "`n" Err.Extra)
    }
}

RemoveManualWindowBorder(hwnd) {
    global g
    try {
        if (g["ManualWindows"].Has(hwnd)) {
            data := g["ManualWindows"][hwnd]
            if (data.Has("gui")) {
                data["gui"].Destroy()
            }
            g["ManualWindows"].Delete(hwnd)
        }
    }
}

UpdateManualBorders() {
    global g, Config
    for hwnd, data in g["ManualWindows"].Clone() {
        try {
            ; Remove expired locks
            if (A_TickCount > data["expire"]) {
                RemoveManualWindowBorder(hwnd)
                continue
            }

            ; Update border position if window exists
            if (WinExist("ahk_id " hwnd) && data.Has("gui")) {
                WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
                ; Border extends 5px outside the window on all sides
                data["gui"].Show("x" x-5 " y" y-5 " w" w+10 " h" h+10 " NA")
            }
        }
    }
}

ClearManualFlags() {
    global g, Config
    for hwnd, data in g["ManualWindows"].Clone() {
        if (A_TickCount > data["expire"]) {
            ; LOCK STATE AWARENESS: Record that this window's lock is being disabled
            ; This allows physics engine to resume normal management
            for win in g["Windows"] {
                if (win["hwnd"] == hwnd) {
                    ; Mark that lock was just lost for any dependent systems
                    win["LockLostAt"] := A_TickCount
                    win.Delete("ManualLock")
                    win.Delete("IsManual")
                    break
                }
            }
            RemoveManualWindowBorder(hwnd)
        }
    }
}

DragWindow() {
    global g, Config

    ; Thread-health guard: if a previous drag thread is still marked active
    ; but hasn't updated in 30 seconds, force-reset (prevents permanent stall)
    if (g["_dragThreadActive"]) {
        if (A_TickCount - g["_dragThreadStart"] > 30000) {
            DebugLog("DragFailsafe — previous drag thread stale ({}ms), force-resetting", A_TickCount - g["_dragThreadStart"])
            g["_dragThreadActive"] := false
            g["_dragThreadStart"] := 0
            g["_dragFailsafeCount"] += 1
            ReleaseHighResTimer()
        } else {
            return  ; Previous drag still running — don't re-enter
        }
    }

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

    g["_dragThreadActive"] := true
    g["_dragThreadStart"] := A_TickCount
    g["ActiveWindow"] := winID
    g["LastUserMove"] := A_TickCount
    
    ; Keep physics running during drag to allow dragged window to push other windows
    ; The physics will skip the dragged window itself but apply to all others

    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " winID)
        ; CRITICAL: Store original window dimensions to prevent any reshaping
        origW := w
        origH := h
        winCenterX := x + w/2
        winCenterY := y + h/2
        monNum := MonitorGetFromPoint(winCenterX, winCenterY)
        resolvedMon := SafeMonitorGet(monNum, &mL, &mT, &mR, &mB)
        if (resolvedMon)
            monNum := resolvedMon

        ; Check if this window was already locked before drag
        wasPreLocked := false
        for win in g["Windows"] {
            if (win["hwnd"] == winID) {
                ; Check if already has active ManualLock
                wasPreLocked := (win.Has("ManualLock") && A_TickCount < win["ManualLock"])
                
                ; Don't auto-lock Electron apps - they update their UI frequently
                if (!IsElectronApp(winID)) {
                    ; Temporarily clear manual lock while dragging
                    if (wasPreLocked) {
                        win.Delete("ManualLock")
                    }
                    win["IsManual"] := true
                    win["vx"] := 0
                    win["vy"] := 0
                    AddManualWindowBorder(winID)
                }
                win["monitor"] := monNum
                break
            }
        }

        offsetX := mx - x
        offsetY := my - y

        AcquireHighResTimer()

        while GetKeyState("LButton", "P") {
            MouseGetPos(&nx, &ny)
            newX := nx - offsetX
            newY := ny - offsetY

            ; Update monitor bounds based on current mouse position for seamless multi-monitor dragging
            ; This allows windows to be dragged freely across all monitors
            currentMonNum := MonitorGetFromPoint(nx, ny)
            if (currentMonNum) {
                try {
                    MonitorGet currentMonNum, &currML, &currMT, &currMR, &currMB
                    ; Use current monitor bounds for clamping, using original dimensions
                    newX := Max(currML + Config["MinMargin"], Min(newX, currMR - origW - Config["MinMargin"]))
                    newY := Max(currMT + Config["MinMargin"], Min(newY, currMB - origH - Config["MinMargin"]))
                } catch {
                    ; Fallback to original monitor bounds
                    newX := Max(mL + Config["MinMargin"], Min(newX, mR - origW - Config["MinMargin"]))
                    newY := Max(mT + Config["MinMargin"], Min(newY, mB - origH - Config["MinMargin"]))
                }
            } else {
                ; Fallback to original monitor bounds
                newX := Max(mL + Config["MinMargin"], Min(newX, mR - origW - Config["MinMargin"]))
                newY := Max(mT + Config["MinMargin"], Min(newY, mB - origH - Config["MinMargin"]))
            }

            ; --- Hard zone barrier during drag: prevent entering icon zones ---
            if (Config["DesktopIconRepulsion"] && g["_iconZones"].Length > 0) {
                checkMon := currentMonNum ? currentMonNum : monNum
                if (checkMon == MonitorGetPrimary()) {
                    cx := newX
                    cy := newY
                    cw := origW
                    ch := origH
                    for zone in g["_iconZones"] {
                        zL := zone["left"], zR := zone["right"], zT := zone["top"], zB := zone["bottom"]
                        if (!(zL < cx + cw && zR > cx && zT < cy + ch && zB > cy))
                            continue
                        dR := zR - cx
                        dL := cx + cw - zL
                        dD := zB - cy
                        dU := cy + ch - zT
                        best := dR
                        dir := "R"
                        if (dL < best) {
                            best := dL
                            dir := "L"
                        }
                        if (dD < best) {
                            best := dD
                            dir := "D"
                        }
                        if (dU < best) {
                            best := dU
                            dir := "U"
                        }
                        if (dir == "R")
                            cx := zR
                        else if (dir == "L")
                            cx := zL - cw
                        else if (dir == "D")
                            cy := zB
                        else
                            cy := zT - ch
                    }
                    newX := cx
                    newY := cy
                }
            }

            ; CRITICAL: Explicitly pass original dimensions to prevent any reshaping
            try WinMove(newX, newY, origW, origH, "ahk_id " winID)
            
            ; AUTO-EXTEND LOCK: Refresh lock timeout during active drag to prevent expiry mid-interaction
            for win in g["Windows"] {
                if (win["hwnd"] == winID) {
                    if (win.Has("ManualLock")) {
                        win["ManualLock"] := A_TickCount + Config["ManualLockDuration"]
                    }
                    break
                }
            }
            
            ; Update border position during drag if window is locked
            if (g["ManualWindows"].Has(winID)) {
                data := g["ManualWindows"][winID]
                if (data.Has("gui")) {
                    ; Border extends 5px outside the window on all sides
                    data["gui"].Show("x" newX-5 " y" newY-5 " w" origW+10 " h" origH+10 " NA")
                }
            }
            
            ; CRITICAL: Verify window size hasn't changed (safety check)
            ; This catches any accidental resizing and immediately corrects it
            try {
                WinGetPos(,, &currW, &currH, "ahk_id " winID)
                if (currW != origW || currH != origH) {
                    ; Window was accidentally resized - restore original size immediately
                    WinMove(,, origW, origH, "ahk_id " winID)
                }
            }

            for win in g["Windows"] {
                if (win["hwnd"] == winID) {
                    win["x"] := newX
                    win["y"] := newY
                    win["targetX"] := newX
                    win["targetY"] := newY
                    win["lastMove"] := A_TickCount
                    ; CRITICAL: Zero velocity on every frame during drag to prevent physics interference
                    win["vx"] := 0
                    win["vy"] := 0
                    ; Update monitor tracking based on window position
                    if (currentMonNum) {
                        win["monitor"] := currentMonNum
                    }
                    break
                }
            }

            Sleep(1)
        }
    }
    catch as dragErr {
        DebugLog("DragWindow — exception during drag: {}", dragErr.Message)
    }
    finally {
        g["_dragThreadActive"] := false
        g["_dragThreadStart"] := 0
        ReleaseHighResTimer()
    }

    ; Re-lock the window if it was pre-locked before the drag
    for win in g["Windows"] {
        if (win["hwnd"] == winID) {
            win["JustDragged"] := A_TickCount
            
            ; Force zero velocity and sync final position to ensure window stays exactly where user placed it
            win["vx"] := 0
            win["vy"] := 0
            
            ; Get the final actual position of the window
            try {
                WinGetPos(&finalX, &finalY, &finalW, &finalH, "ahk_id " winID)
                win["x"] := finalX
                win["y"] := finalY
                win["targetX"] := finalX
                win["targetY"] := finalY
            }
            
            ; Re-apply ManualLock if it was pre-locked, OR if set during drag
            ; This extends the lock timer on the newly positioned window
            if (wasPreLocked || win.Has("IsManual")) {
                win["ManualLock"] := A_TickCount + Config["ManualLockDuration"]
                win["IsManual"] := true
                AddManualWindowBorder(winID)
            }
            break
        }
    }

    ; Keep the window as active for longer to ensure it stays where placed
    ; Don't immediately reset to 0 - let it time out naturally
    g["LastUserMove"] := A_TickCount
    
    ; Physics were kept running during drag, so no need to resume them
}

ToggleArrangement() {
    global g
    g["ArrangementActive"] := !g["ArrangementActive"]
    if (g["ArrangementActive"]) {
        AcquireHighResTimer()
        UpdateWindowStates()
        SetTimerEx(CalculateDynamicLayout, Config["PhysicsTimeStep"])
        SetTimerEx(ApplyWindowMovements, Config["VisualTimeStep"])
        ShowTooltip("Window Arrangement: ON")
    } else {
        SetTimerEx(CalculateDynamicLayout, 0)
        SetTimerEx(ApplyWindowMovements, 0)
        ReleaseHighResTimer()
        ShowTooltip("Window Arrangement: OFF")
    }
    BuildFWDEMenus()
}

TogglePhysics() {
    global g
    g["PhysicsEnabled"] := !g["PhysicsEnabled"]
    if (g["PhysicsEnabled"]) {
        SetTimerEx(CalculateDynamicLayout, Config["PhysicsTimeStep"])
        ShowTooltip("Physics Engine: ON")
    } else {
        SetTimerEx(CalculateDynamicLayout, 0)
        ShowTooltip("Physics Engine: OFF")
    }
    BuildFWDEMenus()
}

ToggleMultimonitorExpanse() {
    global Config, g
    Config["MultimonitorExpanse"] := !Config["MultimonitorExpanse"]

    if (Config["MultimonitorExpanse"]) {
        ; Update monitor bounds to use virtual desktop
        g["Monitor"] := GetVirtualDesktopBounds()
        ShowTooltip("Multimonitor Expanse: ON - Windows can float across all monitors")
    } else {
        ; Revert to current monitor
        g["Monitor"] := GetCurrentMonitorInfo()
        ShowTooltip("Multimonitor Expanse: OFF - Windows confined to current monitor")
    }

    ; Force update of all window states to apply new boundaries
    if (g["ArrangementActive"]) {
        UpdateWindowStates()
    }
    BuildFWDEMenus()
}

ToggleIconRepulsion() {
    global Config, g
    Config["DesktopIconRepulsion"] := !Config["DesktopIconRepulsion"]
    if (Config["DesktopIconRepulsion"]) {
        ; Refresh icon grid from cache or probe
        newRects := GetDesktopIconRects()
        if (newRects.Length > 0)
            g["DesktopIconRects"] := newRects
        ShowTooltip("Icon Repulsion: ON (" g["DesktopIconRects"].Length " obstacles)")
    } else {
        g["DesktopIconRects"] := []
        g["_iconZones"] := []
        g["_iconZonesLive"] := false
        ShowTooltip("Icon Repulsion: OFF")
    }
    BuildFWDEMenus()
}

ToggleWindowLock() {
    global g, Config
    menuNeedsRefresh := true
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
            g["ActiveWindow"] := 0
            RemoveManualWindowBorder(focusedWindow)
            ShowTooltip("Window UNLOCKED - will move with physics")
        } else {
            ; Lock the window
            targetWin["ManualLock"] := A_TickCount + Config["ManualLockDuration"]
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
    if (menuNeedsRefresh)
        BuildFWDEMenus()
}

OptimizeWindowPositions() {
    global g, Config

    if (g["Windows"].Length <= 1) {
        ShowTooltip("Not enough windows to optimize")
        return
    }

    ; Get current monitor info
    monitor := GetCurrentMonitorInfo()
    if (!monitor.Count) {
        ShowTooltip("Could not get monitor information")
        return
    }

    ; Create a copy of windows for repositioning
    windowsToPlace := []
    for win in g["Windows"] {
        ; Skip locked or active windows
        isLocked := (win["hwnd"] == g["ActiveWindow"] ||
                    (win.Has("ManualLock") && A_TickCount < win["ManualLock"]))
        if (!isLocked) {
            windowsToPlace.Push(win)
        }
    }

    if (windowsToPlace.Length == 0) {
        ShowTooltip("All windows are locked - nothing to optimize")
        return
    }

    ; Manual sort by area (largest first)
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
    optimizedPositions := PackWindowsOptimally(windowsToPlace, monitor)

    ; Apply optimized positions
    repositionedCount := 0
    for i, win in windowsToPlace {
        if (optimizedPositions.Has(i)) {
            newPos := optimizedPositions[i]
            win["targetX"] := newPos["x"]
            win["targetY"] := newPos["y"]
            ; Add some velocity toward the target for smooth movement
            win["vx"] := (newPos["x"] - win["x"]) * 0.1
            win["vy"] := (newPos["y"] - win["y"]) * 0.1
            repositionedCount++
        }
    }

    ShowTooltip("Optimized " repositionedCount " window positions for better space utilization")

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

        ; CRITICAL: NEVER change window dimensions - windows should maintain their original size
        ; Place windows even if partially off-screen, or skip if they don't fit at all
        bestPos := FindBestPosition(win, placedWindows, monitor, gridSize, gridCols, gridRows)
        if (bestPos.Count > 0) {
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
        "gaps"                   ; Fill gaps between existing windows
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
                tempHeight := Max(80, monitor["Bottom"] - Config["MinMargin"] - pos["y"])
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
            margin := 20
            ; Top edge
            posX := useableLeft
            while (posX <= useableRight) {
                candidates.Push(Map("x", posX, "y", useableTop))
                posX += 80
            }
            ; Left edge
            posY := useableTop
            while (posY <= useableBottom) {
                candidates.Push(Map("x", useableLeft, "y", posY))
                posY += 80
            }
            ; Right edge
            posY := useableTop
            while (posY <= useableBottom) {
                candidates.Push(Map("x", useableRight, "y", posY))
                posY += 80
            }
            ; Bottom edge
            posX := useableLeft
            while (posX <= useableRight) {
                candidates.Push(Map("x", posX, "y", useableBottom))
                posX += 80
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
    }
    ; Optimize: Remove duplicate positions
    unique := Map()
    for pos in candidates {
        key := pos["x"] "," pos["y"]
        if !unique.Has(key)
            unique[key] := pos
    }
    ; Return all values as an array
    arr := []
    for _, v in unique
        arr.Push(v)

    ; Rotate candidate order by a per-window seed so identical windows don't
    ; always pick the same first available slot.
    if (arr.Length > 1) {
        seed := GetWindowPlacementSeed(window)
        startIdx := Mod(seed, arr.Length) + 1
        rotated := []
        Loop arr.Length {
            idx := Mod(startIdx + A_Index - 2, arr.Length) + 1
            rotated.Push(arr[idx])
        }
        arr := rotated
    }

    ; Add subtle diagonal variants first to improve de-stacking for same-size windows.
    if (arr.Length > 0 && Config["SeedDiagonalStep"] > 0) {
        offset := GetSeededDiagonalOffset(window)
        seededArr := []
        seededKeys := Map()
        maxSeeded := Min(arr.Length, 24)
        Loop maxSeeded {
            pos := arr[A_Index]
            sx := Clamp(pos["x"] + offset["dx"], useableLeft, useableRight)
            sy := Clamp(pos["y"] + offset["dy"], useableTop, useableBottom)
            key := sx "," sy
            if (!seededKeys.Has(key) && !unique.Has(key)) {
                seededKeys[key] := true
                seededArr.Push(Map("x", sx, "y", sy))
            }
        }

        if (seededArr.Length > 0) {
            merged := []
            for pos in seededArr
                merged.Push(pos)
            for pos in arr
                merged.Push(pos)
            return merged
        }
    }

    return arr
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

; Calculate force to move windows toward less crowded areas of the screen
CalculateSpaceSeekingForce(win, allWindows) {
    if (allWindows.Length <= 2)
        return Map()  ; Not enough windows to need space seeking

    ; Use work area so space-seeking never pushes windows under the taskbar.
    SafeMonitorGetWorkArea(win["monitor"], &mL, &mT, &mR, &mB)

    winCenterX := win["x"] + win["width"]/2
    winCenterY := win["y"] + win["height"]/2

    ; Calculate local density around this window
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
    bestDirection := FindLeastCrowdedDirection(win, allWindows, mL, mT, mR, mB)

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
    searchDistance := 300  ; How far to look ahead - increased for better space utilization

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
    influenceRadius := 200  ; Increased for better space distribution

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

WindowMoveHandler(wParam, lParam, msg, hwnd) {
    global g, Config
    try {  ; Harden against exceptions that could destabilise state

    ; Ignore move messages produced by our own physics/apply pipeline
    if ((g.Has("InternalMoveDepth") && g["InternalMoveDepth"] > 0) ||
        (g.Has("LastInternalMoveTick") && A_TickCount - g["LastInternalMoveTick"] < 60))
        return

    ; Only react to windows we actively manage
    targetWin := 0
    for win in g["Windows"] {
        if (win["hwnd"] == hwnd) {
            targetWin := win
            break
        }
    }
    if (!targetWin)
        return

    if (!g["ArrangementActive"])
        return

    Critical

    ; === FAST PATH: runs on every WM_MOVE to keep DragActive + position in sync ===
    isBeingDragged := GetKeyState("LButton", "P")
    if (isBeingDragged) {
        g["SnapInProgress"][hwnd] := A_TickCount + 2000
        g["DragActive"] := true   ; Activate drag physics pipeline for real-time repulsion
    } else {
        g["DragActive"] := false  ; Drag ended — deactivate
    }

    g["LastUserMove"] := A_TickCount
    g["ActiveWindow"] := hwnd

    try {
        if (WinGetMinMax("ahk_id " hwnd) != 0) {
            g["DragActive"] := false
            return
        }
    } catch {
        g["DragActive"] := false
        return
    }

    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        monNum := MonitorGetFromPoint(x + w/2, y + h/2)

        ; CRITICAL: Sync live drag position every WM_MOVE so physics sees real-time position
        targetWin["x"] := x
        targetWin["y"] := y
        targetWin["targetX"] := x
        targetWin["targetY"] := y
        targetWin["width"] := w
        targetWin["height"] := h
        targetWin["vx"] := 0
        targetWin["vy"] := 0
        targetWin["monitor"] := monNum
    } catch {
        g["DragActive"] := false
        return
    }

    ; === THROTTLED PATH: heavy work only every ResizeDelay ms ===
    if (A_TickCount - g["LastWMMoveHeavy"] < Config["ResizeDelay"])
        return
    g["LastWMMoveHeavy"] := A_TickCount

    ; Don't auto-lock Electron apps - they update their UI frequently
    if (!IsElectronApp(hwnd)) {
        targetWin["ManualLock"] := A_TickCount + Config["ManualLockDuration"]
        targetWin["IsManual"] := true
        AddManualWindowBorder(hwnd)
    }

    SetTimerEx(UpdateWindowStates, -Config["ResizeDelay"])
    } catch as wmErr {
        DebugLog("WindowMoveHandler — exception: {}", wmErr.Message)
    }
}

WindowSizeHandler(wParam, lParam, msg, hwnd) {
    global g, Config
    try {  ; Harden against exceptions that could destabilise state

    ; Ignore size messages produced by our own physics/apply pipeline
    if ((g.Has("InternalMoveDepth") && g["InternalMoveDepth"] > 0) ||
        (g.Has("LastInternalMoveTick") && A_TickCount - g["LastInternalMoveTick"] < 60))
        return

    ; Only react to windows we actively manage
    targetWin := 0
    for win in g["Windows"] {
        if (win["hwnd"] == hwnd) {
            targetWin := win
            break
        }
    }
    if (!targetWin)
        return

    if (!g["ArrangementActive"] || (A_TickCount - g["LastUserMove"] < Config["ResizeDelay"]))
        return

    Critical
    
    ; Windows Snap often resizes windows - extend protection time
    g["SnapInProgress"][hwnd] := A_TickCount + 2000  ; 2 second protection during/after snap
    
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

        ; Don't auto-lock Electron apps - they update their UI frequently
        if (!IsElectronApp(hwnd)) {
            targetWin["ManualLock"] := A_TickCount + Config["ManualLockDuration"]
            targetWin["IsManual"] := true
            targetWin["vx"] := 0
            targetWin["vy"] := 0
            AddManualWindowBorder(hwnd)
        }
        targetWin["monitor"] := monNum
    }
    catch {
        return
    }

    SetTimerEx(UpdateWindowStates, -Config["ResizeDelay"])
    } catch as wsErr {
        DebugLog("WindowSizeHandler — exception: {}", wsErr.Message)
    }
}

UpdateWindowStates() {
    global g, Config
    pu := _PerfStart()
    
    g["_hbWindowList"] := A_TickCount  ; HealthMonitor heartbeat
    
    ; CRITICAL: Skip rebuilding window list if user is actively dragging a window
    ; This prevents interference with user placement
    try {
        draggedCheck := GetDraggedManagedWindow()
    } catch {
        draggedCheck := 0
    }
    if (draggedCheck != 0)
        return
    
    ; CRITICAL: Skip if any window is currently being snapped by Windows
    ; Clean up expired snap states first — with type validation and stuck-entry failsafe
    oldestSnapAge := 0
    for hwnd, expireTime in g["SnapInProgress"].Clone() {
        ; Validate the value is a number; delete garbage entries immediately
        if (!IsNumber(expireTime) || A_TickCount > expireTime + 0) {
            g["SnapInProgress"].Delete(hwnd)
            continue
        }
        ; Calculate how long this entry has existed (protection is 2000ms)
        entryAge := A_TickCount - (expireTime - 2000)
        if (entryAge > oldestSnapAge)
            oldestSnapAge := entryAge
    }
    g["_snapOldestTick"] := oldestSnapAge
    ; Don't update if snap is still in progress — BUT with a hard 15s failsafe
    if (g["SnapInProgress"].Count > 0) {
        if (oldestSnapAge > 15000) {
            ; Failsafe: snap entries stuck >15s — force-clear to prevent permanent stall
            DebugLog("SnapFailsafe — {} stuck snap entries (oldest {}ms) force-cleared", g["SnapInProgress"].Count, oldestSnapAge)
            g["SnapInProgress"] := Map()
            g["_recoveryCount"] += 1
            g["_snapFailsafeCount"] += 1
        } else {
            return
        }
    }
    
    ; Get current monitor info or virtual desktop bounds
    monitor := Config["MultimonitorExpanse"] ? GetVirtualDesktopBounds() : GetCurrentMonitorInfo()
    ; Update window list
    g["Windows"] := GetVisibleWindows(monitor)
    ; Log window list refresh periodically (every ~4s at 250ms interval ≈ 16 ticks)
    static uwsCounter := 0
    uwsCounter += 1
    if (Mod(uwsCounter, 16) == 0) {
        DebugLog("WindowList — {} windows detected on monitor {}", g["Windows"].Length, monitor["Number"])
    }
    ; Update manual borders and clear expired flags
    UpdateManualBorders()
    ClearManualFlags()
    _PerfEnd("UWS", pu)
}

; --- Improved Taskbar Detection and Context Menu ---

global TaskbarMenu := Menu()
global DebugTaskbarMenu := Menu()
global DebugTrayMenu := Menu()

StatusText(isEnabled) {
    return isEnabled ? "enabled" : "disabled"
}

GetWindowLockStatusText() {
    global g
    try {
        hwnd := WinExist("A")
        if (!hwnd)
            return "n/a"

        for win in g["Windows"] {
            if (win["hwnd"] == hwnd) {
                isLocked := (win.Has("ManualLock") && A_TickCount < win["ManualLock"])
                return isLocked ? "enabled" : "disabled"
            }
        }
        return "n/a"
    }
    catch {
        return "n/a"
    }
}

BuildFWDEMenus() {
    global TaskbarMenu, DebugTaskbarMenu, DebugTrayMenu, g, Config, DebugMode

    arrangementStatus := StatusText(g["ArrangementActive"])
    physicsStatus := StatusText(g["PhysicsEnabled"])
    expanseStatus := StatusText(Config["MultimonitorExpanse"])
    debugStatus := StatusText(DebugMode)
    windowLockStatus := GetWindowLockStatusText()

    ; Status emoji/symbols
    onSymbol := "🟢"
    offSymbol := "🔴"
    arrIcon := (g["ArrangementActive"] ? onSymbol : offSymbol)
    physIcon := (g["PhysicsEnabled"] ? onSymbol : offSymbol)
    expIcon := (Config["MultimonitorExpanse"] ? onSymbol : offSymbol)
    lockIcon := (windowLockStatus = "enabled" ? "🔒" : (windowLockStatus = "disabled" ? "🔓" : "◯"))
    iconRepelStatus := StatusText(Config["DesktopIconRepulsion"])
    iconIcon := (Config["DesktopIconRepulsion"] ? onSymbol : offSymbol)

    ; Rebuild custom FWDE popup menu
    TaskbarMenu.Delete()
    DebugTaskbarMenu.Delete()

    ; Main controls group
    TaskbarMenu.Add(arrIcon " Toggle Arrangement [" arrangementStatus "] (Ctrl+Alt+Space)", (*) => ToggleArrangement())
    TaskbarMenu.Add("▶ Optimize Windows (Ctrl+Alt+O)", (*) => OptimizeWindowPositions())
    TaskbarMenu.Add(physIcon " Toggle Physics [" physicsStatus "] (Ctrl+Alt+P)", (*) => TogglePhysics())
    TaskbarMenu.Add(expIcon " Toggle Multimonitor Expanse [" expanseStatus "] (Ctrl+Alt+M)", (*) => ToggleMultimonitorExpanse())
    TaskbarMenu.Add(lockIcon " Toggle Window Lock [" windowLockStatus "] (Ctrl+Alt+L)", (*) => ToggleWindowLock())
    TaskbarMenu.Add(iconIcon " Toggle Icon Repulsion [" iconRepelStatus "] (Ctrl+Alt+I)", (*) => ToggleIconRepulsion())
    TaskbarMenu.Add()
    ; Settings group - Parameter Settings stands out
    TaskbarMenu.Add("⚙️ Parameter Settings", (*) => ShowParameterSettingsWindow())
    TaskbarMenu.Add("💾 Save Settings", SaveUserParameterSettings)
    TaskbarMenu.Add("📂 Load Settings", LoadUserParameterSettings)

    debugIcon := (DebugMode ? onSymbol : offSymbol)
    DebugTaskbarMenu.Add(debugIcon " Toggle Debug Mode [" debugStatus "]", (*) => ToggleDebugMode())
    DebugTaskbarMenu.Add("🔍 Debug Window Info (Ctrl+Alt+D)", (*) => DebugWindowInfo())
    DebugTaskbarMenu.Add("🔍 Debug Active Window", (*) => DebugActiveWindow())
    DebugTaskbarMenu.Add("➕ Force Add Active Window (Ctrl+Alt+A)", (*) => ForceAddActiveWindow())
    DebugTaskbarMenu.Add("📋 Copy Debug Log (Ctrl+Alt+C)", (*) => DumpDebugLog())
    DebugTaskbarMenu.Add("📊 Status Dashboard (Ctrl+Alt+S)", (*) => ShowStatusDashboard())
    DebugTaskbarMenu.Add("⏱ Toggle Profiling (Ctrl+Alt+F)", (*) => _PerfToggle())

    TaskbarMenu.Add("🔧 Debug", DebugTaskbarMenu)
    TaskbarMenu.Add()
    TaskbarMenu.Add("🔄 Restart FWDE", (*) => RestartFWDE())
    TaskbarMenu.Add("❌ Exit", (*) => ExitApp())

    ; Rebuild actual AutoHotkey tray icon menu (right-click tray icon)
    A_TrayMenu.Delete()
    DebugTrayMenu.Delete()

    ; Main controls group
    A_TrayMenu.Add(arrIcon " Toggle Arrangement [" arrangementStatus "] (Ctrl+Alt+Space)", (*) => ToggleArrangement())
    A_TrayMenu.Add("▶ Optimize Windows (Ctrl+Alt+O)", (*) => OptimizeWindowPositions())
    A_TrayMenu.Add(physIcon " Toggle Physics [" physicsStatus "] (Ctrl+Alt+P)", (*) => TogglePhysics())
    A_TrayMenu.Add(expIcon " Toggle Multimonitor Expanse [" expanseStatus "] (Ctrl+Alt+M)", (*) => ToggleMultimonitorExpanse())
    A_TrayMenu.Add(lockIcon " Toggle Window Lock [" windowLockStatus "] (Ctrl+Alt+L)", (*) => ToggleWindowLock())
    A_TrayMenu.Add(iconIcon " Toggle Icon Repulsion [" iconRepelStatus "] (Ctrl+Alt+I)", (*) => ToggleIconRepulsion())
    A_TrayMenu.Add()
    ; Settings group
    A_TrayMenu.Add("⚙️ Parameter Settings", (*) => ShowParameterSettingsWindow())
    A_TrayMenu.Add("💾 Save Settings", SaveUserParameterSettings)
    A_TrayMenu.Add("📂 Load Settings", LoadUserParameterSettings)

    DebugTrayMenu.Add(debugIcon " Toggle Debug Mode [" debugStatus "]", (*) => ToggleDebugMode())
    DebugTrayMenu.Add("🔍 Debug Window Info (Ctrl+Alt+D)", (*) => DebugWindowInfo())
    DebugTrayMenu.Add("🔍 Debug Active Window", (*) => DebugActiveWindow())
    DebugTrayMenu.Add("➕ Force Add Active Window (Ctrl+Alt+A)", (*) => ForceAddActiveWindow())
    DebugTrayMenu.Add("📋 Copy Debug Log (Ctrl+Alt+C)", (*) => DumpDebugLog())
    DebugTrayMenu.Add("📊 Status Dashboard (Ctrl+Alt+S)", (*) => ShowStatusDashboard())
    DebugTrayMenu.Add("⏱ Toggle Profiling (Ctrl+Alt+F)", (*) => _PerfToggle())

    A_TrayMenu.Add("🔧 Debug", DebugTrayMenu)
    A_TrayMenu.Add()
    A_TrayMenu.Add("🔄 Restart FWDE", (*) => RestartFWDE())
    A_TrayMenu.Add("❌ Exit", (*) => ExitApp())
}

RestartFWDE() {
    ; Reload restarts the current script process in AutoHotkey v2.
    Reload()
}

CloneMapDeep(value) {
    if (Type(value) = "Map") {
        copy := Map()
        for k, v in value {
            copy[k] := CloneMapDeep(v)
        }
        return copy
    }
    if (Type(value) = "Array") {
        copy := []
        for _, v in value {
            copy.Push(CloneMapDeep(v))
        }
        return copy
    }
    return value
}

GetMapValueByPath(mapRef, path) {
    keys := StrSplit(path, ".")
    cur := mapRef
    for _, key in keys {
        if (Type(cur) != "Map" || !cur.Has(key))
            return ""
        cur := cur[key]
    }
    return cur
}

SetMapValueByPath(&mapRef, path, value) {
    keys := StrSplit(path, ".")
    cur := mapRef
    last := keys.Length
    Loop last - 1 {
        key := keys[A_Index]
        if (!cur.Has(key) || Type(cur[key]) != "Map")
            cur[key] := Map()
        cur := cur[key]
    }
    cur[keys[last]] := value
}

GetDecimalPlaces(value) {
    txt := Format("{:.6f}", value)
    txt := RTrim(txt, "0")
    if (SubStr(txt, -1) = ".")
        return 0
    dotPos := InStr(txt, ".")
    if (!dotPos)
        return 0
    return StrLen(txt) - dotPos
}

ShouldTreatAsBoolean(path) {
    static boolPaths := Map(
        "MultimonitorExpanse", true,
        "DesktopIconRepulsion", true
    )
    return boolPaths.Has(path)
}

ShouldSkipParameterPath(path) {
    static skipPaths := Map(
        "FloatStyles", true
    )
    return skipPaths.Has(path)
}

BuildNumericParamSpec(path, defaultValue) {
    absVal := Abs(defaultValue)
    isInt := (Round(defaultValue) = defaultValue)

    if (isInt) {
        decimals := 0
        scale := 1
        if (defaultValue >= 0) {
            maxVal := Max(10, Ceil(defaultValue * 2.5))
            minVal := 0
        } else {
            span := Max(10, Ceil(absVal * 2.5))
            minVal := -span
            maxVal := span
        }
    } else {
        decimals := Max(2, Min(6, GetDecimalPlaces(defaultValue) + 1))
        scale := 10 ** decimals

        if (defaultValue >= 0) {
            maxVal := Max(defaultValue + 0.05, defaultValue * 2.5)
            minVal := 0
        } else {
            span := Max(absVal + 0.05, absVal * 2.5)
            minVal := -span
            maxVal := span
        }
    }

    label := StrReplace(path, ".", " - ")
    spec := Map(
        "path", path,
        "label", label,
        "type", "number",
        "default", defaultValue,
        "decimals", decimals,
        "scale", scale,
        "min", Round(minVal * scale),
        "max", Round(maxVal * scale)
    )
    return ApplyNumericSpecOverrides(spec)
}

ApplyNumericSpecOverrides(spec) {
    static overrides := Map(
        "AttractionForce", Map("min", 0.0, "max", 0.005, "decimals", 6),
        "RepulsionForce", Map("min", 0.01, "max", 20.0, "decimals", 3),
        "RepulsionRangeMultiplier", Map("min", 0.25, "max", 8.0, "decimals", 3),
        "RepulsionImpulseScale", Map("min", 0.01, "max", 10.0, "decimals", 3),
        "PairSeparationBase", Map("min", 0.001, "max", 0.5, "decimals", 4),
        "PairSeparationOverlapScale", Map("min", 0.01, "max", 20.0, "decimals", 3),
        "PairSmallWindowBoost", Map("min", 0.5, "max", 8.0, "decimals", 3),
        "MaxSmallWindowRepulsionBoost", Map("min", 0.5, "max", 10.0, "decimals", 3),
        "SmallWindowReferenceDim", Map("min", 40, "max", 3000, "decimals", 0),
        "CollisionOverlapThreshold", Map("min", 0, "max", 300, "decimals", 0),
        "SmallWindowThresholdW", Map("min", 40, "max", 3000, "decimals", 0),
        "SmallWindowThresholdH", Map("min", 30, "max", 2000, "decimals", 0),
        "Damping", Map("min", 0.0, "max", 1.0, "decimals", 4),
        "MaxSpeed", Map("min", 0.5, "max", 240.0, "decimals", 2),
        "MaxIconSpeed", Map("min", 1.0, "max", 150.0, "decimals", 1),
        "PhysicsTimeStep", Map("min", 1, "max", 50, "decimals", 0),
        "VisualTimeStep", Map("min", 1, "max", 100, "decimals", 0),
        "ParameterHelpTooltipDuration", Map("min", 100, "max", 30000, "decimals", 0),
        "ManualRepulsionMultiplier", Map("min", 0.05, "max", 15.0, "decimals", 3),
        "SeedDiagonalStep", Map("min", 1, "max", 200, "decimals", 0),
        "SeedDiagonalMaxSteps", Map("min", 1, "max", 50, "decimals", 0),
        "SeedJitterRange", Map("min", 0, "max", 100, "decimals", 0),
        "MinMargin", Map("min", 0, "max", 200, "decimals", 0),
        "MinGap", Map("min", 0, "max", 200, "decimals", 0),
        "NoiseScale", Map("min", 100, "max", 20000, "decimals", 0),
        "NoiseInfluence", Map("min", 0, "max", 2000, "decimals", 0),
        "ResizeDelay", Map("min", 1, "max", 200, "decimals", 0),
        "TooltipDuration", Map("min", 100, "max", 30000, "decimals", 0),
        "UserMoveTimeout", Map("min", 50, "max", 5000, "decimals", 0),
        "ManualLockDuration", Map("min", 1000, "max", 120000, "decimals", 0),
        "ManualWindowAlpha", Map("min", 0, "max", 255, "decimals", 0),
        "Stabilization.MinSpeedThreshold", Map("min", 0.0, "max", 5.0, "decimals", 3),
        "Stabilization.EnergyThreshold", Map("min", 0.0, "max", 10.0, "decimals", 3),
        "Stabilization.DampingBoost", Map("min", 0.0, "max", 1.0, "decimals", 3),
        "Stabilization.OverlapTolerance", Map("min", 0, "max", 500, "decimals", 0),
        "DesktopIconMargin", Map("min", 0, "max", 200, "decimals", 0),
        "DesktopIconRepulsionForce", Map("min", 0.0, "max", 25.0, "decimals", 1),
        "DesktopIconInterRepelRange", Map("min", 0.1, "max", 3.0, "decimals", 2)
    )

    path := spec["path"]
    if (!overrides.Has(path)) {
        if (spec["max"] <= spec["min"])
            spec["max"] := spec["min"] + 1
        return spec
    }

    ov := overrides[path]

    if (ov.Has("decimals")) {
        spec["decimals"] := ov["decimals"]
        spec["scale"] := 10 ** spec["decimals"]
    }
    if (ov.Has("min"))
        spec["min"] := Round(ov["min"] * spec["scale"])
    if (ov.Has("max"))
        spec["max"] := Round(ov["max"] * spec["scale"])

    if (spec["max"] <= spec["min"])
        spec["max"] := spec["min"] + 1

    return spec
}

CollectParameterSpecsRecursive(mapRef, prefix := "") {
    specs := []
    for key, val in mapRef {
        path := (prefix = "") ? key : (prefix "." key)
        if (ShouldSkipParameterPath(path))
            continue

        if (Type(val) = "Map") {
            nested := CollectParameterSpecsRecursive(val, path)
            for _, spec in nested
                specs.Push(spec)
            continue
        }

        ; Check booleans BEFORE the Number gate — AHK v2 true/false are not Numbers
        if (ShouldTreatAsBoolean(path)) {
            specs.Push(Map(
                "path", path,
                "label", StrReplace(path, ".", " - "),
                "type", "bool",
                "default", !!val
            ))
            continue
        }

        if !(val is Number)
            continue

        specs.Push(BuildNumericParamSpec(path, val))
    }
    return specs
}

EnsureParameterSpecs() {
    global ParamSpecs, DefaultConfig
    if (ParamSpecs.Length > 0)
        return
    ParamSpecs := CollectParameterSpecsRecursive(DefaultConfig)
}

FormatParamDisplay(spec, value) {
    if (spec["type"] = "bool")
        return value ? "On" : "Off"
    if (spec["decimals"] <= 0)
        return Format("{:.0f}", value)
    return Format("{:." spec["decimals"] "f}", value)
}

NormalizeSliderFromConfig(spec, value) {
    return Round(value * spec["scale"])
}

NormalizeConfigFromSlider(spec, sliderValue) {
    numericValue := sliderValue / spec["scale"]
    if (spec["decimals"] <= 0)
        return Round(numericValue)  ; integer return - safe
    ; Round(N, Places>0) returns a STRING in AHK v2, which would break JSON save/load.
    ; Explicitly convert back to Float so Config always stores a proper number.
    return Float(Round(numericValue, spec["decimals"]))
}

GetSliderDefaultMarkerX(sliderX, sliderWidth, spec) {
    defaultSliderVal := NormalizeSliderFromConfig(spec, spec["default"])
    defaultSliderVal := Min(Max(defaultSliderVal, spec["min"]), spec["max"])
    span := Max(spec["max"] - spec["min"], 1)
    ratio := (defaultSliderVal - spec["min"]) / span
    return sliderX + Round(ratio * sliderWidth)
}

EscapeJsonString(value) {
    text := value ""
    text := StrReplace(text, "\\", "\\\\")
    text := StrReplace(text, '"', '\\"')
    text := StrReplace(text, "`r", "\\r")
    text := StrReplace(text, "`n", "\\n")
    text := StrReplace(text, "`t", "\\t")
    return text
}

ToJsonScalar(value) {
    ; Numbers: use %.10g format for clean, precise, parseable output (no trailing noise digits).
    if (value is Number)
        return Format("{:.10g}", value + 0)
    if (Type(value) = "String") {
        ; Numeric strings can end up in Config when Round(N,Places) is called.
        ; Serialize them as bare numbers so the load regex matches them correctly.
        if (IsNumber(value))
            return Format("{:.10g}", Float(value))
        return '"' EscapeJsonString(value) '"'
    }
    return value ? "true" : "false"
}

EscapeRegexLiteral(text) {
    return RegExReplace(text, "([\\.\^\$\|\(\)\[\]\{\}\*\+\?\\-])", "\\$1")
}

ParseJsonScalar(text) {
    s := Trim(text)
    if (s = "true")
        return true
    if (s = "false")
        return false
    if (SubStr(s, 1, 1) = '"' && SubStr(s, -1) = '"') {
        inner := SubStr(s, 2, StrLen(s) - 2)
        inner := StrReplace(inner, "\\\\", "\\")
        inner := StrReplace(inner, "\\n", "`n")
        inner := StrReplace(inner, "\\r", "`r")
        inner := StrReplace(inner, "\\t", "`t")
        ; If the quoted value is actually a number (e.g. "60.00" from the Round() string bug),
        ; return it as a proper number so Config is not polluted with strings.
        if (IsNumber(inner))
            return Float(inner)
        return inner
    }
    return s + 0
}

LoadUserParameterSettings(*) {
    global UserConfigPath, ParamSpecs, Config

    EnsureParameterSpecs()
    if (!FileExist(UserConfigPath))
        return

    try raw := FileRead(UserConfigPath, "UTF-8")
    catch {
        ShowTooltip("Failed to read settings file")
        return
    }

    changes := 0
    for _, spec in ParamSpecs {
        path := spec["path"]
        keyPattern := EscapeRegexLiteral(path)
        ; Also match quoted numbers like "60.00" – left by older saves where Round() returned a string.
        if (!RegExMatch(raw, '"' keyPattern '"\s*:\s*(true|false|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|"[^"]*")', &m))
            continue

        value := ParseJsonScalar(m[1])
        if (spec["type"] = "bool")
            value := !!value

        SetMapValueByPath(&Config, path, value)
        changes += 1
    }

    if (changes > 0) {
        SyncRuntimeFromConfig()
        if (Type(ParamSettingsGui) = "Gui")
            UpdateParameterControlsFromConfig()
        ShowTooltip("Settings loaded")
    }
}

SaveUserParameterSettings(*) {
    global UserConfigPath, ParamSpecs, Config

    EnsureParameterSpecs()

    lines := ["{", '  "_metadata": {', '    "application": "FWDE",', '    "saved": "' A_Now '",', '    "format": "flat-path-v1"', "  },"]

    total := ParamSpecs.Length
    for idx, spec in ParamSpecs {
        path := spec["path"]
        value := GetMapValueByPath(Config, path)
        jsonValue := ToJsonScalar(value)
        trailing := (idx < total) ? "," : ""
        lines.Push('  "' EscapeJsonString(path) '": ' jsonValue trailing)
    }
    lines.Push("}")

    payload := ""
    for i, line in lines {
        payload .= line (i < lines.Length ? "`n" : "")
    }

    ; Use FileOpen in write ("w") mode to atomically overwrite the file.
    ; FileDelete+FileAppend is unsafe: if delete silently fails, FileAppend appends
    ; duplicate keys and RegExMatch finds the stale first-occurrence on next load.
    try {
        f := FileOpen(UserConfigPath, "w", "UTF-8")
        f.Write(payload)
        f.Close()
        ShowTooltip("Settings saved")
    } catch as err {
        ShowTooltip("Failed to save settings: " err.Message)
    }
}

SyncRuntimeFromConfig() {
    global Config, g

    if (Config["MultimonitorExpanse"]) {
        g["Monitor"] := GetVirtualDesktopBounds()
    } else {
        g["Monitor"] := GetCurrentMonitorInfo()
    }

    if (g["ArrangementActive"]) {
        SetTimerEx(CalculateDynamicLayout, Config["PhysicsTimeStep"])
        SetTimerEx(ApplyWindowMovements, Config["VisualTimeStep"])
        SetTimerEx(UpdateWindowStates, 250)  ; Window list rebuild ~4 Hz — expensive, doesn't need 60 Hz
    } else if (g["PhysicsEnabled"]) {
        SetTimerEx(CalculateDynamicLayout, Config["PhysicsTimeStep"])
    }

    BuildFWDEMenus()
}

UpdateParameterControlsFromConfig() {
    global ParamControlRefs, Config

    for path, refs in ParamControlRefs {
        spec := refs["spec"]
        value := GetMapValueByPath(Config, path)

        if (spec["type"] = "bool") {
            refs["input"].Value := value ? 1 : 0
            refs["valueText"].Text := FormatParamDisplay(spec, value)
        } else {
            sliderVal := NormalizeSliderFromConfig(spec, value)
            sliderVal := Min(Max(sliderVal, spec["min"]), spec["max"])
            refs["input"].Value := sliderVal
            refs["valueText"].Text := FormatParamDisplay(spec, NormalizeConfigFromSlider(spec, sliderVal))
        }
    }
}

ApplySingleParameterDefault(path, *) {
    global Config, DefaultConfig
    defaultValue := GetMapValueByPath(DefaultConfig, path)
    SetMapValueByPath(&Config, path, defaultValue)
    SyncRuntimeFromConfig()
    UpdateParameterControlsFromConfig()
}

ApplyAllParameterDefaults(*) {
    global Config, DefaultConfig
    Config := CloneMapDeep(DefaultConfig)
    SyncRuntimeFromConfig()
    UpdateParameterControlsFromConfig()
    ShowTooltip("All parameters restored to defaults")
}

OnParameterSliderChange(path, ctrl, *) {
    global Config, ParamControlRefs
    refs := ParamControlRefs[path]
    spec := refs["spec"]
    newValue := NormalizeConfigFromSlider(spec, ctrl.Value)
    SetMapValueByPath(&Config, path, newValue)
    refs["valueText"].Text := FormatParamDisplay(spec, newValue)
    SyncRuntimeFromConfig()
}

OnParameterCheckboxChange(path, ctrl, *) {
    global Config, ParamControlRefs
    newValue := (ctrl.Value = 1)
    SetMapValueByPath(&Config, path, newValue)
    ParamControlRefs[path]["valueText"].Text := FormatParamDisplay(ParamControlRefs[path]["spec"], newValue)
    SyncRuntimeFromConfig()
}

OnParameterSliderDoubleClick(wParam, lParam, msg, hwnd) {
    global ParamSliderHwndToPath
    if (!ParamSliderHwndToPath.Has(hwnd))
        return
    ApplySingleParameterDefault(ParamSliderHwndToPath[hwnd])
}

HideParameterHoverTooltip(*) {
    global ParamHoverLastPath
    ToolTip(,,, 19)
    ParamHoverLastPath := ""
}

RegisterParameterHoverControl(ctrl, path) {
    global ParamHoverControlToPath
    if (Type(ctrl) = "Gui.Control")
        ParamHoverControlToPath[ctrl.Hwnd] := path
}

GetParameterDescription(path) {
    static descriptions := Map(
        "AttractionForce", "Center-seeking pull that prevents windows drifting too far away.",
        "RepulsionForce", "Base push strength when windows get close.",
        "RepulsionRangeMultiplier", "How far out repulsion starts acting between windows.",
        "RepulsionImpulseScale", "Per-step push intensity during close interactions.",
        "PairSeparationBase", "Base collision-separation strength when windows overlap.",
        "PairSeparationOverlapScale", "Extra separation scaling for deeper overlaps.",
        "PairSmallWindowBoost", "Additional overlap-separation boost for small windows.",
        "CollisionOverlapThreshold", "Minimum overlap before overlap handling engages.",
        "SmallWindowReferenceDim", "Reference size used to classify/boost small windows.",
        "MaxSmallWindowRepulsionBoost", "Cap on extra repulsion boost for small windows.",
        "SmallWindowThresholdW", "Width threshold used for small-window behavior.",
        "SmallWindowThresholdH", "Height threshold used for small-window behavior.",
        "MinMargin", "Minimum margin to keep windows away from monitor boundaries.",
        "MinGap", "Preferred spacing target used by layout placement routines.",
        "ManualRepulsionMultiplier", "Extra push when interacting with manually moved windows.",
        "ManualLockDuration", "How long a manually moved window stays physics-locked (ms).",
        "UserMoveTimeout", "Cooldown before focused windows rejoin normal physics (ms).",
        "ResizeDelay", "Delay before resize/move events trigger state refresh (ms).",
        "TooltipDuration", "Duration for the standard status tooltip messages (ms).",
        "ParameterHelpTooltipDuration", "How long parameter hover-help tooltips stay visible (ms).",
        "Damping", "Velocity damping; higher values reduce motion faster.",
        "MaxSpeed", "Maximum velocity cap for floating windows.",
        "PhysicsTimeStep", "Physics tick interval (ms). Lower means more frequent updates.",
        "VisualTimeStep", "Movement apply/render interval (ms). Lower is smoother.",
        "NoiseScale", "Spatial scale for procedural drift/noise effects.",
        "NoiseInfluence", "Strength of procedural drift/noise effects.",
        "MultimonitorExpanse", "Allow windows to float across all monitors instead of current monitor only.",
        "Stabilization.MinSpeedThreshold", "Speed threshold where stronger settling behavior starts.",
        "Stabilization.EnergyThreshold", "Energy threshold used to detect calm vs chaotic state.",
        "Stabilization.DampingBoost", "Extra damping added while system is settling.",
        "Stabilization.OverlapTolerance", "Allowed overlap before stabilization treats windows as colliding."
    )
    return descriptions.Has(path) ? descriptions[path] : "Runtime tuning parameter for FWDE window behavior."
}

ShowParameterHoverTooltip(path) {
    global Config, ParamControlRefs
    if (!ParamControlRefs.Has(path))
        return

    refs := ParamControlRefs[path]
    spec := refs["spec"]
    currentValue := GetMapValueByPath(Config, path)
    defaultValue := spec["default"]
    text := spec["label"] "`n" GetParameterDescription(path)

    if (spec["type"] = "bool") {
        text .= "`nCurrent: " FormatParamDisplay(spec, currentValue) "   Default: " FormatParamDisplay(spec, defaultValue)
    } else {
        minVal := NormalizeConfigFromSlider(spec, spec["min"])
        maxVal := NormalizeConfigFromSlider(spec, spec["max"])
        text .= "`nCurrent: " FormatParamDisplay(spec, currentValue) "   Default: " FormatParamDisplay(spec, defaultValue)
        text .= "`nRange: " FormatParamDisplay(spec, minVal) " to " FormatParamDisplay(spec, maxVal)
        text .= "`nHint: Double-click slider to reset this parameter"
    }

    MouseGetPos(&mx, &my)
    ToolTip(text, mx + 14, my + 16, 19)
    SetTimerEx(HideParameterHoverTooltip, -Max(300, Round(Config["ParameterHelpTooltipDuration"])))
}

OnParameterHoverMouseMove(wParam, lParam, msg, hwnd) {
    global ParamHoverControlToPath, ParamHoverLastPath

    if (!ParamHoverControlToPath.Has(hwnd)) {
        if (ParamHoverLastPath != "")
            HideParameterHoverTooltip()
        return
    }

    path := ParamHoverControlToPath[hwnd]
    if (path = ParamHoverLastPath)
        return

    ParamHoverLastPath := path
    ShowParameterHoverTooltip(path)
}

ShowParameterSettingsWindow(*) {
    global ParamSettingsGui, ParamControlRefs, ParamSpecs, Config, ParamSliderHwndToPath, ParamSliderDblClickHooked, ParamHoverControlToPath, ParamHoverHooked

    EnsureParameterSpecs()

    if (Type(ParamSettingsGui) = "Gui") {
        UpdateParameterControlsFromConfig()
        ParamSettingsGui.Show()
        return
    }

    settingsGui := Gui("+AlwaysOnTop +Resize", "FWDE Parameter Settings")
    settingsGui.SetFont("s9", "Segoe UI")

    ParamControlRefs := Map()
    ParamSliderHwndToPath := Map()
    ParamHoverControlToPath := Map()
    if (!ParamSliderDblClickHooked) {
        OnMessage(0x203, OnParameterSliderDoubleClick)
        ParamSliderDblClickHooked := true
    }
    if (!ParamHoverHooked) {
        OnMessage(0x200, OnParameterHoverMouseMove)
        ParamHoverHooked := true
    }

    total := ParamSpecs.Length
    leftCount := Ceil(total / 2)
    rowHeight := 28
    xCol1 := 12
    xCol2 := 512

    settingsGui.AddText("x12 y2 w760 c006400", "Changes apply instantly while you move sliders or toggles. Hover any parameter for details.")

    for idx, spec in ParamSpecs {
        col := (idx <= leftCount) ? 1 : 2
        row := (col = 1) ? idx : (idx - leftCount)
        y := 20 + (row - 1) * rowHeight
        x := (col = 1) ? xCol1 : xCol2

        labelCtrl := settingsGui.AddText("x" x " y" y+5 " w190", spec["label"])
        RegisterParameterHoverControl(labelCtrl, spec["path"])

        if (spec["type"] = "bool") {
            input := settingsGui.AddCheckbox("x" x+195 " y" y " w62", "On")
            valueText := settingsGui.AddText("x" x+262 " y" y+5 " w58 Right", "")
            defBtn := settingsGui.AddButton("x" x+326 " y" y-1 " w72 h22", "Default")

            input.OnEvent("Click", OnParameterCheckboxChange.Bind(spec["path"]))
            defBtn.OnEvent("Click", ApplySingleParameterDefault.Bind(spec["path"]))
        } else {
            rangeOpt := "Range" spec["min"] "-" spec["max"]
            sliderX := x + 195
            sliderW := 160
            input := settingsGui.AddSlider("x" sliderX " y" y " w" sliderW " " rangeOpt " ToolTip", 0)
            valueText := settingsGui.AddText("x" x+362 " y" y+5 " w40 Right", "")
            defBtn := settingsGui.AddButton("x" x+408 " y" y-1 " w72 h22", "Default")

            markerX := GetSliderDefaultMarkerX(sliderX, sliderW, spec)
            ; Draw a stable default tick below the slider to avoid repaint artifacts on the track itself.
            settingsGui.AddProgress("x" markerX " y" y+22 " w2 h5 cCC0000 BackgroundCC0000", 100)

            input.OnEvent("Change", OnParameterSliderChange.Bind(spec["path"]))
            defBtn.OnEvent("Click", ApplySingleParameterDefault.Bind(spec["path"]))
            ParamSliderHwndToPath[input.Hwnd] := spec["path"]
        }

        RegisterParameterHoverControl(input, spec["path"])
        RegisterParameterHoverControl(valueText, spec["path"])
        RegisterParameterHoverControl(defBtn, spec["path"])

        ParamControlRefs[spec["path"]] := Map(
            "spec", spec,
            "input", input,
            "valueText", valueText
        )
    }

    footerY := 34 + Ceil(total / 2) * rowHeight
    settingsGui.AddButton("x12 y" footerY " w120 h28", "Save Settings").OnEvent("Click", SaveUserParameterSettings)
    settingsGui.AddButton("x138 y" footerY " w120 h28", "Load Settings").OnEvent("Click", LoadUserParameterSettings)
    settingsGui.AddButton("x264 y" footerY " w150 h28", "Restore All Defaults").OnEvent("Click", ApplyAllParameterDefaults)
    settingsGui.AddButton("x420 y" footerY " w170 h28", "Re-read Current Values").OnEvent("Click", (*) => UpdateParameterControlsFromConfig())
    settingsGui.AddButton("x596 y" footerY " w90 h28", "Close").OnEvent("Click", (*) => settingsGui.Hide())

    settingsGui.OnEvent("Close", (*) => settingsGui.Hide())
    ParamSettingsGui := settingsGui

    UpdateParameterControlsFromConfig()
    settingsGui.Show("w1008 h" footerY + 72)
}

BuildFWDEMenus()
LoadUserParameterSettings()

ShowTaskbarMenu() {
    BuildFWDEMenus()
    rect := GetTaskbarRect()
    if (rect) {
        TaskbarMenu.Show(rect.left + 10, rect.top + 10)
    } else {
        TaskbarMenu.Show(10, 10)
    }
}

GetTaskbarRect() {
    ; Returns the rect of the taskbar on the monitor the mouse is currently on.
    ; Supports:
    ;   - Windows native taskbar (Shell_TrayWnd = primary, Shell_SecondaryTrayWnd = per-monitor)
    ;   - RetroBar (one window per monitor, found via ahk_exe; also tries known WPF class names)
    ; Uses WinGetList instead of WinExist so all instances are checked (multi-monitor coverage).
    ; Returns 0 when no taskbar is detectable.
    ;
    ; NOTE: for physics/boundary purposes prefer SafeMonitorGetWorkArea — it reads the
    ; system work area directly and doesn't need to know which side the taskbar is on.
    ; This function is kept for ShowTaskbarMenu popup placement.

    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)
    monNum := MonitorGetFromPoint(mx, my)
    if (!monNum)
        monNum := MonitorGetPrimary()
    SafeMonitorGet(monNum, &mL, &mT, &mR, &mB)

    ; --- Collect all candidate taskbar window handles ---
    candidates := []

    ; Native primary taskbar (always exactly one per system)
    try {
        hwnd := WinExist("ahk_class Shell_TrayWnd")
        if (hwnd)
            candidates.Push(hwnd)
    }

    ; Native per-monitor secondary taskbars (one per additional monitor)
    try {
        for hwnd in WinGetList("ahk_class Shell_SecondaryTrayWnd")
            candidates.Push(hwnd)
    }

    ; RetroBar — registers as an AppBar and can run one instance per monitor.
    ; WinGetList("ahk_exe RetroBar.exe") covers all its windows regardless of class name.
    try {
        for hwnd in WinGetList("ahk_exe RetroBar.exe") {
            try {
                if (WinGetMinMax("ahk_id " hwnd) == 0)   ; skip minimised/tray
                    candidates.Push(hwnd)
            }
        }
    }

    ; --- Pass 1: prefer the taskbar whose left-top corner is on the mouse's monitor ---
    for hwnd in candidates {
        try {
            if (!SafeWinExist(hwnd))
                continue
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            if (w == 0 || h == 0)
                continue
            ; The taskbar is "on" this monitor when its origin is within monitor bounds.
            ; (Taskbars always start at a monitor edge, so the origin is sufficient.)
            if (x >= mL && x < mR && y >= mT && y < mB)
                return { left: x, top: y, right: x + w, bottom: y + h }
        } catch {
            continue
        }
    }

    ; --- Pass 2: fall back to any non-zero taskbar found ---
    for hwnd in candidates {
        try {
            if (!SafeWinExist(hwnd))
                continue
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            if (w > 0 && h > 0)
                return { left: x, top: y, right: x + w, bottom: y + h }
        } catch {
            continue
        }
    }

    return 0
}

; --- Debug function to show window information ---
ToggleDebugMode() {
    global DebugMode
    DebugMode := !DebugMode
    ShowTooltip("Debug Mode: " (DebugMode ? "ON" : "OFF"))
    BuildFWDEMenus()
}

DebugWindowInfo() {
    global g, Config
    
    ; Get all visible windows
    allWindows := []
    trackedWindows := []
    untrackedWindows := []
    
    ; Get current monitor for filtering
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)
    activeMonitor := MonitorGetFromPoint(mx, my)
    SafeMonitorGet(activeMonitor, &mL, &mT, &mR, &mB)
    
    ; Check all windows
    for hwnd in WinGetList() {
        try {
            if (!SafeWinExist(hwnd))
                continue
                
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            if (w == 0 || h == 0)
                continue
                
            title := WinGetTitle("ahk_id " hwnd)
            winClass := WinGetClass("ahk_id " hwnd)
            processName := WinGetProcessName("ahk_id " hwnd)
            
            if (title == "" || title == "Program Manager")
                continue
                
            isPlugin := IsPluginWindow(hwnd)
            isFloating := IsWindowFloating(hwnd)
            isTracked := false
            
            ; Check if window is currently tracked
            for trackedWin in g["Windows"] {
                if (trackedWin["hwnd"] == hwnd) {
                    isTracked := true
                    break
                }
            }
            
            windowInfo := Map(
                "hwnd", hwnd,
                "title", title,
                "class", winClass,
                "process", processName,
                "x", x, "y", y, "width", w, "height", h,
                "isPlugin", isPlugin,
                "isFloating", isFloating,
                "isTracked", isTracked
            )
            
            allWindows.Push(windowInfo)
            
            if (isTracked) {
                trackedWindows.Push(windowInfo)
            } else if (isFloating || isPlugin) {
                untrackedWindows.Push(windowInfo)
            }
            
        } catch {
            continue
        }
    }
    
    ; Create debug message
    debugMsg := "=== FWDE WINDOW DEBUG ===`n`n"
    debugMsg .= "Arrangement Active: " . (g["ArrangementActive"] ? "YES" : "NO") . "`n"
    debugMsg .= "Total Windows: " . allWindows.Length . "`n"
    debugMsg .= "Tracked Windows: " . trackedWindows.Length . "`n"
    debugMsg .= "Untracked Floating Windows: " . untrackedWindows.Length . "`n`n"
    
    debugMsg .= "--- TRACKED WINDOWS ---`n"
    for win in trackedWindows {
        debugMsg .= "вњ“ " . win["title"] . " (" . win["class"] . ") [" . win["process"] . "]`n"
        debugMsg .= "  Size: " . win["width"] . "x" . win["height"] . " at " . win["x"] . "," . win["y"] . "`n"
    }
    
    debugMsg .= "`n--- UNTRACKED FLOATING WINDOWS ---`n"
    for win in untrackedWindows {
        debugMsg .= "вњ— " . win["title"] . " (" . win["class"] . ") [" . win["process"] . "]`n"
        debugMsg .= "  Size: " . win["width"] . "x" . win["height"] . " at " . win["x"] . "," . win["y"] . "`n"
        debugMsg .= "  Plugin: " . (win["isPlugin"] ? "YES" : "NO") . " | Floating: " . (win["isFloating"] ? "YES" : "NO") . "`n"
    }
    
    debugMsg .= "`n--- CONFIG PATTERNS ---`n"
    debugMsg .= "ForceFloatProcesses: " . Config["ForceFloatProcesses"].Length . " patterns`n"
    debugMsg .= "FloatClassPatterns: " . Config["FloatClassPatterns"].Length . " patterns`n"
    debugMsg .= "FloatTitlePatterns: " . Config["FloatTitlePatterns"].Length . " patterns`n"
    
    ; Show tooltip with debug info
    ToolTip(debugMsg)
    SetTimerEx(() => ToolTip(), -10000)  ; Hide after 10 seconds
}

; --- Force add active window to tracking ---
ForceAddActiveWindow() {
    global g, Config
    
    hwnd := WinExist("A")
    if (!hwnd || !SafeWinExist(hwnd)) {
        ToolTip("No active window found!")
        SetTimerEx(() => ToolTip(), -2000)
        return
    }
    
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        title := WinGetTitle("ahk_id " hwnd)
        winClass := WinGetClass("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)
        
        if (w == 0 || h == 0) {
            ToolTip("Invalid window size!")
            SetTimerEx(() => ToolTip(), -2000)
            return
        }
        
        ; Check if already tracked
        for win in g["Windows"] {
            if (win["hwnd"] == hwnd) {
                ToolTip("Window already tracked: " . title)
                SetTimerEx(() => ToolTip(), -2000)
                return
            }
        }
        
        ; Get monitor info
        winCenterX := x + w/2
        winCenterY := y + h/2
        winMonitor := MonitorGetFromPoint(winCenterX, winCenterY)
        if (!winMonitor) {
            winMonitor := MonitorGetPrimary()
        }
        
        ; Add to tracking
        g["Windows"].Push(Map(
            "hwnd", hwnd,
            "x", x, "y", y,
            "width", w, "height", h,
            "area", w * h,
            "mass", w * h / 100000,
            "lastMove", 0,
            "vx", 0, "vy", 0,
            "targetX", x, "targetY", y,
            "monitor", winMonitor,
            "isPlugin", IsPluginWindow(hwnd),
            "lastSeen", A_TickCount,
            "forced", true  ; Mark as manually added
        ))
        
        
        ToolTip("Added to tracking: " . title . " (" . winClass . ")")
        SetTimerEx(() => ToolTip(), -3000)
        
    } catch {
        ToolTip("Failed to add window to tracking!")
        SetTimerEx(() => ToolTip(), -2000)
    }
}

; --- Debug active window details ---
DebugActiveWindow() {
    global g, Config
    
    hwnd := WinExist("A")
    if (!hwnd) {
        ToolTip("No active window!")
        SetTimerEx(() => ToolTip(), -2000)
        return
    }
    
    try {
        title := WinGetTitle("ahk_id " hwnd)
        winClass := WinGetClass("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)
        style := WinGetStyle("ahk_id " hwnd)
        exStyle := WinGetExStyle("ahk_id " hwnd)
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        minMax := WinGetMinMax("ahk_id " hwnd)
        
        isPlugin := IsPluginWindow(hwnd)
        isFloating := IsWindowFloating(hwnd)
        isValid := IsWindowValid(hwnd)
        isFullscreen := IsFullscreenWindow(hwnd)
        
        debugMsg := "=== ACTIVE WINDOW DEBUG ===`n`n"
        debugMsg .= "Title: " . title . "`n"
        debugMsg .= "Class: " . winClass . "`n"
        debugMsg .= "Process: " . processName . "`n"
        debugMsg .= "Position: " . x . "," . y . " Size: " . w . "x" . h . "`n"
        debugMsg .= "Min/Max: " . minMax . "`n"
        debugMsg .= "Style: 0x" . Format("{:08X}", style) . "`n"
        debugMsg .= "ExStyle: 0x" . Format("{:08X}", exStyle) . "`n`n"
        
        debugMsg .= "--- DETECTION RESULTS ---`n"
        debugMsg .= "IsValid: " . (isValid ? "YES" : "NO") . "`n"
        debugMsg .= "IsPlugin: " . (isPlugin ? "YES" : "NO") . "`n"
        debugMsg .= "IsFloating: " . (isFloating ? "YES" : "NO") . "`n"
        debugMsg .= "IsFullscreen: " . (isFullscreen ? "YES" : "NO") . "`n`n"
        
        debugMsg .= "--- PATTERN CHECKS ---`n"
        
        ; Check ForceFloatProcesses
        debugMsg .= "ForceFloatProcesses: "
        for pattern in Config["ForceFloatProcesses"] {
            if (processName ~= "i)^" pattern "$") {
                debugMsg .= "MATCH (" . pattern . ") "
            }
        }
        debugMsg .= "`n"
        
        ; Check FloatClassPatterns
        debugMsg .= "FloatClassPatterns: "
        for pattern in Config["FloatClassPatterns"] {
            if (winClass ~= "i)" pattern) {
                debugMsg .= "MATCH (" . pattern . ") "
            }
        }
        debugMsg .= "`n"
        
        ; Check FloatTitlePatterns
        debugMsg .= "FloatTitlePatterns: "
        for pattern in Config["FloatTitlePatterns"] {
            if (title ~= "i)" pattern) {
                debugMsg .= "MATCH (" . pattern . ") "
            }
        }
        debugMsg .= "`n"
        
        ; Check style flags
        debugMsg .= "FloatStyles: " . ((style & Config["FloatStyles"]) != 0 ? "MATCH" : "NO MATCH") . "`n"
        debugMsg .= "WS_EX_TOOLWINDOW: " . ((exStyle & 0x80) ? "YES" : "NO") . "`n"
        debugMsg .= "WS_VISIBLE: " . ((style & 0x10000000) ? "YES" : "NO") . "`n"
        
        ToolTip(debugMsg)
        SetTimerEx(() => ToolTip(), -15000)  ; Show for 15 seconds
        
    } catch {
        ToolTip("Failed to get window details!")
        SetTimerEx(() => ToolTip(), -2000)
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
;  PERFORMANCE PROFILING — high-resolution timing for every function
;  Toggle with Ctrl+Alt+F. Data shown in StatusDashboard (Ctrl+Alt+S).
;  Uses QueryPerformanceCounter for microsecond resolution.
; ═══════════════════════════════════════════════════════════════════════════════

_PerfInit() {
    global g
    if (g["_perfFreq"] == 0) {
        f := 0
        DllCall("QueryPerformanceFrequency", "Int64*", &f)
        g["_perfFreq"] := f
    }
}

; Call at the start of a timed section. Returns start counter.
_PerfStart() {
    global g
    if (!g["_perfOn"])
        return 0
    _PerfInit()
    c := 0
    DllCall("QueryPerformanceCounter", "Int64*", &c)
    return c
}

; Call at the end. key identifies the function/section.
_PerfEnd(key, start) {
    global g
    if (start == 0)
        return
    end := 0
    DllCall("QueryPerformanceCounter", "Int64*", &end)
    us := (end - start) * 1000000 / g["_perfFreq"]
    if !g["_perfData"].Has(key)
        g["_perfData"][key] := [0.0, 0]
    d := g["_perfData"][key]
    d[1] += us
    d[2] += 1
}

_PerfToggle() {
    global g
    try {
        g["_perfOn"] := !g["_perfOn"]
        if (g["_perfOn"]) {
            _PerfInit()
            ToolTip("Performance profiling: ON", 10, 10)
            SetTimer () => ToolTip(), -2000
        } else {
            g["_perfData"] := Map()
            ToolTip("Performance profiling: OFF", 10, 10)
            SetTimer () => ToolTip(), -2000
        }
    } catch as e {
        DebugLog("PerfToggle error: " e.Message)
        ToolTip("PerfToggle error — see debug log", 10, 10)
        SetTimer () => ToolTip(), -3000
    }
}

_PerfReport() {
    global g
    txt := "══════ PERF ══════`n"
    txt .= Format("{:28s} {:8s} {:12s} {:10s}`n", "Section", "Calls", "Total ms", "Avg µs")
    for key, d in g["_perfData"] {
        avg := d[2] > 0 ? d[1] / d[2] : 0
        txt .= Format("{:28s} {:8d} {:12.2f} {:10.2f}`n", key, d[2], d[1] / 1000, avg)
    }
    return txt
}

; ═══════════════════════════════════════════════════════════════════════════════
;  HEALTH MONITOR — autonomous watchdog that detects and recovers from stalls
; ═══════════════════════════════════════════════════════════════════════════════
; Runs every 5 seconds. Checks timer heartbeats, stuck drag state, stale
; SnapInProgress entries, DragActive flag, and memory pressure. Auto-recovers
; where safe and logs all anomalies so the user can review before restarting.

HealthMonitor() {
    global g, Config
    static lastMemClean := 0
    ph := _PerfStart()

    try {
        g["_hbWatchdog"] := A_TickCount
        now := A_TickCount
        anomalies := []
        recovered := false

        ; --- 1. Timer heartbeat checks ---
        ; If a timer callback hasn't updated its heartbeat in >2× its period,
        ; the timer has likely been killed by an unhandled exception.

        physStale := now - g["_hbPhysics"]
        physMax := Max(Config["PhysicsTimeStep"] * 3, 100)
        if (physStale > physMax && g["ArrangementActive"]) {
            anomalies.Push("Physics timer stale (" physStale "ms)")
            ; Auto-recover: re-register the timer
            SetTimerEx(CalculateDynamicLayout, Config["PhysicsTimeStep"])
            recovered := true
        }

        visualStale := now - g["_hbVisual"]
        visualMax := Max(Config["VisualTimeStep"] * 3, 100)
        if (visualStale > visualMax && g["ArrangementActive"]) {
            anomalies.Push("Visual timer stale (" visualStale "ms)")
            SetTimerEx(ApplyWindowMovements, Config["VisualTimeStep"])
            recovered := true
        }

        windowListStale := now - g["_hbWindowList"]
        if (windowListStale > 2000 && g["ArrangementActive"]) {
            anomalies.Push("Window-list timer stale (" windowListStale "ms)")
            SetTimerEx(UpdateWindowStates, 250)
            recovered := true
        }

        ; --- 2. Stuck drag-thread detection ---
        if (g["_dragThreadActive"]) {
            dragAge := now - g["_dragThreadStart"]
            if (dragAge > 30000) {
                anomalies.Push("Drag thread stuck (" dragAge "ms) — force-resetting")
                g["_dragThreadActive"] := false
                g["_dragThreadStart"] := 0
                ReleaseHighResTimer()
                recovered := true
            }
        }

        ; --- 3. Stale DragActive flag ---
        ; DragActive should only be true during real LButton-down drags.
        ; If LButton is up but DragActive is still true, it's stale.
        if (g["DragActive"] && !GetKeyState("LButton", "P")) {
            anomalies.Push("DragActive flag stale (LButton not held)")
            g["DragActive"] := false
            recovered := true
        }

        ; --- 4. Stuck SnapInProgress entries ---
        if (g["SnapInProgress"].Count > 0 && g["_snapOldestTick"] > 15000) {
            anomalies.Push("SnapInProgress stuck (" g["SnapInProgress"].Count " entries, oldest " g["_snapOldestTick"] "ms)")
            g["SnapInProgress"] := Map()
            g["_recoveryCount"] += 1
            g["_snapFailsafeCount"] += 1
            recovered := true
        }

        ; --- 5. Window-list health: log if tracked count changes significantly ---
        static lastTrackedCount := -1
        if (lastTrackedCount == -1) {
            lastTrackedCount := g["Windows"].Length
        } else if (Abs(g["Windows"].Length - lastTrackedCount) >= 5) {
            DebugLog("HealthMonitor — window count changed: {} → {}", lastTrackedCount, g["Windows"].Length)
            lastTrackedCount := g["Windows"].Length
        } else if (now - lastMemClean > 60000) {
            lastMemClean := now
            lastTrackedCount := g["Windows"].Length
        }

        ; --- 6. Icon zone adaptive refresh: retry LV detection periodically ---
        ; Only when using virtual fallback zones (real ListView not yet found)
        static lastIconRetry := 0
        if (lastIconRetry == 0)
            lastIconRetry := now  ; prime to prevent immediate first-fire
        if (Config["DesktopIconRepulsion"] && !g["_iconZonesLive"] && now - lastIconRetry > 30000) {
            lastIconRetry := now
            fresh := GetDesktopIconRects()
            if (fresh.Length > 0) {
                g["DesktopIconRects"] := fresh
                g["DesktopIconLastRefresh"] := A_TickCount
                DebugLog("IconRetry — LV found after fallback, {} obstacles, {} zones",
                    fresh.Length, g["_iconZones"].Length)
            }
        }

        ; --- 7. Report ---
        if (anomalies.Length > 0) {
            DebugLog("HealthMonitor — {} anomalies detected:", anomalies.Length)
            for _, msg in anomalies
                DebugLog("  • {}", msg)
        }
        if (recovered) {
            g["_recoveryCount"] += 1
            DebugLog("HealthMonitor — auto-recovery performed (total recoveries: {})", g["_recoveryCount"])
        }

        ; Always log periodic status heartbeat
        DebugLog("Health beat — {} windows, energy={:.4f}, drag={}, snap={}, phys={}ms, vis={}ms"
            , g["Windows"].Length, g["SystemEnergy"] / Max(g["Windows"].Length, 1) / 10000
            , g["DragActive"] ? "yes" : "no"
            , g["SnapInProgress"].Count
            , now - g["_hbPhysics"]
            , now - g["_hbVisual"])

    _PerfEnd("HLM", ph)
    } catch as hmErr {
        ; The watchdog itself must never crash — log and continue
        DebugLog("HealthMonitor — internal exception: {}", hmErr.Message)
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
;  STATUS DASHBOARD — real-time internal-state overlay (Ctrl+Alt+S)
;  Shows timer health, drag state, snap state, energy, recovery count, etc.
;  Designed for autonomous user exploration — no need to read source code.
; ═══════════════════════════════════════════════════════════════════════════════

ShowStatusDashboard(*) {
    global g, Config
    now := A_TickCount

    ; Compute health indicators
    physAge := now - g["_hbPhysics"]
    physStatus := (physAge < Max(Config["PhysicsTimeStep"] * 2, 50)) ? "🟢 OK" : "🔴 STALE"
    visualAge := now - g["_hbVisual"]
    visualStatus := (visualAge < Max(Config["VisualTimeStep"] * 2, 50)) ? "🟢 OK" : "🔴 STALE"
    wlAge := now - g["_hbWindowList"]
    wlStatus := (wlAge < 1000) ? "🟢 OK" : "🔴 STALE"
    wdAge := now - g["_hbWatchdog"]
    wdStatus := (wdAge < 15000) ? "🟢 OK" : "🔴 STALE"

    dragStatus := g["_dragThreadActive"] ? "⏳ ACTIVE (" (now - g["_dragThreadStart"]) "ms)" : "⚪ idle"
    dragActiveStatus := g["DragActive"] ? "⚠️ TRUE" : "⚪ false"
    snapCount := g["SnapInProgress"].Count
    snapStatus := (snapCount > 0) ? "⏳ " snapCount " entries (oldest " g["_snapOldestTick"] "ms)" : "⚪ clear"

    energy := g["SystemEnergy"]
    normEnergy := energy / Max(g["Windows"].Length, 1) / 10000
    energyBar := ""
    Loop Round(Min(normEnergy * 100, 20))
        energyBar .= "█"
    if (normEnergy > 0.2)
        energyBar .= "…"

    ; Build dashboard text
    text := ""
    text .= "══════════ FWDE STATUS DASHBOARD ══════════`n`n"
    text .= "⏱️  TIMER HEALTH`n"
    text .= "  Physics (CalcDynamicLayout):  " physStatus "  (" physAge "ms ago, period=" Config["PhysicsTimeStep"] "ms)`n"
    text .= "  Visual  (ApplyMovements):     " visualStatus "  (" visualAge "ms ago, period=" Config["VisualTimeStep"] "ms)`n"
    text .= "  Windows (UpdateWindowStates): " wlStatus "  (" wlAge "ms ago)`n"
    text .= "  Watchdog (HealthMonitor):     " wdStatus "  (" wdAge "ms ago)`n`n"
    text .= "🖱️  DRAG & SNAP STATE`n"
    text .= "  DragThread:  " dragStatus "`n"
    text .= "  DragActive:  " dragActiveStatus "`n"
    text .= "  SnapInProgress: " snapStatus "`n"
    text .= "  ActiveWindow: 0x" Format("{:X}", g["ActiveWindow"]) "`n`n"
    text .= "📊  SYSTEM`n"
    text .= "  Windows tracked:  " g["Windows"].Length "`n"
    text .= "  Arrangement:       " (g["ArrangementActive"] ? "🟢 ON" : "🔴 OFF") "`n"
    text .= "  Physics:           " (g["PhysicsEnabled"] ? "🟢 ON" : "🔴 OFF") "`n"
    text .= "  System energy:     " Format("{:.1f}", energy) "  " energyBar "`n"
    text .= "  Icon obstacles:    " g["DesktopIconRects"].Length "`n"
    text .= "  Multi-monitor:     " (Config["MultimonitorExpanse"] ? "🟢 ON" : "🔴 OFF") "`n`n"
    text .= "🩺  RECOVERY`n"
    text .= "  Auto-recoveries:  " g["_recoveryCount"] "`n"
    text .= "  Drag failsafes:   " g["_dragFailsafeCount"] "`n"
    text .= "  Snap failsafes:   " g["_snapFailsafeCount"] "`n`n"

    ; Performance profiling data
    if (g["_perfOn"] && g["_perfData"].Count > 0) {
        text .= _PerfReport()
        text .= "`n"
    }

    text .= "💡 Ctrl+Alt+D for window debug | Ctrl+Alt+C for log`n"
    text .= "   Ctrl+Alt+Space toggle arrangement | Ctrl+Alt+F perf`n"

    ToolTip(text, 10, 10)
    ; Auto-hide after 20 seconds
    SetTimerEx(() => ToolTip(,,, 20), -20000)

    DebugLog("StatusDashboard — displayed: {} windows, energy={:.1f}, recoveries={}",
        g["Windows"].Length, energy, g["_recoveryCount"])
}


; --- Hotkey to show the menu on right-click of the taskbar ---
^!T::ShowTaskbarMenu() ; Ctrl+Alt+T to show the upgraded taskbar menu

;HOTKEYS

^!Space::ToggleArrangement()      ; Ctrl+Alt+Space to toggle
^!P::TogglePhysics()              ; Ctrl+Alt+P for physics
^!M::ToggleMultimonitorExpanse() ; Ctrl+Alt+M for multimonitor expanse
^!O::OptimizeWindowPositions()    ; Ctrl+Alt+O to optimize
^!L::ToggleWindowLock()           ; Ctrl+Alt+L to lock/unlock active window
^!D::DebugWindowInfo()            ; Ctrl+Alt+D to debug window information
^!A::ForceAddActiveWindow()       ; Ctrl+Alt+A to force add active window
^!I::ToggleIconRepulsion()       ; Ctrl+Alt+I to toggle desktop icon repulsion
^!C::DumpDebugLog()               ; Ctrl+Alt+C to copy debug log to clipboard
^!S::ShowStatusDashboard()        ; Ctrl+Alt+S to show real-time status dashboard
^!F::_PerfToggle()                ; Ctrl+Alt+F to toggle performance profiling

; HealthMonitor watchdog — runs every 5 seconds, autonomously detects and recovers from stalls
SetTimerEx(HealthMonitor, 5000)

; Periodic debug dump to disk + clipboard — keeps the log always fresh and retrievable
; Runs every 60 seconds so the clipboard always has a recent copy of the debug log
SetTimerEx(DumpDebugLogPeriodic, 60000)
 
; Start timers - but respect active window protection
SetTimerEx(UpdateWindowStates, 250)  ; Window list rebuild ~4 Hz — expensive WinGetList+IsWindowValid cycle
SetTimerEx(ApplyWindowMovements, Config["VisualTimeStep"])
UpdateWindowStates()

; Start physics calculations but only AFTER ensuring manual locks are respected
SetTimerEx(CalculateDynamicLayout, Config["PhysicsTimeStep"])      ; Only need this once

OnMessage(0x0003, WindowMoveHandler)
OnMessage(0x0005, WindowSizeHandler)

OnExit(*) {
    global g_TimerResolutionRefs, g_Crashed
    ; Always dump the debug log on exit — file + clipboard.
    ; Use DumpDebugLog for the standard format (not crash-dump header).
    if (g_Crashed) {
        ; OnError already called CopyLogToClipboard, but call again as safety net
        CopyLogToClipboard()
    } else {
        ; Normal exit: still copy the full log to clipboard so user can retrieve it
        DumpDebugLog(true)
    }
    for hwnd in g["ManualWindows"]
        RemoveManualWindowBorder(hwnd)
    while (g_TimerResolutionRefs > 0) {
        try DllCall("winmm\timeEndPeriod", "UInt", 1)
        g_TimerResolutionRefs -= 1
    }
}

; ====== REQUIRED HELPER FUNCTIONS ======
MoveWindowAPI(hwnd, x, y, w := "", h := "") {
    global g

    ; CRITICAL: Validate window handle before operation
    if (!hwnd || hwnd == 0)
        return false
    
    try {
        ; CRITICAL: Validate window still exists before moving
        if (!SafeWinExist(hwnd))
            return false
        
        ; CRITICAL: Always use SWP_NOSIZE to ensure window size is NEVER changed
        ; Flags: 0x0010 (SWP_NOACTIVATE) | 0x0004 (SWP_NOZORDER) | 0x0001 (SWP_NOSIZE)
        ; When SWP_NOSIZE is set, w and h parameters are ignored, so we can pass anything
        flags := 0x0010 | 0x0004 | 0x0001  ; SWP_NOACTIVATE | SWP_NOZORDER | SWP_NOSIZE
        if (w == "" || h == "")
            w := 0, h := 0  ; Not needed when SWP_NOSIZE is set, but required for function signature
        
        ; Mark internal scripted movement so WM_MOVE/WM_SIZE handlers can ignore it
        g["InternalMoveDepth"] += 1
        try {
            ; CRITICAL: Validate SetWindowPos return value
            result := DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", flags)
        }
        finally {
            g["LastInternalMoveTick"] := A_TickCount
            g["InternalMoveDepth"] := Max(0, g["InternalMoveDepth"] - 1)
        }
        return result != 0  ; Return true if successful, false otherwise
    } catch {
        return false
    }
}

; Add this Clamp helper function near the top-level (outside any class)
Clamp(val, min, max) {
    return val < min ? min : val > max ? max : val
}

; Helper function to identify Electron-based applications
IsElectronApp(hwnd) {
    try {
        if (!SafeWinExist(hwnd))
            return false
            
        winClass := WinGetClass("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)
        
        ; Electron apps typically use Chrome_WidgetWin_1 class
        electronClasses := [
            "Chrome_WidgetWin_1",        ; Standard Electron/Chromium class
            "Chrome_WidgetWin_0",        ; Alternative Electron class
            "ElectronMainWindow",         ; Some Electron apps use this
            "CEF-OSC-WIDGET"             ; Chromium Embedded Framework
        ]
        
        ; Electron-based applications
        electronProcesses := [
            "cursor.exe",                ; Cursor editor
            "code.exe",                  ; VS Code
            "discord.exe",               ; Discord
            "slack.exe",                 ; Slack
            "spotify.exe",               ; Spotify
            "whatsapp.exe",              ; WhatsApp Desktop
            "telegram.exe",              ; Telegram Desktop
            "notion.exe",                ; Notion
            "obsidian.exe",              ; Obsidian
            "typora.exe",                ; Typora
            "hyper.exe",                 ; Hyper terminal
            "insomnia.exe",              ; Insomnia
            "postman.exe",               ; Postman
            "figma.exe",                 ; Figma Desktop
            "sketch.exe",                ; Sketch (if Electron-based)
            "atom.exe",                  ; Atom editor
            "vscode.exe"                 ; Alternative VS Code process name
        ]
        
        ; Check window class
        for electronClass in electronClasses {
            if (winClass == electronClass)
                return true
        }
        
        ; Check process name
        for process in electronProcesses {
            if (processName ~= "i)^" process "$")
                return true
        }
        
        return false
    }
    catch {
        return false
    }
}

; Time phasing visual effects removed to prioritize physics performance.
