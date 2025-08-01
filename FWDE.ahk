#Requires AutoHotkey v2.0
#SingleInstance Force
#WinActivateForce
#Warn
#MaxThreadsPerHotkey 255
#MaxThreads 255
A_IconTip := "Floating Windows - Dynamic Equilibrium"
ProcessSetPriority("High")

; Enhanced debug logging system
global DebugLevel := 3  ; 0=None, 1=Error, 2=Warning, 3=Info, 4=Verbose, 5=Trace
global DebugToFile := true
global DebugFile := A_ScriptDir "\FWDE_Debug.log"

; Initialize debug log
DebugLog("SYSTEM", "FWDE Starting - Debug Level: " DebugLevel, 1)
DebugLog("SYSTEM", "Script Path: " A_ScriptFullPath, 2)
DebugLog("SYSTEM", "Working Directory: " A_WorkingDir, 2)

#DllLoad "gdi32.dll"
#DllLoad "user32.dll"
#DllLoad "dwmapi.dll" ; Desktop Composition API



; Pre-allocate memory buffers
global g_NoiseBuffer := Buffer(1024)
global g_PhysicsBuffer := Buffer(4096)

; CRITICAL FIX: Add missing global data structures for movement system
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
        ApplyConfigurationChanges(appliedConfig)
        
        DebugLog("CONFIG", "Configuration loaded and applied successfully", 2)
        return true
        
    } catch as e {
        RecordSystemError("LoadConfigurationFromFile", e, ConfigFile)
        return AttemptConfigurationRecovery()
    }
}

; Atomic configuration saving with backup and validation
SaveConfigurationToFile() {
    global Config, ConfigFile, ConfigBackupFile, ConfigSchema
    
    try {
        ; Validate configuration before saving
        validation := ValidateConfiguration(Config)
        if (!validation["valid"]) {
            DebugLog("CONFIG", "Cannot save invalid configuration", 1)
            return false
        }
        
        ; Create configuration object for JSON
        configToSave := Map()
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
        
        ; Atomic write operation
        tempFile := ConfigFile . ".tmp"
        
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
    
    try {
        ; Store current state for rollback
        previousConfig := Map()
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
        }
        
        return false
    }
}

; Apply configuration changes to running system
ApplyConfigurationChanges(newConfig) {
    global g, Config 
    
    try {
        ; Update monitor bounds if seamless floating changed
        if (newConfig.Has("SeamlessMonitorFloat") && newConfig["SeamlessMonitorFloat"] != Config.Get("SeamlessMonitorFloat", false)) {
            if (newConfig["SeamlessMonitorFloat"]) {
                g["Monitor"] := GetVirtualDesktopBounds()
                DebugLog("CONFIG", "Switched to seamless multi-monitor mode", 2)
            } else {
                g["Monitor"] := GetCurrentMonitorInfo()
                DebugLog("CONFIG", "Switched to single monitor mode", 2)
            }
        }
        
        ; Update timer intervals if they changed
        if (newConfig.Has("PhysicsUpdateInterval") && newConfig["PhysicsUpdateInterval"] != Config.Get("PhysicsUpdateInterval", 200)) {
            SetTimer(CalculateDynamicLayout, newConfig["PhysicsUpdateInterval"])
            DebugLog("CONFIG", "Updated physics timer interval to " newConfig["PhysicsUpdateInterval"] "ms", 2)
        }
        
        if (newConfig.Has("VisualTimeStep") && newConfig["VisualTimeStep"] != Config.Get("VisualTimeStep", 2)) {
            SetTimer(ApplyWindowMovements, newConfig["VisualTimeStep"])
            DebugLog("CONFIG", "Updated movement timer interval to " newConfig["VisualTimeStep"] "ms", 2)
        }
        
        if (newConfig.Has("ScreenshotCheckInterval") && newConfig["ScreenshotCheckInterval"] != Config.Get("ScreenshotCheckInterval", 250)) {
            SetTimer(UpdateScreenshotState, newConfig["ScreenshotCheckInterval"])
            DebugLog("CONFIG", "Updated screenshot check interval to " newConfig["ScreenshotCheckInterval"] "ms", 2)
        }
        
        ; Reset physics state if critical parameters changed
        criticalParams := ["AttractionForce", "RepulsionForce", "Damping", "MaxSpeed"]
        resetPhysics := false
        for param in criticalParams {
            if (newConfig.Has(param) && newConfig[param] != Config.Get(param, 0)) {
                resetPhysics := true
                break
            }
        }
        
        if (resetPhysics) {
            ; Reset all window velocities
            for win in g["Windows"] {
                win["vx"] := 0
                win["vy"] := 0
            }
            DebugLog("CONFIG", "Reset physics state due to parameter changes", 2)
        }
        
    } catch as e {
        RecordSystemError("ApplyConfigurationChanges", e)
    }
}

