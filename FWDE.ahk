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
    ShowTooltip(title ": " message, duration)
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

; Apply physics calculations to a window
ApplyPhysicsToWindow(win) {
    global Config, g
    
    try {
        ; Get current window position
        if (!IsWindowValid(win["hwnd"])) {
            return
        }
        
        WinGetPos(&x, &y, &w, &h, "ahk_id " win["hwnd"])
        
        ; Initialize physics properties if missing
        if (!win.Has("vx")) win["vx"] := 0
        if (!win.Has("vy")) win["vy"] := 0
        if (!win.Has("x")) win["x"] := x
        if (!win.Has("y")) win["y"] := y
        
        ; Calculate forces
        fx := 0, fy := 0
        
        ; Center attraction
        centerX := g["Monitor"]["Left"] + g["Monitor"]["Width"] / 2
        centerY := g["Monitor"]["Top"] + g["Monitor"]["Height"] / 2
        dx := centerX - x
        dy := centerY - y
        dist := Sqrt(dx*dx + dy*dy)
        
        if (dist > 0) {
            fx += Config["AttractionForce"] * dx / dist
            fy += Config["AttractionForce"] * dy / dist
        }
        
        ; Repulsion from other windows
        for otherWin in g["Windows"] {
            if (otherWin["hwnd"] == win["hwnd"]) {
                continue
            }
            
            if (IsWindowValid(otherWin["hwnd"])) {
                WinGetPos(&ox, &oy, &ow, &oh, "ahk_id " otherWin["hwnd"])
                dx := x - ox
                dy := y - oy
                dist := Sqrt(dx*dx + dy*dy)
                
                if (dist > 0 && dist < 300) {  ; Only apply repulsion within range
                    force := Config["RepulsionForce"] / (dist * dist)
                    fx += force * dx / dist
                    fy += force * dy / dist
                }
            }
        }
        
        ; Edge repulsion
        edgeForce := Config["EdgeRepulsionForce"]
        margin := Config["MinMargin"]
        
        if (x < g["Monitor"]["Left"] + margin) {
            fx += edgeForce * (g["Monitor"]["Left"] + margin - x)
        }
        if (x + w > g["Monitor"]["Right"] - margin) {
            fx -= edgeForce * (x + w - g["Monitor"]["Right"] + margin)
        }
        if (y < g["Monitor"]["Top"] + margin) {
            fy += edgeForce * (g["Monitor"]["Top"] + margin - y)
        }
        if (y + h > g["Monitor"]["Bottom"] - margin) {
            fy -= edgeForce * (y + h - g["Monitor"]["Bottom"] + margin)
        }
        
        ; Update velocity
        win["vx"] += fx * Config["PhysicsTimeStep"]
        win["vy"] += fy * Config["PhysicsTimeStep"]
        
        ; Apply damping
        win["vx"] *= (1 - Config["Damping"])
        win["vy"] *= (1 - Config["Damping"])
        
        ; Limit speed
        speed := Sqrt(win["vx"]*win["vx"] + win["vy"]*win["vy"])
        if (speed > Config["MaxSpeed"]) {
            win["vx"] *= Config["MaxSpeed"] / speed
            win["vy"] *= Config["MaxSpeed"] / speed
        }
        
        ; Update position
        win["x"] += win["vx"] * Config["PhysicsTimeStep"]
        win["y"] += win["vy"] * Config["PhysicsTimeStep"]
        
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

; Enhanced configuration change handler
ApplyConfigurationChanges(newConfig) {
    global Config, g
    
    try {
        DebugLog("CONFIG", "Applying configuration changes", 2)
        
        ; Update monitor info if seamless floating changed
        if (newConfig.Has("SeamlessMonitorFloat")) {
            g["Monitor"] := GetCurrentMonitorInfo()
        }
        
        ; Restart timers with new intervals if they changed
        if (newConfig.Has("PhysicsUpdateInterval") || newConfig.Has("VisualTimeStep") || newConfig.Has("ScreenshotCheckInterval")) {
            if (g.Get("PhysicsEnabled", false)) {
                ; Restart timers with new intervals
                SetTimer(PhysicsUpdateLoop, 0)
                SetTimer(VisualUpdateLoop, 0)
                SetTimer(UpdateScreenshotState, 0)
                
                SetTimer(PhysicsUpdateLoop, Config["PhysicsUpdateInterval"])
                SetTimer(VisualUpdateLoop, Config["VisualTimeStep"])
                SetTimer(UpdateScreenshotState, Config["ScreenshotCheckInterval"])
            }
        }
        
        DebugLog("CONFIG", "Configuration changes applied successfully", 2)
        
    } catch as e {
        RecordSystemError("ApplyConfigurationChanges", e)
    }
}

; Initialize the configuration system when the script starts
InitializeConfigurationSystem()

; Auto-start the system
SetTimer(() => StartFWDE(), -1000)  ; Start after 1 second delay

; Show startup message
ShowNotification("FWDE", "Floating Windows Dynamic Equilibrium loaded. Ctrl+Alt+S to start/stop.", "info", 5000)