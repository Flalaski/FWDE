; ===================================================================
; FWDE DAW-Specific Automation Scripts System
; Automated workflow optimization for Digital Audio Workstations
; ===================================================================

; Global DAW automation system
global DAWAutomation := Map(
    "Framework", Map(
        "Enabled", true,
        "AutoDetection", true,
        "ActiveDAW", "",
        "ProjectType", "",
        "SessionState", Map(),
        "AutomationRules", Map(),
        "CustomTriggers", Map()
    ),
    "ProjectAwareness", Map(
        "Enabled", true,
        "ProjectTemplates", Map(),
        "AutoLayoutSwitching", true,
        "ProjectClassification", Map(),
        "LayoutPreferences", Map()
    ),
    "SessionIntegration", Map(
        "FileMonitoring", true,
        "ProjectFileExtensions", [".als", ".flp", ".cpr", ".ptx", ".logic", ".rpp", ".song"],
        "MonitoredDirectories", [],
        "ActiveProject", "",
        "ProjectHistory", [],
        "SessionCallbacks", Map()
    ),
    "AutomationScripts", Map(
        "TrackCreation", Map(
            "enabled", true,
            "autoArrangeMixer", true,
            "groupRelatedWindows", true,
            "optimizePluginLayout", true
        ),
        "MixingWorkflow", Map(
            "enabled", true,
            "autoShowMixer", true,
            "organizeFXChains", true,
            "groupByBusRouting", true
        ),
        "CompositionMode", Map(
            "enabled", true,
            "maximizeArrangement", true,
            "minimizePlugins", true,
            "focusOnTimeline", true
        ),
        "RecordingMode", Map(
            "enabled", true,
            "showInputMeters", true,
            "minimizeDistractions", true,
            "prioritizeTransport", true
        )
    )
)

; DAW-specific automation profiles
global DAWProfiles := Map(
    "Ableton_Live", Map(
        "name", "Ableton Live",
        "processName", "Ableton Live*.exe",
        "projectExtension", ".als",
        "windowPatterns", ["Ableton Live*", "*Live*"],
        "automationScripts", Map(
            "SessionView", "OptimizeAbletonSessionView",
            "ArrangementView", "OptimizeAbletonArrangementView",
            "DeviceRack", "OrganizeAbletonDevices",
            "Mixer", "OptimizeAbletonMixer"
        ),
        "projectTypes", Map(
            "Electronic", Map("template", "Electronic Production", "layout", "Electronic_Layout"),
            "Recording", Map("template", "Audio Recording", "layout", "Recording_Layout"),
            "Live", Map("template", "Live Performance", "layout", "Performance_Layout")
        )
    ),
    "FL_Studio", Map(
        "name", "FL Studio",
        "processName", "FL*.exe",
        "projectExtension", ".flp",
        "windowPatterns", ["FL Studio*", "*FL*"],
        "automationScripts", Map(
            "Playlist", "OptimizeFLPlaylist",
            "Piano_Roll", "OptimizeFLPianoRoll",
            "Mixer", "OptimizeFLMixer",
            "Browser", "OptimizeFLBrowser"
        ),
        "projectTypes", Map(
            "Beat", Map("template", "Beat Making", "layout", "Beat_Layout"),
            "Song", Map("template", "Full Song", "layout", "Song_Layout"),
            "Remix", Map("template", "Remix Project", "layout", "Remix_Layout")
        )
    ),
    "Cubase", Map(
        "name", "Steinberg Cubase",
        "processName", "Cubase*.exe",
        "projectExtension", ".cpr",
        "windowPatterns", ["Cubase*", "*Steinberg*"],
        "automationScripts", Map(
            "Project", "OptimizeCubaseProject",
            "MixConsole", "OptimizeCubaseMixer",
            "Inspector", "OptimizeCubaseInspector",
            "MediaBay", "OptimizeCubaseMediaBay"
        ),
        "projectTypes", Map(
            "Recording", Map("template", "Audio Recording", "layout", "Cubase_Recording"),
            "MIDI", Map("template", "MIDI Composition", "layout", "Cubase_MIDI"),
            "Mixing", Map("template", "Mixing Project", "layout", "Cubase_Mixing")
        )
    ),
    "Pro_Tools", Map(
        "name", "Avid Pro Tools",
        "processName", "ProTools*.exe",
        "projectExtension", ".ptx",
        "windowPatterns", ["Pro Tools*", "*Avid*"],
        "automationScripts", Map(
            "Edit", "OptimizeProToolsEdit",
            "Mix", "OptimizeProToolsMix",
            "Transport", "OptimizeProToolsTransport",
            "Workspace", "OptimizeProToolsWorkspace"
        ),
        "projectTypes", Map(
            "Recording", Map("template", "Studio Recording", "layout", "ProTools_Recording"),
            "Editing", Map("template", "Audio Editing", "layout", "ProTools_Editing"),
            "Mixing", Map("template", "Professional Mixing", "layout", "ProTools_Mixing")
        )
    ),
    "Reaper", Map(
        "name", "Cockos REAPER",
        "processName", "reaper.exe",
        "projectExtension", ".rpp",
        "windowPatterns", ["REAPER*", "*Cockos*"],
        "automationScripts", Map(
            "Arrange", "OptimizeReaperArrange",
            "Mixer", "OptimizeReaperMixer",
            "FX", "OptimizeReaperFX",
            "Actions", "OptimizeReaperActions"
        ),
        "projectTypes", Map(
            "Podcast", Map("template", "Podcast Production", "layout", "Reaper_Podcast"),
            "Music", Map("template", "Music Production", "layout", "Reaper_Music"),
            "Post", Map("template", "Post Production", "layout", "Reaper_Post")
        )
    )
)