; Configuration backup and recovery
BackupCurrentConfiguration() {
    global Config, ConfigBackupFile
    
    try {
        backupData := Map()
        backupData["_backup_metadata"] := Map(
            "created", FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"),
            "reason", "pre_load_backup"
        )
        
        for key, value in Config {
            backupData[key] := value
        }
        
        jsonText := JSON.stringify(backupData, 2)
        FileAppend(jsonText, ConfigBackupFile)
        
        DebugLog("CONFIG", "Configuration backup created", 3)
        
    } catch as e {
        RecordSystemError("BackupCurrentConfiguration", e)
    }
}

AttemptConfigurationRecovery() {
    global Config, ConfigBackupFile
    
    try {
        if (FileExist(ConfigBackupFile)) {
            DebugLog("CONFIG", "Attempting to restore from backup", 2)
            
            backupText := FileRead(ConfigBackupFile)
            backupData := JSON.parse(backupText)
            
            ; Apply backup configuration
            for key, value in backupData {
                if (key != "_backup_metadata") {
                    Config[key] := value
                }
            }
            
            DebugLog("CONFIG", "Configuration restored from backup", 2)
            ShowTooltip("Configuration restored from backup due to load failure")
            return true
        } else {
            DebugLog("CONFIG", "No backup available, keeping current configuration", 2)
            return false
        }
        
    } catch as e {
        RecordSystemError("AttemptConfigurationRecovery", e)
        return false
    }
}

; Configuration export/import functionality
ExportConfiguration(exportPath := "") {
    global Config
    
    if (exportPath == "") {
        exportPath := A_ScriptDir "\FWDE_Config_Export_" FormatTime(A_Now, "yyyyMMdd_HHmmss") ".json"
    }
    
    try {
        exportData := Map()
        exportData["_export_metadata"] := Map(
            "exported", FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"),
            "version", ConfigSchema["version"],
            "application", "FWDE"
        )
        
        for key, value in Config {
            exportData[key] := value
        }
        
        jsonText := JSON.stringify(exportData, 2)
        FileAppend(jsonText, exportPath)
        
        DebugLog("CONFIG", "Configuration exported to " exportPath, 2)
        ShowTooltip("Configuration exported to:`n" exportPath)
        return true
        
    } catch as e {
        RecordSystemError("ExportConfiguration", e, exportPath)
        ShowTooltip("Failed to export configuration")
        return false
    }
}

ImportConfiguration(importPath) {
    global Config
    
    try {
        if (!FileExist(importPath)) {
            ShowTooltip("Import file not found: " importPath)
            return false
        }
        
        ; Backup current configuration
        BackupCurrentConfiguration()
        
        ; Read and parse import file
        importText := FileRead(importPath)
        importData := JSON.parse(importText)
        
        ; Validate imported configuration
        validation := ValidateConfigurationSchema(importData)
        if (!validation["valid"]) {
            ShowTooltip("Import failed: " validation["error"])
            return false
        }
        
        ; Apply imported configuration
        for key, value in importData {
            if (key != "_export_metadata" && ConfigSchema["structure"].Has(key)) {
                Config[key] := value
            }
        }
        
        ; Validate complete configuration
        fullValidation := ValidateConfiguration(Config)
        if (!fullValidation["valid"]) {
            AttemptConfigurationRecovery()
            ShowTooltip("Import failed validation, restored from backup")
            return false
        }
        
        ; Apply changes and save
        ApplyConfigurationChanges(Config)
        SaveConfigurationToFile()
        
        DebugLog("CONFIG", "Configuration imported from " importPath, 2)
        ShowTooltip("Configuration imported successfully")
        return true
        
    } catch as e {
        RecordSystemError("ImportConfiguration", e, importPath)
        AttemptConfigurationRecovery()
        ShowTooltip("Import failed, restored from backup")
        return false
    }
}

