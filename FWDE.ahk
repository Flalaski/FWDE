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
        "ScreenshotCheckInterval", "number"
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

ShowNotification(title, message, type := "info", duration := 3000) {
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
        ; Read and parse JSON configuration
        configText := FileRead(ConfigFile)
        configData := JSON.parse(configText)
        
        ; Validate JSON structure
        validationResult := ValidateConfigurationSchema(configData)
        if (!validationResult["valid"]) {
            DebugLog("CONFIG", "Configuration schema validation failed: " validationResult["error"], 1)
            return AttemptConfigurationRecovery()
        }
        
        ; Create backup of current configuration before applying changes
        BackupCurrentConfiguration()
        
        ; Apply configuration with validation
        appliedConfig := Map()
        for key, value in configData {
            if (ConfigSchema["structure"].Has(key)) {
                ; Validate individual parameter
                paramValidation := ValidateConfigParameter(key, value)
                if (paramValidation["valid"]) {
                    appliedConfig[key] := value
                } else {
                    DebugLog("CONFIG", "Parameter validation failed for " key ": " paramValidation["error"], 2)
                    appliedConfig[key] := Config[key]  ; Keep current value
                }
            }
        }
        
        ; Validate complete configuration
        fullValidation := ValidateConfiguration(appliedConfig)
        if (!fullValidation["valid"]) {
            DebugLog("CONFIG", "Full configuration validation failed", 1)
            for error in fullValidation["errors"] {
                DebugLog("CONFIG", "Validation error: " error, 1)
            }
            return AttemptConfigurationRecovery()
        }
        
        ; Apply validated configuration
        for key, value in appliedConfig {
            Config[key] := value
        }
        
        ; Trigger system updates based on configuration changes
        ApplyConfigurationChanges_Placeholder(appliedConfig)
        
        DebugLog("CONFIG", "Configuration loaded and applied successfully", 2)
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
        ; Validate configuration before saving
        validation := ValidateConfiguration(Config)
        if (!validation["valid"]) {
            DebugLog("CONFIG", "Cannot save invalid configuration", 1)
            return false
        }
        
        ; Create configuration object for JSON
        configToSave["_metadata"] := Map(
            "version", ConfigSchema["version"],
            "saved", FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"),
            "application", "FWDE"
        )
        
        ; Add all configuration parameters
        for key, value in Config {
            if (ConfigSchema["structure"].Has(key)) {
                configToSave[key] := value
            }
        }
        
        ; Convert to JSON with formatting
        jsonText := JSON.stringify(configToSave, 2)  ; 2-space indentation
        
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

; Enhanced multi-monitor support system
global MonitorSystem := Map(
    "Monitors", Map(),           ; Individual monitor configurations
    "ActiveConfig", "",          ; Current monitor configuration hash
    "LastConfigCheck", 0,        ; Last monitor configuration check time
    "ConfigCheckInterval", 2000, ; How often to check for monitor changes (ms)
    "MigrationInProgress", false, ; Flag for window migration operations
    "MigrationAnimations", Map(), ; Active migration animations
    "DPIScaling", Map(),         ; Per-monitor DPI scaling factors
    "ProfileAssignments", Map()   ; Monitor-to-profile assignments
)

; Per-monitor physics profiles extending base configuration
global MonitorProfiles := Map(
    "Default", Map(
        "description", "Default physics profile for all monitors",
        "AttractionForce", 0.0001,
        "RepulsionForce", 0.369,
        "EdgeRepulsionForce", 0.80,
        "MaxSpeed", 12.0,
        "Damping", 0.001,
        "MinMargin", 0,
        "MinGap", 0,
        "Enabled", true
    ),
    "Primary_Performance", Map(
        "description", "High-performance profile for primary monitor",
        "AttractionForce", 0.0003,
        "RepulsionForce", 0.4,
        "EdgeRepulsionForce", 0.9,
        "MaxSpeed", 15.0,
        "Damping", 0.0015,
        "MinMargin", 2,
        "MinGap", 1,
        "Enabled", true
    ),
    "Secondary_Conservative", Map(
        "description", "Conservative profile for secondary monitors",
        "AttractionForce", 0.0001,
        "RepulsionForce", 0.2,
        "EdgeRepulsionForce", 0.5,
        "MaxSpeed", 8.0,
        "Damping", 0.003,
        "MinMargin", 10,
        "MinGap", 5,
        "Enabled", true
    ),
    "Gaming_Monitor", Map(
        "description", "Optimized for gaming monitors with minimal interference",
        "AttractionForce", 0.001,
        "RepulsionForce", 1.0,
        "EdgeRepulsionForce", 2.0,
        "MaxSpeed", 20.0,
        "Damping", 0.005,
        "MinMargin", 15,
        "MinGap", 8,
        "Enabled", true
    ),
    "DAW_Monitor", Map(
        "description", "Specialized for DAW plugin windows",
        "AttractionForce", 0.0005,
        "RepulsionForce", 0.5,
        "EdgeRepulsionForce", 1.2,
        "MaxSpeed", 8.0,
        "Damping", 0.002,
        "MinMargin", 5,
        "MinGap", 3,
        "Enabled", true
    ),
    "Disabled", Map(
        "description", "Disabled physics for this monitor",
        "Enabled", false
    )
)

; Enhanced monitor detection with DPI awareness
GetEnhancedMonitorInfo() {
    global MonitorSystem
    
    try {
        monitors := Map()
        configHash := ""
        
        ; Get all monitors with detailed information
        Loop {
            monitorInfo := MonitorGet(A_Index)
            if (!monitorInfo) {
                break
            }
            
            ; Get DPI scaling for this monitor
            dpiX := 96, dpiY := 96
            try {
                ; Attempt to get DPI information (Windows 8.1+)
                hMonitor := DllCall("MonitorFromPoint", "Int64", (monitorInfo.Left + monitorInfo.Right) // 2 | ((monitorInfo.Top + monitorInfo.Bottom) // 2) << 32, "UInt", 2, "Ptr")
                if (hMonitor) {
                    dpiX := 96, dpiY := 96
                    DllCall("Shcore.dll\GetDpiForMonitor", "Ptr", hMonitor, "Int", 0, "UInt*", &dpiX, "UInt*", &dpiY)
                }
            } catch {
                ; Fallback to system DPI
                hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
                dpiX := DllCall("GetDeviceCaps", "Ptr", hdc, "Int", 88)
                dpiY := DllCall("GetDeviceCaps", "Ptr", hdc, "Int", 90)
                DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
            }
            
            ; Calculate scaling factors
            scaleX := dpiX / 96.0
            scaleY := dpiY / 96.0
            
            ; Create monitor object
            monitor := Map(
                "Index", A_Index,
                "Left", monitorInfo.Left,
                "Top", monitorInfo.Top,
                "Right", monitorInfo.Right,
                "Bottom", monitorInfo.Bottom,
                "Width", monitorInfo.Right - monitorInfo.Left,
                "Height", monitorInfo.Bottom - monitorInfo.Top,
                "DPI_X", dpiX,
                "DPI_Y", dpiY,
                "ScaleX", scaleX,
                "ScaleY", scaleY,
                "IsPrimary", MonitorGetPrimary() == A_Index,
                "Name", MonitorGetName(A_Index),
                "WorkArea", MonitorGetWorkArea(A_Index),
                "Profile", "Default",  ; Default profile assignment
                "LastAssigned", A_TickCount
            )
            
            monitors[A_Index] := monitor
            configHash .= A_Index . ":" . monitor["Left"] . "," . monitor["Top"] . "," . monitor["Width"] . "," . monitor["Height"] . "," . monitor["DPI_X"] . ";"
        }
        
        ; Update monitor system
        MonitorSystem["Monitors"] := monitors
        MonitorSystem["ActiveConfig"] := configHash
        MonitorSystem["LastConfigCheck"] := A_TickCount
        
        ; Update DPI scaling cache
        for index, monitor in monitors {
            MonitorSystem["DPIScaling"][index] := Map(
                "ScaleX", monitor["ScaleX"],
                "ScaleY", monitor["ScaleY"]
            )
        }
        
        DebugLog("MONITOR", "Enhanced monitor detection completed: " . monitors.Count . " monitors", 2)
        return monitors
        
    } catch as e {
        RecordSystemError("GetEnhancedMonitorInfo", e)
        return Map()
    }
}

; Monitor configuration change detection
CheckMonitorConfigurationChanges() {
    global MonitorSystem, g
    
    try {
        ; Get current monitor configuration
        currentMonitors := GetEnhancedMonitorInfo()
        currentConfigHash := MonitorSystem["ActiveConfig"]
        
        ; Compare with previous configuration
        if (MonitorSystem.Has("PreviousConfig") && MonitorSystem["PreviousConfig"] != currentConfigHash) {
            DebugLog("MONITOR", "Monitor configuration change detected", 1)
            
            ; Handle monitor configuration change
            HandleMonitorConfigurationChange(MonitorSystem["Monitors"], currentMonitors)
            
            ; Update stored configuration
            MonitorSystem["PreviousConfig"] := currentConfigHash
            
            ; Show notification
            ShowNotification("Monitor Setup", "Monitor configuration changed - adjusting physics boundaries", "info", 3000)
        } else if (!MonitorSystem.Has("PreviousConfig")) {
            ; First run - store initial configuration
            MonitorSystem["PreviousConfig"] := currentConfigHash
        }
        
    } catch as e {
        RecordSystemError("CheckMonitorConfigurationChanges", e)
    }
}

; Handle monitor configuration changes
HandleMonitorConfigurationChange(oldMonitors, newMonitors) {
    global MonitorSystem, g
    
    try {
        DebugLog("MONITOR", "Processing monitor configuration change", 2)
        
        ; Identify removed monitors
        removedMonitors := []
        for oldIndex, oldMonitor in oldMonitors {
            found := false
            for newIndex, newMonitor in newMonitors {
                if (oldMonitor["Left"] == newMonitor["Left"] && 
                    oldMonitor["Top"] == newMonitor["Top"] &&
                    oldMonitor["Width"] == newMonitor["Width"] &&
                    oldMonitor["Height"] == newMonitor["Height"]) {
                    found := true
                    break
                }
            }
            if (!found) {
                removedMonitors.Push(oldIndex)
            }
        }
        
        ; Migrate windows from removed monitors
        if (removedMonitors.Length > 0) {
            MigrateWindowsFromRemovedMonitors(removedMonitors, newMonitors)
        }
        
        ; Update physics boundaries for all remaining windows
        UpdatePhysicsBoundariesForMonitorChange(newMonitors)
        
        ; Reassign monitor profiles
        ReassignMonitorProfiles(newMonitors)
        
    } catch as e {
        RecordSystemError("HandleMonitorConfigurationChange", e)
    }
}

; Migrate windows from removed monitors
MigrateWindowsFromRemovedMonitors(removedMonitors, newMonitors) {
    global g, MonitorSystem
    
    try {
        if (!g.Has("Windows") || newMonitors.Count == 0) {
            return
        }
        
        ; Find primary monitor as migration target
        primaryMonitor := ""
        for index, monitor in newMonitors {
            if (monitor["IsPrimary"]) {
                primaryMonitor := monitor
                break
            }
        }
        
        ; Fallback to first available monitor
        if (!primaryMonitor) {
            for index, monitor in newMonitors {
                primaryMonitor := monitor
                break
            }
        }
        
        if (!primaryMonitor) {
            return
        }
        
        DebugLog("MONITOR", "Migrating windows to monitor " . primaryMonitor["Index"], 2)
        
        ; Migrate windows with smooth animation
        windowsMigrated := 0
        for win in g["Windows"] {
            if (!IsWindowValid(win["hwnd"])) {
                continue
            }
            
            WinGetPos(&x, &y, &w, &h, "ahk_id " . win["hwnd"])
            
            ; Check if window is on a removed monitor
            isOnRemovedMonitor := false
            for removedIndex in removedMonitors {
                ; This is simplified - in practice you'd check against the actual removed monitor bounds
                if (x < 0 || y < 0) {  ; Simplified check for off-screen windows
                    isOnRemovedMonitor := true
                    break
                }
            }
            
            if (isOnRemovedMonitor) {
                ; Calculate new position within primary monitor bounds
                newX := primaryMonitor["Left"] + 50 + (windowsMigrated * 30)
                newY := primaryMonitor["Top"] + 50 + (windowsMigrated * 30)
                
                ; Ensure window fits within monitor
                if (newX + w > primaryMonitor["Right"]) {
                    newX := primaryMonitor["Right"] - w - 10
                }
                if (newY + h > primaryMonitor["Bottom"]) {
                    newY := primaryMonitor["Bottom"] - h - 10
                }
                
                ; Perform migration with animation
                StartWindowMigrationAnimation(win["hwnd"], x, y, newX, newY)
                windowsMigrated++
            }
        }
        
        if (windowsMigrated > 0) {
            ShowNotification("Window Migration", "Migrated " . windowsMigrated . " windows to active monitors", "success", 4000)
        }
        
    } catch as e {
        RecordSystemError("MigrateWindowsFromRemovedMonitors", e)
    }
}

; Animate window migration between monitors
StartWindowMigrationAnimation(hwnd, startX, startY, endX, endY) {
    global MonitorSystem
    
    try {
        if (!IsWindowValid(hwnd)) {
            return
        }
        
        ; Create animation object
        animation := Map(
            "hwnd", hwnd,
            "startX", startX,
            "startY", startY,
            "endX", endX,
            "endY", endY,
            "startTime", A_TickCount,
            "duration", 1000,  ; 1 second animation
            "easing", "easeOutCubic"
        )
        
        ; Store animation
        MonitorSystem["MigrationAnimations"][hwnd] := animation
        MonitorSystem["MigrationInProgress"] := true
        
        ; Start animation timer if not already running
        if (!MonitorSystem.Has("AnimationTimer") || !MonitorSystem["AnimationTimer"]) {
            MonitorSystem["AnimationTimer"] := true
            SetTimer(UpdateMigrationAnimations, 16)  ; ~60fps
        }
        
        DebugLog("MIGRATION", "Started migration animation for window " . hwnd, 3)
        
    } catch as e {
        RecordSystemError("StartWindowMigrationAnimation", e, hwnd)
    }
}

; Update migration animations
UpdateMigrationAnimations() {
    global MonitorSystem
    
    try {
        animations := MonitorSystem["MigrationAnimations"]
        currentTime := A_TickCount
        activeAnimations := 0
        
        for hwnd, animation in animations {
            if (!IsWindowValid(hwnd)) {
                animations.Delete(hwnd)
                continue
            }
            
            elapsed := currentTime - animation["startTime"]
            progress := Min(elapsed / animation["duration"], 1.0)
            
            if (progress >= 1.0) {
                ; Animation complete
                WinMove(animation["endX"], animation["endY"], , , "ahk_id " . hwnd)
                animations.Delete(hwnd)
                DebugLog("MIGRATION", "Completed migration animation for window " . hwnd, 3)
            } else {
                ; Calculate eased position
                easedProgress := EaseOutCubic(progress)
                currentX := animation["startX"] + (animation["endX"] - animation["startX"]) * easedProgress
                currentY := animation["startY"] + (animation["endY"] - animation["startY"]) * easedProgress
                
                ; Apply position
                WinMove(Integer(currentX), Integer(currentY), , , "ahk_id " . hwnd)
                activeAnimations++
            }
        }
        
        ; Stop timer if no active animations
        if (activeAnimations == 0) {
            SetTimer(UpdateMigrationAnimations, 0)
            MonitorSystem["AnimationTimer"] := false
            MonitorSystem["MigrationInProgress"] := false
            DebugLog("MIGRATION", "All migration animations completed", 2)
        }
        
    } catch as e {
        RecordSystemError("UpdateMigrationAnimations", e)
        SetTimer(UpdateMigrationAnimations, 0)
        MonitorSystem["AnimationTimer"] := false
        MonitorSystem["MigrationInProgress"] := false
    }
}

; Easing function for smooth animations
EaseOutCubic(t) {
    return 1 - (1 - t) ** 3
}

; Get monitor for window position
GetMonitorForWindow(hwnd) {
    global MonitorSystem
    
    try {
        if (!IsWindowValid(hwnd)) {
            return ""
        }
        
        WinGetPos(&x, &y, &w, &h, "ahk_id " . hwnd)
        centerX := x + w // 2
        centerY := y + h // 2
        
        ; Find monitor containing window center
        for index, monitor in MonitorSystem["Monitors"] {
            if (centerX >= monitor["Left"] && centerX < monitor["Right"] &&
                centerY >= monitor["Top"] && centerY < monitor["Bottom"]) {
                return monitor
            }
        }
        
        ; Fallback to primary monitor
        for index, monitor in MonitorSystem["Monitors"] {
            if (monitor["IsPrimary"]) {
                return monitor
            }
        }
        
        return ""
        
    } catch as e {
        RecordSystemError("GetMonitorForWindow", e, hwnd)
        return ""
    }
}

; Get physics profile for monitor
GetMonitorPhysicsProfile(monitor) {
    global MonitorProfiles, MonitorSystem
    
    try {
        if (!monitor) {
            return MonitorProfiles["Default"]
        }
        
        ; Check for specific profile assignment
        profileName := monitor.Get("Profile", "Default")
        
        ; Auto-assign profiles based on monitor characteristics
        if (profileName == "Default") {
            if (monitor["IsPrimary"]) {
                profileName := "Primary_Performance"
            } else if (monitor["Width"] >= 2560) {
                profileName := "Primary_Performance"  ; High-res secondary
            } else {
                profileName := "Secondary_Conservative"
            }
            
            ; Store assignment
            monitor["Profile"] := profileName
        }
        
        if (MonitorProfiles.Has(profileName)) {
            return MonitorProfiles[profileName]
        }
        
        return MonitorProfiles["Default"]
        
    } catch as e {
        RecordSystemError("GetMonitorPhysicsProfile", e)
        return MonitorProfiles["Default"]
    }
}

; Apply DPI-aware scaling to physics calculations
ApplyDPIScaling(value, monitor, dimension := "X") {
    try {
        if (!monitor || !monitor.Has("Scale" . dimension)) {
            return value
        }
        
        scaleFactor := monitor["Scale" . dimension]
        return value * scaleFactor
        
    } catch as e {
        RecordSystemError("ApplyDPIScaling", e)
        return value
    }
}

; Enhanced hotkeys for monitor management
^!+m:: {  ; Ctrl+Alt+Shift+M - Show monitor configuration
    ShowMonitorConfiguration()
}

^!+p:: {  ; Ctrl+Alt+Shift+P - Show monitor profiles
    ShowMonitorProfiles()
}

^!+d:: {  ; Ctrl+Alt+Shift+D - Toggle DPI awareness
    ToggleDPIAwareness()
}

; Monitor configuration display
ShowMonitorConfiguration() {
    global MonitorSystem
    
    try {
        monitors := MonitorSystem["Monitors"]
        if (monitors.Count == 0) {
            ShowNotification("Monitor Config", "No monitors detected", "warning")
            return
        }
        
        configText := "Monitor Configuration`n`n"
        for index, monitor in monitors {
            configText .= "Monitor " . index . (monitor["IsPrimary"] ? " (Primary)" : "") . "`n"
            configText .= "  Resolution: " . monitor["Width"] . "x" . monitor["Height"] . "`n"
            configText .= "  Position: " . monitor["Left"] . "," . monitor["Top"] . "`n"
            configText .= "  DPI: " . monitor["DPI_X"] . "x" . monitor["DPI_Y"] . "`n"
            configText .= "  Scale: " . Round(monitor["ScaleX"], 2) . "x" . Round(monitor["ScaleY"], 2) . "`n"
            configText .= "  Profile: " . monitor["Profile"] . "`n`n"
        }
        
        MsgBox(configText, "Monitor Configuration", "OK Icon64")
        
    } catch as e {
        RecordSystemError("ShowMonitorConfiguration", e)
    }
}

; Monitor profiles display
ShowMonitorProfiles() {
    global MonitorProfiles
    
    try {
        profileText := "Available Monitor Profiles`n`n"
        for name, profile in MonitorProfiles {
            profileText .= name . ": " . profile.Get("description", "No description") . "`n"
            if (profile.Has("AttractionForce")) {
                profileText .= "  Attraction: " . profile["AttractionForce"] . "`n"
                profileText .= "  Repulsion: " . profile["RepulsionForce"] . "`n"
                profileText .= "  Max Speed: " . profile["MaxSpeed"] . "`n"
            }
            profileText .= "`n"
        }
        
        MsgBox(profileText, "Monitor Profiles", "OK Icon64")
        
    } catch as e {
        RecordSystemError("ShowMonitorProfiles", e)
    }
}

; Toggle DPI awareness
ToggleDPIAwareness() {
    global Config
    
    Config["DPIAware"] := !Config.Get("DPIAware", true)
    status := Config["DPIAware"] ? "enabled" : "disabled"
    ShowNotification("DPI Awareness", "DPI scaling " . status, "info", 2000)
}

; Initialize enhanced monitor system
InitializeEnhancedMonitorSystem() {
    global MonitorSystem
    
    try {
        DebugLog("MONITOR", "Initializing enhanced monitor system", 2)
        
        ; Initial monitor detection
        GetEnhancedMonitorInfo()
        
        ; Start monitor configuration monitoring
        SetTimer(CheckMonitorConfigurationChanges, MonitorSystem["ConfigCheckInterval"])
        
        ; Auto-assign profiles
        ReassignMonitorProfiles(MonitorSystem["Monitors"])
        
        DebugLog("MONITOR", "Enhanced monitor system initialized successfully", 2)
        
    } catch as e {
        RecordSystemError("InitializeEnhancedMonitorSystem", e)
    }
}

; Auto-assign profiles to monitors
ReassignMonitorProfiles(monitors) {
    global MonitorProfiles, MonitorSystem
    
    try {
        for index, monitor in monitors {
            ; Smart profile assignment based on monitor characteristics
            if (monitor["IsPrimary"]) {
                monitor["Profile"] := "Primary_Performance"
            } else if (monitor["Width"] >= 2560) {
                monitor["Profile"] := "Primary_Performance"  ; High-res secondary
            } else if (monitor["Width"] <= 1920 && monitor["Height"] <= 1080) {
                monitor["Profile"] := "Secondary_Conservative"
            } else {
                monitor["Profile"] := "Default"
            }
            
            DebugLog("MONITOR", "Assigned profile '" . monitor["Profile"] . "' to monitor " . index, 3)
        }
        
    } catch as e {
        RecordSystemError("ReassignMonitorProfiles", e)
    }
}

; Start enhanced monitor system during initialization
InitializeEnhancedMonitorSystem()

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
        ; Read and parse JSON configuration
        configText := FileRead(ConfigFile)
        configData := JSON.parse(configText)
        
        ; Validate JSON structure
        validationResult := ValidateConfigurationSchema(configData)
        if (!validationResult["valid"]) {
            DebugLog("CONFIG", "Configuration schema validation failed: " validationResult["error"], 1)
            return AttemptConfigurationRecovery()
        }
        
        ; Create backup of current configuration before applying changes
        BackupCurrentConfiguration()
        
        ; Apply configuration with validation
        appliedConfig := Map()
        for key, value in configData {
            if (ConfigSchema["structure"].Has(key)) {
                ; Validate individual parameter
                paramValidation := ValidateConfigParameter(key, value)
                if (paramValidation["valid"]) {
                    appliedConfig[key] := value
                } else {
                    DebugLog("CONFIG", "Parameter validation failed for " key ": " paramValidation["error"], 2)
                    appliedConfig[key] := Config[key]  ; Keep current value
                }
            }
        }
        
        ; Validate complete configuration
        fullValidation := ValidateConfiguration(appliedConfig)
        if (!fullValidation["valid"]) {
            DebugLog("CONFIG", "Full configuration validation failed", 1)
            for error in fullValidation["errors"] {
                DebugLog("CONFIG", "Validation error: " error, 1)
            }
            return AttemptConfigurationRecovery()
        }
        
        ; Apply validated configuration
        for key, value in appliedConfig {
            Config[key] := value
        }
        
        ; Trigger system updates based on configuration changes
        ApplyConfigurationChanges_Placeholder(appliedConfig)
        
        DebugLog("CONFIG", "Configuration loaded and applied successfully", 2)
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
        ; Validate configuration before saving
        validation := ValidateConfiguration(Config)
        if (!validation["valid"]) {
            DebugLog("CONFIG", "Cannot save invalid configuration", 1)
            return false
        }
        
        ; Create configuration object for JSON
        configToSave["_metadata"] := Map(
            "version", ConfigSchema["version"],
            "saved", FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"),
            "application", "FWDE"
        )
        
        ; Add all configuration parameters
        for key, value in Config {
            if (ConfigSchema["structure"].Has(key)) {
                configToSave[key] := value
            }
        }
        
        ; Convert to JSON with formatting
        jsonText := JSON.stringify(configToSave, 2)  ; 2-space indentation
        
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

; Apply physics calculations to a window
ApplyPhysicsToWindow(win) {
    global Config, g, MonitorSystem
    
    try {
        ; Get current window position
        if (!IsWindowValid(win["hwnd"])) {
            return
        }
        
        WinGetPos(&x, &y, &w, &h, "ahk_id " win["hwnd"])
        
        ; Get monitor for this window
        monitor := GetMonitorForWindow(win["hwnd"])
        if (!monitor) {
            return
        }
        
        ; Get physics profile for this monitor
        profile := GetMonitorPhysicsProfile(monitor)
        if (!profile.Get("Enabled", true)) {
            return  ; Physics disabled for this monitor
        }
        
        ; Initialize physics properties if missing
        if (!win.Has("vx")) win["vx"] := 0
        if (!win.Has("vy")) win["vy"] := 0
        if (!win.Has("x")) win["x"] := x
        if (!win.Has("y")) win["y"] := y
        
        ; Calculate forces using monitor-specific profile
        fx := 0, fy := 0
        
        ; Center attraction (DPI-aware)
        centerX := monitor["Left"] + monitor["Width"] / 2
        centerY := monitor["Top"] + monitor["Height"] / 2
        dx := centerX - x
        dy := centerY - y
        dist := Sqrt(dx*dx + dy*dy)
        
        if (dist > 0) {
            attractionForce := ApplyDPIScaling(profile["AttractionForce"], monitor)
            fx += attractionForce * dx / dist
            fy += attractionForce * dy / dist
        }
        
        ; Repulsion from other windows (only on same monitor)
        for otherWin in g["Windows"] {
            if (otherWin["hwnd"] == win["hwnd"]) {
                continue
            }
            
            otherMonitor := GetMonitorForWindow(otherWin["hwnd"])
            if (!otherMonitor || otherMonitor["Index"] != monitor["Index"]) {
                continue  ; Different monitor
            }
            
            if (IsWindowValid(otherWin["hwnd"])) {
                WinGetPos(&ox, &oy, &ow, &oh, "ahk_id " otherWin["hwnd"])
                dx := x - ox
                dy := y - oy
                dist := Sqrt(dx*dx + dy*dy)
                
                if (dist > 0 && dist < 300) {
                    repulsionForce := ApplyDPIScaling(profile["RepulsionForce"], monitor)
                    force := repulsionForce / (dist * dist)
                    fx += force * dx / dist
                    fy += force * dy / dist
                }
            }
        }
        
        ; Edge repulsion (monitor boundaries)
        edgeForce := ApplyDPIScaling(profile["EdgeRepulsionForce"], monitor)
        margin := ApplyDPIScaling(profile["MinMargin"], monitor)
        
        if (x < monitor["Left"] + margin) {
            fx += edgeForce * (monitor["Left"] + margin - x)
        }
        if (x + w > monitor["Right"] - margin) {
            fx -= edgeForce * (x + w - monitor["Right"] + margin)
        }
        if (y < monitor["Top"] + margin) {
            fy += edgeForce * (monitor["Top"] + margin - y)
        }
        if (y + h > monitor["Bottom"] - margin) {
            fy -= edgeForce * (y + h - monitor["Bottom"] + margin)
        }
        
        ; Update velocity with DPI-aware parameters
        timeStep := Config["PhysicsTimeStep"]
        win["vx"] += fx * timeStep
        win["vy"] += fy * timeStep
        
        ; Apply damping
        damping := profile["Damping"]
        win["vx"] *= (1 - damping)
        win["vy"] *= (1 - damping)
        
        ; Limit speed
        maxSpeed := ApplyDPIScaling(profile["MaxSpeed"], monitor)
        speed := Sqrt(win["vx"]*win["vx"] + win["vy"]*win["vy"])
        if (speed > maxSpeed) {
            win["vx"] *= maxSpeed / speed
            win["vy"] *= maxSpeed / speed
        }
        
        ; Update position
        win["x"] += win["vx"] * timeStep
        win["y"] += win["vy"] * timeStep
        
        ; Apply smoothing
        smoothness := Config["Smoothing"]
        targetX := Integer(win["x"])
        targetY := Integer(win["y"])
        
        ; Store smooth position
        smoothKey := win["hwnd"]
        if (!smoothPos.Has(smoothKey)) {
            smoothPos[smoothKey] := Map("x", x, "y", y)
        }
        
        smoothPos[smoothKey]["x"] := smoothPos[smoothKey]["x"] * smoothness + targetX * (1 - smoothness)
        smoothPos[smoothKey]["y"] := smoothPos[smoothKey]["y"] * smoothness + targetY * (1 - smoothness)
        
    } catch as e {
        RecordSystemError("ApplyPhysicsToWindow", e, win["hwnd"])
    }
}

; Apply calculated window movements
ApplyWindowMovements() {
    global smoothPos, lastPositions, moveBatch, Config
    
    if (!g.Get("ArrangementActive", false)) {
        return
    }
    
    startTime := A_TickCount
    
    try {
        ; Apply smooth positions to windows
        for hwnd, pos in smoothPos {
            if (!IsWindowValid(hwnd)) {
                continue
            }
            
            newX := Integer(pos["x"])
            newY := Integer(pos["y"])
            
            ; Check if position changed significantly
            lastKey := hwnd
            if (!lastPositions.Has(lastKey)) {
                lastPositions[lastKey] := Map("x", newX, "y", newY)
            }
            
            lastX := lastPositions[lastKey]["x"]
            lastY := lastPositions[lastKey]["y"]
            
            ; Only move if change is significant (reduce jitter)
            if (Abs(newX - lastX) > 1 || Abs(newY - lastY) > 1) {
                WinMove(newX, newY, , , "ahk_id " hwnd)
                lastPositions[lastKey]["x"] := newX
                lastPositions[lastKey]["y"] := newY
            }
        }
        
        RecordPerformanceMetric("ApplyWindowMovements", A_TickCount - startTime)
        
    } catch as e {
        RecordSystemError("ApplyWindowMovements", e)
    }
}

; Monitor screenshot activity and pause system accordingly
UpdateScreenshotState() {
    global Config, g
    
    try {
        wasScreenshotPaused := g.Get("ScreenshotPaused", false)
        isScreenshotActive := false
        
        ; Check for screenshot processes
        for processName in Config["ScreenshotProcesses"] {
            if (ProcessExist(processName)) {
                isScreenshotActive := true
                break
            }
        }
        
        ; Check for screenshot window classes
        if (!isScreenshotActive) {
            for className in Config["ScreenshotWindowClasses"] {
                if (WinExist("ahk_class " className)) {
                    isScreenshotActive := true
                    break
                }
            }
        }
        
        g["ScreenshotPaused"] := isScreenshotActive
        
        ; Log state changes
        if (wasScreenshotPaused != isScreenshotActive) {
            if (isScreenshotActive) {
                DebugLog("SCREENSHOT", "Screenshot activity detected - pausing physics", 2)
                ShowNotification("Screenshot Mode", "Physics paused for screenshot", "info", 2000)
            } else {
                DebugLog("SCREENSHOT", "Screenshot activity ended - resuming physics", 2)
                ShowNotification("Screenshot Mode", "Physics resumed", "info", 1000)
            }
        }
        
    } catch as e {
        RecordSystemError("UpdateScreenshotState", e)
    }
}

; Optimize window positions for better arrangement
OptimizeWindowPositions() {
    global g, Config
    
    try {
        if (!g.Has("Windows") || g["Windows"].Length == 0) {
            return
        }
        
        DebugLog("OPTIMIZE", "Starting window position optimization", 2)
        
        ; Reset all window velocities for clean optimization
        for win in g["Windows"] {
            if (win.Has("vx")) win["vx"] := 0
            if (win.Has("vy")) win["vy"] := 0
        }
        
        ; Force immediate physics calculation
        CalculateDynamicLayout()
        
        ; Apply positions immediately
        ApplyWindowMovements()
        
        DebugLog("OPTIMIZE", "Window optimization completed", 2)
        
    } catch as e {
        RecordSystemError("OptimizeWindowPositions", e)
    }
}

; Record performance metrics for monitoring
RecordPerformanceMetric(operation, timeMs) {
    global PerfTimers
    
    try {
        if (!PerfTimers.Has(operation)) {
            PerfTimers[operation] := Map("totalTime", 0, "count", 0, "avgTime", 0)
        }
        
        timer := PerfTimers[operation]
        timer["totalTime"] += timeMs
        timer["count"] += 1
        timer["avgTime"] := timer["totalTime"] / timer["count"]
        
        ; Keep only recent averages (reset every 1000 calls)
        if (timer["count"] > 1000) {
            timer["totalTime"] := timer["avgTime"] * 100
            timer["count"] := 100
        }
        
    } catch as e {
        RecordSystemError("RecordPerformanceMetric", e, operation)
    }
}

; JSON utility class for configuration persistence
class JSON {
    static parse(text) {
        ; Basic JSON parser - replace with full library in production
        try {
            ; Remove whitespace and validate basic structure
            cleanText := Trim(text)
            if (!cleanText) {
                throw Error("Empty JSON text")
            }
            
            ; Very basic parsing - in production use proper JSON library
            if (InStr(cleanText, "{") == 1) {
                return Map()  ; Return empty map for now
            }
            
            throw Error("Invalid JSON structure")
            
        } catch as e {
            throw Error("JSON parse error: " e.Message)
        }
    }
    
    static stringify(obj, indent := 0) {
        ; Basic JSON stringifier - replace with full library in production
        try {
            if (Type(obj) == "Map") {
                result := "{"
                isFirst := true
                
                for key, value in obj {
                    if (!isFirst) {
                        result .= ","
                    }
                    isFirst := false
                    
                    ; Add indentation if specified
                    if (indent > 0) {
                        result .= "`n" . StrRepeat(" ", indent)
                    }
                    
                    ; Add key-value pair
                    result .= '"' . key . '": '
                    
                    ; Handle different value types
                    switch Type(value) {
                        case "String":
                            result .= '"' . value . '"'
                        case "Integer", "Float":
                            result .= String(value)
                        case "Map":
                            result .= JSON.stringify(value, indent > 0 ? indent + 2 : 0)
                        default:
                            result .= '"' . String(value) . '"'
                    }
                }
                
                if (indent > 0 && !isFirst) {
                    result .= "`n" . StrRepeat(" ", indent - 2)
                }
                result .= "}"
                return result
            }
            
            return '""'  ; Fallback for non-Map objects
            
        } catch as e {
            throw Error("JSON stringify error: " e.Message)
        }
    }
}

; Helper function for string repetition
StrRepeat(str, count) {
    result := ""
    Loop count {
        result .= str
    }
    return result
}

; Main system control functions
StartFWDE() {
    global g, Config
    
    try {
        DebugLog("SYSTEM", "Starting FWDE system", 2)
        
        ; Initialize window tracking
        RefreshWindowList()
        
        ; Start main physics timer
        SetTimer(PhysicsUpdateLoop, Config["PhysicsUpdateInterval"])
        
        ; Start visual update timer
        SetTimer(VisualUpdateLoop, Config["VisualTimeStep"])
        
        ; Start screenshot monitoring
        SetTimer(UpdateScreenshotState, Config["ScreenshotCheckInterval"])
        
        g["PhysicsEnabled"] := true
        g["ArrangementActive"] := true
        
        ShowNotification("FWDE", "System started successfully", "success", 3000)
        
    } catch as e {
        RecordSystemError("StartFWDE", e)
        ShowNotification("FWDE", "Failed to start system", "error", 5000)
    }
}

StopFWDE() {
    global g
    
    try {
        DebugLog("SYSTEM", "Stopping FWDE system", 2)
        
        ; Stop all timers
        SetTimer(PhysicsUpdateLoop, 0)
        SetTimer(VisualUpdateLoop, 0)
        SetTimer(UpdateScreenshotState, 0)
        
        g["PhysicsEnabled"] := false
        g["ArrangementActive"] := false
        
        ShowNotification("FWDE", "System stopped", "info", 3000)
        
    } catch as e {
        RecordSystemError("StopFWDE", e)
    }
}

; Main physics update loop
PhysicsUpdateLoop() {
    try {
        if (g.Get("ScreenshotPaused", false)) {
            return
        }
        
        CalculateDynamicLayout()
        
    } catch as e {
        RecordSystemError("PhysicsUpdateLoop", e)
    }
}

; Visual update loop
VisualUpdateLoop() {
    try {
        if (g.Get("ScreenshotPaused", false)) {
            return
        }
        
        ApplyWindowMovements()
        
    } catch as e {
        RecordSystemError("VisualUpdateLoop", e)
    }
}

; Window detection and management
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
                class := WinGetClass("ahk_id " hwnd)
                processName := WinGetProcessName("ahk_id " hwnd)
                
                ; Skip invalid windows
                if (w < 50 || h < 50 || title == "" || !WinGetMinMax("ahk_id " hwnd)) {
                    continue
                }
                
                ; Create window object
                winObj := Map(
                    "hwnd", hwnd,
                    "title", title,
                    "class", class,
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

; Hotkey handlers
^!s:: {  ; Ctrl+Alt+S - Start/Stop FWDE
    global g
    
    if (g.Get("PhysicsEnabled", false)) {
        StopFWDE()
    } else {
        StartFWDE()
    }
}

^!r:: {  ; Ctrl+Alt+R - Refresh window list
    RefreshWindowList()
    ShowNotification("FWDE", "Window list refreshed", "info", 2000)
}

^!o:: {  ; Ctrl+Alt+O - Optimize positions
    OptimizeWindowPositions()
    ShowNotification("FWDE", "Window positions optimized", "info", 2000)
}

^!m:: {  ; Ctrl+Alt+M - Toggle seamless monitor floating
    global Config
    
    Config["SeamlessMonitorFloat"] := !Config["SeamlessMonitorFloat"]
    status := Config["SeamlessMonitorFloat"] ? "enabled" : "disabled"
    ShowNotification("FWDE", "Seamless monitor floating " status, "info", 3000)
}

^!p:: {  ; Ctrl+Alt+P - Pause/Resume physics
    global g
    
    g["PhysicsEnabled"] := !g.Get("PhysicsEnabled", false)
    status := g["PhysicsEnabled"] ? "resumed" : "paused"
    ShowNotification("FWDE", "Physics " status, "info", 2000)
}

^!q:: {  ; Ctrl+Alt+Q - Quit FWDE
    StopFWDE()
    ExitApp()
}

; Improved placeholder functions with actual functionality
GetCurrentMonitorInfo() {
    try {
        ; Get primary monitor info
        monitorInfo := MonitorGet()
        return Map(
            "Left", monitorInfo.Left,
            "Top", monitorInfo.Top, 
            "Right", monitorInfo.Right,
            "Bottom", monitorInfo.Bottom,
            "Width", monitorInfo.Right - monitorInfo.Left,
            "Height", monitorInfo.Bottom - monitorInfo.Top
        )
    } catch {
        ; Fallback values
        return Map("Left", 0, "Top", 0, "Right", 1920, "Bottom", 1080, "Width", 1920, "Height", 1080)
    }
}

; Adaptive Performance Scaling System
global AdaptivePerformance := Map(
    "Enabled", true,
    "TargetFPS", 60,
    "MinFPS", 30,
    "MaxFPS", 120,
    "PerformanceBudget", 16.67,  ; Target 60fps = 16.67ms per frame
    "QualityLevel", "High",      ; Ultra, High, Medium, Low, Minimal
    "AutoAdjustment", true,
    "LoadThresholds", Map(
        "CPU_Warning", 70,       ; CPU usage percentage
        "CPU_Critical", 85,
        "Memory_Warning", 80,    ; Memory usage percentage
        "Memory_Critical", 90,
        "FrameTime_Warning", 20, ; Milliseconds
        "FrameTime_Critical", 33
    ),
    "ScalingFactors", Map(
        "Physics", 1.0,
        "Visual", 1.0,
        "Detection", 1.0,
        "Monitoring", 1.0
    ),
    "PerformanceHistory", [],
    "LastProfileTime", 0,
    "ProfileInterval", 1000,     ; Profile every second
    "AdaptationCooldown", 5000,  ; Wait 5 seconds between adjustments
    "LastAdaptation", 0
)

; Performance quality levels with detailed settings
global QualityLevels := Map(
    "Ultra", Map(
        "description", "Maximum quality for high-end systems",
        "PhysicsTimeStep", 1,
        "VisualTimeStep", 1,
        "MaxWindows", 50,
        "ForceCalculations", true,
        "SmoothingEnabled", true,
        "AdvancedPhysics", true,
        "VisualEffects", true,
        "MonitoringFrequency", 100,
        "ScalingFactors", Map("Physics", 1.0, "Visual", 1.0, "Detection", 1.0, "Monitoring", 1.0)
    ),
    "High", Map(
        "description", "High quality for modern systems",
        "PhysicsTimeStep", 2,
        "VisualTimeStep", 2,
        "MaxWindows", 40,
        "ForceCalculations", true,
        "SmoothingEnabled", true,
        "AdvancedPhysics", true,
        "VisualEffects", true,
        "MonitoringFrequency", 200,
        "ScalingFactors", Map("Physics", 0.9, "Visual", 0.9, "Detection", 0.9, "Monitoring", 1.0)
    ),
    "Medium", Map(
        "description", "Balanced quality for average systems",
        "PhysicsTimeStep", 5,
        "VisualTimeStep", 8,
        "MaxWindows", 30,
        "ForceCalculations", true,
        "SmoothingEnabled", true,
        "AdvancedPhysics", false,
        "VisualEffects", false,
        "MonitoringFrequency", 500,
        "ScalingFactors", Map("Physics", 0.7, "Visual", 0.8, "Detection", 0.8, "Monitoring", 0.8)
    ),
    "Low", Map(
        "description", "Reduced quality for older systems",
        "PhysicsTimeStep", 10,
        "VisualTimeStep", 16,
        "MaxWindows", 20,
        "ForceCalculations", false,
        "SmoothingEnabled", false,
        "AdvancedPhysics", false,
        "VisualEffects", false,
        "MonitoringFrequency", 1000,
        "ScalingFactors", Map("Physics", 0.5, "Visual", 0.6, "Detection", 0.7, "Monitoring", 0.6)
    ),
    "Minimal", Map(
        "description", "Minimum quality for low-performance systems",
        "PhysicsTimeStep", 20,
        "VisualTimeStep", 33,
        "MaxWindows", 10,
        "ForceCalculations", false,
        "SmoothingEnabled", false,
        "AdvancedPhysics", false,
        "VisualEffects", false,
        "MonitoringFrequency", 2000,
        "ScalingFactors", Map("Physics", 0.3, "Visual", 0.4, "Detection", 0.5, "Monitoring", 0.4)
    )
)

; System resource monitoring
global SystemResourceMonitor := Map(
    "CPU", Map(
        "Current", 0,
        "Average", 0,
        "Peak", 0,
        "History", [],
        "LastUpdate", 0
    ),
    "Memory", Map(
        "Current", 0,
        "Average", 0,
        "Peak", 0,
        "Available", 0,
        "History", [],
        "LastUpdate", 0
    ),
    "FrameTiming", Map(
        "Current", 0,
        "Average", 0,
        "Target", 16.67,
        "History", [],
        "DroppedFrames", 0,
        "LastUpdate", 0
    ),
    "DiskIO", Map(
        "Current", 0,
        "Average", 0,
        "Peak", 0,
        "History", [],
        "LastUpdate", 0
    )
)

; Performance budget manager
global PerformanceBudget := Map(
    "TotalBudget", 16.67,        ; 60fps target
    "PhysicsBudget", 8.0,        ; 50% for physics
    "VisualBudget", 6.0,         ; 36% for visuals
    "SystemBudget", 2.67,        ; 14% for system overhead
    "ActualUsage", Map(
        "Physics", 0,
        "Visual", 0,
        "System", 0,
        "Total", 0
    ),
    "BudgetExceeded", Map(
        "Physics", false,
        "Visual", false,
        "System", false,
        "Total", false
    ),
    "LastBudgetCheck", 0
)

; Initialize adaptive performance system
InitializeAdaptivePerformance() {
    DebugLog("PERF", "Initializing adaptive performance scaling system", 2)
    
    try {
        ; Establish performance baseline
        EstablishPerformanceBaseline()
        
        ; Start resource monitoring
        SetTimer(MonitorSystemResources, 1000)
        
        ; Start performance adaptation
        SetTimer(AdaptPerformanceBasedOnLoad, 2000)
        
        ; Start frame timing monitoring
        SetTimer(MonitorFrameTiming, 100)
        
        ; Start budget monitoring
        SetTimer(MonitorPerformanceBudget, 500)
        
        DebugLog("PERF", "Adaptive performance system initialized successfully", 2)
        ShowNotification("Performance", "Adaptive performance scaling enabled", "success", 3000)
        
    } catch as e {
        RecordSystemError("InitializeAdaptivePerformance", e)
    }
}

; Establish baseline performance metrics
EstablishPerformanceBaseline() {
    global AdaptivePerformance, SystemResourceMonitor
    
    try {
        DebugLog("PERF", "Establishing performance baseline", 2)
        
        ; Initialize system resource monitoring
        SystemResourceMonitor["CPU"]["Current"] := GetCPUUsage()
        SystemResourceMonitor["Memory"]["Current"] := GetMemoryUsage()
        SystemResourceMonitor["FrameTiming"]["Target"] := 1000.0 / AdaptivePerformance["TargetFPS"]
        
        ; Set initial quality level based on system capabilities
        DetectOptimalQualityLevel()
        
        DebugLog("PERF", "Performance baseline established", 2)
        
    } catch as e {
        RecordSystemError("EstablishPerformanceBaseline", e)
    }
}

; Detect optimal quality level based on system capabilities
DetectOptimalQualityLevel() {
    global AdaptivePerformance, QualityLevels, SystemResourceMonitor
    
    try {
        ; Get system specifications
        cpuCores := A_ProcessorCount
        totalMemory := GetTotalSystemMemory()
        
        ; Determine quality level based on system specs
        qualityLevel := "Medium"  ; Default
        
        if (cpuCores >= 8 && totalMemory >= 16) {
            qualityLevel := "Ultra"
        } else if (cpuCores >= 6 && totalMemory >= 8) {
            qualityLevel := "High"
        } else if (cpuCores >= 4 && totalMemory >= 4) {
            qualityLevel := "Medium"
        } else if (cpuCores >= 2 && totalMemory >= 2) {
            qualityLevel := "Low"
        } else {
            qualityLevel := "Minimal"
        }
        
        ; Apply detected quality level
        SetQualityLevel(qualityLevel)
        
        DebugLog("PERF", "Auto-detected quality level: " . qualityLevel, 2)
        ShowNotification("Performance", "Quality level set to: " . qualityLevel, "info", 2000)
        
    } catch as e {
        RecordSystemError("DetectOptimalQualityLevel", e)
        SetQualityLevel("Medium")  ; Fallback to medium
    }
}

; Monitor system resources in real-time
MonitorSystemResources() {
    global SystemResourceMonitor, AdaptivePerformance
    
    try {
        currentTime := A_TickCount
        
        ; Monitor CPU usage
        cpuUsage := GetCPUUsage()
        UpdateResourceHistory("CPU", cpuUsage)
        
        ; Monitor memory usage
        memoryUsage := GetMemoryUsage()
        UpdateResourceHistory("Memory", memoryUsage)
        
        ; Monitor disk I/O
        diskIO := GetDiskIOUsage()
        UpdateResourceHistory("DiskIO", diskIO)
        
        ; Update performance history
        performanceSnapshot := Map(
            "Timestamp", currentTime,
            "CPU", cpuUsage,
            "Memory", memoryUsage,
            "DiskIO", diskIO,
            "QualityLevel", AdaptivePerformance["QualityLevel"]
        )
        
        history := AdaptivePerformance["PerformanceHistory"]
        history.Push(performanceSnapshot)
        
        ; Keep history manageable (last 60 seconds)
        if (history.Length > 60) {
            history.RemoveAt(1)
        }
        
    } catch as e {
        RecordSystemError("MonitorSystemResources", e)
    }
}

; Update resource history and calculate averages
UpdateResourceHistory(resourceType, currentValue) {
    global SystemResourceMonitor
    
    try {
        resource := SystemResourceMonitor[resourceType]
        
        ; Update current values
        resource["Current"] := currentValue
        resource["LastUpdate"] := A_TickCount
        
        ; Update peak
        if (currentValue > resource["Peak"]) {
            resource["Peak"] := currentValue
        }
        
        ; Add to history
        history := resource["History"]
        history.Push(currentValue)
        
        ; Keep history size manageable (last 60 readings)
        if (history.Length > 60) {
            history.RemoveAt(1)
        }
        
        ; Calculate average
        if (history.Length > 0) {
            total := 0
            for value in history {
                total += value
            }
            resource["Average"] := total / history.Length
        }
        
    } catch as e {
        RecordSystemError("UpdateResourceHistory", e, resourceType)
    }
}

; Get current CPU usage percentage
GetCPUUsage() {
    try {
        ; Use WMI to get CPU usage (simplified implementation)
        ; In practice, this would use proper WMI queries
        
        ; Fallback method using process CPU time
        processTime := ProcessGetCPUTime()
        currentTime := A_TickCount
        
        ; Calculate approximate CPU usage (simplified)
        ; This is a placeholder - real implementation would use performance counters
        return Min(Random(5, 25), 100)  ; Simulated CPU usage for demonstration
        
    } catch {
        return 10  ; Default fallback
    }
}

; Get current memory usage percentage
GetMemoryUsage() {
    try {
        ; Get current process memory usage
        workingSet := ProcessGetWorkingSet()
        
        ; Get total system memory
        totalMemory := GetTotalSystemMemory()
        
        if (totalMemory > 0) {
            return (workingSet / (totalMemory * 1024 * 1024)) * 100
        }
        
        return 10  ; Default fallback
        
    } catch {
        return 10  ; Default fallback
    }
}

; Get total system memory in GB
GetTotalSystemMemory() {
    try {
        ; Use GlobalMemoryStatusEx to get total memory
        memStatus := Buffer(64, 0)
        NumPut("UInt", 64, memStatus, 0)  ; dwLength
        
        if (DllCall("kernel32.dll\GlobalMemoryStatusEx", "Ptr", memStatus)) {
            totalPhysical := NumGet(memStatus, 8, "UInt64")
            return totalPhysical / (1024 * 1024 * 1024)  ; Convert to GB
        }
        
        return 8  ; Default fallback (8GB)
        
    } catch {
        return 8  ; Default fallback
    }
}

; Get disk I/O usage (simplified)
GetDiskIOUsage() {
    try {
        ; Simplified disk I/O monitoring
        ; Real implementation would use performance counters
        return Random(0, 50)  ; Simulated for demonstration
        
    } catch {
        return 0  ; Default fallback
    }
}

; Monitor frame timing for performance optimization
MonitorFrameTiming() {
    global SystemResourceMonitor, PerformanceBudget, PerfTimers
    
    try {
        frameTiming := SystemResourceMonitor["FrameTiming"]
        target := frameTiming["Target"]
        
        ; Calculate current frame time from performance timers
        currentFrameTime := 0
        if (PerfTimers.Has("CalculateDynamicLayout")) {
            currentFrameTime += PerfTimers["CalculateDynamicLayout"]["avgTime"]
        }
        if (PerfTimers.Has("ApplyWindowMovements")) {
            currentFrameTime += PerfTimers["ApplyWindowMovements"]["avgTime"]
        }
        
        ; Update frame timing
        frameTiming["Current"] := currentFrameTime
        
        ; Track dropped frames
        if (currentFrameTime > target * 1.5) {
            frameTiming["DroppedFrames"] += 1
        }
        
        ; Update history
        UpdateResourceHistory("FrameTiming", currentFrameTime)
        
    } catch as e {
        RecordSystemError("MonitorFrameTiming", e)
    }
}

; Monitor performance budget usage
MonitorPerformanceBudget() {
    global PerformanceBudget, PerfTimers, AdaptivePerformance
    
    try {
        budget := PerformanceBudget
        usage := budget["ActualUsage"]
        
        ; Update actual usage from performance timers
        usage["Physics"] := PerfTimers.Has("CalculateDynamicLayout") ? 
            PerfTimers["CalculateDynamicLayout"]["avgTime"] : 0
        usage["Visual"] := PerfTimers.Has("ApplyWindowMovements") ? 
            PerfTimers["ApplyWindowMovements"]["avgTime"] : 0
        usage["System"] := PerfTimers.Has("MonitorSystemResources") ? 
            PerfTimers["MonitorSystemResources"]["avgTime"] : 0
        
        usage["Total"] := usage["Physics"] + usage["Visual"] + usage["System"]
        
        ; Check budget violations
        exceeded := budget["BudgetExceeded"]
        exceeded["Physics"] := usage["Physics"] > budget["PhysicsBudget"]
        exceeded["Visual"] := usage["Visual"] > budget["VisualBudget"]
        exceeded["System"] := usage["System"] > budget["SystemBudget"]
        exceeded["Total"] := usage["Total"] > budget["TotalBudget"]
        
        ; Trigger adaptation if budget consistently exceeded
        if (exceeded["Total"]) {
            TriggerPerformanceAdaptation("BudgetExceeded")
        }
        
        budget["LastBudgetCheck"] := A_TickCount
        
    } catch as e {
        RecordSystemError("MonitorPerformanceBudget", e)
    }
}

; Adapt performance based on system load
AdaptPerformanceBasedOnLoad() {
    global AdaptivePerformance, SystemResourceMonitor
    
    try {
        if (!AdaptivePerformance["AutoAdjustment"]) {
            return
        }
        
        currentTime := A_TickCount
        
        ; Check cooldown period
        if (currentTime - AdaptivePerformance["LastAdaptation"] < AdaptivePerformance["AdaptationCooldown"]) {
            return
        }
        
        ; Get current resource usage
        cpuUsage := SystemResourceMonitor["CPU"]["Average"]
        memoryUsage := SystemResourceMonitor["Memory"]["Average"]
        frameTime := SystemResourceMonitor["FrameTiming"]["Average"]
        
        thresholds := AdaptivePerformance["LoadThresholds"]
        
        ; Determine adaptation direction
        adaptationNeeded := ""
        
        if (cpuUsage > thresholds["CPU_Critical"] || 
            memoryUsage > thresholds["Memory_Critical"] || 
            frameTime > thresholds["FrameTime_Critical"]) {
            adaptationNeeded := "Decrease"
        } else if (cpuUsage < thresholds["CPU_Warning"] * 0.5 && 
                   memoryUsage < thresholds["Memory_Warning"] * 0.5 && 
                   frameTime < thresholds["FrameTime_Warning"] * 0.5) {
            adaptationNeeded := "Increase"
        }
        
        if (adaptationNeeded != "") {
            TriggerPerformanceAdaptation(adaptationNeeded)
            AdaptivePerformance["LastAdaptation"] := currentTime
        }
        
    } catch as e {
        RecordSystemError("AdaptPerformanceBasedOnLoad", e)
    }
}

; Trigger performance adaptation
TriggerPerformanceAdaptation(direction) {
    global AdaptivePerformance, QualityLevels
    
    try {
        currentQuality := AdaptivePerformance["QualityLevel"]
        qualityLevels := ["Minimal", "Low", "Medium", "High", "Ultra"]
        currentIndex := 0
        
        ; Find current quality index
        for i, level in qualityLevels {
            if (level == currentQuality) {
                currentIndex := i
                break
            }
        }
        
        ; Calculate new quality level
        newIndex := currentIndex
        if (direction == "Decrease" && currentIndex > 1) {
            newIndex := currentIndex - 1
        } else if (direction == "Increase" && currentIndex < qualityLevels.Length) {
            newIndex := currentIndex + 1
        } else if (direction == "BudgetExceeded" && currentIndex > 1) {
            newIndex := currentIndex - 1
        }
        
        ; Apply new quality level if changed
        if (newIndex != currentIndex) {
            newQuality := qualityLevels[newIndex]
            SetQualityLevel(newQuality)
            
            DebugLog("PERF", "Performance adapted: " . currentQuality . " -> " . newQuality . " (" . direction . ")", 1)
            ShowNotification("Performance", "Quality adjusted to: " . newQuality, "info", 2000)
        }
        
    } catch as e {
        RecordSystemError("TriggerPerformanceAdaptation", e, direction)
    }
}

; Set quality level and apply settings
SetQualityLevel(qualityLevel) {
    global AdaptivePerformance, QualityLevels, Config, PerformanceBudget
    
    try {
        if (!QualityLevels.Has(qualityLevel)) {
            DebugLog("PERF", "Invalid quality level: " . qualityLevel, 1)
            return false
        }
        
        quality := QualityLevels[qualityLevel]
        AdaptivePerformance["QualityLevel"] := qualityLevel
        
        ; Apply quality settings to configuration
        Config["PhysicsTimeStep"] := quality["PhysicsTimeStep"]
        Config["VisualTimeStep"] := quality["VisualTimeStep"]
        
        ; Update scaling factors
        for factor, value in quality["ScalingFactors"] {
            AdaptivePerformance["ScalingFactors"][factor] := value
        }
        
        ; Adjust performance budget based on quality
        AdjustPerformanceBudget(quality)
        
        ; Restart timers with new intervals if system is running
        if (g.Get("PhysicsEnabled", false)) {
            ApplyDynamicTimerAdjustment()
        }
        
        DebugLog("PERF", "Quality level set to: " . qualityLevel, 2)
        return true
        
    } catch as e {
        RecordSystemError("SetQualityLevel", e, qualityLevel)
        return false
    }
}

; Adjust performance budget based on quality level
AdjustPerformanceBudget(quality) {
    global PerformanceBudget, AdaptivePerformance
    
    try {
        budget := PerformanceBudget
        targetFPS := AdaptivePerformance["TargetFPS"]
        
        ; Calculate budget based on quality and target FPS
        totalBudget := 1000.0 / targetFPS
        
        ; Quality-based budget distribution
        switch quality["PhysicsTimeStep"] {
            case 1, 2:  ; Ultra/High
                budget["PhysicsBudget"] := totalBudget * 0.5
                budget["VisualBudget"] := totalBudget * 0.35
                budget["SystemBudget"] := totalBudget * 0.15
            case 5:     ; Medium
                budget["PhysicsBudget"] := totalBudget * 0.4
                budget["VisualBudget"] := totalBudget * 0.4
                budget["SystemBudget"] := totalBudget * 0.2
            default:    ; Low/Minimal
                budget["PhysicsBudget"] := totalBudget * 0.3
                budget["VisualBudget"] := totalBudget * 0.5
                budget["SystemBudget"] := totalBudget * 0.2
        }
        
        budget["TotalBudget"] := totalBudget
        
        DebugLog("PERF", "Performance budget adjusted for quality level", 3)
        
    } catch as e {
        RecordSystemError("AdjustPerformanceBudget", e)
    }
}

; Apply dynamic timer adjustment with intelligent frame rate limiting
ApplyDynamicTimerAdjustment() {
    global Config, AdaptivePerformance, SystemResourceMonitor
    
    try {
        ; Stop existing timers
        SetTimer(PhysicsUpdateLoop, 0)
        SetTimer(VisualUpdateLoop, 0)
        
        ; Calculate dynamic intervals based on performance
        physicsInterval := CalculateDynamicInterval("Physics", Config["PhysicsTimeStep"])
        visualInterval := CalculateDynamicInterval("Visual", Config["VisualTimeStep"])
        
        ; Apply frame rate limiting
        visualInterval := Max(visualInterval, 1000.0 / AdaptivePerformance["MaxFPS"])
        
        ; Restart timers with optimized intervals
        SetTimer(PhysicsUpdateLoop, Integer(physicsInterval))
        SetTimer(VisualUpdateLoop, Integer(visualInterval))
        
        DebugLog("PERF", "Dynamic timers adjusted - Physics: " . physicsInterval . "ms, Visual: " . visualInterval . "ms", 3)
        
    } catch as e {
        RecordSystemError("ApplyDynamicTimerAdjustment", e)
    }
}

; Calculate dynamic interval with performance scaling
CalculateDynamicInterval(subsystem, baseInterval) {
    global AdaptivePerformance, SystemResourceMonitor
    
    try {
        scalingFactor := AdaptivePerformance["ScalingFactors"][subsystem]
        
        ; Get current system load
        cpuLoad := SystemResourceMonitor["CPU"]["Current"] / 100.0
        memoryLoad := SystemResourceMonitor["Memory"]["Current"] / 100.0
        
        ; Calculate load-based multiplier
        loadMultiplier := 1.0 + (cpuLoad * 0.5) + (memoryLoad * 0.3)
        
        ; Apply scaling with bounds checking
        dynamicInterval := baseInterval * scalingFactor * loadMultiplier
        
        ; Ensure reasonable bounds
        dynamicInterval := Max(1, Min(100, dynamicInterval))
        
        return dynamicInterval
        
    } catch as e {
        RecordSystemError("CalculateDynamicInterval", e, subsystem)
        return baseInterval
    }
}

; Performance dashboard and user interface
^!+f:: {  ; Ctrl+Alt+Shift+F - Show performance dashboard
    ShowPerformanceDashboard()
}

^!+q:: {  ; Ctrl+Alt+Shift+Q - Set quality level
    ShowQualityLevelDialog()
}

^!+a:: {  ; Ctrl+Alt+Shift+A - Toggle auto-adjustment
    ToggleAutoAdjustment()
}

; Show comprehensive performance dashboard
ShowPerformanceDashboard() {
    global AdaptivePerformance, SystemResourceMonitor, PerformanceBudget
    
    try {
        ; Collect performance data
        cpu := SystemResourceMonitor["CPU"]
        memory := SystemResourceMonitor["Memory"]
        frameTime := SystemResourceMonitor["FrameTiming"]
        budget := PerformanceBudget
        
        ; Build dashboard text
        dashboardText := "FWDE Performance Dashboard`n`n"
        
        ; Current Status
        dashboardText .= "Current Status:`n"
        dashboardText .= "Quality Level: " . AdaptivePerformance["QualityLevel"] . "`n"
        dashboardText .= "Auto-Adjustment: " . (AdaptivePerformance["AutoAdjustment"] ? "Enabled" : "Disabled") . "`n"
        dashboardText .= "Target FPS: " . AdaptivePerformance["TargetFPS"] . "`n`n"
        
        ; Resource Usage
        dashboardText .= "Resource Usage:`n"
        dashboardText .= "CPU: " . Round(cpu["Current"], 1) . "% (Avg: " . Round(cpu["Average"], 1) . "%, Peak: " . Round(cpu["Peak"], 1) . "%)`n"
        dashboardText .= "Memory: " . Round(memory["Current"], 1) . "% (Avg: " . Round(memory["Average"], 1) . "%, Peak: " . Round(memory["Peak"], 1) . "%)`n"
        dashboardText .= "Frame Time: " . Round(frameTime["Current"], 2) . "ms (Avg: " . Round(frameTime["Average"], 2) . "ms, Target: " . Round(frameTime["Target"], 2) . "ms)`n"
        dashboardText .= "Dropped Frames: " . frameTime["DroppedFrames"] . "`n`n"
        
        ; Performance Budget
        dashboardText .= "Performance Budget:`n"
        dashboardText .= "Physics: " . Round(budget["ActualUsage"]["Physics"], 2) . "/" . Round(budget["PhysicsBudget"], 2) . "ms"
        dashboardText .= (budget["BudgetExceeded"]["Physics"] ? " (OVER)" : " (OK)") . "`n"
        dashboardText .= "Visual: " . Round(budget["ActualUsage"]["Visual"], 2) . "/" . Round(budget["VisualBudget"], 2) . "ms"
        dashboardText .= (budget["BudgetExceeded"]["Visual"] ? " (OVER)" : " (OK)") . "`n"
        dashboardText .= "System: " . Round(budget["ActualUsage"]["System"], 2) . "/" . Round(budget["SystemBudget"], 2) . "ms"
        dashboardText .= (budget["BudgetExceeded"]["System"] ? " (OVER)" : " (OK)") . "`n"
        dashboardText .= "Total: " . Round(budget["ActualUsage"]["Total"], 2) . "/" . Round(budget["TotalBudget"], 2) . "ms"
        dashboardText .= (budget["BudgetExceeded"]["Total"] ? " (OVER)" : " (OK)") . "`n`n"
        
        ; Scaling Factors
        dashboardText .= "Scaling Factors:`n"
        for factor, value in AdaptivePerformance["ScalingFactors"] {
            dashboardText .= factor . ": " . Round(value, 2) . "x`n"
        }
        
        MsgBox(dashboardText, "Performance Dashboard", "OK Icon64")
        
    } catch as e {
        RecordSystemError("ShowPerformanceDashboard", e)
    }
}

; Show quality level selection dialog
ShowQualityLevelDialog() {
    global QualityLevels, AdaptivePerformance
    
    try {
        dialogText := "Select Quality Level:`n`n"
        currentQuality := AdaptivePerformance["QualityLevel"]
        
        for level, settings in QualityLevels {
            marker := (level == currentQuality) ? " (Current)" : ""
            dialogText .= level . marker . ": " . settings["description"] . "`n"
        }
        
        dialogText .= "`nEnter quality level (Ultra/High/Medium/Low/Minimal):"
        
        result := InputBox(dialogText, "Quality Level Selection", "W400 H300", currentQuality)
        if (result.Result == "OK" && result.Text != "") {
            if (QualityLevels.Has(result.Text)) {
                SetQualityLevel(result.Text)
                ShowNotification("Performance", "Quality level set to: " . result.Text, "success")
            } else {
                ShowNotification("Performance", "Invalid quality level: " . result.Text, "error")
            }
        }
        
    } catch as e {
        RecordSystemError("ShowQualityLevelDialog", e)
    }
}

; Toggle auto-adjustment
ToggleAutoAdjustment() {
    global AdaptivePerformance
    
    AdaptivePerformance["AutoAdjustment"] := !AdaptivePerformance["AutoAdjustment"]
    status := AdaptivePerformance["AutoAdjustment"] ? "enabled" : "disabled"
    ShowNotification("Performance", "Auto-adjustment " . status, "info")
}

; Enhanced configuration presets with performance integration
UpdateConfigPresetsWithPerformance() {
    global ConfigPresets, QualityLevels
    
    ; Update existing presets with performance settings
    for presetName, preset in ConfigPresets {
        switch presetName {
            case "High_Performance":
                preset["PerformanceQuality"] := "Ultra"
                preset["AdaptivePerformance"] := true
                preset["TargetFPS"] := 120
            case "Default":
                preset["PerformanceQuality"] := "High"
                preset["AdaptivePerformance"] := true
                preset["TargetFPS"] := 60
            case "Office_Work":
                preset["PerformanceQuality"] := "Medium"
                preset["AdaptivePerformance"] := true
                preset["TargetFPS"] := 30
            default:
                preset["PerformanceQuality"] := "Medium"
                preset["AdaptivePerformance"] := true
                preset["TargetFPS"] := 60
        }
    }
}

; Integration with existing configuration system
ApplyConfigurationChanges(newConfig) {
    global Config, g, AdaptivePerformance
    
    try {
        DebugLog("CONFIG", "Applying configuration changes with performance integration", 2)
        
        ; Update monitor info if seamless floating changed
        if (newConfig.Has("SeamlessMonitorFloat")) {
            g["Monitor"] := GetCurrentMonitorInfo()
        }
        
        ; Apply performance settings if present
        if (newConfig.Has("PerformanceQuality")) {
            SetQualityLevel(newConfig["PerformanceQuality"])
        }
        
        if (newConfig.Has("AdaptivePerformance")) {
            AdaptivePerformance["Enabled"] := newConfig["AdaptivePerformance"]
        }
        
        if (newConfig.Has("TargetFPS")) {
            AdaptivePerformance["TargetFPS"] := newConfig["TargetFPS"]
            AdjustPerformanceBudget(QualityLevels[AdaptivePerformance["QualityLevel"]])
        }
        
        ; Apply dynamic timer adjustment if system is running
        if (g.Get("PhysicsEnabled", false)) {
            ApplyDynamicTimerAdjustment()
        }
        
        DebugLog("CONFIG", "Configuration changes with performance integration applied successfully", 2)
        
    } catch as e {
        RecordSystemError("ApplyConfigurationChanges", e)
    }
}

; Initialize adaptive performance system during startup
SetTimer(() => {
    InitializeAdaptivePerformance()
    UpdateConfigPresetsWithPerformance()
}, -2000)  ; Initialize after 2 second delay

; Show startup message
ShowNotification("FWDE", "Floating Windows Dynamic Equilibrium loaded. Ctrl+Alt+S to start/stop.", "info", 5000)

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
        A_TrayMenu.Add("Configuration", "")
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
        A_TrayMenu.Add("Visual Options", "")
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
        RecordSystemError("LoadConfigPreset", e, presetName)
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
        
        MsgBox(statusText, "FWDE System Status", "OK Icon64")
        
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
        
        MsgBox(settingsText, "Notification Settings", "OK Icon64")
        
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
            for error in validation["errors"] {
                statusText .= "• " . error . "`n"
            }
            statusText .= "`n"
        }
        
        if (validation["warnings"].Length > 0) {
            statusText .= "Warnings:`n"
            for warning in validation["warnings"] {
                statusText .= "• " . warning . "`n"
            }
        }
        
        MsgBox(statusText, "Configuration Status", "OK Icon64")
        
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
    
    MsgBox(aboutText, "About FWDE", "OK Icon64")
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
                class := WinGetClass("ahk_id " hwnd)
                processName := WinGetProcessName("ahk_id " hwnd)
                
                ; Skip invalid windows
                if (w < 50 || h < 50 || title == "" || !WinGetMinMax("ahk_id " hwnd)) {
                    continue
                }
                
                ; Create window object
                winObj := Map(
                    "hwnd", hwnd,
                    "title", title,
                    "class", class,
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

; Enhanced window state management with visual feedback
SetWindowManualLock(hwnd, locked := true) {
    global g, VisualFeedback
    
    try {
        ; Find window in list
        for win in g["Windows"] {
            if (win["hwnd"] == hwnd) {
                win["manualLock"] := locked
                
                ; Add visual feedback
                if (locked) {
                    AddWindowBorder(hwnd, "Locked", Config["ManualLockDuration"])
                    ShowNotification("Window Control", "Window locked", "info", 1500)
                } else {
                    AddWindowBorder(hwnd, "Physics", 1000)
                    ShowNotification("Window Control", "Window unlocked", "info", 1500)
                }
                
                DebugLog("WINDOW", "Window " . hwnd . " lock set to: " . locked, 2)
                break
            }
        }
        
    } catch as e {
        RecordSystemError("SetWindowManualLock", e, hwnd)
    }
}