; Automation rule types and triggers
global AutomationRules := Map(
    "WindowCreation", Map(
        "enabled", true,
        "description", "Triggered when new windows are created",
        "triggers", ["OnWindowCreate", "OnPluginLoad"],
        "actions", ["GroupRelatedWindows", "ApplyLayoutTemplate", "SetZOrder"]
    ),
    "ProjectLoad", Map(
        "enabled", true,
        "description", "Triggered when DAW project is loaded",
        "triggers", ["OnProjectOpen", "OnFileChange"],
        "actions", ["DetectProjectType", "LoadProjectLayout", "ConfigureWorkspace"]
    ),
    "WorkflowMode", Map(
        "enabled", true,
        "description", "Triggered by user workflow changes",
        "triggers", ["OnModeSwitch", "OnWindowFocus"],
        "actions", ["OptimizeForWorkflow", "AdjustWindowPriorities", "UpdateLayout"]
    ),
    "SessionState", Map(
        "enabled", true,
        "description", "Triggered by session state changes",
        "triggers", ["OnProjectSave", "OnProjectClose"],
        "actions", ["SaveLayoutState", "BackupPreferences", "CleanupWindows"]
    )
)

; Initialize DAW automation system
InitializeDAWAutomation() {
    try {
        DebugLog("DAW_AUTO", "Initializing DAW automation system", 2)
        
        ; Initialize automation framework
        InitializeAutomationFramework()
        
        ; Start DAW detection
        StartDAWDetection()
        
        ; Initialize project awareness
        InitializeProjectAwareness()
        
        ; Setup session integration
        InitializeSessionIntegration()
        
        ; Load custom automation rules
        LoadCustomAutomationRules()
        
        ; Start automation monitoring
        StartAutomationMonitoring()
        
        DebugLog("DAW_AUTO", "DAW automation system initialized successfully", 2)
        ShowNotification("DAW Automation", "Workflow automation enabled", "success", 3000)
        
        return true
        
    } catch Error as e {
        RecordSystemError("InitializeDAWAutomation", e)
        return false
    }
}

; Initialize automation framework core
InitializeAutomationFramework() {
    global DAWAutomation
    
    try {
        ; Clear existing automation state
        DAWAutomation["Framework"]["SessionState"].Clear()
        DAWAutomation["Framework"]["AutomationRules"].Clear()
        DAWAutomation["Framework"]["CustomTriggers"].Clear()
        
        ; Initialize rule engine
        InitializeRuleEngine()
        
        ; Setup automation callbacks
        SetupAutomationCallbacks()
        
        DebugLog("DAW_AUTO", "Automation framework initialized", 3)
        
    } catch Error as e {
        RecordSystemError("InitializeAutomationFramework", e)
    }
}