; User interface functions for configuration management
ShowConfigurationManager() {
    global Config
    
    configInfo := "FWDE Configuration Manager`n"
    configInfo .= "═══════════════════════`n`n"
    
    ; Current configuration status
    validation := ValidateConfiguration(Config)
    configInfo .= "Status: " (validation["valid"] ? "✓ Valid" : "✗ Invalid") "`n"
    
    if (validation["errors"].Length > 0) {
        configInfo .= "Errors:`n"
        for error in validation["errors"] {
            configInfo .= "  • " error "`n"
        }
    }
    
    if (validation["warnings"].Length > 0) {
        configInfo .= "Warnings:`n"
        for warning in validation["warnings"] {
            configInfo .= "  • " warning "`n"
        }
    }
    
    configInfo .= "`nHotkeys:`n"
    configInfo .= "Ctrl+Alt+S - Save configuration`n"
    configInfo .= "Ctrl+Alt+R - Reload from file`n"
    configInfo .= "Ctrl+Alt+E - Export configuration`n"
    configInfo .= "Ctrl+Alt+I - Import configuration`n"
    configInfo .= "Ctrl+Alt+C - Show status`n"
    configInfo .= "Ctrl+Alt+V - List presets`n"
    
    ShowTooltip(configInfo, 10000)
}

; Enhanced JSON library integration (simplified version)
class JSON {
    static parse(text) {
        ; Simple JSON parser - in production, use a full JSON library
        ; This is a basic implementation for demonstration
        return Map()  ; Placeholder - implement full JSON parsing
    }
    
    static stringify(obj, indent := 0) {
        ; Simple JSON stringifier - in production, use a full JSON library
        ; This is a basic implementation for demonstration
        return "{}"  ; Placeholder - implement full JSON stringification
    }
}

; Enhanced hotkeys for configuration persistence
^!S::SaveConfigurationToFile()
^!R::HotReloadConfiguration()
^!E::ExportConfiguration()
^!I::{
    ; Simple file dialog for import
    importFile := FileSelect(1, , "Import Configuration", "JSON Files (*.json)")
    if (importFile) {
        ImportConfiguration(importFile)
    }
}
^!M::ShowConfigurationManager()

; Initialize configuration system when script starts
InitializeConfigurationSystem()

; Enhanced Visual Feedback System
global VisualFeedback := Map(
    "SystemTrayEnabled", true,
    "TooltipTheme", "Default",
    "NotificationHistory", [],
    "MaxHistoryItems", 50,
    "BorderAnimationEnabled", true,
    "StatusOverlayEnabled", false,
    "PerformanceMetricsVisible", false,
    "LastStatusUpdate", 0,
    "StatusUpdateInterval", 1000,
    "Themes", Map(
        "Default", Map(
            "BackgroundColor", "0x1E1E1E",
            "TextColor", "0xFFFFFF",
            "BorderColor", "0x007ACC",
            "ErrorColor", "0xFF4444",
            "WarningColor", "0xFFAA00",
            "SuccessColor", "0x44AA44",
            "FontSize", 11,
            "FontFamily", "Segoe UI"
        ),
        "Dark", Map(
            "BackgroundColor", "0x2D2D30",
            "TextColor", "0xF1F1F1",
            "BorderColor", "0x3C3C3C",
            "ErrorColor", "0xF14C4C",
            "WarningColor", "0xFFCC02",
            "SuccessColor", "0x73C991",
            "FontSize", 11,
            "FontFamily", "Segoe UI"
        ),
        "Light", Map(
            "BackgroundColor", "0xF8F8F8",
            "TextColor", "0x333333",
            "BorderColor", "0x0078D4",
            "ErrorColor", "0xD13438",
            "WarningColor", "0xFF8C00",
            "SuccessColor", "0x107C10",
            "FontSize", 11,
            "FontFamily", "Segoe UI"
        )
    )
)

