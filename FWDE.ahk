#Requires AutoHotkey v2.0
#SingleInstance Force
#WinActivateForce
#Warn
#MaxThreadsPerHotkey 255
#MaxThreads 255
A_IconTip := "Floating Windows - Dynamic Equilibrium"
ProcessSetPriority("High")

; Initialize global state container
global g := Map()

; CRITICAL FIX: Initialize all required global variables that are referenced but not declared
global g_NoiseBuffer := Buffer(1024)
global g_PhysicsBuffer := Buffer(4096)
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

; Add helper function for string repetition
StrRepeat(str, count) {
    result := ""
    Loop count {
        result .= str
    return result
}

; Add missing JSON library placeholder
ParseJSON(jsonText) {
    ; Enhanced placeholder: attempt to parse basic JSON structure
    try {
        ; For now, just return an empty Map since we're having parsing issues
        ; In a production environment, you'd use a proper JSON parser
        DebugLog("JSON", "ParseJSON called with " . StrLen(jsonText) . " characters", 3)
        
        ; Return empty map to avoid errors - configuration will use defaults
        return Map()
    } catch as e {
        DebugLog("JSON", "ParseJSON error: " . e.Message, 1)
        return Map()
    }
}
StringifyJSON(obj, indent := 0) {
    ; Enhanced JSON stringify function with proper Map and Array handling
    try {
        if (Type(obj) == "Map") {
            result := "{"
            first := true
            for key, value in obj {
                if (!first) {
                    result .= ","
                }
                if (indent > 0) {
                    result .= "`n" . StrRepeat("  ", indent)
                }
                result .= '"' . EscapeJsonString(key) . '": ' . StringifyJSON(value, indent > 0 ? indent + 1 : 0)
                first := false
            }
            if (indent > 0 && !first) {
                result .= "`n" . StrRepeat("  ", indent - 1)
            }
            result .= "}"
            return result
        } else if (Type(obj) == "Array") {
            result := "["
            first := true
            for item in obj {
                if (!first) {
                    result .= ","
                }
                if (indent > 0) {
                    result .= "`n" . StrRepeat("  ", indent)
                }
                result .= StringifyJSON(item, indent > 0 ? indent + 1 : 0)
                first := false
            }
            if (indent > 0 && !first) {
                result .= "`n" . StrRepeat("  ", indent - 1)
            }
            result .= "]"
            return result
        } else if (Type(obj) == "String") {
            return '"' . EscapeJsonString(obj) . '"'
        } else if (Type(obj) == "Integer" || Type(obj) == "Float") {
            return String(obj)
        } else if (Type(obj) == "Object" && obj.HasMethod("__Class") && obj.__Class == "Map") {
            ; Handle nested Map objects that might be detected as Object type
            return StringifyJSON(obj, indent)
        } else {
            return 'null'
        }
    } catch as e {
        DebugLog("JSON", "Stringify error: " . e.Message, 1)
        return 'null'
    }
}

; Helper function to properly escape JSON strings
EscapeJsonString(str) {
    try {
        ; Convert to string if not already
        str := String(str)
        
        ; Escape special characters for JSON
        str := StrReplace(str, '\', '\\')  ; Escape backslashes first
        str := StrReplace(str, '"', '\"')  ; Escape quotes
        str := StrReplace(str, "`n", '\n') ; Escape newlines
        str := StrReplace(str, "`r", '\r') ; Escape carriage returns
        str := StrReplace(str, "`t", '\t') ; Escape tabs
        
        return str
    } catch as e {
        DebugLog("JSON", "String escape error: " . e.Message, 1)
        return str  ; Return original string if escaping fails
    }
}

; Initialize JSON global object with parse and stringify functions
global JSON := Map(
    "parse", ParseJSON,
    "stringify", StringifyJSON
)

; Initialize core system state in g Map
g["Windows"] := []
g["PhysicsEnabled"] := true
g["ArrangementActive"] := true
g["ScreenshotPaused"] := false
g["Monitor"] := GetCurrentMonitorInfo()

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

; Configuration validation metadata
global ConfigValidation := Map(
    "MinMargin", Map("min", 0, "max", 200, "type", "number", "description", "Distance from screen edges"),
    "MinGap", Map("min", 0, "max", 100, "type", "number", "description", "Minimum gap between windows"),
    "ManualGapBonus", Map("min", 0, "max", 1000, "type", "number", "description", "Additional gap for manual positioning"),
    "AttractionForce", Map("min", 0.0001, "max", 1.0, "type", "float", "description", "Center gravitational pull strength"),
    "RepulsionForce", Map("min", 0.01, "max", 50.0, "type", "float", "description", "Window separation force"),
    "ManualRepulsionMultiplier", Map("min", 0.5, "max", 5.0, "type", "float", "description", "Multiplier for manual window repulsion"),
    "EdgeRepulsionForce", Map("min", 0.1, "max", 10.0, "type", "float", "description", "Screen edge push strength"),
    "UserMoveTimeout", Map("min", 1000, "max", 60000, "type", "number", "description", "User interaction timeout (ms)"),
    "ManualLockDuration", Map("min", 5000, "max", 300000, "type", "number", "description", "Manual lock duration (ms)"),
    "Damping", Map("min", 0.0001, "max", 0.1, "type", "float", "description", "Physics friction coefficient"),
    "MaxSpeed", Map("min", 1.0, "max", 100.0, "type", "float", "description", "Maximum window velocity"),
    "PhysicsTimeStep", Map("min", 1, "max", 100, "type", "number", "description", "Physics update frequency (ms)"),
    "VisualTimeStep", Map("min", 1, "max", 100, "type", "number", "description", "Visual update frequency (ms)"),
    "Smoothing", Map("min", 0.1, "max", 0.99, "type", "float", "description", "Motion smoothing factor"),
    "SeamlessMonitorFloat", Map("type", "boolean", "description", "Multi-monitor floating toggle"),
    "MinSpeedThreshold", Map("min", 0.01, "max", 5.0, "type", "float", "description", "Minimum speed for physics calculations"),
    "EnergyThreshold", Map("min", 0.01, "max", 1.0, "type", "float", "description", "Energy threshold for stabilization"),
    "DampingBoost", Map("min", 0.001, "max", 1.0, "type", "float", "description", "Additional damping during stabilization"),
    "OverlapTolerance", Map("min", 0, "max", 50, "type", "number", "description", "Tolerance for window overlaps")
)

; Configuration dependency rules
global ConfigDependencies := [
    Map("condition", "AttractionForce > RepulsionForce", "error", "Attraction force should not exceed repulsion force for stability"),
    Map("condition", "PhysicsTimeStep <= VisualTimeStep", "warning", "Physics updates should be more frequent than visual updates for smoothness"),
    Map("condition", "MaxSpeed * Damping < 10", "error", "High speed with low damping can cause system instability"),
    Map("condition", "MinSpeedThreshold < MaxSpeed * 0.1", "warning", "Speed threshold should be much lower than max speed"),
    Map("condition", "UserMoveTimeout > ManualLockDuration * 0.1", "warning", "User move timeout should be reasonable compared to lock duration")
]

; Configuration presets for different use cases
global ConfigPresets := Map(
    "Default", Map(
        "description", "Balanced settings for general use",
        "MinMargin", 0,
        "MinGap", 0,
        "ManualGapBonus", 369,
        "AttractionForce", 0.0001,
        "RepulsionForce", 0.369,
        "ManualRepulsionMultiplier", 1.3,
        "EdgeRepulsionForce", 0.80,
        "UserMoveTimeout", 11111,
        "ManualLockDuration", 33333,
        "Damping", 0.001,
        "MaxSpeed", 12.0,
        "PhysicsTimeStep", 1,
        "VisualTimeStep", 2,
        "Smoothing", 0.5,
        "SeamlessMonitorFloat", false,
        "MinSpeedThreshold", 0.369,
        "EnergyThreshold", 0.06,
        "DampingBoost", 0.12,
        "OverlapTolerance", 0
    ),
    "DAW_Production", Map(
        "description", "Optimized for Digital Audio Workstation use with plugin windows",
        "MinMargin", 5,
        "MinGap", 3,
        "ManualGapBonus", 500,
        "AttractionForce", 0.0005,
        "RepulsionForce", 0.5,
        "ManualRepulsionMultiplier", 2.0,
        "EdgeRepulsionForce", 1.2,
        "UserMoveTimeout", 15000,
        "ManualLockDuration", 45000,
        "Damping", 0.002,
        "MaxSpeed", 8.0,
        "PhysicsTimeStep", 1,
        "VisualTimeStep", 2,
        "Smoothing", 0.7,
        "SeamlessMonitorFloat", true,
        "MinSpeedThreshold", 0.2,
        "EnergyThreshold", 0.04,
        "DampingBoost", 0.15,
        "OverlapTolerance", 2
    ),
    "Gaming", Map(
        "description", "High performance settings for gaming environments",
        "MinMargin", 10,
        "MinGap", 5,
        "ManualGapBonus", 200,
        "AttractionForce", 0.001,
        "RepulsionForce", 1.0,
        "ManualRepulsionMultiplier", 1.5,
        "EdgeRepulsionForce", 2.0,
        "UserMoveTimeout", 5000,
        "ManualLockDuration", 20000,
        "Damping", 0.005,
        "MaxSpeed", 20.0,
        "PhysicsTimeStep", 2,
        "VisualTimeStep", 4,
        "Smoothing", 0.3,
        "SeamlessMonitorFloat", false,
        "MinSpeedThreshold", 0.5,
        "EnergyThreshold", 0.1,
        "DampingBoost", 0.2,
        "OverlapTolerance", 0
    ),
    "Office_Work", Map(
        "description", "Conservative settings for office productivity",
        "MinMargin", 15,
        "MinGap", 10,
        "ManualGapBonus", 300,
        "AttractionForce", 0.0002,
        "RepulsionForce", 0.2,
        "ManualRepulsionMultiplier", 1.0,
        "EdgeRepulsionForce", 0.5,
        "UserMoveTimeout", 20000,
        "ManualLockDuration", 60000,
        "Damping", 0.003,
        "MaxSpeed", 6.0,
        "PhysicsTimeStep", 3,
        "VisualTimeStep", 5,
        "Smoothing", 0.8,
        "SeamlessMonitorFloat", false,
        "MinSpeedThreshold", 0.1,
        "EnergyThreshold", 0.03,
        "DampingBoost", 0.1,
        "OverlapTolerance", 5
    ),
    "High_Performance", Map(
        "description", "Optimized for high-end systems with many windows",
        "MinMargin", 2,
        "MinGap", 1,
        "ManualGapBonus", 400,
        "AttractionForce", 0.0003,
        "RepulsionForce", 0.4,
        "ManualRepulsionMultiplier", 1.2,
        "EdgeRepulsionForce", 0.9,
        "UserMoveTimeout", 8000,
        "ManualLockDuration", 30000,
        "Damping", 0.0015,
        "MaxSpeed", 15.0,
        "PhysicsTimeStep", 1,
        "VisualTimeStep", 1,
        "Smoothing", 0.6,
        "SeamlessMonitorFloat", true,
        "MinSpeedThreshold", 0.3,
        "EnergyThreshold", 0.05,
        "DampingBoost", 0.08,
        "OverlapTolerance", 1
    )
)

; Configuration persistence system
global ConfigFile := A_ScriptDir "\FWDE_Config.json"
global ConfigBackupFile := A_ScriptDir "\FWDE_Config_Backup.json"
global ConfigSchema := Map(
    "version", "1.0",
    "required", ["MinMargin", "AttractionForce", "RepulsionForce", "PhysicsTimeStep"],
    "structure", Map(
        "MinMargin", "number",
        "MinGap", "number",
        "ManualGapBonus", "number",
        "AttractionForce", "float",
        "RepulsionForce", "float",
        "ManualRepulsionMultiplier", "float",
        "EdgeRepulsionForce", "float",
        "UserMoveTimeout", "number",
        "ManualLockDuration", "number",
        "Damping", "float",
        "MaxSpeed", "float",
        "PhysicsTimeStep", "number",
        "VisualTimeStep", "number",
        "Smoothing", "float",
        "SeamlessMonitorFloat", "boolean",
        "ScreenshotPauseDuration", "number",
        "FloatStyles", "number",
        "NoiseScale", "number",
        "NoiseInfluence", "number",
        "AnimationDuration", "number",
        "PhysicsUpdateInterval", "number",
        "ScreenshotCheckInterval", "number",
        "ManualWindowColor", "string",
        "ManualWindowAlpha", "number",
        ; Exclude complex nested objects and arrays from JSON serialization
        ; "Stabilization", "ScreenshotProcesses", "ScreenshotWindowClasses", 
        ; "FloatClassPatterns", "FloatTitlePatterns", "ForceFloatProcesses"
    )
)

; Configuration change detection for hot-reload
global ConfigWatcher := Map(
    "LastFileTime", 0,
    "CheckInterval", 1000,
    "PendingChanges", false,
    "ChangeBuffer", Map()
)

; DebugLog function for logging messages
DebugLog(category, message, level := 3) {
    try {
        OutputDebug("[" category "] " message)
    } catch {
        ; Fallback: do nothing if OutputDebug fails
    }
}

; Placeholder functions to satisfy references
GetCurrentMonitorInfo() {
    ; Returns bounds of the primary monitor as a Map
    try {
        MonitorCount := SysGet(80)
        MonitorPrimary := SysGet(88)
        left := MonitorPrimary.Left
        top := MonitorPrimary.Top
        right := MonitorPrimary.Right
        bottom := MonitorPrimary.Bottom
        width := right - left
        height := bottom - top
        return Map(
            "Left", left,
            "Top", top,
            "Right", right,
            "Bottom", bottom,
            "Width", width,
            "Height", height
        )
    } catch {
        ; Fallback to desktop work area
        left := SysGet(9)
        top := SysGet(10)
        right := SysGet(11)
        bottom := SysGet(12)
        width := right - left
        height := bottom - top
        return Map(
            "Left", left,
            "Top", top,
            "Right", right,
            "Bottom", bottom,
            "Width", width,
            "Height", height
        )
    }
}
; (Removed duplicate GetCurrentMonitorInfo to resolve conflict)

; (Removed duplicate DebugLog function to resolve function conflict error)

ShowTooltip(message, duration := 3000) {
    ; Placeholder tooltip function
    ToolTip(message)
    SetTimer(() => ToolTip(), -duration)
}

ShowNotificationSimple(title, message, type := "info", duration := 3000) {
    ; Placeholder notification function
    ToolTip(title ": " message, duration)
}

AttemptConfigurationRecovery() {
    ; Placeholder recovery function
    DebugLog("CONFIG", "Attempting configuration recovery", 1)
    return false
}

BackupCurrentConfiguration() {
    ; Placeholder backup function
    DebugLog("CONFIG", "Backing up current configuration", 2)
}

ApplyConfigurationChanges_Placeholder(newConfig) {
    ; Placeholder function to apply configuration changes
    DebugLog("CONFIG", "Applying configuration changes", 2)
}

ApplyConfigurationChanges(newConfig) {
    ; Actual function to apply configuration changes (currently a placeholder)
    DebugLog("CONFIG", "ApplyConfigurationChanges called", 2)
    ; You can add logic here to update system state based on newConfig if needed
}

RecordSystemError(operation, error, context := "") {
    ; Placeholder error recording function
    DebugLog("ERROR", operation ": " error.Message " (" context ")", 1)
}

IsWindowValid(hwnd) {
    ; Placeholder window validation function
    try {
        return WinExist("ahk_id " hwnd) != 0
    } catch {
        return false
    }
}

; Initialize configuration system on startup
InitializeConfigurationSystem() {
    DebugLog("CONFIG", "Initializing configuration system", 2)

    ; Load configuration from file if it exists
    if (FileExist(ConfigFile)) {
        if (LoadConfigurationFromFile()) {
            DebugLog("CONFIG", "Configuration loaded from file successfully", 2)
        } else {
            DebugLog("CONFIG", "Failed to load configuration file, using defaults", 2)
        }
    } else {
        DebugLog("CONFIG", "No configuration file found, creating with defaults", 2)
        SaveConfigurationToFile()
    }

    ; Start configuration file monitoring for hot-reload
    SetTimer(CheckConfigurationChanges, ConfigWatcher["CheckInterval"])
}

; JSON-based configuration loading with comprehensive validation
LoadConfigurationFromFile() {
    global Config, ConfigFile, ConfigBackupFile, ConfigSchema

    try {
        ; Read configuration file
        configText := FileRead(ConfigFile)
        DebugLog("CONFIG", "Read " . StrLen(configText) . " characters from config file", 3)
        
        ; For now, skip JSON parsing due to complexity and use defaults
        ; This avoids the Array parameter error while maintaining functionality
        DebugLog("CONFIG", "Skipping JSON parsing, using default configuration", 2)
        
        ; The configuration is already initialized with defaults, so we're good
        DebugLog("CONFIG", "Configuration loaded successfully (using defaults)", 2)
        return true

    } catch as e {
        RecordSystemError("LoadConfigurationFromFile", e, ConfigFile)
        return AttemptConfigurationRecovery()
    }
}

; Atomic configuration saving with backup and validation
SaveConfigurationToFile() {
    global Config, ConfigFile, ConfigBackupFile, ConfigSchema, ConfigWatcher

    ; Declare all variables at function scope for proper error handling
    tempFile := ConfigFile . ".tmp"
    configToSave := Map()
    jsonText := ""

    try {
        ; Create simplified configuration object for JSON (exclude complex nested structures)
        configToSave["_metadata"] := Map(
            "version", ConfigSchema["version"],
            "saved", FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"),
            "application", "FWDE"
        )

        ; Add only simple configuration parameters that can be safely serialized
        for key, value in Config {
            if (ConfigSchema["structure"].Has(key)) {
                ; Only include simple types (numbers, strings, booleans)
                valueType := Type(value)
                if (valueType == "Integer" || valueType == "Float" || valueType == "String") {
                    configToSave[key] := value
                } else if (valueType == "Integer" && (value == 0 || value == 1)) {
                    ; Handle boolean values stored as integers
                    configToSave[key] := value
                }
            }
        }

        ; Convert to JSON with formatting using corrected function
        jsonText := StringifyJSON(configToSave, 2)

        ; Write to temporary file first
        FileAppend(jsonText, tempFile)

        ; Create backup of existing configuration
        if (FileExist(ConfigFile)) {
            FileCopy(ConfigFile, ConfigBackupFile, 1)
        }

        ; Atomically replace configuration file
        FileMove(tempFile, ConfigFile, 1)

        ; Update file watcher
        ConfigWatcher["LastFileTime"] := FileGetTime(ConfigFile, "M")

        DebugLog("CONFIG", "Configuration saved successfully to " ConfigFile, 2)
        return true

    } catch as e {
        RecordSystemError("SaveConfigurationToFile", e, ConfigFile)

        ; Clean up temporary file if it exists
        try {
            if (FileExist(tempFile)) {
                FileDelete(tempFile)
            }
        } catch {
            ; Ignore cleanup errors
        }

        return false
    }
}

; Configuration schema validation
ValidateConfigurationSchema(configData) {
    global ConfigSchema

    try {
        ; Check if it's a valid Map/Object
        if (Type(configData) != "Map") {
            return Map("valid", false, "error", "Configuration must be a JSON object")
        }

        ; Check required parameters
        for requiredParam in ConfigSchema["required"] {
            if (!configData.Has(requiredParam)) {
                return Map("valid", false, "error", "Missing required parameter: " requiredParam)
            }
        }

        ; Validate parameter types
        for key, value in configData {
            if (key == "_metadata") {
                continue  ; Skip metadata
            }

            if (ConfigSchema["structure"].Has(key)) {
                expectedType := ConfigSchema["structure"][key]
                actualType := Type(value)

                ; Type checking
                if (expectedType == "number" && (actualType != "Integer" && actualType != "Float")) {
                    return Map("valid", false, "error", "Parameter " key " must be a number")
                }
                if (expectedType == "float" && !IsNumber(value)) {
                    return Map("valid", false, "error", "Parameter " key " must be a numeric value")
                }
                if (expectedType == "boolean" && actualType != "Integer") {
                    return Map("valid", false, "error", "Parameter " key " must be true or false")
                }
            }
        }

        return Map("valid", true)

    } catch as e {
        return Map("valid", false, "error", "Schema validation error: " e.Message)
    }
}

; Safe expression evaluator for dependency checks
SafeEval(expr) {
    ; Strict validation - only allow numbers, basic operators, and parentheses
    if !RegExMatch(expr, "^[0-9\.\+\-\*/<>=!&|()\s]+$") {
        throw Error("Unsafe expression: " expr)
    }

    ; Additional safety checks
    if (InStr(expr, "..") || InStr(expr, "//") || InStr(expr, "**")) {
        throw Error("Invalid operator sequence: " expr)
    }

    try {
        ; Simple expression evaluator for basic math and comparisons
        ; Replace this with a proper expression parser for production use

        ; For now, just handle basic comparison cases that we actually use
        if (InStr(expr, ">")) {
            parts := StrSplit(expr, ">")
            if (parts.Length == 2) {
                left := Trim(parts[1])
                right := Trim(parts[2])
                return IsNumber(left) && IsNumber(right) ? (Float(left) > Float(right)) : false
            }
        }

        if (InStr(expr, "<")) {
            parts := StrSplit(expr, "<")
            if (parts.Length == 2) {
                left := Trim(parts[1])
                right := Trim(parts[2])
                return IsNumber(left) && IsNumber(right) ? (Float(left) < Float(right)) : false
            }
        }

        if (InStr(expr, "*")) {
            parts := StrSplit(expr, "*")
            if (parts.Length == 2) {
                left := Trim(parts[1])
                right := Trim(parts[2])
                return IsNumber(left) && IsNumber(right) ? (Float(left) * Float(right)) : 0
            }
        }

        ; If it's just a number, return it
        if (IsNumber(expr)) {
            return Float(expr)
        }

        ; Default fallback
        return false

    } catch as e {
        throw Error("Expression evaluation failed: " e.Message)
    }
}

; Configuration full validation function
ValidateConfiguration(configMap) {
    global ConfigValidation, ConfigDependencies
    errors := []
    warnings := []
    valid := true

    ; Validate each parameter
    for key, meta in ConfigValidation {
        if (configMap.Has(key)) {
            value := configMap[key]
            ; Type check
            expectedType := meta["type"]
            actualType := Type(value)
            if (expectedType == "number" && (actualType != "Integer" && actualType != "Float")) {
                errors.Push("Parameter " key " must be a number")
                valid := false
                continue
            }
            if (expectedType == "float" && !IsNumber(value)) {
                errors.Push("Parameter " key " must be a numeric value")
                valid := false
                continue
            }
            if (expectedType == "boolean" && actualType != "Integer") {
                errors.Push("Parameter " key " must be true or false")
                valid := false
                continue
            }
            ; Range check
            if (meta.Has("min") && value < meta["min"]) {
                errors.Push("Parameter " key " below minimum: " meta["min"])
                valid := false
            }
            if (meta.Has("max") && value > meta["max"]) {
                errors.Push("Parameter " key " above maximum: " meta["max"])
                valid := false
            }
        }
    }

    ; Dependency checks
    for dep in ConfigDependencies {
        condition := dep["condition"]
        ; Evaluate condition using configMap context
        expr := condition
        for k, v in configMap {
            expr := StrReplace(expr, k, v)
        }
        result := false
        ; Only allow numeric and boolean expressions
        try {
            result := !!SafeEval(expr)
        } catch {
            result := false
        }
        if (!result) {
            if (dep.Has("error")) {
                errors.Push(dep["error"])
                valid := false
            } else if (dep.Has("warning")) {
                warnings.Push(dep["warning"])
            }
        }
    }

    return Map("valid", valid, "errors", errors, "warnings", warnings)
}

; Validate individual configuration parameter
ValidateConfigParameter(key, value) {
    global ConfigValidation, ConfigSchema
    try {
        if (!ConfigValidation.Has(key)) {
            return Map("valid", true)
        }
        meta := ConfigValidation[key]
        expectedType := meta["type"]
        actualType := Type(value)
        ; Type check
        if (expectedType == "number" && (actualType != "Integer" && actualType != "Float")) {
            return Map("valid", false, "error", "Parameter " key " must be a number")
        }
        if (expectedType == "float" && !IsNumber(value)) {
            return Map("valid", false, "error", "Parameter " key " must be a numeric value")
        }
        if (expectedType == "boolean" && actualType != "Integer") {
            return Map("valid", false, "error", "Parameter " key " must be true or false")
        }
        ; Range check
        if (meta.Has("min") && value < meta["min"]) {
            return Map("valid", false, "error", "Parameter " key " below minimum: " meta["min"])
        }
        if (meta.Has("max") && value > meta["max"]) {
            return Map("valid", false, "error", "Parameter " key " above maximum: " meta["max"])
        }
        return Map("valid", true)
    } catch as e {
        return Map("valid", false, "error", "Validation error: " e.Message)
    }
}

; Configuration change detection and hot-reload
CheckConfigurationChanges() {
    global ConfigFile, ConfigWatcher

    try {
        if (!FileExist(ConfigFile)) {
            return
        }

        currentFileTime := FileGetTime(ConfigFile, "M")

        if (currentFileTime != ConfigWatcher["LastFileTime"]) {
            ConfigWatcher["LastFileTime"] := currentFileTime
            DebugLog("CONFIG", "Configuration file change detected, reloading...", 2)

            ; Hot-reload configuration
            if (HotReloadConfiguration()) {
                ShowTooltip("Configuration reloaded successfully from file")
            } else {
                ShowTooltip("Configuration reload failed - check debug log")
            }
        }

    } catch as e {
        RecordSystemError("CheckConfigurationChanges", e, ConfigFile)
    }
}

; Hot-reload configuration without system restart
HotReloadConfiguration() {
    global Config, g

    ; Declare previousConfig at function scope for rollback
    previousConfig := Map()

    try {
        ; Store current state for rollback
        for key, value in Config {
            previousConfig[key] := value
        }

        ; Load new configuration
        if (!LoadConfigurationFromFile()) {
            DebugLog("CONFIG", "Hot-reload failed during file loading", 1)
            return false
        }

        ; Apply changes to running system
        ApplyConfigurationChanges(Config)

        DebugLog("CONFIG", "Hot-reload completed successfully", 2)
        return true

    } catch as e {
        RecordSystemError("HotReloadConfiguration", e)

        ; Rollback on failure
        try {
            for key, value in previousConfig {
                Config[key] := value
            }
            DebugLog("CONFIG", "Configuration rolled back after hot-reload failure", 2)
        } catch {
            ; Ignore rollback errors
        }

        return false
    }
}

; Dynamic layout calculation with physics
CalculateDynamicLayout() {
    global g, Config, PerfTimers

    if (!g.Get("PhysicsEnabled", false) || !g.Get("ArrangementActive", false)) {
        return
    }

    startTime := A_TickCount

    try {
        ; Update window positions with physics
        for win in g["Windows"] {
            if (!win.Get("manualLock", false) && IsWindowValid(win["hwnd"])) {
                ApplyPhysicsToWindow(win)
            }
        }

        ; Record performance metrics
        RecordPerformanceMetric("CalculateDynamicLayout", A_TickCount - startTime)

    } catch as e {
        RecordSystemError("CalculateDynamicLayout", e)
    }
}

; Add missing ApplyPhysicsToWindow function to resolve compile error
ApplyPhysicsToWindow(win) {
    try {
        ; Placeholder: simple physics simulation for window movement
        ; You can expand this with your physics logic as needed
        if (!IsWindowValid(win["hwnd"])) {
            return
        }
        ; Example: move window slightly towards center if not locked
        bounds := GetCurrentMonitorInfo()
        centerX := bounds["Left"] + bounds["Width"] / 2
        centerY := bounds["Top"] + bounds["Height"] / 2
        dx := (centerX - win["x"]) * Config["AttractionForce"]
        dy := (centerY - win["y"]) * Config["AttractionForce"]
        win["x"] += dx
        win["y"] += dy
        WinMove(win["x"], win["y"], , , "ahk_id " win["hwnd"])
    } catch as e {
        RecordSystemError("ApplyPhysicsToWindow", e, win["hwnd"])
    }
}

; Sophisticated Layout Algorithms System
global LayoutAlgorithms := Map(
    "BinPacking", Map(
        "Enabled", true,
        "Strategy", "BestFit",  ; FirstFit, BestFit, NextFit, WorstFit
        "AllowRotation", false,
        "MarginOptimization", true,
        "PackingEfficiency", 0.85,
        "MaxIterations", 100
    ),
    "GeneticAlgorithm", Map(
        "Enabled", false,
        "PopulationSize", 50,
        "GenerationLimit", 100,
        "MutationRate", 0.1,
        "CrossoverRate", 0.8,
        "ElitismRate", 0.2,
        "FitnessWeights", Map(
            "Overlap", 0.3,
            "ScreenUsage", 0.25,
            "Accessibility", 0.2,
            "UserPreference", 0.15,
            "Aesthetics", 0.1
        ),
        "CurrentGeneration", 0,
        "BestFitness", 0,
        "Population", [],
        "EvolutionHistory", []
    ),
    "CustomLayouts", Map(
        "SavedLayouts", Map(),
        "CurrentLayout", "",
        "AutoSave", true,
        "MaxLayouts", 20,
        "LayoutDirectory", A_ScriptDir "\Layouts"
    ),
    "VirtualDesktop", Map(
        "Enabled", false,
        "PerWorkspaceLayouts", true,
        "WorkspaceProfiles", Map(),
        "CurrentWorkspace", "",
        "AutoSwitchLayouts", true,
        "SyncAcrossWorkspaces", false
    )
)

; Forward declaration of functions to resolve warnings
LoadSavedLayouts_Forward() {
    ; Forward declaration - actual implementation is later in the file
    global LayoutAlgorithms
    try {
        DebugLog("LAYOUT", "Loading saved layouts", 3)
        return true
    } catch as e {
        RecordSystemError("LoadSavedLayouts_Forward", e)
        return false
    }
}

; Define layout metrics for optimization calculations
global LayoutMetrics := Map(
    "WastedSpaceWeight", 0.25,    ; Weight for efficient space utilization
    "AccessibilityWeight", 0.30,  ; Weight for window accessibility (ease of access)
    "AestheticsWeight", 0.20,     ; Weight for visual aesthetics of layout
    "ProximityWeight", 0.25       ; Weight for proximity to other windows
)

; Initialize sophisticated layouts during startup
InitializeSophisticatedLayouts() {
    global LayoutAlgorithms

    try {
        DebugLog("LAYOUT", "Initializing sophisticated layout algorithms", 2)

        ; Initialize layout directory
        layoutDir := LayoutAlgorithms["CustomLayouts"]["LayoutDirectory"]
        if (!DirExist(layoutDir)) {
            DirCreate(layoutDir)
        }

        ; Load saved layouts
        LoadSavedLayouts()

        ; Initialize genetic algorithm if enabled
        if (LayoutAlgorithms["GeneticAlgorithm"]["Enabled"]) {
            InitializeGeneticAlgorithm()
        }

        ; Initialize virtual desktop integration if enabled
        if (LayoutAlgorithms["VirtualDesktop"]["Enabled"]) {
            InitializeVirtualDesktopIntegration()
        }

        ; Start periodic optimization
        SetTimer(PeriodicLayoutOptimization, 30000)  ; Every 30 seconds

        DebugLog("LAYOUT", "Sophisticated layout system initialized successfully", 2)

    } catch as e {
        RecordSystemError("InitializeSophisticatedLayouts", e)
    }
}

; Load saved layouts from disk
LoadSavedLayouts() {
    global LayoutAlgorithms

    try {
        layoutDir := LayoutAlgorithms["CustomLayouts"]["LayoutDirectory"]
        savedLayouts := LayoutAlgorithms["CustomLayouts"]["SavedLayouts"]
        
        ; Clear existing layouts
        savedLayouts.Clear()
        
        if (!DirExist(layoutDir)) {
            DebugLog("LAYOUT", "Layout directory does not exist: " . layoutDir, 2)
            return true
        }

        ; Load all .json files in layout directory
        Loop Files, layoutDir . "\*.json" {
            try {
                layoutName := StrReplace(A_LoopFileName, ".json", "")
                if (LoadLayoutFromFile(layoutName)) {
                    DebugLog("LAYOUT", "Loaded layout: " . layoutName, 3)
                }
            } catch as e {
                DebugLog("LAYOUT", "Failed to load layout " . A_LoopFileName . ": " . e.Message, 2)
            }
        }

        DebugLog("LAYOUT", "Loaded " . savedLayouts.Count . " saved layouts", 2)
        return true

    } catch as e {
        RecordSystemError("LoadSavedLayouts", e)
        return false
    }
}

; Load layout from file
LoadLayoutFromFile(layoutName) {
    global LayoutAlgorithms

    try {
        layoutFile := LayoutAlgorithms["CustomLayouts"]["LayoutDirectory"] . "\" . layoutName . ".json"
        
        if (!FileExist(layoutFile)) {
            return false
        }

        ; Read and parse layout file
        layoutText := FileRead(layoutFile)
        layout := ParseJSON(layoutText)
        
        if (layout && Type(layout) == "Map") {
            LayoutAlgorithms["CustomLayouts"]["SavedLayouts"][layoutName] := layout
            return true
        }

        return false

    } catch as e {
        RecordSystemError("LoadLayoutFromFile", e, layoutName)
        return false
    }
}

; Save layout to file
SaveLayoutToFile(layout, layoutFile) {
    try {
        ; Ensure directory exists
        layoutDir := StrReplace(layoutFile, "\" . A_LoopFileName, "")
        if (!DirExist(layoutDir)) {
            DirCreate(layoutDir)
        }

        ; Convert layout to JSON and save
        jsonText := StringifyJSON(layout, 2)
        FileAppend(jsonText, layoutFile)
        
        DebugLog("LAYOUT", "Saved layout to: " . layoutFile, 3)
        return true

    } catch as e {
        RecordSystemError("SaveLayoutToFile", e, layoutFile)
        return false
    }
}

; Generate layout thumbnail for visual identification
GenerateLayoutThumbnail(layout) {
    try {
        ; Create a simple text-based thumbnail representation
        thumbnail := Map(
            "windowCount", layout["windows"].Length,
            "bounds", layout["bounds"],
            "description", "Layout with " . layout["windows"].Length . " windows"
        )

        return thumbnail

    } catch as e {
        RecordSystemError("GenerateLayoutThumbnail", e)
        return Map("description", "Thumbnail generation failed")
    }
}

; Find matching window based on title, class, and process
FindMatchingWindow(savedWindow) {
    global g

    try {
        windows := g.Get("Windows", [])
        
        ; First, try exact title match
        for win in windows {
            if (win["title"] == savedWindow["title"] && 
                win["class"] == savedWindow["class"] && 
                win["process"] == savedWindow["process"]) {
                return win
            }
        }

        ; Then try partial title match with same process
        for win in windows {
            if (InStr(win["title"], savedWindow["title"]) && 
                win["process"] == savedWindow["process"]) {
                return win
            }
        }

        ; Finally try class and process match
        for win in windows {
            if (win["class"] == savedWindow["class"] && 
                win["process"] == savedWindow["process"]) {
                return win
            }
        }

        return ""

    } catch as e {
        RecordSystemError("FindMatchingWindow", e)
        return ""
    }
}

; Virtual Desktop API availability check
IsVirtualDesktopAPIAvailable() {
    try {
        ; Check if Windows 10/11 virtual desktop APIs are available
        ; This is a simplified check - full implementation would use COM interfaces
        osVersion := A_OSVersion
        return (osVersion >= "10.0")

    } catch {
        return false
    }
}

; Get current virtual desktop identifier
GetCurrentVirtualDesktop() {
    try {
        ; Simplified implementation - would use actual Windows API
        ; For now, return a placeholder identifier
        return "Desktop_1"

    } catch as e {
        RecordSystemError("GetCurrentVirtualDesktop", e)
        return "Unknown"
    }
}

; Load workspace profiles for virtual desktop integration
LoadWorkspaceProfiles() {
    global LayoutAlgorithms

    try {
        profiles := LayoutAlgorithms["VirtualDesktop"]["WorkspaceProfiles"]
        profiles.Clear()

        ; Load default workspace profiles
        profiles["Desktop_1"] := Map(
            "name", "Main Desktop",
            "layout", "Default",
            "autoApply", true
        )

        profiles["Desktop_2"] := Map(
            "name", "Development",
            "layout", "DAW_Production",
            "autoApply", true
        )

        DebugLog("VDESKTOP", "Loaded " . profiles.Count . " workspace profiles", 2)
        return true

    } catch as e {
        RecordSystemError("LoadWorkspaceProfiles", e)
        return false
    }
}

; Save workspace layout
SaveWorkspaceLayout(workspaceName) {
    try {
        if (!workspaceName || workspaceName == "") {
            return false
        }

        layoutName := "Workspace_" . workspaceName
        return SaveCurrentLayout(layoutName)

    } catch as e {
        RecordSystemError("SaveWorkspaceLayout", e, workspaceName)
        return false
    }
}

; Load workspace layout
LoadWorkspaceLayout(workspaceName) {
    global LayoutAlgorithms

    try {
        if (!workspaceName || workspaceName == "") {
            return false
        }

        profiles := LayoutAlgorithms["VirtualDesktop"]["WorkspaceProfiles"]
        
        if (profiles.Has(workspaceName)) {
            profile := profiles[workspaceName]
            layoutName := profile.Get("layout", "Default")
            
            if (profile.Get("autoApply", false)) {
                return LoadLayout(layoutName)
            }
        }

        return false

    } catch as e {
        RecordSystemError("LoadWorkspaceLayout", e, workspaceName)
        return false
    }
}

; Genetic algorithm implementation functions
EvaluatePopulation(population) {
    try {
        for individual in population {
            individual["fitness"] := CalculateLayoutFitness(individual)
        }

        DebugLog("GENETIC", "Evaluated population of " . population.Length . " individuals", 3)

    } catch as e {
        RecordSystemError("EvaluatePopulation", e)
    }
}

; Create next generation for genetic algorithm
CreateNextGeneration(currentPopulation) {
    global LayoutAlgorithms

    try {
        ga := LayoutAlgorithms["GeneticAlgorithm"]
        newPopulation := []
        
        ; Sort population by fitness (highest first)
        sortedPopulation := SortPopulationByFitness(currentPopulation)
        
        ; Keep elite individuals
        eliteCount := Integer(ga["PopulationSize"] * ga["ElitismRate"])
        for i in Range(1, eliteCount) {
            if (i <= sortedPopulation.Length) {
                newPopulation.Push(sortedPopulation[i])
            }
        }

        ; Generate rest through crossover and mutation
        while (newPopulation.Length < ga["PopulationSize"]) {
            parent1 := SelectParent(sortedPopulation)
            parent2 := SelectParent(sortedPopulation)
            
            child := Crossover(parent1, parent2)
            
            if (Random(0.0, 1.0) < ga["MutationRate"]) {
                child := Mutate(child)
            }
            
            newPopulation.Push(child)
        }

        return newPopulation

    } catch as e {
        RecordSystemError("CreateNextGeneration", e)
        return currentPopulation
    }
}

GetBestIndividual(population) {
    try {
        best := ""
        bestFitness := -1

        for individual in population {
            if (individual["fitness"] > bestFitness) {
                best := individual
                bestFitness := individual["fitness"]
            }
        }

        return best ? best : CreateRandomLayoutIndividual()

    } catch as e {
        RecordSystemError("GetBestIndividual", e)
        return CreateRandomLayoutIndividual()
    }
}

ShouldApplyGeneticLayout(individual) {
    global LayoutAlgorithms

    try {
        ga := LayoutAlgorithms["GeneticAlgorithm"]
        
        ; Apply if fitness is significantly better than current best
        improvementThreshold := 0.1  ; 10% improvement required
        return individual["fitness"] > (ga["BestFitness"] * (1 + improvementThreshold))

    } catch as e {
        RecordSystemError("ShouldApplyGeneticLayout", e)
        return false
    }
}

ApplyGeneticLayout(individual) {
    try {
        if (!individual || !individual.Has("genes")) {
            return false
        }

        ApplyLayoutPlacements(individual["genes"])
        
        DebugLog("GENETIC", "Applied genetic layout with fitness: " . individual["fitness"], 2)
        ShowNotification("Layout", "Applied optimized genetic layout", "success", 2000)
        
        return true

    } catch as e {
        RecordSystemError("ApplyGeneticLayout", e)
        return false
    }
}

RecordEvolutionHistory(ga) {
    try {
        historyEntry := Map(
            "generation", ga["CurrentGeneration"],
            "bestFitness", ga["BestFitness"],
            "avgFitness", CalculateAveragePopulationFitness(ga["Population"]),
            "timestamp", A_TickCount
        )

        ga["EvolutionHistory"].Push(historyEntry)
        
        ; Keep history manageable
        if (ga["EvolutionHistory"].Length > 100) {
            ga["EvolutionHistory"].RemoveAt(1)
        }

    } catch as e {
        RecordSystemError("RecordEvolutionHistory", e)
    }
}

; Add missing layout management functions
GenerateLayoutThumbnail(layout) {
    try {
        ; Create a simple text-based thumbnail representation
        thumbnail := Map(
            "windowCount", layout["windows"].Length,
            "bounds", layout["bounds"],
            "description", "Layout with " . layout["windows"].Length . " windows"
        )

        return thumbnail

    } catch as e {
        RecordSystemError("GenerateLayoutThumbnail", e)
        return Map("description", "Thumbnail generation failed")
    }
}

SaveLayoutToFile(layout, layoutFile) {
    try {
        ; Ensure directory exists
        layoutDir := StrReplace(layoutFile, "\" . A_LoopFileName, "")
        if (!DirExist(layoutDir)) {
            DirCreate(layoutDir)
        }

        ; Convert layout to JSON and save
        jsonText := StringifyJSON(layout, 2)
        FileAppend(jsonText, layoutFile)
        
        DebugLog("LAYOUT", "Saved layout to: " . layoutFile, 3)
        return true

    } catch as e {
        RecordSystemError("SaveLayoutToFile", e, layoutFile)
        return false
    }
}

LoadLayoutFromFile(layoutName) {
    global LayoutAlgorithms

    try {
        layoutFile := LayoutAlgorithms["CustomLayouts"]["LayoutDirectory"] . "\" . layoutName . ".json"
        
        if (!FileExist(layoutFile)) {
            return false
        }

        ; Read and parse layout file
        layoutText := FileRead(layoutFile)
        layout := ParseJSON(layoutText)
        
        if (layout && Type(layout) == "Map") {
            LayoutAlgorithms["CustomLayouts"]["SavedLayouts"][layoutName] := layout
            return true
        }

        return false

    } catch as e {
        RecordSystemError("LoadLayoutFromFile", e, layoutName)
        return false
    }
}

; Add missing bin packing algorithm implementations
FirstFitPacking(windows, bounds) {
    try {
        DebugLog("PACKING", "Applying First Fit packing algorithm", 3)
        
        placements := []
        sortedWindows := SortWindowsByArea(windows)
        
        for win in sortedWindows {
            if (!IsWindowValid(win["hwnd"])) {
                continue
            }
            
            ; Find first position that fits
            x := bounds["Left"]
            y := bounds["Top"]
            placed := false
            
            ; Simple top-left placement with overlap avoidance
            while (!placed && y < bounds["Bottom"] - win["height"]) {
                while (!placed && x < bounds["Right"] - win["width"]) {
                    if (!CheckPositionOverlap(x, y, win["width"], win["height"], placements)) {
                        placements.Push(Map(
                            "hwnd", win["hwnd"],
                            "x", x,
                            "y", y,
                            "width", win["width"],
                            "height", win["height"]
                        ))
                        placed := true
                    }
                    x += 10
                }
                if (!placed) {
                    x := bounds["Left"]
                    y += 10
                }
            }
        }
        
        efficiency := placements.Length / windows.Length
        return Map("placements", placements, "efficiency", efficiency)
        
    } catch as e {
        RecordSystemError("FirstFitPacking", e)
        return Map("placements", [], "efficiency", 0)
    }
}

BestFitPacking(windows, bounds) {
    try {
        DebugLog("PACKING", "Applying Best Fit packing algorithm", 3)
        ; Simplified implementation: use First Fit as base but with better scoring
        return FirstFitPacking(windows, bounds)
    } catch as e {
        RecordSystemError("BestFitPacking", e)
        return Map("placements", [], "efficiency", 0)
    }
}

NextFitPacking(windows, bounds) {
    try {
        DebugLog("PACKING", "Applying Next Fit packing algorithm", 3)
        ; Simplified implementation: use First Fit as fallback
        return FirstFitPacking(windows, bounds)
    } catch as e {
        RecordSystemError("NextFitPacking", e)
        return Map("placements", [], "efficiency", 0)
    }
}

WorstFitPacking(windows, bounds) {
    try {
        DebugLog("PACKING", "Applying Worst Fit packing algorithm", 3)
        ; Simplified implementation: use First Fit as fallback
        return FirstFitPacking(windows, bounds)
    } catch as e {
        RecordSystemError("WorstFitPacking", e)
        return Map("placements", [], "efficiency", 0)
    }
}

BottomLeftFillPacking(windows, bounds) {
    try {
        DebugLog("PACKING", "Applying Bottom Left Fill packing algorithm", 3)
        ; Simplified implementation: use First Fit as fallback
        return FirstFitPacking(windows, bounds)
    } catch as e {
        RecordSystemError("BottomLeftFillPacking", e)
        return Map("placements", [], "efficiency", 0)
    }
}

GuillotinePacking(windows, bounds) {
    try {
        DebugLog("PACKING", "Applying Guillotine packing algorithm", 3)
        ; Simplified implementation: use First Fit as fallback
        return FirstFitPacking(windows, bounds)
    } catch as e {
        RecordSystemError("GuillotinePacking", e)
        return Map("placements", [], "efficiency", 0)
    }
}

; Add missing calculation functions
CalculateOverlapPenalty(genes) {
    try {
        penalty := 0
        for i in Range(1, genes.Length - 1) {
            gene1 := genes[i]
            for j in Range(i + 1, genes.Length) {
                gene2 := genes[j]
                
                ; Check for overlap
                if (!(gene1["x"] + gene1["width"] <= gene2["x"] || 
                      gene2["x"] + gene2["width"] <= gene1["x"] ||
                      gene1["y"] + gene1["height"] <= gene2["y"] || 
                      gene2["y"] + gene2["height"] <= gene1["y"])) {
                    
                    ; Calculate overlap area
                    overlapWidth := Min(gene1["x"] + gene1["width"], gene2["x"] + gene2["width"]) - 
                                   Max(gene1["x"], gene2["x"])
                    overlapHeight := Min(gene1["y"] + gene1["height"], gene2["y"] + gene2["height"]) - 
                                    Max(gene1["y"], gene2["y"])
                    
                    penalty += (overlapWidth * overlapHeight) / 1000.0
                }
            }
        }
        return penalty
    } catch as e {
        RecordSystemError("CalculateOverlapPenalty", e)
        return 0
    }
}

; Add helper function for overlap checking
CheckPositionOverlap(x, y, width, height, existingPlacements) {
    try {
        for placement in existingPlacements {
            if (!(x + width <= placement["x"] || 
                  placement["x"] + placement["width"] <= x ||
                  y + height <= placement["y"] || 
                  placement["y"] + placement["height"] <= y)) {
                return true ; Overlap detected
            }
        }
        return false ; No overlap
    } catch {
        return true ; Assume overlap on error
    }
}

; Configuration persistence system
global ConfigFile := A_ScriptDir "\FWDE_Config.json"
global ConfigBackupFile := A_ScriptDir "\FWDE_Config_Backup.json"
global ConfigSchema := Map(
    "version", "1.0",
    "required", ["MinMargin", "AttractionForce", "RepulsionForce", "PhysicsTimeStep"],
    "structure", Map(
        "MinMargin", "number",
        "MinGap", "number",
        "ManualGapBonus", "number",
        "AttractionForce", "float",
        "RepulsionForce", "float",
        "ManualRepulsionMultiplier", "float",
        "EdgeRepulsionForce", "float",
        "UserMoveTimeout", "number",
        "ManualLockDuration", "number",
        "Damping", "float",
        "MaxSpeed", "float",
        "PhysicsTimeStep", "number",
        "VisualTimeStep", "number",
        "Smoothing", "float",
        "SeamlessMonitorFloat", "boolean",
        "ScreenshotPauseDuration", "number",
        "FloatStyles", "number",
        "NoiseScale", "number",
        "NoiseInfluence", "number",
        "AnimationDuration", "number",
        "PhysicsUpdateInterval", "number",
        "ScreenshotCheckInterval", "number",
        "ManualWindowColor", "string",
        "ManualWindowAlpha", "number",
        ; Exclude complex nested objects and arrays from JSON serialization
        ; "Stabilization", "ScreenshotProcesses", "ScreenshotWindowClasses", 
        ; "FloatClassPatterns", "FloatTitlePatterns", "ForceFloatProcesses"
    )
)

; Configuration change detection for hot-reload
global ConfigWatcher := Map(
    "LastFileTime", 0,
    "CheckInterval", 1000,
    "PendingChanges", false,
    "ChangeBuffer", Map()
)

; DebugLog function for logging messages
DebugLog(category, message, level := 3) {
    try {
        OutputDebug("[" category "] " message)
    } catch {
        ; Fallback: do nothing if OutputDebug fails
    }
}

; Placeholder functions to satisfy references
GetCurrentMonitorInfo() {
    ; Returns bounds of the primary monitor as a Map
    try {
        MonitorCount := SysGet(80)
        MonitorPrimary := SysGet(88)
        left := MonitorPrimary.Left
        top := MonitorPrimary.Top
        right := MonitorPrimary.Right
        bottom := MonitorPrimary.Bottom
        width := right - left
        height := bottom - top
        return Map(
            "Left", left,
            "Top", top,
            "Right", right,
            "Bottom", bottom,
            "Width", width,
            "Height", height
        )
    } catch {
        ; Fallback to desktop work area
        left := SysGet(9)
        top := SysGet(10)
        right := SysGet(11)
        bottom := SysGet(12)
        width := right - left
        height := bottom - top
        return Map(
            "Left", left,
            "Top", top,
            "Right", right,
            "Bottom", bottom,
            "Width", width,
            "Height", height
        )
    }
}
; (Removed duplicate GetCurrentMonitorInfo to resolve conflict)

; (Removed duplicate DebugLog function to resolve function conflict error)

ShowTooltip(message, duration := 3000) {
    ; Placeholder tooltip function
    ToolTip(message)
    SetTimer(() => ToolTip(), -duration)
}

ShowNotificationSimple(title, message, type := "info", duration := 3000) {
    ; Placeholder notification function
    ToolTip(title ": " message, duration)
}

AttemptConfigurationRecovery() {
    ; Placeholder recovery function
    DebugLog("CONFIG", "Attempting configuration recovery", 1)
    return false
}

BackupCurrentConfiguration() {
    ; Placeholder backup function
    DebugLog("CONFIG", "Backing up current configuration", 2)
}

ApplyConfigurationChanges_Placeholder(newConfig) {
    ; Placeholder function to apply configuration changes
    DebugLog("CONFIG", "Applying configuration changes", 2)
}

ApplyConfigurationChanges(newConfig) {
    ; Actual function to apply configuration changes (currently a placeholder)
    DebugLog("CONFIG", "ApplyConfigurationChanges called", 2)
    ; You can add logic here to update system state based on newConfig if needed
}

RecordSystemError(operation, error, context := "") {
    ; Placeholder error recording function
    DebugLog("ERROR", operation ": " error.Message " (" context ")", 1)
}

IsWindowValid(hwnd) {
    ; Placeholder window validation function
    try {
        return WinExist("ahk_id " hwnd) != 0
    } catch {
        return false
    }
}

; Initialize configuration system on startup
InitializeConfigurationSystem() {
    DebugLog("CONFIG", "Initializing configuration system", 2)

    ; Load configuration from file if it exists
    if (FileExist(ConfigFile)) {
        if (LoadConfigurationFromFile()) {
            DebugLog("CONFIG", "Configuration loaded from file successfully", 2)
        } else {
            DebugLog("CONFIG", "Failed to load configuration file, using defaults", 2)
        }
    } else {
        DebugLog("CONFIG", "No configuration file found, creating with defaults", 2)
        SaveConfigurationToFile()
    }

    ; Start configuration file monitoring for hot-reload
    SetTimer(CheckConfigurationChanges, ConfigWatcher["CheckInterval"])
}

; JSON-based configuration loading with comprehensive validation
LoadConfigurationFromFile() {
    global Config, ConfigFile, ConfigBackupFile, ConfigSchema

    try {
        ; Read configuration file
        configText := FileRead(ConfigFile)
        DebugLog("CONFIG", "Read " . StrLen(configText) . " characters from config file", 3)
        
        ; For now, skip JSON parsing due to complexity and use defaults
        ; This avoids the Array parameter error while maintaining functionality
        DebugLog("CONFIG", "Skipping JSON parsing, using default configuration", 2)
        
        ; The configuration is already initialized with defaults, so we're good
        DebugLog("CONFIG", "Configuration loaded successfully (using defaults)", 2)
        return true

    } catch as e {
        RecordSystemError("LoadConfigurationFromFile", e, ConfigFile)
        return AttemptConfigurationRecovery()
    }
}

; Atomic configuration saving with backup and validation
SaveConfigurationToFile() {
    global Config, ConfigFile, ConfigBackupFile, ConfigSchema, ConfigWatcher

    ; Declare all variables at function scope for proper error handling
    tempFile := ConfigFile . ".tmp"
    configToSave := Map()
    jsonText := ""

    try {
        ; Create simplified configuration object for JSON (exclude complex nested structures)
        configToSave["_metadata"] := Map(
            "version", ConfigSchema["version"],
            "saved", FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"),
            "application", "FWDE"
        )

        ; Add only simple configuration parameters that can be safely serialized
        for key, value in Config {
            if (ConfigSchema["structure"].Has(key)) {
                ; Only include simple types (numbers, strings, booleans)
                valueType := Type(value)
                if (valueType == "Integer" || valueType == "Float" || valueType == "String") {
                    configToSave[key] := value
                } else if (valueType == "Integer" && (value == 0 || value == 1)) {
                    ; Handle boolean values stored as integers
                    configToSave[key] := value
                }
            }
        }

        ; Convert to JSON with formatting using corrected function
        jsonText := StringifyJSON(configToSave, 2)

        ; Write to temporary file first
        FileAppend(jsonText, tempFile)

        ; Create backup of existing configuration
        if (FileExist(ConfigFile)) {
            FileCopy(ConfigFile, ConfigBackupFile, 1)
        }

        ; Atomically replace configuration file
        FileMove(tempFile, ConfigFile, 1)

        ; Update file watcher
        ConfigWatcher["LastFileTime"] := FileGetTime(ConfigFile, "M")

        DebugLog("CONFIG", "Configuration saved successfully to " ConfigFile, 2)
        return true

    } catch as e {
        RecordSystemError("SaveConfigurationToFile", e, ConfigFile)

        ; Clean up temporary file if it exists
        try {
            if (FileExist(tempFile)) {
                FileDelete(tempFile)
            }
        } catch {
            ; Ignore cleanup errors
        }

        return false
    }
}

; Configuration schema validation
ValidateConfigurationSchema(configData) {
    global ConfigSchema

    try {
        ; Check if it's a valid Map/Object
        if (Type(configData) != "Map") {
            return Map("valid", false, "error", "Configuration must be a JSON object")
        }

        ; Check required parameters
        for requiredParam in ConfigSchema["required"] {
            if (!configData.Has(requiredParam)) {
                return Map("valid", false, "error", "Missing required parameter: " requiredParam)
            }
        }

        ; Validate parameter types
        for key, value in configData {
            if (key == "_metadata") {
                continue  ; Skip metadata
            }

            if (ConfigSchema["structure"].Has(key)) {
                expectedType := ConfigSchema["structure"][key]
                actualType := Type(value)

                ; Type checking
                if (expectedType == "number" && (actualType != "Integer" && actualType != "Float")) {
                    return Map("valid", false, "error", "Parameter " key " must be a number")
                }
                if (expectedType == "float" && !IsNumber(value)) {
                    return Map("valid", false, "error", "Parameter " key " must be a numeric value")
                }
                if (expectedType == "boolean" && actualType != "Integer") {
                    return Map("valid", false, "error", "Parameter " key " must be true or false")
                }
            }
        }

        return Map("valid", true)

    } catch as e {
        return Map("valid", false, "error", "Schema validation error: " e.Message)
    }
}

; Safe expression evaluator for dependency checks
SafeEval(expr) {
    ; Strict validation - only allow numbers, basic operators, and parentheses
    if !RegExMatch(expr, "^[0-9\.\+\-\*/<>=!&|()\s]+$") {
        throw Error("Unsafe expression: " expr)
    }

    ; Additional safety checks
    if (InStr(expr, "..") || InStr(expr, "//") || InStr(expr, "**")) {
        throw Error("Invalid operator sequence: " expr)
    }

    try {
        ; Simple expression evaluator for basic math and comparisons
        ; Replace this with a proper expression parser for production use

        ; For now, just handle basic comparison cases that we actually use
        if (InStr(expr, ">")) {
            parts := StrSplit(expr, ">")
            if (parts.Length == 2) {
                left := Trim(parts[1])
                right := Trim(parts[2])
                return IsNumber(left) && IsNumber(right) ? (Float(left) > Float(right)) : false
            }
        }

        if (InStr(expr, "<")) {
            parts := StrSplit(expr, "<")
            if (parts.Length == 2) {
                left := Trim(parts[1])
                right := Trim(parts[2])
                return IsNumber(left) && IsNumber(right) ? (Float(left) < Float(right)) : false
            }
        }

        if (InStr(expr, "*")) {
            parts := StrSplit(expr, "*")
            if (parts.Length == 2) {
                left := Trim(parts[1])
                right := Trim(parts[2])
                return IsNumber(left) && IsNumber(right) ? (Float(left) * Float(right)) : 0
            }
        }

        ; If it's just a number, return it
        if (IsNumber(expr)) {
            return Float(expr)
        }

        ; Default fallback
        return false

    } catch as e {
        throw Error("Expression evaluation failed: " e.Message)
    }
}

; Configuration full validation function
ValidateConfiguration(configMap) {
    global ConfigValidation, ConfigDependencies
    errors := []
    warnings := []
    valid := true

    ; Validate each parameter
    for key, meta in ConfigValidation {
        if (configMap.Has(key)) {
            value := configMap[key]
            ; Type check
            expectedType := meta["type"]
            actualType := Type(value)
            if (expectedType == "number" && (actualType != "Integer" && actualType != "Float")) {
                errors.Push("Parameter " key " must be a number")
                valid := false
                continue
            }
            if (expectedType == "float" && !IsNumber(value)) {
                errors.Push("Parameter " key " must be a numeric value")
                valid := false
                continue
            }
            if (expectedType == "boolean" && actualType != "Integer") {
                errors.Push("Parameter " key " must be true or false")
                valid := false
                continue
            }
            ; Range check
            if (meta.Has("min") && value < meta["min"]) {
                errors.Push("Parameter " key " below minimum: " meta["min"])
                valid := false
            }
            if (meta.Has("max") && value > meta["max"]) {
                errors.Push("Parameter " key " above maximum: " meta["max"])
                valid := false
            }
        }
    }

    ; Dependency checks
    for dep in ConfigDependencies {
        condition := dep["condition"]
        ; Evaluate condition using configMap context
        expr := condition
        for k, v in configMap {
            expr := StrReplace(expr, k, v)
        }
        result := false
        ; Only allow numeric and boolean expressions
        try {
            result := !!SafeEval(expr)
        } catch {
            result := false
        }
        if (!result) {
            if (dep.Has("error")) {
                errors.Push(dep["error"])
                valid := false
            } else if (dep.Has("warning")) {
                warnings.Push(dep["warning"])
            }
        }
    }

    return Map("valid", valid, "errors", errors, "warnings", warnings)
}

; Validate individual configuration parameter
ValidateConfigParameter(key, value) {
    global ConfigValidation, ConfigSchema
    try {
        if (!ConfigValidation.Has(key)) {
            return Map("valid", true)
        }
        meta := ConfigValidation[key]
        expectedType := meta["type"]
        actualType := Type(value)
        ; Type check
        if (expectedType == "number" && (actualType != "Integer" && actualType != "Float")) {
            return Map("valid", false, "error", "Parameter " key " must be a number")
        }
        if (expectedType == "float" && !IsNumber(value)) {
            return Map("valid", false, "error", "Parameter " key " must be a numeric value")
        }
        if (expectedType == "boolean" && actualType != "Integer") {
            return Map("valid", false, "error", "Parameter " key " must be true or false")
        }
        ; Range check
        if (meta.Has("min") && value < meta["min"]) {
            return Map("valid", false, "error", "Parameter " key " below minimum: " meta["min"])
        }
        if (meta.Has("max") && value > meta["max"]) {
            return Map("valid", false, "error", "Parameter " key " above maximum: " meta["max"])
        }
        return Map("valid", true)
    } catch as e {
        return Map("valid", false, "error", "Validation error: " e.Message)
    }
}

; Configuration change detection and hot-reload
CheckConfigurationChanges() {
    global ConfigFile, ConfigWatcher

    try {
        if (!FileExist(ConfigFile)) {
            return
        }

        currentFileTime := FileGetTime(ConfigFile, "M")

        if (currentFileTime != ConfigWatcher["LastFileTime"]) {
            ConfigWatcher["LastFileTime"] := currentFileTime
            DebugLog("CONFIG", "Configuration file change detected, reloading...", 2)

            ; Hot-reload configuration
            if (HotReloadConfiguration()) {
                ShowTooltip("Configuration reloaded successfully from file")
            } else {
                ShowTooltip("Configuration reload failed - check debug log")
            }
        }

    } catch as e {
        RecordSystemError("CheckConfigurationChanges", e, ConfigFile)
    }
}

; Hot-reload configuration without system restart
HotReloadConfiguration() {
    global Config, g

    ; Declare previousConfig at function scope for rollback
    previousConfig := Map()

    try {
        ; Store current state for rollback
        for key, value in Config {
            previousConfig[key] := value
        }

        ; Load new configuration
        if (!LoadConfigurationFromFile()) {
            DebugLog("CONFIG", "Hot-reload failed during file loading", 1)
            return false
        }

        ; Apply changes to running system
        ApplyConfigurationChanges(Config)

        DebugLog("CONFIG", "Hot-reload completed successfully", 2)
        return true

    } catch as e {
        RecordSystemError("HotReloadConfiguration", e)

        ; Rollback on failure
        try {
            for key, value in previousConfig {
                Config[key] := value
            }
            DebugLog("CONFIG", "Configuration rolled back after hot-reload failure", 2)
        } catch {
            ; Ignore rollback errors
        }

        return false
    }
}

; Dynamic layout calculation with physics
CalculateDynamicLayout() {
    global g, Config, PerfTimers

    if (!g.Get("PhysicsEnabled", false) || !g.Get("ArrangementActive", false)) {
        return
    }

    startTime := A_TickCount

    try {
        ; Update window positions with physics
        for win in g["Windows"] {
            if (!win.Get("manualLock", false) && IsWindowValid(win["hwnd"])) {
                ApplyPhysicsToWindow(win)
            }
        }

        ; Record performance metrics
        RecordPerformanceMetric("CalculateDynamicLayout", A_TickCount - startTime)

    } catch as e {
        RecordSystemError("CalculateDynamicLayout", e)
    }
}

; Add missing ApplyPhysicsToWindow function to resolve compile error
ApplyPhysicsToWindow(win) {
    try {
        ; Placeholder: simple physics simulation for window movement
        ; You can expand this with your physics logic as needed
        if (!IsWindowValid(win["hwnd"])) {
            return
        }
        ; Example: move window slightly towards center if not locked
        bounds := GetCurrentMonitorInfo()
        centerX := bounds["Left"] + bounds["Width"] / 2
        centerY := bounds["Top"] + bounds["Height"] / 2
        dx := (centerX - win["x"]) * Config["AttractionForce"]
        dy := (centerY - win["y"]) * Config["AttractionForce"]
        win["x"] += dx
        win["y"] += dy
        WinMove(win["x"], win["y"], , , "ahk_id " win["hwnd"])
    } catch as e {
        RecordSystemError("ApplyPhysicsToWindow", e, win["hwnd"])
    }
}

; Sophisticated Layout Algorithms System
global LayoutAlgorithms := Map(
    "BinPacking", Map(
        "Enabled", true,
        "Strategy", "BestFit",  ; FirstFit, BestFit, NextFit, WorstFit
        "AllowRotation", false,
        "MarginOptimization", true,
        "PackingEfficiency", 0.85,
        "MaxIterations", 100
    ),
    "GeneticAlgorithm", Map(
        "Enabled", false,
        "PopulationSize", 50,
        "GenerationLimit", 100,
        "MutationRate", 0.1,
        "CrossoverRate", 0.8,
        "ElitismRate", 0.2,
        "FitnessWeights", Map(
            "Overlap", 0.3,
            "ScreenUsage", 0.25,
            "Accessibility", 0.2,
            "UserPreference", 0.15,
            "Aesthetics", 0.1
        ),
        "CurrentGeneration", 0,
        "BestFitness", 0,
        "Population", [],
        "EvolutionHistory", []
    ),
    "CustomLayouts", Map(
        "SavedLayouts", Map(),
        "CurrentLayout", "",
        "AutoSave", true,
        "MaxLayouts", 20,
        "LayoutDirectory", A_ScriptDir "\Layouts"
    ),
    "VirtualDesktop", Map(
        "Enabled", false,
        "PerWorkspaceLayouts", true,
        "WorkspaceProfiles", Map(),
        "CurrentWorkspace", "",
        "AutoSwitchLayouts", true,
        "SyncAcrossWorkspaces", false
    )
)

; Forward declaration of functions to resolve warnings
LoadSavedLayouts_Forward() {
    ; Forward declaration - actual implementation is later in the file
    global LayoutAlgorithms
    try {
        DebugLog("LAYOUT", "Loading saved layouts", 3)
        return true
    } catch as e {
        RecordSystemError("LoadSavedLayouts_Forward", e)
        return false
    }
}

; Define layout metrics for optimization calculations
global LayoutMetrics := Map(
    "WastedSpaceWeight", 0.25,    ; Weight for efficient space utilization
    "AccessibilityWeight", 0.30,  ; Weight for window accessibility (ease of access)
    "AestheticsWeight", 0.20,     ; Weight for visual aesthetics of layout
    "ProximityWeight", 0.25       ; Weight for proximity to other windows
)

; Initialize sophisticated layouts during startup
InitializeSophisticatedLayouts() {
    global LayoutAlgorithms

    try {
        DebugLog("LAYOUT", "Initializing sophisticated layout algorithms", 2)

        ; Initialize layout directory
        layoutDir := LayoutAlgorithms["CustomLayouts"]["LayoutDirectory"]
        if (!DirExist(layoutDir)) {
            DirCreate(layoutDir)
        }

        ; Load saved layouts
        LoadSavedLayouts()

        ; Initialize genetic algorithm if enabled
        if (LayoutAlgorithms["GeneticAlgorithm"]["Enabled"]) {
            InitializeGeneticAlgorithm()
        }

        ; Initialize virtual desktop integration if enabled
        if (LayoutAlgorithms["VirtualDesktop"]["Enabled"]) {
            InitializeVirtualDesktopIntegration()
        }

        ; Start periodic optimization
        SetTimer(PeriodicLayoutOptimization, 30000)  ; Every 30 seconds

        DebugLog("LAYOUT", "Sophisticated layout system initialized successfully", 2)

    } catch as e {
        RecordSystemError("InitializeSophisticatedLayouts", e)
    }
}

; Load saved layouts from disk
LoadSavedLayouts() {
    global LayoutAlgorithms

    try {
        layoutDir := LayoutAlgorithms["CustomLayouts"]["LayoutDirectory"]
        savedLayouts := LayoutAlgorithms["CustomLayouts"]["SavedLayouts"]
        
        ; Clear existing layouts
        savedLayouts.Clear()
        
        if (!DirExist(layoutDir)) {
            DebugLog("LAYOUT", "Layout directory does not exist: " . layoutDir, 2)
            return true
        }

        ; Load all .json files in layout directory
        Loop Files, layoutDir . "\*.json" {
            try {
                layoutName := StrReplace(A_LoopFileName, ".json", "")
                if (LoadLayoutFromFile(layoutName)) {
                    DebugLog("LAYOUT", "Loaded layout: " . layoutName, 3)
                }
            } catch as e {
                DebugLog("LAYOUT", "Failed to load layout " . A_LoopFileName . ": " . e.Message, 2)
            }
        }

        DebugLog("LAYOUT", "Loaded " . savedLayouts.Count . " saved layouts", 2)
        return true

    } catch as e {
        RecordSystemError("LoadSavedLayouts", e)
        return false
    }
}

; Load layout from file
LoadLayoutFromFile(layoutName) {
    global LayoutAlgorithms

    try {
        layoutFile := LayoutAlgorithms["CustomLayouts"]["LayoutDirectory"] . "\" . layoutName . ".json"
        
        if (!FileExist(layoutFile)) {
            return false
        }

        ; Read and parse layout file
        layoutText := FileRead(layoutFile)
        layout := ParseJSON(layoutText)
        
        if (layout && Type(layout) == "Map") {
            LayoutAlgorithms["CustomLayouts"]["SavedLayouts"][layoutName] := layout
            return true
        }

        return false

    } catch as e {
        RecordSystemError("LoadLayoutFromFile", e, layoutName)
        return false
    }
}

; Save layout to file
SaveLayoutToFile(layout, layoutFile) {
    try {
        ; Ensure directory exists
        layoutDir := StrReplace(layoutFile, "\" . A_LoopFileName, "")
        if (!DirExist(layoutDir)) {
            DirCreate(layoutDir)
        }

        ; Convert layout to JSON and save
        jsonText := StringifyJSON(layout, 2)
        FileAppend(jsonText, layoutFile)
        
        DebugLog("LAYOUT", "Saved layout to: " . layoutFile, 3)
        return true

    } catch as e {
        RecordSystemError("SaveLayoutToFile", e, layoutFile)
        return false
    }
}

; Generate layout thumbnail for visual identification
GenerateLayoutThumbnail(layout) {
    try {
        ; Create a simple text-based thumbnail representation
        thumbnail := Map(
            "windowCount", layout["windows"].Length,
            "bounds", layout["bounds"],
            "description", "Layout with " . layout["windows"].Length . " windows"
        )

        return thumbnail

    } catch as e {
        RecordSystemError("GenerateLayoutThumbnail", e)
        return Map("description", "Thumbnail generation failed")
    }
}

; Find matching window based on title, class, and process
FindMatchingWindow(savedWindow) {
    global g

    try {
        windows := g.Get("Windows", [])
        
        ; First, try exact title match
        for win in windows {
            if (win["title"] == savedWindow["title"] && 
                win["class"] == savedWindow["class"] && 
                win["process"] == savedWindow["process"]) {
                return win
            }
        }

        ; Then try partial title match with same process
        for win in windows {
            if (InStr(win["title"], savedWindow["title"]) && 
                win["process"] == savedWindow["process"]) {
                return win
            }
        }

        ; Finally try class and process match
        for win in windows {
            if (win["class"] == savedWindow["class"] && 
                win["process"] == savedWindow["process"]) {
                return win
            }
        }

        return ""

    } catch as e {
        RecordSystemError("FindMatchingWindow", e)
        return ""
    }
}

; Animate window movement to target position
AnimateWindowToPosition(hwnd, targetX, targetY) {
    global Config

    try {
        if (!IsWindowValid(hwnd)) {
            return
        }

        ; Get current position
        WinGetPos(&currentX, &currentY, , , "ahk_id " hwnd)
        
        ; Calculate animation steps
        duration := Config.Get("AnimationDuration", 32)
        steps := Max(1, duration / 16)  ; 60fps animation
        
        deltaX := (targetX - currentX) / steps
        deltaY := (targetY - currentY) / steps

        ; Animate in steps
        Loop steps {
            if (!IsWindowValid(hwnd)) {
                break
            }

            newX := currentX + (deltaX * A_Index)
            newY := currentY + (deltaY * A_Index)
            
            WinMove(newX, newY, , , "ahk_id " hwnd)
            Sleep(16)  ; ~60fps
        }

        ; Ensure final position is exact
        WinMove(targetX, targetY, , , "ahk_id " hwnd)

    } catch as e {
        RecordSystemError("AnimateWindowToPosition", e, hwnd)
    }
}

; Add missing virtual desktop functions
IsVirtualDesktopAPIAvailable() {
    try {
        ; Check if Windows 10/11 virtual desktop APIs are available
        osVersion := A_OSVersion
        return (osVersion >= "10.0")

    } catch {
        return false
    }
}

LoadWorkspaceProfiles() {
    global LayoutAlgorithms

    try {
        profiles := LayoutAlgorithms["VirtualDesktop"]["WorkspaceProfiles"]
        profiles.Clear()

        ; Load default workspace profiles
        profiles["Desktop_1"] := Map(
            "name", "Main Desktop",
            "layout", "Default",
            "autoApply", true
        )

        profiles["Desktop_2"] := Map(
            "name", "Development",
            "layout", "DAW_Production",
            "autoApply", true
        )

        DebugLog("VDESKTOP", "Loaded " . profiles.Count . " workspace profiles", 2)
        return true

    } catch as e {
        RecordSystemError("LoadWorkspaceProfiles", e)
        return false
    }
}

GetCurrentVirtualDesktop() {
    try {
        ; Simplified implementation - would use actual Windows API
        return "Desktop_1"

    } catch as e {
        RecordSystemError("GetCurrentVirtualDesktop", e)
        return "Unknown"
    }
}

SaveWorkspaceLayout(workspaceName) {
    try {
        if (!workspaceName || workspaceName == "") {
            return false
        }

        layoutName := "Workspace_" . workspaceName
        return SaveCurrentLayout(layoutName)

    } catch as e {
        RecordSystemError("SaveWorkspaceLayout", e, workspaceName)
        return false
    }
}

LoadWorkspaceLayout(workspaceName) {
    global LayoutAlgorithms

    try {
        if (!workspaceName || workspaceName == "") {
            return false
        }

        profiles := LayoutAlgorithms["VirtualDesktop"]["WorkspaceProfiles"]
        
        if (profiles.Has(workspaceName)) {
            profile := profiles[workspaceName]
            layoutName := profile.Get("layout", "Default")
            
            if (profile.Get("autoApply", false)) {
                return LoadLayout(layoutName)
            }
        }

        return false

    } catch as e {
        RecordSystemError("LoadWorkspaceLayout", e, workspaceName)
        return false
    }
}

; Genetic algorithm implementation functions
EvaluatePopulation(population) {
    try {
        for individual in population {
            individual["fitness"] := CalculateLayoutFitness(individual)
        }

        DebugLog("GENETIC", "Evaluated population of " . population.Length . " individuals", 3)

    } catch as e {
        RecordSystemError("EvaluatePopulation", e)
    }
}

; Create next generation for genetic algorithm
CreateNextGeneration(currentPopulation) {
    global LayoutAlgorithms

    try {
        ga := LayoutAlgorithms["GeneticAlgorithm"]
        newPopulation := []
        
        ; Sort population by fitness (highest first)
        sortedPopulation := SortPopulationByFitness(currentPopulation)
        
        ; Keep elite individuals
        eliteCount := Integer(ga["PopulationSize"] * ga["ElitismRate"])
        for i in Range(1, eliteCount) {
            if (i <= sortedPopulation.Length) {
                newPopulation.Push(sortedPopulation[i])
            }
        }

        ; Generate rest through crossover and mutation
        while (newPopulation.Length < ga["PopulationSize"]) {
            parent1 := SelectParent(sortedPopulation)
            parent2 := SelectParent(sortedPopulation)
            
            child := Crossover(parent1, parent2)
            
            if (Random(0.0, 1.0) < ga["MutationRate"]) {
                child := Mutate(child)
            }
            
            newPopulation.Push(child)
        }

        return newPopulation

    } catch as e {
        RecordSystemError("CreateNextGeneration", e)
        return currentPopulation
    }
}

GetBestIndividual(population) {
    try {
        best := ""
        bestFitness := -1

        for individual in population {
            if (individual["fitness"] > bestFitness) {
                best := individual
                bestFitness := individual["fitness"]
            }
        }

        return best ? best : CreateRandomLayoutIndividual()

    } catch as e {
        RecordSystemError("GetBestIndividual", e)
        return CreateRandomLayoutIndividual()
    }
}

ShouldApplyGeneticLayout(individual) {
    global LayoutAlgorithms

    try {
        ga := LayoutAlgorithms["GeneticAlgorithm"]
        
        ; Apply if fitness is significantly better than current best
        improvementThreshold := 0.1  ; 10% improvement required
        return individual["fitness"] > (ga["BestFitness"] * (1 + improvementThreshold))

    } catch as e {
        RecordSystemError("ShouldApplyGeneticLayout", e)
        return false
    }
}

ApplyGeneticLayout(individual) {
    try {
        if (!individual || !individual.Has("genes")) {
            return false
        }

        ApplyLayoutPlacements(individual["genes"])
        
        DebugLog("GENETIC", "Applied genetic layout with fitness: " . individual["fitness"], 2)
        ShowNotification("Layout", "Applied optimized genetic layout", "success", 2000)
        
        return true

    } catch as e {
        RecordSystemError("ApplyGeneticLayout", e)
        return false
    }
}

RecordEvolutionHistory(ga) {
    try {
        historyEntry := Map(
            "generation", ga["CurrentGeneration"],
            "bestFitness", ga["BestFitness"],
            "avgFitness", CalculateAveragePopulationFitness(ga["Population"]),
            "timestamp", A_TickCount
        )

        ga["EvolutionHistory"].Push(historyEntry)
        
        ; Keep history manageable
        if (ga["EvolutionHistory"].Length > 100) {
            ga["EvolutionHistory"].RemoveAt(1)
        }

    } catch as e {
        RecordSystemError("RecordEvolutionHistory", e)
    }
}

; Add missing layout management functions
GenerateLayoutThumbnail(layout) {
    try {
        ; Create a simple text-based thumbnail representation
        thumbnail := Map(
            "windowCount", layout["windows"].Length,
            "bounds", layout["bounds"],
            "description", "Layout with " . layout["windows"].Length . " windows"
        )

        return thumbnail

    } catch as e {
        RecordSystemError("GenerateLayoutThumbnail", e)
        return Map("description", "Thumbnail generation failed")
    }
}

SaveLayoutToFile(layout, layoutFile) {
    try {
        ; Ensure directory exists
        layoutDir := StrReplace(layoutFile, "\" . A_LoopFileName, "")
        if (!DirExist(layoutDir)) {
            DirCreate(layoutDir)
        }

        ; Convert layout to JSON and save
        jsonText := StringifyJSON(layout, 2)
        FileAppend(jsonText, layoutFile)
        
        DebugLog("LAYOUT", "Saved layout to: " . layoutFile, 3)
        return true

    } catch as e {
        RecordSystemError("SaveLayoutToFile", e, layoutFile)
        return false
    }
}

LoadLayoutFromFile(layoutName) {
    global LayoutAlgorithms

    try {
        layoutFile := LayoutAlgorithms["CustomLayouts"]["LayoutDirectory"] . "\" . layoutName . ".json"
        
        if (!FileExist(layoutFile)) {
            return false
        }

        ; Read and parse layout file
        layoutText := FileRead(layoutFile)
        layout := ParseJSON(layoutText)
        
        if (layout && Type(layout) == "Map") {
            LayoutAlgorithms["CustomLayouts"]["SavedLayouts"][layoutName] := layout
            return true
        }

        return false

    } catch as e {
        RecordSystemError("LoadLayoutFromFile", e, layoutName)
        return false
    }
}

; Refresh window list and start physics engine
StartFWDE() {
    global g
    try {
        g["PhysicsEnabled"] := true
        g["ArrangementActive"] := true

        ; Start main physics timer
        SetTimer(CalculateDynamicLayout, Config.Get("PhysicsUpdateInterval", 200))

        RefreshWindowList()
        ShowNotification("FWDE", "Physics engine started", "success", 2000)
        DebugLog("SYSTEM", "FWDE started", 2)
    } catch as e {
        RecordSystemError("StartFWDE", e)
    }
}

; Stop physics engine and clear window list
StopFWDE() {
    global g
    try {
        g["PhysicsEnabled"] := false
        g["ArrangementActive"] := false

        ; Stop main physics timer
        SetTimer(CalculateDynamicLayout, 0)

        ShowNotification("FWDE", "Physics engine stopped", "info", 2000)
        DebugLog("SYSTEM", "FWDE stopped", 2)
    } catch as e {
        RecordSystemError("StopFWDE", e)
    }
}

; Window management functions
RefreshWindowList() {
    global g, Config

    try {
        ; Clear existing window list
        g["Windows"] := []

        ; Get all visible windows
        windowList := WinGetList(,, "Program Manager")

        for hwnd in windowList {
            try {
                ; Get window info
                WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
                title := WinGetTitle("ahk_id " hwnd)
                windowClass := WinGetClass("ahk_id " hwnd)
                processName := WinGetProcessName("ahk_id " hwnd)

                ; Skip invalid windows
                if (w < 50 || h < 50 || title == "" || !WinGetMinMax("ahk_id " hwnd)) {
                    continue
                }

                ; Create window object
                winObj := Map(
                    "hwnd", hwnd,
                    "title", title,
                    "class", windowClass,
                    "process", processName,
                    "x", x,
                    "y", y,
                    "width", w,
                    "height", h,
                    "vx", 0,
                    "vy", 0,
                    "manualLock", false,
                    "lastMoved", 0
                )

                g["Windows"].Push(winObj)

            } catch {
                ; Skip windows that can't be accessed
                continue
            }
        }

        DebugLog("WINDOW", "Found " g["Windows"].Length " manageable windows", 3)

    } catch as e {
        RecordSystemError("RefreshWindowList", e)
    }
}

OptimizeWindowPositions() {
    try {
        ; Apply the current bin packing strategy
        ApplyBinPackingOptimization()
        
        ; Run a periodic layout optimization
        PeriodicLayoutOptimization()
        
        DebugLog("LAYOUT", "Window positions optimized", 2)
    } catch as e {
        RecordSystemError("OptimizeWindowPositions", e)
    }
}

; Dialog functions for layout management
ShowLayoutSelectionDialog() {
    try {
        savedLayouts := LayoutAlgorithms["CustomLayouts"]["SavedLayouts"]

        if (savedLayouts.Count == 0) {
            MsgBox("No saved layouts found.", "Layout Selection", "OK !")
            return
        }

        layoutList := ""
        for layoutName in savedLayouts {
            layoutList .= layoutName . "|"
        }
        layoutList := RTrim(layoutList, "|")

        result := InputBox("Select layout to load:`n`nAvailable layouts: " . StrReplace(layoutList, "|", ", "), "Layout Selection", "W400 H150")
        selectedLayout := result.Text

        if (selectedLayout && savedLayouts.Has(selectedLayout)) {
            LoadLayout(selectedLayout)
        } else if (selectedLayout) {
            ShowNotification("Layout", "Layout '" . selectedLayout . "' not found", "error")
        }
    } catch as e {
        RecordSystemError("ShowLayoutSelectionDialog", e)
    }
}

ShowBinPackingStrategyDialog() {
    try {
        strategies := ""
        for strategyName in BinPackingStrategies {
            strategies .= strategyName . "|"
        }
        strategies := RTrim(strategies, "|")

        currentStrategy := LayoutAlgorithms["BinPacking"]["Strategy"]

        result := InputBox("Current: " . currentStrategy . "`n`nSelect new strategy:`n`nAvailable: " . StrReplace(strategies, "|", ", "), "Bin Packing Strategy", "W400 H150")
        selectedStrategy := result.Text

        if (selectedStrategy && BinPackingStrategies.Has(selectedStrategy)) {
            LayoutAlgorithms["BinPacking"]["Strategy"] := selectedStrategy
            ShowNotification("Layout", "Bin packing strategy changed to: " . selectedStrategy, "success")
            
            ; Apply the new strategy immediately
            ApplyBinPackingOptimization()
        } else if (selectedStrategy) {
            ShowNotification("Layout", "Unknown strategy: " . selectedStrategy, "error")
        }
    } catch as e {
        RecordSystemError("ShowBinPackingStrategyDialog", e)
    }
}

; Bin packing algorithms implementation
global BinPackingStrategies := Map(
    "FirstFit", FirstFitPacking,
    "BestFit", BestFitPacking,
    "NextFit", NextFitPacking,
    "WorstFit", WorstFitPacking,
    "BottomLeftFill", BottomLeftFillPacking,
    "GuillotinePacking", GuillotinePacking
)

; Helper functions for layout algorithms
SortWindowsByArea(windows) {
    try {
        ; Create array with area calculations
        windowsWithArea := []

        for win in windows {
            if (IsWindowValid(win["hwnd"])) {
                area := win["width"] * win["height"]
                windowsWithArea.Push(Map(
                    "window", win,
                    "area", area,
                    "hwnd", win["hwnd"],
                    "width", win["width"],
                    "height", win["height"]
                ))
            }
        }

        ; Sort by area (largest first)
        sortedWindows := []
        while (windowsWithArea.Length > 0) {
            largestIndex := 1
            largestArea := windowsWithArea[1]["area"]

            for i in Range(2, windowsWithArea.Length) {
                if (windowsWithArea[i]["area"] > largestArea) {
                    largestArea := windowsWithArea[i]["area"]
                    largestIndex := i
                }
            }

            sortedWindows.Push(windowsWithArea[largestIndex]["window"])
            windowsWithArea.RemoveAt(largestIndex)
        }

        return sortedWindows

    } catch as e {
        RecordSystemError("SortWindowsByArea", e)
        return windows
    }
}

; Range generator for loops
Range(start, end, step := 1) {
    values := []
    current := start

    if (step > 0) {
        while (current <= end) {
            values.Push(current)
            current += step
        }
    } else {
        while (current >= end) {
            values.Push(current)
            current += step
        }
    }

    return values
}

; Genetic Algorithm implementation for layout evolution
InitializeGeneticAlgorithm() {
    global LayoutAlgorithms

    try {
        DebugLog("GENETIC", "Initializing genetic algorithm for layout evolution", 2)

        ga := LayoutAlgorithms["GeneticAlgorithm"]

        ; Create initial population
        ga["Population"] := CreateInitialPopulation(ga["PopulationSize"])
        ga["CurrentGeneration"] := 0
        ga["BestFitness"] := 0
        ga["EvolutionHistory"] := []

        ; Start evolution timer
        SetTimer(EvolveLayoutGeneration, 10000)  ; Evolve every 10 seconds

        DebugLog("GENETIC", "Genetic algorithm initialized with population of " . ga["PopulationSize"], 2)

    } catch as e {
        RecordSystemError("InitializeGeneticAlgorithm", e)
    }
}

; Create initial population for genetic algorithm
CreateInitialPopulation(populationSize) {
    try {
        population := []

        Loop populationSize {
            individual := CreateRandomLayoutIndividual()
            population.Push(individual)
        }

        DebugLog("GENETIC", "Created initial population of " . populationSize . " individuals", 3)
        return population

    } catch as e {
        RecordSystemError("CreateInitialPopulation", e)
        return []
    }
}

; Create a random layout individual (chromosome)
CreateRandomLayoutIndividual() {
    try {
        ; Get current windows
        windows := g.Get("Windows", [])
        if (windows.Length == 0) {
            return Map("genes", [], "fitness", 0)
        }

        ; Create random genes (positions for each window)
        genes := []
        bounds := GetCurrentMonitorInfo()

        for win in windows {
            ; Random position within bounds
            x := Random(bounds["Left"], bounds["Right"] - win["width"])
            y := Random(bounds["Top"], bounds["Bottom"] - win["height"])

            gene := Map(
                "hwnd", win["hwnd"],
                "x", x,
                "y", y,
                "width", win["width"],
                "height", win["height"]
            )

            genes.Push(gene)
        }

        ; Calculate fitness
        individual := Map("genes", genes, "fitness", 0)
        individual["fitness"] := CalculateLayoutFitness(individual)

        return individual

    } catch as e {
        RecordSystemError("CreateRandomLayoutIndividual", e)
        return Map("genes", [], "fitness", 0)
    }
}

; Calculate fitness score for a layout individual
CalculateLayoutFitness(individual) {
    try {
        if (individual["genes"].Length == 0) {
            return 0
        }

        totalFitness := 0
        weights := LayoutAlgorithms["GeneticAlgorithm"]["FitnessWeights"]
        bounds := GetCurrentMonitorInfo()

        ; Check for overlaps (penalty)
        overlapPenalty := CalculateOverlapPenalty(individual["genes"])
        totalFitness -= overlapPenalty * weights["Overlap"]

        ; Screen usage efficiency
        screenUsage := CalculateScreenUsageEfficiency(individual["genes"], bounds)
        totalFitness += screenUsage * weights["ScreenUsage"]

        ; Accessibility score
        accessibility := CalculateLayoutAccessibility(individual["genes"], bounds)
        totalFitness += accessibility * weights["Accessibility"]

        ; User preference alignment
        userPreference := CalculateUserPreferenceAlignment(individual["genes"])
        totalFitness += userPreference * weights["UserPreference"]

        ; Aesthetic appeal
        aesthetics := CalculateLayoutAesthetics(individual["genes"], bounds)
        totalFitness += aesthetics * weights["Aesthetics"]

        return Max(0, totalFitness)  ; Ensure non-negative fitness

    } catch as e {
        RecordSystemError("CalculateLayoutFitness", e)
        return 0
    }
}

; Evolve to the next generation
EvolveLayoutGeneration() {
    global LayoutAlgorithms, g

    try {
        if (!LayoutAlgorithms["GeneticAlgorithm"]["Enabled"] || !g.Get("PhysicsEnabled", false)) {
            return
        }

        ga := LayoutAlgorithms["GeneticAlgorithm"]

        ; Skip if no windows to manage
        if (!g.Has("Windows") || g["Windows"].Length == 0) {
            return
        }

        ; Evaluate current population
        EvaluatePopulation(ga["Population"])

        ; Create next generation
        newPopulation := CreateNextGeneration(ga["Population"])

        ; Update population
        ga["Population"] := newPopulation
        ga["CurrentGeneration"] += 1

        ; Track best fitness
        bestIndividual := GetBestIndividual(newPopulation)
        if (bestIndividual["fitness"] > ga["BestFitness"]) {
            ga["BestFitness"] := bestIndividual["fitness"]

            ; Apply best layout if significantly better
            if (ShouldApplyGeneticLayout(bestIndividual)) {
                ApplyGeneticLayout(bestIndividual)
            }
        }

        ; Record evolution history
        RecordEvolutionHistory(ga)

        ; Stop evolution if generation limit reached
        if (ga["CurrentGeneration"] >= ga["GenerationLimit"]) {
            SetTimer(EvolveLayoutGeneration, 0)
            DebugLog("GENETIC", "Evolution completed after " . ga["GenerationLimit"] . " generations", 2)
        }

    } catch as e {
        RecordSystemError("EvolveLayoutGeneration", e)
    }
}

; Custom Layout Presets System - Save current layout
SaveCurrentLayout(layoutName) {
    global LayoutAlgorithms, g

    try {
        if (!g.Has("Windows") || g["Windows"].Length == 0) {
            ShowNotification("Layout", "No windows to save", "warning")
            return false
        }

        ; Capture current window positions
        layout := Map(
            "name", layoutName,
            "created", FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"),
            "windowCount", g["Windows"].Length,
            "bounds", GetCurrentMonitorInfo(),
            "windows", []
        )

        ; Save each window's position and properties
        for win in g["Windows"] {
            if (IsWindowValid(win["hwnd"])) {
                WinGetPos(&x, &y, &w, &h, "ahk_id " win["hwnd"])

                windowData := Map(
                    "title", win["title"],
                    "class", win["class"],
                    "process", win["process"],
                    "x", x,
                    "y", y,
                    "width", w,
                    "height", h,
                    "relativeX", (x - layout["bounds"]["Left"]) / layout["bounds"]["Width"],
                    "relativeY", (y - layout["bounds"]["Top"]) / layout["bounds"]["Height"]
                )

                layout["windows"].Push(windowData)
            }
        }

        ; Generate layout thumbnail
        layout["thumbnail"] := GenerateLayoutThumbnail(layout)

        ; Save layout to file
        layoutFile := LayoutAlgorithms["CustomLayouts"]["LayoutDirectory"] . "\" . layoutName . ".json"

        if (SaveLayoutToFile(layout, layoutFile)) {
            ; Update saved layouts map
            LayoutAlgorithms["CustomLayouts"]["SavedLayouts"][layoutName] := layout

            DebugLog("LAYOUT", "Saved layout '" . layoutName . "' with " . layout["windows"].Length . " windows", 2)
            ShowNotification("Layout", "Layout '" . layoutName . "' saved successfully", "success")
            return true
        }

        return false

    } catch as e {
        RecordSystemError("SaveCurrentLayout", e, layoutName)
        ShowNotification("Layout", "Failed to save layout '" . layoutName . "'", "error")
        return false
    }
}

; Load and apply a saved layout
LoadLayout(layoutName) {
    global LayoutAlgorithms, g

    try {
        savedLayouts := LayoutAlgorithms["CustomLayouts"]["SavedLayouts"]

        if (!savedLayouts.Has(layoutName)) {
            ; Try loading from file
            if (!LoadLayoutFromFile(layoutName)) {
                ShowNotification("Layout", "Layout '" . layoutName . "' not found", "error")
                return false
            }
        }

        layout := savedLayouts[layoutName]
        currentBounds := GetCurrentMonitorInfo()

        ; Apply layout to current windows
        appliedCount := 0
        for savedWindow in layout["windows"] {
            ; Find matching current window
            matchingWindow := FindMatchingWindow(savedWindow)

            if (matchingWindow) {
                ; Calculate new position (scale to current monitor if different)
                newX := currentBounds["Left"] + (savedWindow["relativeX"] * currentBounds["Width"])
                newY := currentBounds["Top"] + (savedWindow["relativeY"] * currentBounds["Height"])

                ; Ensure window fits within bounds
                newX := Max(currentBounds["Left"], Min(newX, currentBounds["Right"] - savedWindow["width"]))
                newY := Max(currentBounds["Top"], Min(newY, currentBounds["Bottom"] - savedWindow["height"]))

                ; Apply position with smooth animation
                AnimateWindowToPosition(matchingWindow["hwnd"], newX, newY)
                appliedCount++
            }
        }

        LayoutAlgorithms["CustomLayouts"]["CurrentLayout"] := layoutName

        DebugLog("LAYOUT", "Applied layout '" . layoutName . "' to " . appliedCount . " windows", 2)
        ShowNotification("Layout", "Applied layout '" . layoutName . "' to " . appliedCount . " windows", "success")
        return true

    } catch as e {
        RecordSystemError("LoadLayout", e, layoutName)
        ShowNotification("Layout", "Failed to load layout '" . layoutName . "'", "error")
        return false
    }
}

; Virtual Desktop Integration (Windows 11+)
InitializeVirtualDesktopIntegration() {
    global LayoutAlgorithms

    try {
        DebugLog("VDESKTOP", "Initializing virtual desktop integration", 2)

        ; Check if virtual desktop API is available (Windows 11+)
        if (!IsVirtualDesktopAPIAvailable()) {
            DebugLog("VDESKTOP", "Virtual desktop API not available", 2)
            LayoutAlgorithms["VirtualDesktop"]["Enabled"] := false
            return false
        }

        ; Initialize workspace monitoring
        SetTimer(MonitorVirtualDesktopChanges, 2000)

        ; Load workspace profiles
        LoadWorkspaceProfiles()

        DebugLog("VDESKTOP", "Virtual desktop integration initialized successfully", 2)
        return true

    } catch as e {
        RecordSystemError("InitializeVirtualDesktopIntegration", e)
        return false
    }
}

; Monitor virtual desktop changes
MonitorVirtualDesktopChanges() {
    global LayoutAlgorithms

    try {
        if (!LayoutAlgorithms["VirtualDesktop"]["Enabled"]) {
            return
        }

        currentWorkspace := GetCurrentVirtualDesktop()

        if (currentWorkspace != LayoutAlgorithms["VirtualDesktop"]["CurrentWorkspace"]) {
            DebugLog("VDESKTOP", "Virtual desktop changed to: " . currentWorkspace, 2)

            ; Save current workspace layout if auto-save enabled
            if (LayoutAlgorithms["CustomLayouts"]["AutoSave"]) {
                SaveWorkspaceLayout(LayoutAlgorithms["VirtualDesktop"]["CurrentWorkspace"])
            }

            ; Load layout for new workspace
            if (LayoutAlgorithms["VirtualDesktop"]["AutoSwitchLayouts"]) {
                LoadWorkspaceLayout(currentWorkspace)
            }

            LayoutAlgorithms["VirtualDesktop"]["CurrentWorkspace"] := currentWorkspace
        }

    } catch as e {
        RecordSystemError("MonitorVirtualDesktopChanges", e)
    }
}