; Start DAW detection and monitoring
StartDAWDetection() {
    try {
        ; Start DAW process monitoring
        SetTimer(DetectActiveDAW, 3000)
        
        ; Initial DAW detection
        DetectActiveDAW()
        
        DebugLog("DAW_AUTO", "DAW detection started", 3)
        
    } catch Error as e {
        RecordSystemError("StartDAWDetection", e)
    }
}

; Detect currently active DAW
DetectActiveDAW() {
    global DAWAutomation, DAWProfiles
    
    try {
        previousDAW := DAWAutomation["Framework"]["ActiveDAW"]
        currentDAW := ""
        
        ; Check running processes against DAW profiles
        for dawName, profile in DAWProfiles {
            processPattern := profile["processName"]
            
            ; Check if DAW process is running
            if (ProcessExist(processPattern)) {
                currentDAW := dawName
                break
            }
        }
        
        ; Update active DAW if changed
        if (currentDAW != previousDAW) {
            DAWAutomation["Framework"]["ActiveDAW"] := currentDAW
            
            if (currentDAW) {
                OnDAWActivated(currentDAW)
            } else if (previousDAW) {
                OnDAWDeactivated(previousDAW)
            }
        }
        
    } catch Error as e {
        RecordSystemError("DetectActiveDAW", e)
    }
}

; Handle DAW activation
OnDAWActivated(dawName) {
    global DAWAutomation, DAWProfiles
    
    try {
        DebugLog("DAW_AUTO", "DAW activated: " . dawName, 2)
        
        ; Load DAW-specific profile
        if (DAWProfiles.Has(dawName)) {
            profile := DAWProfiles[dawName]
            
            ; Apply DAW-specific automation rules
            ApplyDAWProfile(profile)
            
            ; Start project monitoring for this DAW
            StartProjectMonitoring(profile)
            
            ; Initialize DAW-specific automation scripts
            InitializeDAWAutomationScripts(dawName)
        }
        
        ShowNotification("DAW Automation", "Activated automation for " . dawName, "info", 3000)
        
    } catch Error as e {
        RecordSystemError("OnDAWActivated", e, dawName)
    }
}

; Apply DAW-specific profile
ApplyDAWProfile(profile) {
    global DAWAutomation
    
    try {
        ; Update automation configuration for this DAW
        DAWAutomation["Framework"]["SessionState"]["dawProfile"] := profile
        
        ; Apply DAW-specific window detection patterns
        UpdateWindowDetectionPatterns(profile["windowPatterns"])
        
        ; Configure automation scripts
        ConfigureDAWAutomationScripts(profile["automationScripts"])
        
        DebugLog("DAW_AUTO", "Applied DAW profile: " . profile["name"], 3)
        
    } catch Error as e {
        RecordSystemError("ApplyDAWProfile", e)
    }
}

; Initialize project awareness system
InitializeProjectAwareness() {
    global DAWAutomation
    
    try {
        ; Load project templates
        LoadProjectTemplates()
        
        ; Initialize project classification
        InitializeProjectClassification()
        
        ; Start project type detection
        SetTimer(DetectProjectType, 5000)
        
        DebugLog("DAW_AUTO", "Project awareness initialized", 3)
        
    } catch Error as e {
        RecordSystemError("InitializeProjectAwareness", e)
    }
}

; Detect current project type
DetectProjectType() {
    global DAWAutomation
    
    try {
        activeDAW := DAWAutomation["Framework"]["ActiveDAW"]
        
        if (!activeDAW) {
            return
        }
        
        ; Get active project information
        projectInfo := GetActiveProjectInfo(activeDAW)
        
        if (projectInfo) {
            ; Classify project type
            projectType := ClassifyProjectType(projectInfo, activeDAW)
            
            ; Update current project type
            previousType := DAWAutomation["Framework"]["ProjectType"]
            DAWAutomation["Framework"]["ProjectType"] := projectType
            
            ; Trigger layout optimization if project type changed
            if (projectType != previousType && projectType) {
                OnProjectTypeChanged(projectType, activeDAW)
            }
        }
        
    } catch Error as e {
        RecordSystemError("DetectProjectType", e)
    }
}