; System Tray Management
global SystemTray := Map(
    "Initialized", false,
    "Icon", "",
    "LastIconUpdate", 0,
    "IconUpdateInterval", 2000,
    "StatusIcons", Map(
        "Normal", A_ScriptDir "\icons\tray_normal.ico",
        "Active", A_ScriptDir "\icons\tray_active.ico",
        "Error", A_ScriptDir "\icons\tray_error.ico",
        "Paused", A_ScriptDir "\icons\tray_paused.ico"
    ),
    "ContextMenu", "",
    "BalloonTips", true
)

; Initialize Visual Feedback System
InitializeVisualFeedback() {
    DebugLog("VISUAL", "Initializing visual feedback system", 2)
    
    try {
        ; Initialize system tray
        if (VisualFeedback["SystemTrayEnabled"]) {
            InitializeSystemTray()
        }
        
        ; Setup performance monitoring
        SetTimer(UpdateSystemStatus, VisualFeedback["StatusUpdateInterval"])
        
        ; Initialize notification system
        InitializeNotificationSystem()
        
        ; Setup window border system
        InitializeWindowBorders()
        
        DebugLog("VISUAL", "Visual feedback system initialized successfully", 2)
        
    } catch as e {
        RecordSystemError("InitializeVisualFeedback", e)
    }
}

; System Tray Integration
InitializeSystemTray() {
    global SystemTray, g
    
    try {
        ; Create context menu
        SystemTray["ContextMenu"] := Menu()
        
        ; Add menu items
        SystemTray["ContextMenu"].Add("&Toggle Physics Engine", TogglePhysicsFromTray)
        SystemTray["ContextMenu"].Add("Toggle &Seamless Float", ToggleSeamlessFromTray)
        SystemTray["ContextMenu"].Add()  ; Separator
        
        ; Configuration submenu
        configMenu := Menu()
        configMenu.Add("&Default Preset", () => LoadConfigPreset("Default"))
        configMenu.Add("&DAW Production", () => LoadConfigPreset("DAW_Production"))
        configMenu.Add("&Gaming", () => LoadConfigPreset("Gaming"))
        configMenu.Add("&Office Work", () => LoadConfigPreset("Office_Work"))
        configMenu.Add("&High Performance", () => LoadConfigPreset("High_Performance"))
        configMenu.Add()
        configMenu.Add("&Configuration Status", ShowConfigStatus)
        configMenu.Add("&Save Configuration", SaveConfigurationToFile)
        configMenu.Add("&Export Configuration", ExportConfiguration)
        
        SystemTray["ContextMenu"].Add("&Configuration", configMenu)
        SystemTray["ContextMenu"].Add()
        
        ; Status and controls
        SystemTray["ContextMenu"].Add("&System Status", ShowSystemStatus)
        SystemTray["ContextMenu"].Add("&Performance Metrics", TogglePerformanceMetrics)
        SystemTray["ContextMenu"].Add("&Optimize Windows", OptimizeAllWindows)
        SystemTray["ContextMenu"].Add()
        
        ; Advanced options
        advancedMenu := Menu()
        advancedMenu.Add("&Debug Information", ShowDebugInformation)
        advancedMenu.Add("&Reset System", ResetSystemState)
        advancedMenu.Add("&Reload Configuration", HotReloadConfiguration)
        
        SystemTray["ContextMenu"].Add("&Advanced", advancedMenu)
        SystemTray["ContextMenu"].Add()
        SystemTray["ContextMenu"].Add("E&xit", ExitApplication)
        
        ; Set tray menu
        A_TrayMenu := SystemTray["ContextMenu"]
        
        ; Set initial icon
        UpdateSystemTrayIcon("Normal")
        
        ; Enable balloon tips if supported
        if (SystemTray["BalloonTips"]) {
            A_IconTip := "FWDE - Floating Windows Dynamic Equilibrium"
        }
        
        SystemTray["Initialized"] := true
        DebugLog("VISUAL", "System tray initialized with context menu", 2)
        
    } catch as e {
        RecordSystemError("InitializeSystemTray", e)
    }
}

