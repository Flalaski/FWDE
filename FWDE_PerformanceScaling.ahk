; ===================================================================
; FWDE Adaptive Performance Scaling System
; Dynamic system resource monitoring and performance optimization
; ===================================================================

; Global performance scaling system
global PerformanceScaling := Map(
    "Enabled", true,
    "AutoAdjust", true,
    "CurrentQualityLevel", "Medium",
    "ResourceMonitoring", Map(
        "CPUUsage", 0,
        "MemoryUsage", 0,
        "DiskIO", 0,
        "LastUpdate", 0,
        "UpdateInterval", 2000,
        "HistorySize", 30,
        "History", Map(
            "CPU", [],
            "Memory", [],
            "DiskIO", []
        )
    ),
    "FrameRateManager", Map(
        "TargetFrameTime", 16.67,  ; 60 FPS target
        "ActualFrameTime", 16.67,
        "FrameTimeHistory", [],
        "FrameTimeVariance", 0,
        "LastFrameTime", 0,
        "AdaptiveTimers", Map(
            "Physics", 1,
            "Visual", 2
        )
    ),
    "PerformanceBudgets", Map(
        "PhysicsCalculation", 8,    ; Max 8ms per physics update
        "WindowMovement", 4,        ; Max 4ms per movement update
        "VisualFeedback", 2,        ; Max 2ms per visual update
        "LayoutOptimization", 20,   ; Max 20ms per optimization
        "PluginDetection", 5        ; Max 5ms per detection cycle
    ),
    "QualityLevels", Map(
        "Ultra", Map(
            "description", "Maximum quality for high-end systems",
            "PhysicsTimeStep", 1,
            "VisualTimeStep", 1,
            "AdvancedVisuals", true,
            "ComplexPhysics", true,
            "DetailedLogging", true,
            "ResourceThreshold", 0.3
        ),
        "High", Map(
            "description", "High quality for powerful systems",
            "PhysicsTimeStep", 1,
            "VisualTimeStep", 2,
            "AdvancedVisuals", true,
            "ComplexPhysics", true,
            "DetailedLogging", false,
            "ResourceThreshold", 0.5
        ),
        "Medium", Map(
            "description", "Balanced quality for most systems",
            "PhysicsTimeStep", 2,
            "VisualTimeStep", 3,
            "AdvancedVisuals", true,
            "ComplexPhysics", false,
            "DetailedLogging", false,
            "ResourceThreshold", 0.7
        ),
        "Low", Map(
            "description", "Performance optimized for older systems",
            "PhysicsTimeStep", 3,
            "VisualTimeStep", 5,
            "AdvancedVisuals", false,
            "ComplexPhysics", false,
            "DetailedLogging", false,
            "ResourceThreshold", 0.85
        ),
        "Minimal", Map(
            "description", "Minimum resource usage for limited systems",
            "PhysicsTimeStep", 5,
            "VisualTimeStep", 10,
            "AdvancedVisuals", false,
            "ComplexPhysics", false,
            "DetailedLogging", false,
            "ResourceThreshold", 1.0
        )
    ),
    "ThresholdSettings", Map(
        "CPUCritical", 90,      ; Critical CPU usage threshold
        "CPUHigh", 75,          ; High CPU usage threshold
        "CPUMedium", 50,        ; Medium CPU usage threshold
        "MemoryCritical", 90,   ; Critical memory usage threshold
        "MemoryHigh", 80,       ; High memory usage threshold
        "MemoryMedium", 60,     ; Medium memory usage threshold
        "FrameTimeHigh", 33.33, ; High frame time (30 FPS)
        "FrameTimeMedium", 25,  ; Medium frame time (40 FPS)
        "VarianceHigh", 10,     ; High frame time variance
        "VarianceMedium", 5     ; Medium frame time variance
    )
)

