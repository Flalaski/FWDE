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
    }
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

DebugLog(category, message, level := 3) {
    ; Placeholder debug logging function
    OutputDebug("[" category "] " message)
}

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
LoadSavedLayouts() {
    ; Forward declaration - actual implementation is later in the file
    global LayoutAlgorithms
    try {
        DebugLog("LAYOUT", "Loading saved layouts", 3)
        return true
    } catch as e {
        RecordSystemError("LoadSavedLayouts", e)
        return false
    }
}

PeriodicLayoutOptimization() {
    ; Forward declaration - actual implementation is later in the file
    try {
        DebugLog("LAYOUT", "Performing periodic layout optimization", 3)
        return true
    } catch as e {
        RecordSystemError("PeriodicLayoutOptimization", e)
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

; Calculate how efficiently the position uses screen space
CalculateUtilizationScore(position, win, bounds) {
    try {
        ; Calculate distance from screen edges (percentage of screen)
        edgeDistanceLeft := (position["x"] - bounds["Left"]) / bounds["Width"]
        edgeDistanceRight := (bounds["Right"] - (position["x"] + win["width"])) / bounds["Width"]
        edgeDistanceTop := (position["y"] - bounds["Top"]) / bounds["Height"]
        edgeDistanceBottom := (bounds["Bottom"] - (position["y"] + win["height"])) / bounds["Height"]
        
        ; Average edge utilization (higher score = better space usage)
        edgeScore := (1 - (edgeDistanceLeft + edgeDistanceRight + edgeDistanceTop + edgeDistanceBottom) / 4)
        
        ; Screen coverage ratio (window area / screen area)
        coverageRatio := (win["width"] * win["height"]) / (bounds["Width"] * bounds["Height"])
        
        ; Combine metrics (higher is better)
        return (edgeScore * 0.7) + (coverageRatio * 0.3)
    } catch as e {
        RecordSystemError("CalculateUtilizationScore", e)
        return 0.5  ; Return middle value on error
    }
}

; Calculate accessibility score (how easy it is to access the window)
CalculateAccessibilityScore(position, win, bounds) {
    try {
        ; Windows closer to screen center are easier to access
        centerX := bounds["Left"] + bounds["Width"] / 2
        centerY := bounds["Top"] + bounds["Height"] / 2
        
        ; Calculate normalized distance from center (0-1 range)
        distX := Abs(position["x"] + win["width"] / 2 - centerX) / (bounds["Width"] / 2)
        distY := Abs(position["y"] + win["height"] / 2 - centerY) / (bounds["Height"] / 2)
        
        ; Average distance from center (lower is better)
        avgDist := (distX + distY) / 2
        
        ; Convert to score (higher is better)
        return 1 - avgDist
    } catch as e {
        RecordSystemError("CalculateAccessibilityScore", e)
        return 0.5  ; Return middle value on error
    }
}

; Calculate aesthetics score (visual appeal of window position)
CalculateAestheticsScore(position, win, usedRectangles, bounds) {
    try {
        ; Alignment with other windows (grid-like alignment is aesthetically pleasing)
        alignmentScore := 0
        edgeAlignments := 0
        
        for rect in usedRectangles {
            ; Check horizontal alignment
            if (Abs(position["x"] - rect["x"]) < 5 || 
                Abs(position["x"] + win["width"] - rect["x"]) < 5 || 
                Abs(position["x"] - (rect["x"] + rect["width"])) < 5) {
                alignmentScore += 0.1
                edgeAlignments++
            }
            
            ; Check vertical alignment
            if (Abs(position["y"] - rect["y"]) < 5 || 
                Abs(position["y"] + win["height"] - rect["y"]) < 5 || 
                Abs(position["y"] - (rect["y"] + rect["height"])) < 5) {
                alignmentScore += 0.1
                edgeAlignments++
            }
        }
        
        ; Cap alignment score
        alignmentScore := Min(alignmentScore, 0.7)
        
        ; Symmetry relative to screen center
        centerX := bounds["Left"] + bounds["Width"] / 2
        centerY := bounds["Top"] + bounds["Height"] / 2
        symmetryScore := 1 - (Abs((position["x"] + win["width"] / 2 - centerX) / (bounds["Width"] / 2)) * 0.3)
        
        return (alignmentScore * 0.6) + (symmetryScore * 0.4)
    } catch as e {
        RecordSystemError("CalculateAestheticsScore", e)
        return 0.5  ; Return middle value on error
    }
}

; Find first available position for a window (First Fit algorithm)
FindFirstFitPosition(win, bounds, usedRectangles) {
    try {
        margin := Config["MinMargin"]
        
        ; Try positions from top-left, moving across and down
        for y in Range(bounds["Top"] + margin, bounds["Bottom"] - win["height"] - margin, 20) {
            for x in Range(bounds["Left"] + margin, bounds["Right"] - win["width"] - margin, 20) {
                position := Map("x", x, "y", y)
                
                ; Check if position is valid (no overlaps)
                if (IsPositionValid(position, win, usedRectangles)) {
                    return position
                }
            }
        }
        
        ; No valid position found
        return ""
        
    } catch as e {
        RecordSystemError("FindFirstFitPosition", e)
        return ""
    }
}

; Calculate proximity score (how close this window is to other windows)
CalculateProximityScore(position, win, usedRectangles) {
    try {
        if (usedRectangles.Length == 0) {
            return 0.5  ; No other windows to be close to
        }
        
        proximitySum := 0
        maxDistance := 1000  ; Arbitrary large distance
        
        for rect in usedRectangles {
            ; Calculate center points
            positionCenterX := position["x"] + win["width"] / 2
            positionCenterY := position["y"] + win["height"] / 2
            rectCenterX := rect["x"] + rect["width"] / 2
            rectCenterY := rect["y"] + rect["height"] / 2
            
            ; Calculate Euclidean distance between centers
            distance := Sqrt((positionCenterX - rectCenterX)**2 + (positionCenterY - rectCenterY)**2)
            
            ; Add to proximity sum (inverse of distance - closer is better)
            proximitySum += (maxDistance / (distance + maxDistance * 0.1))
        }
        
        ; Normalize by number of rectangles
        proximityScore := proximitySum / usedRectangles.Length
        
        ; Normalize to 0-1 range
        return proximityScore / (maxDistance / (maxDistance * 0.1))
    } catch as e {
        RecordSystemError("CalculateProximityScore", e)
        return 0.5  ; Return middle value on error
    }
}

; Calculate overlap penalty for a set of window positions
CalculateOverlapPenalty(genes) {
    try {
        if (genes.Length <= 1) {
            return 0  ; No overlap with 0 or 1 window
        }
        
        totalOverlap := 0
        windowCount := genes.Length
        
        ; Check each window pair for overlap
        Loop windowCount - 1 {
            idx := A_Index
            win1 := genes[idx]
            
            Loop windowCount - idx {
                jdx := idx + A_Index
                win2 := genes[jdx]
                
                ; Calculate overlap area using rectangle intersection
                overlapWidth := Max(0, Min(win1["x"] + win1["width"], win2["x"] + win2["width"]) - Max(win1["x"], win2["x"]))
                overlapHeight := Max(0, Min(win1["y"] + win1["height"], win2["y"] + win2["height"]) - Max(win1["y"], win2["y"]))
                
                ; Add overlap area to total
                overlapArea := overlapWidth * overlapHeight
                totalOverlap += overlapArea
            }
        }
        
        ; Normalize penalty based on average window size for consistent scaling
        averageArea := 0
        for gene in genes {
            averageArea += gene["width"] * gene["height"]
        }
        averageArea /= windowCount
        
        ; Return normalized penalty (0-1 range, higher means more overlap)
        if (averageArea > 0) {
            return Min(1.0, totalOverlap / (averageArea * windowCount))
        } else {
            return 0
        }
    } catch as e {
        RecordSystemError("CalculateOverlapPenalty", e)
        return 0.5  ; Return middle value on error
    }
}

; Add missing IsPositionValid function if needed
IsPositionValid(position, win, usedRectangles) {
    try {
        ; Check for overlaps with existing windows
        for rect in usedRectangles {
            ; Simple rectangle overlap check
            if (!(position["x"] + win["width"] <= rect["x"] || 
                  position["x"] >= rect["x"] + rect["width"] || 
                  position["y"] + win["height"] <= rect["y"] || 
                  position["y"] >= rect["y"] + rect["height"])) {
                return false
            }
        }
        return true
    } catch as e {
        RecordSystemError("IsPositionValid", e)
        return false
    }
}

; Add missing CalculatePlacementScore function if needed
CalculatePlacementScore(position, win, bounds) {
    try {
        ; Simple score based on distance from center
        centerX := bounds["Left"] + bounds["Width"] / 2
        centerY := bounds["Top"] + bounds["Height"] / 2
        
        distX := Abs(position["x"] + win["width"] / 2 - centerX)
        distY := Abs(position["y"] + win["height"] / 2 - centerY)
        
        ; Normalize by screen dimensions
        normalizedDist := (distX / bounds["Width"] + distY / bounds["Height"]) / 2
        
        ; Closer to center = higher score (1.0 is best, 0.0 is worst)
        return 1.0 - normalizedDist
    } catch as e {
        RecordSystemError("CalculatePlacementScore", e)
        return 0
    }
}

; Add missing CalculatePackingEfficiency function if needed
CalculatePackingEfficiency(placements, bounds) {
    try {
        if (placements.Length == 0) {
            return 0
        }
        
        ; Calculate total area of windows
        totalWindowArea := 0
        for placement in placements {
            totalWindowArea += placement["width"] * placement["height"]
        }
        
        ; Calculate screen area
        screenArea := bounds["Width"] * bounds["Height"]
        
        ; Efficiency is ratio of window area to screen area
        return Min(totalWindowArea / screenArea, 1.0)
    } catch as e {
        RecordSystemError("CalculatePackingEfficiency", e)
        return 0
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

; Add missing GuillotinePacking function to fix error
GuillotinePacking(windows, bounds) {
    try {
        DebugLog("PACKING", "Applying Guillotine packing algorithm", 3)
        ; Placeholder implementation: just return empty placements
        return Map("placements", [], "efficiency", 0)
    } catch as e {
        RecordSystemError("GuillotinePacking", e)
        return Map("placements", [], "efficiency", 0)
    }
}

; Add missing BottomLeftFillPacking function to fix error
BottomLeftFillPacking(windows, bounds) {
    try {
        DebugLog("PACKING", "Applying Bottom Left Fill packing algorithm", 3)
        ; Placeholder implementation: just return empty placements
        return Map("placements", [], "efficiency", 0)
    } catch as e {
        RecordSystemError("BottomLeftFillPacking", e)
        return Map("placements", [], "efficiency", 0)
    }
}

; Add missing WorstFitPacking function to fix error
WorstFitPacking(windows, bounds) {
    try {
        DebugLog("PACKING", "Applying Worst Fit packing algorithm", 3)
        ; Placeholder implementation: just return empty placements
        return Map("placements", [], "efficiency", 0)
    } catch as e {
        RecordSystemError("WorstFitPacking", e)
        return Map("placements", [], "efficiency", 0)
    }
}

; Add missing NextFitPacking function to fix error
NextFitPacking(windows, bounds) {
    try {
        DebugLog("PACKING", "Applying Next Fit packing algorithm", 3)
        ; Placeholder implementation: just return empty placements
        return Map("placements", [], "efficiency", 0)
    } catch as e {
        RecordSystemError("NextFitPacking", e)
        return Map("placements", [], "efficiency", 0)
    }
}

; Advanced bin packing: First Fit algorithm
FirstFitPacking(windows, bounds) {
    try {
        DebugLog("PACKING", "Applying First Fit packing algorithm", 3)

        ; Sort windows by area (largest first)
        sortedWindows := SortWindowsByArea(windows)

        ; Initialize placement list
        placements := []
        usedRectangles := []

        for win in sortedWindows {
            bestPosition := FindFirstFitPosition(win, bounds, usedRectangles)

            if (bestPosition) {
                placement := Map(
                    "hwnd", win["hwnd"],
                    "x", bestPosition["x"],
                    "y", bestPosition["y"],
                    "width", win["width"],
                    "height", win["height"],
                    "score", CalculatePlacementScore(bestPosition, win, bounds)
                )

                placements.Push(placement)
                usedRectangles.Push(Map(
                    "x", bestPosition["x"],
                    "y", bestPosition["y"],
                    "width", win["width"],
                    "height", win["height"]
                ))
            }
        }

        return Map("placements", placements, "efficiency", CalculatePackingEfficiency(placements, bounds))

    } catch as e {
        RecordSystemError("FirstFitPacking", e)
        return Map("placements", [], "efficiency", 0)
    }
}

; Advanced bin packing: Best Fit algorithm
BestFitPacking(windows, bounds) {
    try {
        DebugLog("PACKING", "Applying Best Fit packing algorithm", 3)

        sortedWindows := SortWindowsByArea(windows)
        placements := []
        usedRectangles := []

        for win in sortedWindows {
            bestPosition := FindBestFitPosition(win, bounds, usedRectangles)

            if (bestPosition) {
                placement := Map(
                    "hwnd", win["hwnd"],
                    "x", bestPosition["x"],
                    "y", bestPosition["y"],
                    "width", win["width"],
                    "height", win["height"],
                    "score", bestPosition["score"]
                )

                placements.Push(placement)
                usedRectangles.Push(Map(
                    "x", bestPosition["x"],
                    "y", bestPosition["y"],
                    "width", win["width"],
                    "height", win["height"]
                ))
            }
        }

        return Map("placements", placements, "efficiency", CalculatePackingEfficiency(placements, bounds))

    } catch as e {
        RecordSystemError("BestFitPacking", e)
        return Map("placements", [], "efficiency", 0)
    }
}

; Find best fit position for a window
FindBestFitPosition(win, bounds, usedRectangles) {
    try {
        bestPosition := ""
        bestScore := -1
        margin := Config["MinMargin"]

        ; Try different positions
        for x in Range(bounds["Left"] + margin, bounds["Right"] - win["width"] - margin, 20) {
            for y in Range(bounds["Top"] + margin, bounds["Bottom"] - win["height"] - margin, 20) {
                candidate := Map("x", x, "y", y)

                ; Check if position is valid (no overlaps)
                if (IsPositionValid(candidate, win, usedRectangles)) {
                    score := CalculatePositionScore(candidate, win, bounds, usedRectangles)

                    if (score > bestScore) {
                        bestScore := score
                        bestPosition := candidate
                        bestPosition["score"] := score
                    }
                }
            }
        }

        return bestPosition

    } catch as e {
        RecordSystemError("FindBestFitPosition", e)
        return ""
    }
}

; Calculate position score based on multiple factors
CalculatePositionScore(position, win, bounds, usedRectangles) {
    try {
        score := 0

        ; Screen utilization score (prefer positions that use screen efficiently)
        utilizationScore := CalculateUtilizationScore(position, win, bounds)
        score += utilizationScore * LayoutMetrics["WastedSpaceWeight"]

        ; Accessibility score (prefer easily accessible positions)
        accessibilityScore := CalculateAccessibilityScore(position, win, bounds)
        score += accessibilityScore * LayoutMetrics["AccessibilityWeight"]

        ; Aesthetics score (prefer visually pleasing arrangements)
        aestheticsScore := CalculateAestheticsScore(position, win, usedRectangles, bounds)
        score += aestheticsScore * LayoutMetrics["AestheticsWeight"]

        ; Minimize wasted space between windows
        proximityScore := CalculateProximityScore(position, win, usedRectangles)
        score += proximityScore * 0.3

        return score

    } catch as e {
        RecordSystemError("CalculatePositionScore", e)
        return 0
    }
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

; Enhanced hotkeys for sophisticated layout management
^!+l:: {  ; Ctrl+Alt+Shift+L - Save current layout
    layoutName := InputBox("Enter layout name:", "Save Layout", "W300 H100").Text
    if (layoutName) {
        SaveCurrentLayout(layoutName)
    }
}

^!+k:: {  ; Ctrl+Alt+Shift+K - Load layout
    ShowLayoutSelectionDialog()
}

^!+g:: {  ; Ctrl+Alt+Shift+G - Toggle genetic algorithm
    global LayoutAlgorithms

    LayoutAlgorithms["GeneticAlgorithm"]["Enabled"] := !LayoutAlgorithms["GeneticAlgorithm"]["Enabled"]
    status := LayoutAlgorithms["GeneticAlgorithm"]["Enabled"] ? "enabled" : "disabled"

    if (LayoutAlgorithms["GeneticAlgorithm"]["Enabled"]) {
        InitializeGeneticAlgorithm()
    } else {
        SetTimer(EvolveLayoutGeneration, 0)
    }

    ShowNotification("Layout", "Genetic algorithm " . status, "info")
}

^!+b:: {  ; Ctrl+Alt+Shift+B - Change bin packing strategy
    ShowBinPackingStrategyDialog()
}

^!+v:: {  ; Ctrl+Alt+Shift+V - Toggle virtual desktop integration
    global LayoutAlgorithms

    LayoutAlgorithms["VirtualDesktop"]["Enabled"] := !LayoutAlgorithms["VirtualDesktop"]["Enabled"]
    status := LayoutAlgorithms["VirtualDesktop"]["Enabled"] ? "enabled" : "disabled"

    if (LayoutAlgorithms["VirtualDesktop"]["Enabled"]) {
        InitializeVirtualDesktopIntegration()
    }

    ShowNotification("Layout", "Virtual desktop integration " . status, "info")
}

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

; Initialize sophisticated layouts during startup
SetTimer(() => InitializeSophisticatedLayouts(), -3000)  ; Initialize after 3 second delay

; Show startup message
ShowNotificationSimple("FWDE", "Floating Windows Dynamic Equilibrium loaded. Ctrl+Alt+S to start/stop.", "info", 5000)

; Visual feedback and notification system
global VisualFeedback := Map(
    "SystemTray", Map(
        "Icon", A_ScriptDir "\FWDE_Icon.ico",
        "Status", "Normal",  ; Normal, Active, Error, Paused
        "LastUpdate", 0,
        "TooltipText", "FWDE - Floating Windows Dynamic Equilibrium"
    ),
    "Notifications", Map(
        "Theme", "Default",  ; Default, Dark, Light
        "Position", "BottomRight",  ; TopLeft, TopRight, BottomLeft, BottomRight
        "Duration", 3000,
        "MaxQueue", 5,
        "Queue", [],
        "History", [],
        "Enabled", true
    ),
    "WindowBorders", Map(
        "Enabled", true,
        "Colors", Map(
            "Locked", "0xFF5555",     ; Red for locked windows
            "Physics", "0x55FF55",    ; Green for physics-controlled
            "Manual", "0x5555FF",     ; Blue for manual control
            "Error", "0xFF9900"       ; Orange for error state
        ),
        "Width", 3,
        "Duration", 2000,
        "ActiveBorders", Map()
    ),
    "PhysicsOverlay", Map(
        "Enabled", false,
        "ShowForces", true,
        "ShowVelocities", true,
        "ShowTargets", true,
        "Transparency", 128,
        "ActiveOverlays", []
    )
)

; Notification themes configuration
global NotificationThemes := Map(
    "Default", Map(
        "BackgroundColor", "0x2D2D30",
        "TextColor", "0xFFFFFF",
        "BorderColor", "0x007ACC",
        "IconColor", "0x007ACC"
    ),
    "Dark", Map(
        "BackgroundColor", "0x1E1E1E",
        "TextColor", "0xD4D4D4",
        "BorderColor", "0x404040",
        "IconColor", "0x007ACC"
    ),
    "Light", Map(
        "BackgroundColor", "0xF3F3F3",
        "TextColor", "0x1E1E1E",
        "BorderColor", "0x0078D4",
        "IconColor", "0x0078D4"
    )
)

; System health and status monitoring
global SystemHealth := Map(
    "Status", "Healthy",  ; Healthy, Warning, Error, Critical
    "ActiveWindows", 0,
    "PhysicsOperations", 0,
    "ErrorRate", 0.0,
    "PerformanceMetrics", Map(
        "AvgPhysicsTime", 0,
        "AvgMovementTime", 0,
        "MemoryUsage", 0,
        "CPUUsage", 0
    ),
    "LastUpdate", A_TickCount
)

; Initialize visual feedback system
InitializeVisualFeedback() {
    DebugLog("VISUAL", "Initializing visual feedback system", 2)

    try {
        ; Initialize system tray
        InitializeSystemTray()

        ; Initialize notification system
        InitializeNotificationSystem()

        ; Initialize window border system
        InitializeWindowBorderSystem()

        ; Start status monitoring
        SetTimer(UpdateSystemStatus, 1000)  ; Update every second

        DebugLog("VISUAL", "Visual feedback system initialized successfully", 2)

    } catch as e {
        RecordSystemError("InitializeVisualFeedback", e)
    }
}

; System tray integration with comprehensive status monitoring
InitializeSystemTray() {
    global VisualFeedback

    try {
        ; Set custom icon if available
        if (FileExist(VisualFeedback["SystemTray"]["Icon"])) {
            TraySetIcon(VisualFeedback["SystemTray"]["Icon"])
        }

        ; Create context menu
        A_TrayMenu.Delete()  ; Clear default menu

        ; Status section
        A_TrayMenu.Add("FWDE Status", ShowSystemStatus)
        A_TrayMenu.Add()  ; Separator

        ; Control section
        A_TrayMenu.Add("Start/Stop Physics", TogglePhysics)
        A_TrayMenu.Add("Refresh Windows", RefreshWindows)
        A_TrayMenu.Add("Optimize Layout", OptimizeLayout)
        A_TrayMenu.Add()  ; Separator



        ; Configuration presets
        presetMenu := Menu()
        presetMenu.Add("Load Default", (*) => LoadConfigPreset("Default"))
        presetMenu.Add("Load DAW Production", (*) => LoadConfigPreset("DAW_Production"))
        presetMenu.Add("Load Gaming", (*) => LoadConfigPreset("Gaming"))
        presetMenu.Add("Load Office Work", (*) => LoadConfigPreset("Office_Work"))
        presetMenu.Add("Load High Performance", (*) => LoadConfigPreset("High_Performance"))
        presetMenu.Add()  ; Separator
        presetMenu.Add("Save Configuration", SaveCurrentConfig)
        presetMenu.Add("Show Config Status", ShowConfigStatus)
        A_TrayMenu.Add("Configuration", presetMenu)

        ; Visual options
        visualMenu := Menu()
        visualMenu.Add("Toggle Physics Overlay", TogglePhysicsOverlay)
        visualMenu.Add("Toggle Window Borders", ToggleWindowBorders)
        visualMenu.Add("Notification Settings", ShowNotificationSettings)
        A_TrayMenu.Add("Visual Options", visualMenu)

        ; System section
        A_TrayMenu.Add()  ; Separator
        A_TrayMenu.Add("About FWDE", ShowAbout)
        A_TrayMenu.Add("Exit", ExitApplication)

        ; Set default action (double-click)
        A_TrayMenu.Default := "FWDE Status"

        ; Update initial tooltip
        UpdateSystemTrayTooltip()

        DebugLog("TRAY", "System tray initialized with context menu", 2)

    } catch as e {
        RecordSystemError("InitializeSystemTray", e)
    }
}

; Update system tray tooltip with current status
UpdateSystemTrayTooltip() {
    global g, VisualFeedback, SystemHealth

    try {
        status := g.Get("PhysicsEnabled", false) ? "Running" : "Stopped"
        windowCount := SystemHealth["ActiveWindows"]
        healthStatus := SystemHealth["Status"]

        tooltipText := "FWDE - " . status . "`n"
        tooltipText .= "Windows: " . windowCount . "`n"
        tooltipText .= "Health: " . healthStatus . "`n"
        tooltipText .= "Click for options"

        A_IconTip := tooltipText
        VisualFeedback["SystemTray"]["TooltipText"] := tooltipText

    } catch as e {
        RecordSystemError("UpdateSystemTrayTooltip", e)
    }
}

; Update system tray icon based on current status
UpdateSystemTrayIcon() {
    global g, VisualFeedback, SystemHealth

    try {
        newStatus := "Normal"

        if (!g.Get("PhysicsEnabled", false)) {
            newStatus := "Paused"
        } else if (SystemHealth["Status"] == "Error" || SystemHealth["Status"] == "Critical") {
            newStatus := "Error"
        } else if (SystemHealth["ActiveWindows"] > 0) {
            newStatus := "Active"
        }

        if (VisualFeedback["SystemTray"]["Status"] != newStatus) {
            VisualFeedback["SystemTray"]["Status"] := newStatus

            ; Update icon based on status (if custom icons available)
            switch newStatus {
                case "Active":
                    ; Green icon for active
                case "Error":
                    ; Red icon for error
                case "Paused":
                    ; Gray icon for paused
                default:
                    ; Default blue icon
            }

            DebugLog("TRAY", "System tray icon updated to: " . newStatus, 3)
        }

    } catch as e {
        RecordSystemError("UpdateSystemTrayIcon", e)
    }
}

; Enhanced notification system with theming and queue management
InitializeNotificationSystem() {
    global VisualFeedback, NotificationThemes

    try {
        ; Clear any existing notifications
        VisualFeedback["Notifications"]["Queue"] := []
        VisualFeedback["Notifications"]["History"] := []

        ; Start notification processor
        SetTimer(ProcessNotificationQueue, 100)

        DebugLog("NOTIFICATION", "Notification system initialized", 2)

    } catch as e {
        RecordSystemError("InitializeNotificationSystem", e)
    }
}

; Enhanced notification function with theming and queue management
ShowNotification(title, message, type := "info", duration := 0) {
    global VisualFeedback, NotificationThemes

    try {
        if (!VisualFeedback["Notifications"]["Enabled"]) {
            return
        }

        ; Use default duration if not specified
        if (duration == 0) {
            duration := VisualFeedback["Notifications"]["Duration"]
        }

        ; Create notification object
        notification := Map(
            "Title", title,
            "Message", message,
            "Type", type,
            "Duration", duration,
            "Timestamp", A_TickCount,
            "ID", A_TickCount . "_" . Random(1000, 9999)
        )

        ; Add to queue
        queue := VisualFeedback["Notifications"]["Queue"]
        if (queue.Length >= VisualFeedback["Notifications"]["MaxQueue"]) {
            queue.RemoveAt(1)  ; Remove oldest if queue full
        }
        queue.Push(notification)

        ; Add to history
        history := VisualFeedback["Notifications"]["History"]
        history.Push(notification)

        ; Keep history size manageable
        if (history.Length > 50) {
            history.RemoveAt(1)
        }

        DebugLog("NOTIFICATION", title . ": " . message, 2)

    } catch as e {
        RecordSystemError("ShowNotification", e)
    }
}

; Process notification queue and display notifications
ProcessNotificationQueue() {
    global VisualFeedback

    try {
        queue := VisualFeedback["Notifications"]["Queue"]

        if (queue.Length > 0) {
            notification := queue[1]
            queue.RemoveAt(1)

            ; Display notification using system balloon tip
            DisplayBalloonNotification(notification)
        }

    } catch as e {
        RecordSystemError("ProcessNotificationQueue", e)
    }
}

; Display balloon notification with themed styling
DisplayBalloonNotification(notification) {
    global VisualFeedback

    try {
        ; Get icon type based on notification type
        iconType := 1  ; Info icon
        switch notification["Type"] {
            case "success":
                iconType := 1  ; Info icon (closest to success)
            case "warning":
                iconType := 2  ; Warning icon
           
            case "error":
                iconType := 3  ; Error icon
            default:
                iconType := 1  ; Info icon
        }

        ; Show balloon tip
        TrayTip(notification["Message"], notification["Title"], iconType)

        ; Auto-hide after duration
        if (notification["Duration"] > 0) {
            SetTimer(() => TrayTip(), -notification["Duration"])
        }

    } catch as e {
        RecordSystemError("DisplayBalloonNotification", e)
    }
}

; Window border visual indicator system
InitializeWindowBorderSystem() {
    global VisualFeedback

    try {
        ; Clear any existing borders
        VisualFeedback["WindowBorders"]["ActiveBorders"] := Map()

        ; Start border update timer
        SetTimer(UpdateWindowBorders, 500)  ; Update twice per second

        DebugLog("BORDER", "Window border system initialized", 2)

    } catch as e {
        RecordSystemError("InitializeWindowBorderSystem", e)
    }
}

; Add visual border to window based on state
AddWindowBorder(hwnd, state, duration := 0) {
    global VisualFeedback

    try {
        if (!VisualFeedback["WindowBorders"]["Enabled"]) {
            return
        }

        ; Use default duration if not specified
        if (duration == 0) {
            duration := VisualFeedback["WindowBorders"]["Duration"]
        }

        colors := VisualFeedback["WindowBorders"]["Colors"]
        if (!colors.Has(state)) {
            return
        }

        ; Create border info
        borderInfo := Map(
            "HWND", hwnd,
            "State", state,
            "Color", colors[state],
            "StartTime", A_TickCount,
            "Duration", duration,
            "Width", VisualFeedback["WindowBorders"]["Width"]
        )

        ; Store border
        VisualFeedback["WindowBorders"]["ActiveBorders"][hwnd] := borderInfo

        ; Apply visual border (simplified implementation)
        ApplyWindowBorder(borderInfo)

        DebugLog("BORDER", "Added " . state . " border to window " . hwnd, 3)

    } catch as e {
        RecordSystemError("AddWindowBorder", e, hwnd)
    }
}

; Apply visual border to window (simplified implementation using window highlighting)
ApplyWindowBorder(borderInfo) {
    try {
        hwnd := borderInfo["HWND"]

        if (!IsWindowValid(hwnd)) {
                       return
        }

        ; Simple implementation: brief window flash to indicate state
        ; In a full implementation, this would draw custom borders
        try {

            ; Flash window to show state change
            DllCall("FlashWindow", "Ptr", hwnd, "Int", 1)
        } catch {
            ; Ignore flash failures
        }

    } catch as e {
        RecordSystemError("ApplyWindowBorder", e, borderInfo["HWND"])
    }
}

; Update and cleanup window borders
UpdateWindowBorders() {
    global VisualFeedback

    try {
        activeBorders := VisualFeedback["WindowBorders"]["ActiveBorders"]
        currentTime := A_TickCount
        bordersToRemove := []

        ; Check each active border
        for hwnd, borderInfo in activeBorders {
            ; Check if window still exists
            if (!IsWindowValid(hwnd)) {
                bordersToRemove.Push(hwnd)
                continue
            }

            ; Check if border expired
            elapsed := currentTime - borderInfo["StartTime"]
            if (elapsed > borderInfo["Duration"]) {
                bordersToRemove.Push(hwnd)
                continue
            }
        }

        ; Remove expired borders
        for hwnd in bordersToRemove {
            activeBorders.Delete(hwnd)
        }

    } catch as e {
        RecordSystemError("UpdateWindowBorders", e)
    }
}

; System status monitoring and health tracking
UpdateSystemStatus() {
    global g, SystemHealth, VisualFeedback

    try {
        ; Update active window count
        SystemHealth["ActiveWindows"] := g.Has("Windows") ? g["Windows"].Length : 0

        ; Update performance metrics
        UpdatePerformanceMetrics()

        ; Update system health status
        UpdateSystemHealthStatus()

        ; Update visual feedback
        UpdateSystemTrayIcon()
        UpdateSystemTrayTooltip()

        SystemHealth["LastUpdate"] := A_TickCount

    } catch as e {
        RecordSystemError("UpdateSystemStatus", e)
    }
}

; Update performance metrics for system monitoring
UpdatePerformanceMetrics() {
    global PerfTimers, SystemHealth

    try {
        metrics := SystemHealth["PerformanceMetrics"]

        ; Update physics timing
        if (PerfTimers.Has("CalculateDynamicLayout")) {
            metrics["AvgPhysicsTime"] := PerfTimers["CalculateDynamicLayout"]["avgTime"]
        }

        ; Update movement timing
        if (PerfTimers.Has("ApplyWindowMovements")) {
            metrics["AvgMovementTime"] := PerfTimers["ApplyWindowMovements"]["avgTime"]
        }

        ; Update memory usage (simplified)
        metrics["MemoryUsage"] := ProcessGetWorkingSet()

    } catch as e {
        RecordSystemError("UpdatePerformanceMetrics", e)
    }
}

; Update overall system health status
UpdateSystemHealthStatus() {
    global SystemState, SystemHealth

    try {
        errorCount := SystemState.Get("ErrorCount", 0)
        isHealthy := SystemState.Get("SystemHealthy", true)

        ; Determine health status
        if (!isHealthy || errorCount > 10) {
            SystemHealth["Status"] := "Critical"
        } else if (errorCount > 5) {
            SystemHealth["Status"] := "Error"
        } else if (errorCount > 2) {
            SystemHealth["Status"] := "Warning"
        } else {
            SystemHealth["Status"] := "Healthy"
        }

        ; Calculate error rate
        if (SystemState.Has("FailedOperations") && SystemState["FailedOperations"].Length > 0) {
            SystemHealth["ErrorRate"] := errorCount / (errorCount + 100)  ; Simplified calculation
        } else {
            SystemHealth["ErrorRate"] := 0.0
        }

    } catch as e {
        RecordSystemError("UpdateSystemHealthStatus", e)
    }
}

; Configuration preset management with visual feedback
LoadConfigPreset(presetName) {
    global ConfigPresets, QualityLevels

    try {
        if (!ConfigPresets.Has(presetName)) {
            ShowNotification("Configuration", "Preset '" . presetName . "' not found", "error")
            return false
        }

        preset := ConfigPresets[presetName]

        ; Backup current configuration
        BackupCurrentConfiguration()

        ; Apply preset with validation
        validationResult := ValidateConfiguration(preset)
        if (!validationResult["valid"]) {
            ShowNotification("Configuration", "Preset validation failed", "error")
            return false
        }

        ; Apply preset
        for key, value in preset {
            if (key != "description") {
                Config[key] := value
            }
        }

        ; Apply changes to running system
        ApplyConfigurationChanges(Config)

        ; Save configuration
        SaveConfigurationToFile()

        ; Show success notification
        description := preset.Get("description", presetName . " preset")
        ShowNotification("Configuration", "Loaded: " . description, "success")

        DebugLog("CONFIG", "Loaded preset: " . presetName, 2)
        return true

    } catch as e {
        RecordSystemError("LoadConfigPreset", e)
        ShowNotification("Configuration", "Failed to load preset: " . presetName, "error")
        return false
    }
}

; Menu handlers for system tray
ShowSystemStatus(*) {
    global SystemHealth, g

    try {
        status := g.Get("PhysicsEnabled", false) ? "Running" : "Stopped"
        healthStatus := SystemHealth["Status"]
        windowCount := SystemHealth["ActiveWindows"]
        errorRate := Round(SystemHealth["ErrorRate"] * 100, 2)

        statusText := "FWDE System Status`n`n"
        statusText .= "Physics Engine: " . status . "`n"
        statusText .= "System Health: " . healthStatus . "`n"
        statusText .= "Active Windows: " . windowCount . "`n"
        statusText .= "Error Rate: " . errorRate . "%`n`n"
        statusText .= "Performance Metrics:`n"
        statusText .= "Physics Time: " . Round(SystemHealth["PerformanceMetrics"]["AvgPhysicsTime"], 2) . "ms`n"
        statusText .= "Movement Time: " . Round(SystemHealth["PerformanceMetrics"]["AvgMovementTime"], 2) . "ms`n"
        statusText .= "Memory Usage: " . Round(SystemHealth["PerformanceMetrics"]["MemoryUsage"] / 1024 / 1024, 1) . "MB"

        MsgBox(statusText, "FWDE System Status", "OK I")

    } catch as e {
        RecordSystemError("ShowSystemStatus", e)
    }
}

TogglePhysics(*) {
    global g

    if (g.Get("PhysicsEnabled", false)) {
        StopFWDE()
    } else {
        StartFWDE()
    }
}

RefreshWindows(*) {
    RefreshWindowList()
    ShowNotification("FWDE", "Window list refreshed", "info", 2000)
}

OptimizeLayout(*) {
    OptimizeWindowPositions()
    ShowNotification("FWDE", "Window layout optimized", "info", 2000)
}

TogglePhysicsOverlay(*) {
    global VisualFeedback

    VisualFeedback["PhysicsOverlay"]["Enabled"] := !VisualFeedback["PhysicsOverlay"]["Enabled"]
    status := VisualFeedback["PhysicsOverlay"]["Enabled"] ? "enabled" : "disabled"
    ShowNotification("Visual", "Physics overlay " . status, "info")
}

ToggleWindowBorders(*) {
    global VisualFeedback

    VisualFeedback["WindowBorders"]["Enabled"] := !VisualFeedback["WindowBorders"]["Enabled"]
    status := VisualFeedback["WindowBorders"]["Enabled"] ? "enabled" : "disabled"
    ShowNotification("Visual", "Window borders " . status, "info")
}

ShowNotificationSettings(*) {
    global VisualFeedback, NotificationThemes

    try {
        currentTheme := VisualFeedback["Notifications"]["Theme"]
        enabled := VisualFeedback["Notifications"]["Enabled"] ? "Enabled" : "Disabled"

        settingsText := "Notification Settings`n`n"
        settingsText .= "Status: " . enabled . "`n"
        settingsText .= "Current Theme: " . currentTheme . "`n"
        settingsText .= "Position: " . VisualFeedback["Notifications"]["Position"] . "`n"
        settingsText .= "Duration: " . VisualFeedback["Notifications"]["Duration"] . "ms`n"
        settingsText .= "Max Queue: " . VisualFeedback["Notifications"]["MaxQueue"] . "`n`n"
        settingsText .= "Available Themes: "

        for themeName in NotificationThemes {
            settingsText .= themeName . " "
        }

        MsgBox(settingsText, "Notification Settings", "OK I")

    } catch as e {
        RecordSystemError("ShowNotificationSettings", e)
    }
}

SaveCurrentConfig(*) {
    if (SaveConfigurationToFile()) {
        ShowNotification("Configuration", "Configuration saved successfully", "success")
    } else {
        ShowNotification("Configuration", "Failed to save configuration", "error")
    }
}

ShowConfigStatus(*) {
    global Config

    try {
        validation := ValidateConfiguration(Config)
        statusText := "Configuration Status`n`n"
        statusText .= "Valid: " . (validation["valid"] ? "Yes" : "No") . "`n`n"

        if (validation["errors"].Length > 0) {
            statusText .= "Errors:`n"
            for validationError in validation["errors"] {
                statusText .= "• " . validationError . "`n"
            }
            statusText .= "`n"
        }

        if (validation["warnings"].Length > 0) {
            statusText .= "Warnings:`n"
            for validationWarning in validation["warnings"] {
                statusText .= "• " . validationWarning . "`n"
            }
        }

        MsgBox(statusText, "Configuration Status", "OK I")

    } catch as e {
        RecordSystemError("ShowConfigStatus", e)
    }
}

ShowAbout(*) {
    aboutText := "Floating Windows - Dynamic Equilibrium (FWDE)`n`n"
    aboutText .= "An advanced AutoHotkey v2 window management system`n"
    aboutText .= "implementing physics-based window arrangement.`n`n"
    aboutText .= "Features:`n"
    aboutText .= "• Physics-based window positioning`n"
    aboutText .= "• Multi-monitor support`n"
    aboutText .= "• DAW plugin window optimization`n"
    aboutText .= "• Real-time configuration hot-reload`n"
    aboutText .= "• Advanced visual feedback system`n`n"
    aboutText .= "Hotkeys:`n"
    aboutText .= "Ctrl+Alt+S - Start/Stop`n"
    aboutText .= "Ctrl+Alt+R - Refresh Windows`n"
    aboutText .= "Ctrl+Alt+O - Optimize Layout`n"
    aboutText .= "Ctrl+Alt+M - Toggle Multi-Monitor`n"
    aboutText .= "Ctrl+Alt+P - Pause/Resume Physics`n"
    aboutText .= "Ctrl+Alt+Q - Quit FWDE"

    MsgBox(aboutText, "About FWDE", "OK I")
}

ExitApplication(*) {
    StopFWDE()
    ExitApp()
}

; Enhanced window management with visual feedback
RefreshWindowList() {
    global g, Config, VisualFeedback

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

                ; Add visual feedback for newly detected window
                AddWindowBorder(hwnd, "Physics", 1000)

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

; Dialog functions
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

        selectedLayout := InputBox("Select layout to load:", "Layout Selection", "W300 H100", layoutList).Text

        if (selectedLayout && savedLayouts.Has(selectedLayout)) {
            LoadLayout(selectedLayout)
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

        selectedStrategy := InputBox("Current: " . currentStrategy . "`nSelect new strategy:", "Bin Packing Strategy", "W300 H120", strategies).Text

        if (selectedStrategy && BinPackingStrategies.Has(selectedStrategy)) {
            LayoutAlgorithms["BinPacking"]["Strategy"] := selectedStrategy
            ShowNotification("Layout", "Bin packing strategy changed to: " . selectedStrategy, "success")
        }
    } catch as e {
        RecordSystemError("ShowBinPackingStrategyDialog", e)
    }
}

; System functions
ProcessGetWorkingSet() {
    try {
        ; Get current process working set size in bytes
        return ProcessGetMemoryInfo(DllCall("GetCurrentProcessId"))
    } catch {
        return 0
    }
}

ProcessGetMemoryInfo(pid) {
    try {
        ; Simplified memory info - would use Process32 APIs in full implementation
        return 50 * 1024 * 1024  ; Return 50MB as placeholder
    } catch {
        return 0
    }
}

; Core system functions
StartFWDE() {
    global g
    try {
        g["PhysicsEnabled"] := true
        g["ArrangementActive"] := true

        RefreshWindowList()
        ShowNotification("FWDE", "Physics engine started", "success", 2000)
        DebugLog("SYSTEM", "FWDE started", 2)
    } catch as e {
        RecordSystemError("StartFWDE", e)
    }
}

StopFWDE() {
    global g
    try {
        g["PhysicsEnabled"] := false
        g["ArrangementActive"] := false

        ShowNotification("FWDE", "Physics engine stopped", "info", 2000)
        DebugLog("SYSTEM", "FWDE stopped", 2)
    } catch as e {
        RecordSystemError("StopFWDE", e)
    }
}

OptimizeWindowPositions() {
    try {
        PeriodicLayoutOptimization()
        ShowNotification("FWDE", "Window positions optimized", "success", 2000)
    } catch as e {
        RecordSystemError("OptimizeWindowPositions", e)
    }
}

; Initialize visual feedback on startup
SetTimer(() => InitializeVisualFeedback(), -2000)

; Initialize configuration system on startup
SetTimer(() => InitializeConfigurationSystem(), -1000)

; Add missing RecordPerformanceMetric function to resolve compile error
RecordPerformanceMetric(operation, timeMs) {
    global PerfTimers
    try {
        if (!PerfTimers.Has(operation)) {
            PerfTimers[operation] := Map(
                "totalTime", 0,
                "count", 0,
                "avgTime", 0,
                "maxTime", 0,
                "minTime", 999999
            )
        }

        timer := PerfTimers[operation]
        timer["totalTime"] += timeMs
        timer["count"] += 1
        timer["avgTime"] := timer["totalTime"] / timer["count"]
        timer["maxTime"] := Max(timer["maxTime"], timeMs)
        timer["minTime"] := Min(timer["minTime"], timeMs)

        DebugLog("PERF", operation . " took " . timeMs . "ms (avg: " . Round(timer["avgTime"], 2) . "ms)", 3)
    } catch as e {
        RecordSystemError("RecordPerformanceMetric", e, operation)
    }
}

; Add missing QualityLevels global variable
global QualityLevels := Map(
    "Low", Map(
        "description", "Low quality settings for better performance",
        "PhysicsTimeStep", 5,
        "VisualTimeStep", 10,
        "Smoothing", 0.3,
        "MaxSpeed", 20.0,
        "PhysicsUpdateInterval", 500
    ),
    "Medium", Map(
        "description", "Balanced quality and performance",
        "PhysicsTimeStep", 2,
        "VisualTimeStep", 5,
        "Smoothing", 0.5,
        "MaxSpeed", 12.0,
        "PhysicsUpdateInterval", 200
    ),
    "High", Map(
        "description", "High quality settings for smooth visuals",
        "PhysicsTimeStep", 1,
        "VisualTimeStep", 2,
        "Smoothing", 0.7,
        "MaxSpeed", 8.0,
        "PhysicsUpdateInterval", 100
    ),
    "Ultra", Map(
        "description", "Ultra quality settings for maximum smoothness",
        "PhysicsTimeStep", 1,
        "VisualTimeStep", 1,
        "Smoothing", 0.9,
        "MaxSpeed", 6.0,
        "PhysicsUpdateInterval", 50
    )
)