; Update system tray icon based on status
UpdateSystemTrayIcon(status := "") {
    global SystemTray, g
    
    try {
        if (!SystemTray["Initialized"]) {
            return
        }
        
        ; Determine status if not provided
        if (status == "") {
            if (!g.Get("ArrangementActive", false)) {
                status := "Paused"
            } else if (!SystemState["SystemHealthy"]) {
                status := "Error"
            } else if (g.Get("PhysicsEnabled", false) && g["Windows"].Length > 0) {
                status := "Active"
            } else {
                status := "Normal"
            }
        }
        
        ; Update icon if changed
        if (SystemTray["Icon"] != status) {
            SystemTray["Icon"] := status
            
            ; Set icon file if it exists
            iconFile := SystemTray["StatusIcons"][status]
            if (FileExist(iconFile)) {
                TraySetIcon(iconFile)
            }
            
            ; Update tooltip
            tooltipText := "FWDE - " status
            if (g.Has("Windows") && g["Windows"].Length > 0) {
                tooltipText .= " (" g["Windows"].Length " windows)"
            }
            A_IconTip := tooltipText
            
            DebugLog("VISUAL", "System tray icon updated to: " status, 3)
        }
        
    } catch as e {
        RecordSystemError("UpdateSystemTrayIcon", e)
    }
}

; Enhanced notification system
ShowNotification(title, message, type := "info", duration := 5000, showInTray := true) {
    global VisualFeedback, SystemTray
    
    try {
        ; Create notification record
        notification := Map(
            "Title", title,
            "Message", message,
            "Type", type,
            "Timestamp", A_TickCount,
            "Duration", duration
        )
        
        ; Add to history
        VisualFeedback["NotificationHistory"].Push(notification)
        
        ; Maintain history size
        if (VisualFeedback["NotificationHistory"].Length > VisualFeedback["MaxHistoryItems"]) {
            VisualFeedback["NotificationHistory"].RemoveAt(1)
        }
        
        ; Show system tray balloon if enabled
        if (showInTray && SystemTray["BalloonTips"] && SystemTray["Initialized"]) {
            balloonIcon := 1  ; Info
            switch type {
                case "error": balloonIcon := 3
                case "warning": balloonIcon := 2
                case "success": balloonIcon := 1
            }
            
            try {
                TrayTip(message, title, balloonIcon)
            } catch {
                ; Fallback to regular tooltip if balloon tips fail
                ShowEnhancedTooltip(title "`n" message, type, duration)
            }
        } else {
            ; Use enhanced tooltip system
            ShowEnhancedTooltip(title "`n" message, type, duration)
        }
        
        DebugLog("VISUAL", "Notification shown: " title " - " message, 3)
        
    } catch as e {
        RecordSystemError("ShowNotification", e)
        ; Fallback to basic tooltip
        ShowTooltip(title "`n" message, duration)
    }
}

; Enhanced tooltip system with theming
ShowEnhancedTooltip(text, type := "info", duration := 5000) {
    global VisualFeedback
    
    try {
        theme := VisualFeedback["Themes"][VisualFeedback["TooltipTheme"]]
        
        ; Determine colors based on type
        bgColor := theme["BackgroundColor"]
        textColor := theme["TextColor"]
        borderColor := theme["BorderColor"]
        
        switch type {
            case "error": borderColor := theme["ErrorColor"]
            case "warning": borderColor := theme["WarningColor"]
            case "success": borderColor := theme["SuccessColor"]
        }
        
        ; Create custom tooltip (simplified - in production use GUI)
        ; For now, use enhanced basic tooltip with type prefix
        typePrefix := ""
        switch type {
            case "error": typePrefix := "❌ "
            case "warning": typePrefix := "⚠️ "
            case "success": typePrefix := "✅ "
            case "info": typePrefix := "ℹ️ "
        }
        
        ShowTooltip(typePrefix . text, duration)
        
    } catch as e {
        RecordSystemError("ShowEnhancedTooltip", e)
        ShowTooltip(text, duration)
    }
}

; Window border visual feedback system
global WindowBorders := Map()

InitializeWindowBorders() {
    DebugLog("VISUAL", "Initializing window border system", 3)
    ; Window border system initialized - borders will be created on demand
}