; Initialize performance scaling system
InitializePerformanceScaling() {
    try {
        DebugLog("PERFORMANCE", "Initializing adaptive performance scaling system", 2)
        
        ; Initialize resource monitoring
        InitializeResourceMonitoring()
        
        ; Initialize frame rate management
        InitializeFrameRateManager()
        
        ; Initialize performance budgets
        InitializePerformanceBudgets()
        
        ; Start monitoring and adjustment timers
        StartPerformanceMonitoring()
        
        ; Set initial quality level based on system capabilities
        DetectInitialQualityLevel()
        
        DebugLog("PERFORMANCE", "Performance scaling system initialized successfully", 2)
        ShowNotification("Performance", "Adaptive performance scaling enabled", "success", 3000)
        
        return true
        
    } catch Error as e {
        RecordSystemError("InitializePerformanceScaling", e)
        return false
    }
}

; Start performance monitoring timers
StartPerformanceMonitoring() {
    global PerformanceScaling
    
    try {
        updateInterval := PerformanceScaling["ResourceMonitoring"]["UpdateInterval"]
        
        ; Start resource monitoring
        SetTimer(MonitorSystemResources, updateInterval)
        
        ; Start frame rate monitoring
        SetTimer(UpdateFrameRateMetrics, 100)  ; High frequency for accurate frame timing
        
        ; Start performance evaluation
        SetTimer(EvaluatePerformanceAdjustments, 5000)  ; Every 5 seconds
        
        DebugLog("PERFORMANCE", "Performance monitoring timers started", 3)
        
    } catch Error as e {
        RecordSystemError("StartPerformanceMonitoring", e)
    }
}

; Monitor system resources continuously
MonitorSystemResources() {
    global PerformanceScaling
    
    try {
        ; Get current resource usage
        cpuUsage := GetCPUUsage()
        memoryUsage := GetMemoryUsage()
        diskIO := GetDiskIOUsage()
        
        ; Update current readings
        monitoring := PerformanceScaling["ResourceMonitoring"]
        monitoring["CPUUsage"] := cpuUsage
        monitoring["MemoryUsage"] := memoryUsage
        monitoring["DiskIO"] := diskIO
        monitoring["LastUpdate"] := A_TickCount
        
        ; Update history
        UpdateResourceHistory(cpuUsage, memoryUsage, diskIO)
        
        ; Check for critical thresholds
        CheckResourceThresholds()
        
    } catch Error as e {
        RecordSystemError("MonitorSystemResources", e)
    }
}

; Get current CPU usage percentage
GetCPUUsage() {
    try {
        ; Use WMI to get CPU usage (simplified implementation)
        ; In production, this would use more sophisticated CPU monitoring
        
        ; Get processor time counter
        counter := 0
        
        ; Simplified CPU usage calculation
        ; This would be replaced with actual WMI or performance counter queries
        result := DllCall("GetSystemTimes", "Ptr*", &idleTime := 0, "Ptr*", &kernelTime := 0, "Ptr*", &userTime := 0)
        
        if (result) {
            ; Calculate CPU usage from system times
            ; This is a simplified version - production would track deltas over time
            totalTime := kernelTime + userTime
            if (totalTime > 0) {
                counter := ((totalTime - idleTime) / totalTime) * 100
            }
        }
        
        ; Fallback to process-specific monitoring if system-wide fails
        if (counter == 0) {
            ; Monitor our own process as a proxy
            counter := Min(ProcessGetWorkingSet() / (1024 * 1024 * 100), 100)  ; Rough approximation
        }
        
        return Min(Max(counter, 0), 100)
        
    } catch Error as e {
        RecordSystemError("GetCPUUsage", e)
        return 0
    }
}