; Get active project information
GetActiveProjectInfo(dawName) {
    try {
        ; Implementation would vary by DAW
        ; This is a simplified version that analyzes window titles
        
        projectInfo := Map(
            "name", "",
            "path", "",
            "trackCount", 0,
            "pluginCount", 0,
            "characteristics", []
        )
        
        ; Analyze DAW windows for project information
        windowList := WinGetList()
        
        for hwnd in windowList {
            title := WinGetTitle("ahk_id " . hwnd)
            process := WinGetProcessName("ahk_id " . hwnd)
            
            ; Match against DAW process
            if (IsDAWWindow(hwnd, dawName)) {
                ; Extract project information from window titles
                AnalyzeDAWWindow(title, projectInfo)
            }
        }
        
        return projectInfo
        
    } catch Error as e {
        RecordSystemError("GetActiveProjectInfo", e, dawName)
        return ""
    }
}

; Classify project type based on characteristics
ClassifyProjectType(projectInfo, dawName) {
    global DAWProfiles
    
    try {
        if (!DAWProfiles.Has(dawName)) {
            return "Unknown"
        }
        
        profile := DAWProfiles[dawName]
        projectTypes := profile.Get("projectTypes", Map())
        
        ; Analyze project characteristics
        characteristics := projectInfo["characteristics"]
        trackCount := projectInfo["trackCount"]
        pluginCount := projectInfo["pluginCount"]
        
        ; Simple classification logic
        for typeName, typeData in projectTypes {
            if (MatchesProjectType(characteristics, typeName, trackCount, pluginCount)) {
                return typeName
            }
        }
        
        return "General"
        
    } catch Error as e {
        RecordSystemError("ClassifyProjectType", e)
        return "Unknown"
    }
}

; Handle project type change
OnProjectTypeChanged(projectType, dawName) {
    global DAWAutomation, DAWProfiles
    
    try {
        DebugLog("DAW_AUTO", "Project type changed to: " . projectType, 2)
        
        ; Apply project-specific layout if auto-switching enabled
        if (DAWAutomation["ProjectAwareness"]["AutoLayoutSwitching"]) {
            ApplyProjectLayout(projectType, dawName)
        }
        
        ; Configure automation for this project type
        ConfigureProjectAutomation(projectType, dawName)
        
        ShowNotification("Project Detection", "Detected " . projectType . " project", "info", 2000)
        
    } catch Error as e {
        RecordSystemError("OnProjectTypeChanged", e, projectType)
    }
}

; Apply project-specific layout
ApplyProjectLayout(projectType, dawName) {
    global DAWProfiles
    
    try {
        if (!DAWProfiles.Has(dawName)) {
            return
        }
        
        profile := DAWProfiles[dawName]
        projectTypes := profile.Get("projectTypes", Map())
        
        if (projectTypes.Has(projectType)) {
            typeData := projectTypes[projectType]
            layoutName := typeData.Get("layout", "")
            
            if (layoutName && LayoutAlgorithms["CustomLayouts"]["SavedLayouts"].Has(layoutName)) {
                LoadLayout(layoutName)
                DebugLog("DAW_AUTO", "Applied layout: " . layoutName, 3)
            }
        }
        
    } catch Error as e {
        RecordSystemError("ApplyProjectLayout", e, projectType)
    }
}

; Initialize session integration
InitializeSessionIntegration() {
    global DAWAutomation
    
    try {
        ; Setup file monitoring for project files
        if (DAWAutomation["SessionIntegration"]["FileMonitoring"]) {
            InitializeFileMonitoring()
        }
        
        ; Initialize session callbacks
        InitializeSessionCallbacks()
        
        DebugLog("DAW_AUTO", "Session integration initialized", 3)
        
    } catch Error as e {
        RecordSystemError("InitializeSessionIntegration", e)
    }
}

; Start automation monitoring
StartAutomationMonitoring() {
    try {
        ; Start rule evaluation timer
        SetTimer(EvaluateAutomationRules, 2000)
        
        ; Start trigger monitoring
        SetTimer(MonitorAutomationTriggers, 1000)
        
        DebugLog("DAW_AUTO", "Automation monitoring started", 3)
        
    } catch Error as e {
        RecordSystemError("StartAutomationMonitoring", e)
    }
}