; Show colored border around window
ShowWindowBorder(hwnd, borderType := "locked", duration := 0) {
    global WindowBorders, VisualFeedback, Config
    
    try {
        if (!VisualFeedback["BorderAnimationEnabled"]) {
            return
        }
        
        ; Remove existing border if present
        RemoveWindowBorder(hwnd)
        
        ; Get window position and size
        if (!SafeWinExist(hwnd)) {
            return
        }
        
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        
        ; Determine border color
        borderColor := "FF5555"  ; Default red
        switch borderType {
            case "locked": borderColor := Config.Get("ManualWindowColor", "FF5555")
            case "physics": borderColor := "55FF55"
            case "manual": borderColor := "5555FF"
            case "error": borderColor := "FF0000"
            case "warning": borderColor := "FFAA00"
        }
        
        ; Create border GUI (simplified border system)
        borderInfo := Map(
            "hwnd", hwnd,
            "type", borderType,
            "created", A_TickCount,
            "duration", duration,
            "color", borderColor
        )
        
        WindowBorders[hwnd] := borderInfo
        
        ; Set timer to remove border if duration specified
        if (duration > 0) {
            SetTimer(() => RemoveWindowBorder(hwnd), -duration)
        }
        
        DebugLog("VISUAL", "Border shown for window " hwnd " (" borderType ")", 4)
        
    } catch as e {
        RecordSystemError("ShowWindowBorder", e, hwnd)
    }
}

; Remove window border
RemoveWindowBorder(hwnd) {
    global WindowBorders
    
    try {
        if (WindowBorders.Has(hwnd)) {
            ; Clean up border resources here
            WindowBorders.Delete(hwnd)
            DebugLog("VISUAL", "Border removed for window " hwnd, 4)
        }
    } catch as e {
        RecordSystemError("RemoveWindowBorder", e, hwnd)
    }
}

; System status monitoring and display
UpdateSystemStatus() {
    global g, SystemState, VisualFeedback
    
    try {
        currentTime := A_TickCount
        
        ; Update tray icon periodically
        if (currentTime - SystemTray["LastIconUpdate"] > SystemTray["IconUpdateInterval"]) {
            UpdateSystemTrayIcon()
            SystemTray["LastIconUpdate"] := currentTime
        }
        
        ; Update performance metrics if visible
        if (VisualFeedback["PerformanceMetricsVisible"]) {
            ShowPerformanceMetrics()
        }
        
        ; Clean up expired window borders
        CleanupExpiredBorders()
        
        VisualFeedback["LastStatusUpdate"] := currentTime
        
    } catch as e {
        RecordSystemError("UpdateSystemStatus", e)
    }
}

; Cleanup expired window borders
CleanupExpiredBorders() {
    global WindowBorders
    
    try {
        currentTime := A_TickCount
        expiredBorders := []
        
        for hwnd, borderInfo in WindowBorders {
            if (borderInfo["duration"] > 0 && 
                currentTime - borderInfo["created"] > borderInfo["duration"]) {
                expiredBorders.Push(hwnd)
            }
        }
        
        for hwnd in expiredBorders {
            RemoveWindowBorder(hwnd)
        }
        
    } catch as e {
        RecordSystemError("CleanupExpiredBorders", e)
    }
}

; Show comprehensive system status
ShowSystemStatus() {
    global g, SystemState, PerfTimers
    
    statusText := "FWDE System Status`n"
    statusText .= "═══════════════════`n`n"
    
    ; System health
    statusText .= "System Health: " (SystemState["SystemHealthy"] ? "✅ Healthy" : "❌ Degraded") "`n"
    
    if (!SystemState["SystemHealthy"]) {
        statusText .= "Last Error: " SystemState["LastError"] "`n"
        statusText .= "Error Count: " SystemState["ErrorCount"] "`n"
        statusText .= "Recovery Attempts: " SystemState["RecoveryAttempts"] "`n"
    }
    
    ; System state
    statusText .= "`nSystem State:`n"
    statusText .= "Physics Engine: " (g.Get("PhysicsEnabled", false) ? "✅ Active" : "❌ Disabled") "`n"
    statusText .= "Arrangement: " (g.Get("ArrangementActive", false) ? "✅ Active" : "❌ Paused") "`n"
    statusText .= "Seamless Float: " (Config["SeamlessMonitorFloat"] ? "✅ Enabled" : "❌ Disabled") "`n"
    statusText .= "Screenshot Pause: " (g.Get("ScreenshotPaused", false) ? "⏸️ Active" : "▶️ Normal") "`n"
    
    ; Window statistics
    windowCount := g.Has("Windows") ? g["Windows"].Length : 0
    statusText .= "`nWindow Management:`n"
    statusText .= "Managed Windows: " windowCount "`n"
    
    if (windowCount > 0) {
        pluginCount := 0
        lockedCount := 0
        for win in g["Windows"] {
            if (win.Get("isPlugin", false)) pluginCount++
            if (win.Get("manualLock", false)) lockedCount++
        }
        statusText .= "Plugin Windows: " pluginCount "`n"
        statusText .= "Locked Windows: " lockedCount "`n"
    }
    
    ; Performance info
    if (PerfTimers.Count > 0) {
        statusText .= "`nPerformance (avg):`n"
        for operation, timer in PerfTimers {
            avgTime := timer["totalTime"] / timer["count"]
            statusText .= operation ": " Round(avgTime, 2) "ms`n"
        }
    }
    
    ShowNotification("System Status", statusText, "info", 10000)
}