; Get current memory usage percentage
GetMemoryUsage() {
    try {
        ; Get memory status using GlobalMemoryStatusEx
        memStatus := Buffer(64, 0)
        NumPut("UInt", 64, memStatus, 0)  ; Set structure size
        
        result := DllCall("kernel32.dll\GlobalMemoryStatusEx", "Ptr", memStatus)
        
        if (result) {
            ; Extract memory load percentage
            memoryLoad := NumGet(memStatus, 4, "UInt")
            return memoryLoad
        }
        
        ; Fallback method
        totalPhys := 0, availPhys := 0
        result := DllCall("kernel32.dll\GetPhysicallyInstalledSystemMemory", "UInt64*", &totalPhys)
        
        if (result && totalPhys > 0) {
            ; Rough approximation using process working set
            processMemory := ProcessGetWorkingSet()
            return Min((processMemory / (totalPhys * 1024)) * 100, 100)
        }
        
        return 0
        
    } catch Error as e {
        RecordSystemError("GetMemoryUsage", e)
        return 0
    }
}

; Get disk I/O usage (simplified)
GetDiskIOUsage() {
    try {
        ; Simplified disk I/O monitoring
        ; In production, this would monitor actual disk queue length and transfer rates
        
        ; For now, return a low baseline value
        ; This would be replaced with actual disk performance counters
        return 0
        
    } catch Error as e {
        RecordSystemError("GetDiskIOUsage", e)
        return 0
    }
}

; Update resource history for trend analysis
UpdateResourceHistory(cpuUsage, memoryUsage, diskIO) {
    global PerformanceScaling
    
    try {
        history := PerformanceScaling["ResourceMonitoring"]["History"]
        historySize := PerformanceScaling["ResourceMonitoring"]["HistorySize"]
        
        ; Add new readings
        history["CPU"].Push(cpuUsage)
        history["Memory"].Push(memoryUsage)
        history["DiskIO"].Push(diskIO)
        
        ; Maintain history size
        if (history["CPU"].Length > historySize) {
            history["CPU"].RemoveAt(1)
        }
        if (history["Memory"].Length > historySize) {
            history["Memory"].RemoveAt(1)
        }
        if (history["DiskIO"].Length > historySize) {
            history["DiskIO"].RemoveAt(1)
        }
        
    } catch Error as e {
        RecordSystemError("UpdateResourceHistory", e)
    }
}

; Check resource thresholds and trigger performance adjustments
CheckResourceThresholds() {
    global PerformanceScaling
    
    try {
        monitoring := PerformanceScaling["ResourceMonitoring"]
        thresholds := PerformanceScaling["ThresholdSettings"]
        
        cpuUsage := monitoring["CPUUsage"]
        memoryUsage := monitoring["MemoryUsage"]
        
        ; Check for critical resource usage
        if (cpuUsage > thresholds["CPUCritical"] || memoryUsage > thresholds["MemoryCritical"]) {
            TriggerEmergencyPerformanceReduction()
        } else if (cpuUsage > thresholds["CPUHigh"] || memoryUsage > thresholds["MemoryHigh"]) {
            TriggerPerformanceReduction()
        }
        
    } catch Error as e {
        RecordSystemError("CheckResourceThresholds", e)
    }
}

; Initialize frame rate management system
InitializeFrameRateManager() {
    global PerformanceScaling
    
    try {
        frameManager := PerformanceScaling["FrameRateManager"]
        
        ; Initialize frame timing
        frameManager["LastFrameTime"] := A_TickCount
        frameManager["FrameTimeHistory"] := []
        frameManager["FrameTimeVariance"] := 0
        
        DebugLog("PERFORMANCE", "Frame rate manager initialized", 3)
        
    } catch Error as e {
        RecordSystemError("InitializeFrameRateManager", e)
    }
}