; Evaluate automation rules
EvaluateAutomationRules() {
    global DAWAutomation, AutomationRules
    
    try {
        activeDAW := DAWAutomation["Framework"]["ActiveDAW"]
        
        if (!activeDAW) {
            return
        }
        
        ; Check each automation rule
        for ruleName, rule in AutomationRules {
            if (rule["enabled"]) {
                EvaluateAutomationRule(ruleName, rule)
            }
        }
        
    } catch Error as e {
        RecordSystemError("EvaluateAutomationRules", e)
    }
}

; Evaluate specific automation rule
EvaluateAutomationRule(ruleName, rule) {
    try {
        ; Check if any triggers are active
        for trigger in rule["triggers"] {
            if (IsAutomationTriggerActive(trigger)) {
                ; Execute rule actions
                ExecuteRuleActions(rule["actions"], ruleName)
                break
            }
        }
        
    } catch Error as e {
        RecordSystemError("EvaluateAutomationRule", e, ruleName)
    }
}

; Check if automation trigger is active
IsAutomationTriggerActive(triggerName) {
    try {
        switch triggerName {
            case "OnWindowCreate":
                return CheckWindowCreationTrigger()
            case "OnPluginLoad":
                return CheckPluginLoadTrigger()
            case "OnProjectOpen":
                return CheckProjectOpenTrigger()
            case "OnFileChange":
                return CheckFileChangeTrigger()
            case "OnModeSwitch":
                return CheckModeSwitchTrigger()
            case "OnWindowFocus":
                return CheckWindowFocusTrigger()
            case "OnProjectSave":
                return CheckProjectSaveTrigger()
            case "OnProjectClose":
                return CheckProjectCloseTrigger()
            default:
                return false
        }
    } catch Error as e {
        RecordSystemError("IsAutomationTriggerActive", e, triggerName)
        return false
    }
}

; Execute rule actions
ExecuteRuleActions(actions, ruleName) {
    try {
        for action in actions {
            ExecuteAutomationAction(action, ruleName)
        }
        
    } catch Error as e {
        RecordSystemError("ExecuteRuleActions", e, ruleName)
    }
}

; Execute specific automation action
ExecuteAutomationAction(actionName, ruleName) {
    try {
        switch actionName {
            case "GroupRelatedWindows":
                TriggerAutomaticGrouping()
            case "ApplyLayoutTemplate":
                ApplyCurrentProjectLayout()
            case "SetZOrder":
                OptimizeWindowZOrder()
            case "DetectProjectType":
                DetectProjectType()
            case "LoadProjectLayout":
                LoadProjectSpecificLayout()
            case "ConfigureWorkspace":
                ConfigureDAWWorkspace()
            case "OptimizeForWorkflow":
                OptimizeForCurrentWorkflow()
            case "AdjustWindowPriorities":
                AdjustWindowPriorities()
            case "UpdateLayout":
                OptimizeWindowPositions()
            case "SaveLayoutState":
                SaveCurrentLayoutState()
            case "BackupPreferences":
                BackupDAWPreferences()
            case "CleanupWindows":
                CleanupClosedWindows()
            default:
                DebugLog("DAW_AUTO", "Unknown automation action: " . actionName, 2)
        }
        
        DebugLog("DAW_AUTO", "Executed action: " . actionName . " for rule: " . ruleName, 3)
        
    } catch Error as e {
        RecordSystemError("ExecuteAutomationAction", e, actionName)
    }
}

; Custom automation rule management
LoadCustomAutomationRules() {
    try {
        customRulesFile := A_ScriptDir . "\Data\CustomAutomationRules.json"
        
        if (FileExist(customRulesFile)) {
            rulesText := FileRead(customRulesFile)
            customRules := JSON.parse(rulesText)
            
            ; Merge custom rules with default rules
            for ruleName, rule in customRules {
                AutomationRules[ruleName] := rule
            }
            
            DebugLog("DAW_AUTO", "Loaded custom automation rules", 3)
        }
        
    } catch Error as e {
        RecordSystemError("LoadCustomAutomationRules", e)
    }
}