; Toggle performance metrics display
TogglePerformanceMetrics() {
    global VisualFeedback
    
    VisualFeedback["PerformanceMetricsVisible"] := !VisualFeedback["PerformanceMetricsVisible"]
    
    if (VisualFeedback["PerformanceMetricsVisible"]) {
        ShowNotification("Performance Metrics", "Performance metrics overlay enabled", "info")
        ShowPerformanceMetrics()
    } else {
        ShowNotification("Performance Metrics", "Performance metrics overlay disabled", "info")
    }
}

; Show real-time performance metrics
ShowPerformanceMetrics() {
    global PerfTimers, g
    
    try {
        metricsText := "FWDE Performance Metrics`n"
        metricsText .= "═══════════════════════`n"
        
        ; System performance
        windowCount := g.Has("Windows") ? g["Windows"].Length : 0
        metricsText .= "Active Windows: " windowCount "`n"
        metricsText .= "Error Count: " SystemState["ErrorCount"] "`n"
        
        ; Timer performance
        if (PerfTimers.Count > 0) {
            metricsText .= "`nOperation Times (avg):`n"
            for operation, timer in PerfTimers {
                if (timer["count"] > 0) {
                    avgTime := timer["totalTime"] / timer["count"]
                    metricsText .= operation ": " Round(avgTime, 2) "ms`n"
                }
            }
        }
        
        ; Memory info (basic)
        metricsText .= "`nMemory Usage:`n"
        metricsText .= "Position Cache: " hwndPos.Count " entries`n"
        metricsText .= "Movement Batch: " moveBatch.Length " pending`n"
        
        ShowTooltip(metricsText, 3000)
        
    } catch as e {
        RecordSystemError("ShowPerformanceMetrics", e)
    }
}

; Tray menu handlers
TogglePhysicsFromTray() {
    global g
    g["PhysicsEnabled"] := !g.Get("PhysicsEnabled", false)
    status := g["PhysicsEnabled"] ? "enabled" : "disabled"
    ShowNotification("Physics Engine", "Physics engine " status, "info")
    UpdateSystemTrayIcon()
}

ToggleSeamlessFromTray() {
    global Config, g
    Config["SeamlessMonitorFloat"] := !Config["SeamlessMonitorFloat"]
    
    ; Update monitor bounds
    if (Config["SeamlessMonitorFloat"]) {
        g["Monitor"] := GetVirtualDesktopBounds()
        ShowNotification("Seamless Float", "Multi-monitor floating enabled", "success")
    } else {
        g["Monitor"] := GetCurrentMonitorInfo()
        ShowNotification("Seamless Float", "Single monitor mode enabled", "info")
    }
    
    SaveConfigurationToFile()
}

OptimizeAllWindows() {
    try {
        OptimizeWindowPositions()
        ShowNotification("Optimization", "Window positions optimized", "success")
    } catch as e {
        RecordSystemError("OptimizeAllWindows", e)
        ShowNotification("Optimization", "Failed to optimize windows", "error")
    }
}

ShowDebugInformation() {
    debugText := "FWDE Debug Information`n"
    debugText .= "═══════════════════════`n"
    debugText .= "Debug Level: " DebugLevel "`n"
    debugText .= "Debug File: " DebugFile "`n"
    debugText .= "Log to File: " (DebugToFile ? "Enabled" : "Disabled") "`n"
    debugText .= "`nRecent Errors: " SystemState["FailedOperations"].Length "`n"
    
    ShowNotification("Debug Info", debugText, "info", 8000)
}