; Update frame rate metrics continuously
UpdateFrameRateMetrics() {
    global PerformanceScaling
    
    try {
        frameManager := PerformanceScaling["FrameRateManager"]
        currentTime := A_TickCount
        
        if (frameManager["LastFrameTime"] > 0) {
            frameTime := currentTime - frameManager["LastFrameTime"]
            frameManager["ActualFrameTime"] := frameTime
            
            ; Update frame time history
            frameManager["FrameTimeHistory"].Push(frameTime)
            if (frameManager["FrameTimeHistory"].Length > 60) {  ; Keep last 60 frames
                frameManager["FrameTimeHistory"].RemoveAt(1)
            }
            
            ; Calculate frame time variance
            if (frameManager["FrameTimeHistory"].Length > 10) {
                frameManager["FrameTimeVariance"] := CalculateVariance(frameManager["FrameTimeHistory"])
            }
        }
        
        frameManager["LastFrameTime"] := currentTime
        
    } catch Error as e {
        RecordSystemError("UpdateFrameRateMetrics", e)
    }
}

; Calculate variance for frame time stability
CalculateVariance(values) {
    try {
        if (values.Length == 0) {
            return 0
        }
        
        ; Calculate mean
        sum := 0
        for value in values {
            sum += value
        }
        mean := sum / values.Length
        
        ; Calculate variance
        varianceSum := 0
        for value in values {
            varianceSum += (value - mean) ** 2
        }
        
        return varianceSum / values.Length
        
    } catch Error as e {
        RecordSystemError("CalculateVariance", e)
        return 0
    }
}

; Initialize performance budget management
InitializePerformanceBudgets() {
    global PerformanceScaling
    
    try {
        budgets := PerformanceScaling["PerformanceBudgets"]
        
        ; Initialize budget tracking
        budgets["BudgetHistory"] := []
        budgets["UsedBudget"] := Map(
            "PhysicsCalculation", 0,
            "WindowMovement", 0,
            "VisualFeedback", 0,
            "LayoutOptimization", 0,
            "PluginDetection", 0
        )
        
        DebugLog("PERFORMANCE", "Performance budgets initialized", 3)
        
    } catch Error as e {
        RecordSystemError("InitializePerformanceBudgets", e)
    }
}

; Record operation timing for budget management
RecordOperationTiming(operation, startTime, endTime) {
    global PerformanceScaling
    
    try {
        duration := endTime - startTime
        budgets := PerformanceScaling["PerformanceBudgets"]
        
        ; Update used budget
        if (budgets["UsedBudget"].Has(operation)) {
            budgets["UsedBudget"][operation] := duration
        }
        
        ; Update performance metrics
        if (!PerfTimers.Has(operation)) {
            PerfTimers[operation] := Map(
                "totalTime", 0,
                "callCount", 0,
                "avgTime", 0,
                "minTime", 999999,
                "maxTime", 0
            )
        }
        
        timer := PerfTimers[operation]
        timer["totalTime"] += duration
        timer["callCount"] += 1
        timer["avgTime"] := timer["totalTime"] / timer["callCount"]
        timer["minTime"] := Min(timer["minTime"], duration)
        timer["maxTime"] := Max(timer["maxTime"], duration)
        
    } catch Error as e {
        RecordSystemError("RecordOperationTiming", e)
    }
}

; Evaluate and apply performance adjustments
EvaluatePerformanceAdjustments() {
    global PerformanceScaling
    
    try {
        if (!PerformanceScaling["AutoAdjust"]) {
            return
        }
        
        ; Analyze recent performance data
        performanceScore := CalculatePerformanceScore()
        
        ; Determine if adjustment is needed
        currentQuality := PerformanceScaling["CurrentQualityLevel"]
        recommendedQuality := RecommendQualityLevel(performanceScore)
        
        if (recommendedQuality != currentQuality) {
            DebugLog("PERFORMANCE", "Performance adjustment: " . currentQuality . " -> " . recommendedQuality, 2)
            ApplyQualityLevel(recommendedQuality)
            
            ShowNotification("Performance", 
                "Quality adjusted to " . recommendedQuality . " based on system load", 
                "info", 4000)
        }
        
    } catch Error as e {
        RecordSystemError("EvaluatePerformanceAdjustments", e)
    }
}