; Save custom automation rules
SaveCustomAutomationRules() {
    global AutomationRules
    
    try {
        customRulesFile := A_ScriptDir . "\Data\CustomAutomationRules.json"
        
        if (!DirExist(A_ScriptDir . "\Data")) {
            DirCreate(A_ScriptDir . "\Data")
        }
        
        ; Filter out default rules and save only custom ones
        customRules := Map()
        defaultRuleNames := ["WindowCreation", "ProjectLoad", "WorkflowMode", "SessionState"]
        
        for ruleName, rule in AutomationRules {
            if (!HasValue(defaultRuleNames, ruleName)) {
                customRules[ruleName] := rule
            }
        }
        
        rulesText := JSON.stringify(customRules, 2)
        FileAppend(rulesText, customRulesFile)
        
        DebugLog("DAW_AUTO", "Saved custom automation rules", 3)
        return true
        
    } catch Error as e {
        RecordSystemError("SaveCustomAutomationRules", e)
        return false
    }
}

; DAW automation hotkeys
^!+a:: {  ; Ctrl+Alt+Shift+A - Toggle DAW automation
    global DAWAutomation
    
    DAWAutomation["Framework"]["Enabled"] := !DAWAutomation["Framework"]["Enabled"]
    status := DAWAutomation["Framework"]["Enabled"] ? "enabled" : "disabled"
    ShowNotification("DAW Automation", "Automation " . status, "info")
}

^!+t:: {  ; Ctrl+Alt+Shift+T - Force project type detection
    DetectProjectType()
    ShowNotification("DAW Automation", "Project type detection triggered", "info", 2000)
}

^!+y:: {  ; Ctrl+Alt+Shift+Y - Show automation status
    ShowDAWAutomationStatus()
}

; Show DAW automation status
ShowDAWAutomationStatus() {
    global DAWAutomation, AutomationRules
    
    try {
        statusText := "DAW Automation Status`n`n"
        
        ; Framework status
        frameworkStatus := DAWAutomation["Framework"]["Enabled"] ? "Enabled" : "Disabled"
        activeDAW := DAWAutomation["Framework"]["ActiveDAW"]
        projectType := DAWAutomation["Framework"]["ProjectType"]
        
        statusText .= "Framework: " . frameworkStatus . "`n"
        statusText .= "Active DAW: " . (activeDAW ? activeDAW : "None") . "`n"
        statusText .= "Project Type: " . (projectType ? projectType : "Unknown") . "`n`n"
        
        ; Automation rules status
        statusText .= "Automation Rules:`n"
        for ruleName, rule in AutomationRules {
            status := rule["enabled"] ? "Enabled" : "Disabled"
            statusText .= "  " . ruleName . ": " . status . "`n"
        }
        
        ; Project awareness
        statusText .= "`nProject Awareness:`n"
        statusText .= "  Auto Layout Switching: " . (DAWAutomation["ProjectAwareness"]["AutoLayoutSwitching"] ? "Yes" : "No") . "`n"
        statusText .= "  File Monitoring: " . (DAWAutomation["SessionIntegration"]["FileMonitoring"] ? "Yes" : "No") . "`n"
        
        MsgBox(statusText, "DAW Automation Status", "OK Icon64")
        
    } catch Error as e {
        RecordSystemError("ShowDAWAutomationStatus", e)
    }
}

; Helper functions for DAW automation
IsDAWWindow(hwnd, dawName) {
    global DAWProfiles
    
    try {
        if (!DAWProfiles.Has(dawName)) {
            return false
        }
        
        profile := DAWProfiles[dawName]
        windowPatterns := profile["windowPatterns"]
        title := WinGetTitle("ahk_id " . hwnd)
        
        for pattern in windowPatterns {
            if (title ~= pattern) {
                return true
            }
        }
        
        return false
        
    } catch Error as e {
        RecordSystemError("IsDAWWindow", e, dawName)
        return false
    }
}

; Initialize DAW automation on startup
SetTimer(() => {
    InitializeDAWAutomation()
}, -6000)  ; Initialize after 6 second delay