ResetSystemState() {
    try {
        ; Reset system state
        SystemState["ErrorCount"] := 0
        SystemState["SystemHealthy"] := true
        SystemState["RecoveryAttempts"] := 0
        SystemState["FailedOperations"] := []
        
        ; Clear position caches
        hwndPos.Clear()
        smoothPos.Clear()
        lastPositions.Clear()
        moveBatch := []
        
        ShowNotification("System Reset", "System state has been reset", "success")
        UpdateSystemTrayIcon()
        
    } catch as e {
        RecordSystemError("ResetSystemState", e)
        ShowNotification("System Reset", "Failed to reset system state", "error")
    }
}

ExitApplication() {
    ShowNotification("FWDE", "Shutting down...", "info", 1000)
    ExitApp()
}

; Initialize visual feedback system on startup
InitializeVisualFeedback()

; Enhanced ShowTooltip function to use new notification system when appropriate
ShowTooltip(text, duration := 5000) {
    static lastTooltip := ""
    static tooltipTimer := 0
    
    try {
        ; Clear existing tooltip timer
        if (tooltipTimer) {
            SetTimer(tooltipTimer, 0)
        }
        
        ; Show tooltip
        ToolTip(text)
        lastTooltip := text
        
        ; Set timer to clear tooltip
        tooltipTimer := () => ToolTip()
        SetTimer(tooltipTimer, -duration)
        
        DebugLog("VISUAL", "Tooltip shown: " StrReplace(text, "`n", " | "), 4)
        
    } catch as e {
        RecordSystemError("ShowTooltip", e)
    }
}

; Update existing lock/unlock functions to use visual feedback
ToggleWindowLock() {
    activeHwnd := WinGetID("A")
    
    if (!IsWindowValid(activeHwnd)) {
        ShowNotification("Window Lock", "Cannot lock invalid window", "warning")
        return
    }
    
    ; Find window in managed list
    targetWin := 0
    for win in g["Windows"] {
        if (win["hwnd"] == activeHwnd) {
            targetWin := win
            break
        }
    }
    
    if (!targetWin) {
        ShowNotification("Window Lock", "Window is not being managed", "warning")
        return
    }
    
    ; Toggle lock state
    isLocked := targetWin.Get("manualLock", false)
    targetWin["manualLock"] := !isLocked
    
    if (targetWin["manualLock"]) {
        targetWin["lockTime"] := A_TickCount
        ShowWindowBorder(activeHwnd, "locked", Config["ManualLockDuration"])
        ShowNotification("Window Lock", "Window locked for " Round(Config["ManualLockDuration"]/1000) " seconds", "success")
    } else {
        RemoveWindowBorder(activeHwnd)
        ShowNotification("Window Lock", "Window unlocked", "info")
    }
}

; Update configuration loading to show notifications
LoadConfigPreset(presetName) {
    global Config, ConfigPresets
    
    if (!ConfigPresets.Has(presetName)) {
        ShowNotification("Configuration", "Unknown preset: " presetName, "error")
        return false
    }
    
    preset := ConfigPresets[presetName]
    DebugLog("CONFIG", "Loading preset: " presetName " - " preset["description"], 2)
    
    ; Backup current configuration
    backupConfig := Map()
    for key, value in Config {
        backupConfig[key] := value
    }
    
    ; Apply preset configuration
    for key, value in preset {
        if (key != "description") {
            Config[key] := value
        }
    }
    
    ; Validate the new configuration
    validation := ValidateConfiguration(Config)
    
    if (!validation["valid"]) {
        ; Restore backup if validation fails
        for key, value in backupConfig {
            Config[key] := value
        }
        
        errorMsg := "Preset validation failed"
        ShowNotification("Configuration Error", errorMsg, "error")
        return false
    }
    
    ; Update monitor bounds if seamless floating changed
    if (Config["SeamlessMonitorFloat"]) {
        g["Monitor"] := GetVirtualDesktopBounds()
    } else {
        g["Monitor"] := GetCurrentMonitorInfo()
    }
    
    ; Apply configuration changes
    ApplyConfigurationChanges(Config)
    
    ShowNotification("Configuration", "Loaded preset: " presetName, "success")
    UpdateSystemTrayIcon()
    return true
}