; Calculate overall performance score
CalculatePerformanceScore() {
    global PerformanceScaling
    
    try {
        score := 1.0  ; Perfect score = 1.0, worse performance = higher score
        
        ; Factor in CPU usage
        cpuUsage := PerformanceScaling["ResourceMonitoring"]["CPUUsage"]
        if (cpuUsage > 50) {
            score += (cpuUsage - 50) / 50 * 0.5  ; Add up to 0.5 for high CPU
        }
        
        ; Factor in memory usage
        memoryUsage := PerformanceScaling["ResourceMonitoring"]["MemoryUsage"]
        if (memoryUsage > 70) {
            score += (memoryUsage - 70) / 30 * 0.3  ; Add up to 0.3 for high memory
        }
        
        ; Factor in frame time
        frameTime := PerformanceScaling["FrameRateManager"]["ActualFrameTime"]
        targetFrameTime := PerformanceScaling["FrameRateManager"]["TargetFrameTime"]
        if (frameTime > targetFrameTime) {
            score += (frameTime - targetFrameTime) / targetFrameTime * 0.4  ; Add for slow frames
        }
        
        ; Factor in frame time variance (jitter)
        variance := PerformanceScaling["FrameRateManager"]["FrameTimeVariance"]
        if (variance > 5) {
            score += (variance - 5) / 10 * 0.2  ; Add for jittery performance
        }
        
        return score
        
    } catch Error as e {
        RecordSystemError("CalculatePerformanceScore", e)
        return 1.0
    }
}

; Recommend quality level based on performance score
RecommendQualityLevel(performanceScore) {
    try {
        ; Quality level thresholds
        if (performanceScore <= 1.1) {
            return "Ultra"
        } else if (performanceScore <= 1.3) {
            return "High"
        } else if (performanceScore <= 1.6) {
            return "Medium"
        } else if (performanceScore <= 2.0) {
            return "Low"
        } else {
            return "Minimal"
        }
        
    } catch Error as e {
        RecordSystemError("RecommendQualityLevel", e)
        return "Medium"
    }
}

; Apply quality level settings
ApplyQualityLevel(qualityLevel) {
    global PerformanceScaling, Config
    
    try {
        if (!PerformanceScaling["QualityLevels"].Has(qualityLevel)) {
            DebugLog("PERFORMANCE", "Unknown quality level: " . qualityLevel, 1)
            return false
        }
        
        quality := PerformanceScaling["QualityLevels"][qualityLevel]
        
        ; Apply physics settings
        if (quality.Has("PhysicsTimeStep")) {
            Config["PhysicsTimeStep"] := quality["PhysicsTimeStep"]
        }
        
        if (quality.Has("VisualTimeStep")) {
            Config["VisualTimeStep"] := quality["VisualTimeStep"]
        }
        
        ; Apply visual settings
        if (quality.Has("AdvancedVisuals")) {
            VisualFeedback["WindowBorders"]["Enabled"] := quality["AdvancedVisuals"]
            VisualFeedback["PhysicsOverlay"]["Enabled"] := quality["AdvancedVisuals"] && quality.Get("ComplexPhysics", false)
        }
        
        ; Apply logging settings
        if (quality.Has("DetailedLogging")) {
            ; Adjust logging verbosity (implementation depends on logging system)
        }
        
        ; Update timers with new intervals
        UpdateAdaptiveTimers(quality)
        
        PerformanceScaling["CurrentQualityLevel"] := qualityLevel
        
        DebugLog("PERFORMANCE", "Applied quality level: " . qualityLevel, 2)
        return true
        
    } catch Error as e {
        RecordSystemError("ApplyQualityLevel", e, qualityLevel)
        return false
    }
}

; Update timer intervals based on quality settings
UpdateAdaptiveTimers(quality) {
    global PerformanceScaling
    
    try {
        physicsInterval := quality.Get("PhysicsTimeStep", 1)
        visualInterval := quality.Get("VisualTimeStep", 2)
        
        ; Update main physics timer
        if (A_Timer) {
            ; Note: Timer updates would need to be implemented in main script
        }
        
        ; Update visual feedback timer
        SetTimer(UpdateWindowBorders, visualInterval * 50)  ; Scale visual updates
        
        ; Store adaptive timer settings
        PerformanceScaling["FrameRateManager"]["AdaptiveTimers"]["Physics"] := physicsInterval
        PerformanceScaling["FrameRateManager"]["AdaptiveTimers"]["Visual"] := visualInterval
        
    } catch Error as e {
        RecordSystemError("UpdateAdaptiveTimers", e)
    }
}

; Emergency performance reduction for critical resource usage
TriggerEmergencyPerformanceReduction() {
    global PerformanceScaling
    
    try {
        DebugLog("PERFORMANCE", "Emergency performance reduction triggered", 1)
        
        ; Force minimal quality level
        ApplyQualityLevel("Minimal")
        
        ; Additional emergency measures
        ; Pause non-critical systems temporarily
        SetTimer(UpdateWindowBorders, 0)  ; Disable visual updates
        
        ; Show warning notification
        ShowNotification("Performance", 
            "Emergency performance reduction activated due to high system load", 
            "warning", 8000)
        
        ; Set recovery timer
        SetTimer(() => RecoverFromEmergencyReduction(), -10000)
        
    } catch Error as e {
        RecordSystemError("TriggerEmergencyPerformanceReduction", e)
    }
}

; Standard performance reduction for high resource usage
TriggerPerformanceReduction() {
    global PerformanceScaling
    
    try {
        currentQuality := PerformanceScaling["CurrentQualityLevel"]
        
        ; Step down one quality level
        newQuality := ""
        switch currentQuality {
            case "Ultra":
                newQuality := "High"
            case "High":
                newQuality := "Medium"
            case "Medium":
                newQuality := "Low"
            case "Low":
                newQuality := "Minimal"
            default:
                return  ; Already at minimum
        }
        
        ApplyQualityLevel(newQuality)
        
        ShowNotification("Performance", 
            "Performance reduced to " . newQuality . " due to high system load", 
            "info", 3000)
        
    } catch Error as e {
        RecordSystemError("TriggerPerformanceReduction", e)
    }
}

; Recover from emergency performance reduction
RecoverFromEmergencyReduction() {
    try {
        DebugLog("PERFORMANCE", "Attempting recovery from emergency reduction", 2)
        
        ; Re-enable visual updates
        SetTimer(UpdateWindowBorders, 500)
        
        ; Evaluate if we can increase quality
        performanceScore := CalculatePerformanceScore()
        recommendedQuality := RecommendQualityLevel(performanceScore)
        
        if (recommendedQuality != "Minimal") {
            ApplyQualityLevel(recommendedQuality)
            ShowNotification("Performance", 
                "Performance recovered to " . recommendedQuality, 
                "success", 3000)
        }
        
    } catch Error as e {
        RecordSystemError("RecoverFromEmergencyReduction", e)
    }
}

; Detect initial quality level based on system capabilities
DetectInitialQualityLevel() {
    try {
        ; Wait a moment for initial resource readings
        Sleep(1000)
        
        ; Get baseline performance score
        performanceScore := CalculatePerformanceScore()
        recommendedQuality := RecommendQualityLevel(performanceScore)
        
        ; Apply recommended quality level
        ApplyQualityLevel(recommendedQuality)
        
        DebugLog("PERFORMANCE", "Initial quality level set to: " . recommendedQuality, 2)
        
    } catch Error as e {
        RecordSystemError("DetectInitialQualityLevel", e)
        ; Default to medium quality on error
        ApplyQualityLevel("Medium")
    }
}

; Performance scaling hotkeys
^!+q:: {  ; Ctrl+Alt+Shift+Q - Toggle auto performance adjustment
    global PerformanceScaling
    
    PerformanceScaling["AutoAdjust"] := !PerformanceScaling["AutoAdjust"]
    status := PerformanceScaling["AutoAdjust"] ? "enabled" : "disabled"
    ShowNotification("Performance", "Auto performance adjustment " . status, "info")
}

^!+w:: {  ; Ctrl+Alt+Shift+W - Show performance metrics
    ShowPerformanceMetrics()
}

^!+e:: {  ; Ctrl+Alt+Shift+E - Force quality level change
    CycleQualityLevel()
}

; Show comprehensive performance metrics
ShowPerformanceMetrics() {
    global PerformanceScaling, PerfTimers
    
    try {
        monitoring := PerformanceScaling["ResourceMonitoring"]
        frameManager := PerformanceScaling["FrameRateManager"]
        
        metricsText := "FWDE Performance Metrics`n`n"
        
        ; Resource usage
        metricsText .= "Resource Usage:`n"
        metricsText .= "  CPU: " . Round(monitoring["CPUUsage"], 1) . "%`n"
        metricsText .= "  Memory: " . Round(monitoring["MemoryUsage"], 1) . "%`n"
        metricsText .= "  Disk I/O: " . Round(monitoring["DiskIO"], 1) . "%`n`n"
        
        ; Frame timing
        metricsText .= "Frame Timing:`n"
        metricsText .= "  Target: " . Round(frameManager["TargetFrameTime"], 1) . "ms`n"
        metricsText .= "  Actual: " . Round(frameManager["ActualFrameTime"], 1) . "ms`n"
        metricsText .= "  Variance: " . Round(frameManager["FrameTimeVariance"], 1) . "`n`n"
        
        ; Quality settings
        metricsText .= "Quality Level: " . PerformanceScaling["CurrentQualityLevel"] . "`n"
        metricsText .= "Auto Adjust: " . (PerformanceScaling["AutoAdjust"] ? "Enabled" : "Disabled") . "`n`n"
        
        ; Operation timings
        metricsText .= "Operation Performance:`n"
        for operation, timer in PerfTimers {
            if (timer["callCount"] > 0) {
                metricsText .= "  " . operation . ": " . Round(timer["avgTime"], 1) . "ms avg`n"
            }
        }
        
        MsgBox(metricsText, "Performance Metrics", "OK Icon64")
        
    } catch Error as e {
        RecordSystemError("ShowPerformanceMetrics", e)
    }
}

; Cycle through quality levels manually
CycleQualityLevel() {
    global PerformanceScaling
    
    try {
        currentQuality := PerformanceScaling["CurrentQualityLevel"]
        
        newQuality := ""
        switch currentQuality {
            case "Ultra":
                newQuality := "High"
            case "High":
                newQuality := "Medium"
            case "Medium":
                newQuality := "Low"
            case "Low":
                newQuality := "Minimal"
            case "Minimal":
                newQuality := "Ultra"
            default:
                newQuality := "Medium"
        }
        
        ApplyQualityLevel(newQuality)
        ShowNotification("Performance", "Quality level: " . newQuality, "info", 2000)
        
    } catch Error as e {
        RecordSystemError("CycleQualityLevel", e)
    }
}

; Helper function to get working set of current process
ProcessGetWorkingSet() {
    try {
        hProcess := DllCall("GetCurrentProcess", "Ptr")
        workingSetSize := 0
        
        ; Get process memory info
        memInfo := Buffer(40, 0)
        result := DllCall("psapi.dll\GetProcessMemoryInfo", "Ptr", hProcess, "Ptr", memInfo, "UInt", 40)
        
        if (result) {
            workingSetSize := NumGet(memInfo, 4, "UPtr")  ; WorkingSetSize
        }
        
        return workingSetSize
        
    } catch Error as e {
        RecordSystemError("ProcessGetWorkingSet", e)
        return 0
    }
}

; Initialize performance scaling on startup
SetTimer(() => {
    InitializePerformanceScaling()
}, -2000)  ; Initialize after 2 second delay
