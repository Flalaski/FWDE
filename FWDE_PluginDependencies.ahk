; ===================================================================
; FWDE Plugin Window Dependency Tracking System
; Advanced parent-child window relationship detection and management
; ===================================================================

; Global plugin dependency tracking system
global PluginDependencies := Map(
    "WindowHierarchy", Map(),       ; Parent-child relationships
    "PluginGroups", Map(),          ; Grouped plugin windows
    "DependencyRules", Map(),       ; Plugin-specific dependency rules
    "GroupBehaviors", Map(),        ; Group movement and positioning behaviors
    "LifecycleTracking", Map(),     ; Plugin window lifecycle management
    "SessionState", Map(),          ; Persistent state across DAW sessions
    "AutoGrouping", Map(            ; Automatic grouping configuration
        "Enabled", true,
        "MaxGroupSize", 8,
        "GroupingDistance", 200,
        "TimeWindow", 5000,
        "MinGroupMembers", 2
    )
)

; Plugin group types and behaviors
global PluginGroupTypes := Map(
    "InstrumentRack", Map(
        "description", "Instrument plugin with multiple components",
        "maxMembers", 12,
        "movementCoherence", 0.9,
        "positioningStrategy", "Clustered",
        "zOrderManagement", "Hierarchical"
    ),
    "EffectChain", Map(
        "description", "Chain of effect plugins",
        "maxMembers", 8,
        "movementCoherence", 0.8,
        "positioningStrategy", "Linear",
        "zOrderManagement", "Sequential"
    ),
    "MixerSection", Map(
        "description", "Mixer channel components",
        "maxMembers", 6,
        "movementCoherence", 0.95,
        "positioningStrategy", "Vertical",
        "zOrderManagement", "Grouped"
    ),
    "DrumKit", Map(
        "description", "Drum machine components",
        "maxMembers", 16,
        "movementCoherence", 0.7,
        "positioningStrategy", "Grid",
        "zOrderManagement", "Layered"
    ),
    "Sampler", Map(
        "description", "Sampler instrument components",
        "maxMembers", 10,
        "movementCoherence", 0.85,
        "positioningStrategy", "Radial",
        "zOrderManagement", "Centered"
    )
)

; Initialize plugin dependency tracking system
InitializePluginDependencies() {
    try {
        DebugLog("DEPENDENCIES", "Initializing plugin dependency tracking system", 2)
        
        ; Clear existing data
        ClearDependencyTracking()
        
        ; Initialize hierarchy detection
        InitializeHierarchyDetection()
        
        ; Load dependency rules
        LoadPluginDependencyRules()
        
        ; Initialize group behaviors
        InitializeGroupBehaviors()
        
        ; Start lifecycle monitoring
        StartLifecycleMonitoring()
        
        ; Start automatic grouping
        if (PluginDependencies["AutoGrouping"]["Enabled"]) {
            StartAutomaticGrouping()
        }
        
        LogMessage("Plugin dependency tracking system initialized successfully", 2)
        return true
        
    } catch Error as e {
        RecordSystemError("Plugin Dependencies", "Failed to initialize dependency tracking: " . e.message)
        return false
    }
}

; Clear all dependency tracking data
ClearDependencyTracking() {
    global PluginDependencies
    
    PluginDependencies["WindowHierarchy"].Clear()
    PluginDependencies["PluginGroups"].Clear()
    PluginDependencies["LifecycleTracking"].Clear()
    PluginDependencies["SessionState"].Clear()
}

; Parent-child window relationship detection
InitializeHierarchyDetection() {
    try {
        DebugLog("HIERARCHY", "Initializing window hierarchy detection", 2)
        
        ; Start hierarchy monitoring timer
        SetTimer(DetectWindowHierarchies, 2000)
        
        ; Initialize hierarchy analysis rules
        InitializeHierarchyRules()
        
        LogMessage("Window hierarchy detection initialized", 3)
        
    } catch Error as e {
        RecordSystemError("Hierarchy Detection", "Failed to initialize: " . e.message)
    }
}

; Detect parent-child window relationships
DetectWindowHierarchies() {
    global PluginDependencies, DAWPluginDatabase
    
    try {
        ; Get all current plugin windows
        pluginWindows := GetAllPluginWindows()
        
        if (pluginWindows.Length == 0) {
            return
        }
        
        ; Analyze relationships between plugin windows
        for parentWindow in pluginWindows {
            AnalyzeWindowRelationships(parentWindow, pluginWindows)
        }
        
        ; Update hierarchy map
        UpdateHierarchyMap(pluginWindows)
        
        ; Trigger automatic grouping if new relationships found
        if (PluginDependencies["AutoGrouping"]["Enabled"]) {
            TriggerAutomaticGrouping()
        }
        
    } catch Error as e {
        RecordSystemError("Hierarchy Detection", "Failed to detect hierarchies: " . e.message)
    }
}

; Analyze relationships between windows
AnalyzeWindowRelationships(parentWindow, allWindows) {
    try {
        parentHwnd := parentWindow["hwnd"]
        relationships := []
        
        ; Check for actual parent-child relationships using Windows API
        for childWindow in allWindows {
            if (childWindow["hwnd"] == parentHwnd) {
                continue
            }
            
            relationship := DetectWindowRelationship(parentHwnd, childWindow["hwnd"])
            if (relationship["type"] != "None") {
                relationships.Push(Map(
                    "child", childWindow["hwnd"],
                    "type", relationship["type"],
                    "confidence", relationship["confidence"],
                    "detected", A_Now
                ))
            }
        }
        
        ; Store relationships if any found
        if (relationships.Length > 0) {
            PluginDependencies["WindowHierarchy"][parentHwnd] := Map(
                "children", relationships,
                "parentInfo", parentWindow,
                "lastUpdated", A_Now
            )
            
            DebugLog("HIERARCHY", "Found " . relationships.Length . " relationships for window " . parentHwnd, 3)
        }
        
    } catch Error as e {
        RecordSystemError("Relationship Analysis", "Failed to analyze relationships: " . e.message)
    }
}

; Detect specific window relationship using multiple methods
DetectWindowRelationship(parentHwnd, childHwnd) {
    try {
        ; Method 1: Windows API parent-child relationship
        apiParent := DllCall("GetParent", "Ptr", childHwnd, "Ptr")
        if (apiParent == parentHwnd) {
            return Map("type", "APIParent", "confidence", 95)
        }
        
        ; Method 2: Owner window relationship
        owner := DllCall("GetWindow", "Ptr", childHwnd, "UInt", 4, "Ptr")  ; GW_OWNER
        if (owner == parentHwnd) {
            return Map("type", "Owner", "confidence", 90)
        }
        
        ; Method 3: Process-based relationship
        parentProcess := WinGetProcessName("ahk_id " . parentHwnd)
        childProcess := WinGetProcessName("ahk_id " . childHwnd)
        if (parentProcess == childProcess) {
            ; Same process - check window classes and titles for plugin patterns
            confidence := AnalyzePluginPatternRelationship(parentHwnd, childHwnd)
            if (confidence > 60) {
                return Map("type", "PluginComponent", "confidence", confidence)
            }
        }
        
        ; Method 4: Spatial proximity and timing relationship
        spatialRelation := AnalyzeSpatialRelationship(parentHwnd, childHwnd)
        if (spatialRelation["confidence"] > 70) {
            return Map("type", "Spatial", "confidence", spatialRelation["confidence"])
        }
        
        ; Method 5: Creation time correlation
        timingRelation := AnalyzeTimingRelationship(parentHwnd, childHwnd)
        if (timingRelation["confidence"] > 65) {
            return Map("type", "Temporal", "confidence", timingRelation["confidence"])
        }
        
        return Map("type", "None", "confidence", 0)
        
    } catch Error as e {
        RecordSystemError("Relationship Detection", "Failed to detect relationship: " . e.message)
        return Map("type", "None", "confidence", 0)
    }
}

; Analyze plugin pattern relationships using window properties
AnalyzePluginPatternRelationship(parentHwnd, childHwnd) {
    try {
        parentTitle := WinGetTitle("ahk_id " . parentHwnd)
        childTitle := WinGetTitle("ahk_id " . childHwnd)
        parentClass := WinGetClass("ahk_id " . parentHwnd)
        childClass := WinGetClass("ahk_id " . childHwnd)
        
        confidence := 0
        
        ; Check for common plugin naming patterns
        commonPatterns := [
            "VST", "AU", "Plugin", "FX", "Synth", "Effect",
            "Instrument", "Sampler", "Drum", "Bass", "Lead"
        ]
        
        for pattern in commonPatterns {
            if (InStr(parentTitle, pattern) && InStr(childTitle, pattern)) {
                confidence += 15
            }
        }
        
        ; Check for numbered instances (Plugin 1, Plugin 2, etc.)
        if (RegExMatch(parentTitle, "(.+)\s+(\d+)", &parentMatch) && 
            RegExMatch(childTitle, "(.+)\s+(\d+)", &childMatch)) {
            if (parentMatch[1] == childMatch[1]) {
                confidence += 25
            }
        }
        
        ; Check for sub-window indicators
        subWindowIndicators := ["Editor", "Settings", "Preset", "Browser", "Config"]
        for indicator in subWindowIndicators {
            if (InStr(childTitle, indicator) && InStr(parentTitle, StrReplace(childTitle, indicator, ""))) {
                confidence += 30
            }
        }
        
        ; Check window class relationships
        if (InStr(parentClass, "Plugin") && InStr(childClass, "Plugin")) {
            confidence += 10
        }
        
        return Min(confidence, 100)
        
    } catch Error as e {
        RecordSystemError("Plugin Pattern Analysis", "Failed to analyze patterns: " . e.message)
        return 0
    }
}

; Analyze spatial relationship between windows
AnalyzeSpatialRelationship(parentHwnd, childHwnd) {
    try {
        ; Get window positions
        WinGetPos(&px, &py, &pw, &ph, "ahk_id " . parentHwnd)
        WinGetPos(&cx, &cy, &cw, &ch, "ahk_id " . childHwnd)
        
        ; Calculate distances
        centerDistance := Sqrt((px + pw/2 - cx - cw/2)**2 + (py + ph/2 - cy - ch/2)**2)
        edgeDistance := Min(
            Abs(px - (cx + cw)),  ; Parent left to child right
            Abs((px + pw) - cx),  ; Parent right to child left
            Abs(py - (cy + ch)),  ; Parent top to child bottom
            Abs((py + ph) - cy)   ; Parent bottom to child top
        )
        
        confidence := 0
        
        ; Close proximity indicates relationship
        if (centerDistance < 100) {
            confidence += 40
        } else if (centerDistance < 200) {
            confidence += 25
        } else if (centerDistance < 400) {
            confidence += 10
        }
        
        ; Adjacent positioning indicates relationship
        if (edgeDistance < 20) {
            confidence += 30
        } else if (edgeDistance < 50) {
            confidence += 15
        }
        
        ; Size relationship (child typically smaller)
        childArea := cw * ch
        parentArea := pw * ph
        if (childArea < parentArea * 0.8) {
            confidence += 10
        }
        
        return Map("confidence", confidence, "distance", centerDistance)
        
    } catch Error as e {
        RecordSystemError("Spatial Analysis", "Failed to analyze spatial relationship: " . e.message)
        return Map("confidence", 0, "distance", 0)
    }
}

; Analyze timing relationship between windows
AnalyzeTimingRelationship(parentHwnd, childHwnd) {
    try {
        ; Check if we have creation time data
        lifecycle := PluginDependencies["LifecycleTracking"]
        
        if (!lifecycle.Has(parentHwnd) || !lifecycle.Has(childHwnd)) {
            return Map("confidence", 0, "timeDiff", 0)
        }
        
        parentCreated := lifecycle[parentHwnd]["created"]
        childCreated := lifecycle[childHwnd]["created"]
        
        timeDiff := Abs(DateDiff(parentCreated, childCreated, "Seconds"))
        confidence := 0
        
        ; Windows created close in time are likely related
        if (timeDiff < 2) {
            confidence += 50
        } else if (timeDiff < 5) {
            confidence += 35
        } else if (timeDiff < 10) {
            confidence += 20
        } else if (timeDiff < 30) {
            confidence += 10
        }
        
        return Map("confidence", confidence, "timeDiff", timeDiff)
        
    } catch Error as e {
        RecordSystemError("Timing Analysis", "Failed to analyze timing relationship: " . e.message)
        return Map("confidence", 0, "timeDiff", 0)
    }
}

; Automatic plugin window grouping
StartAutomaticGrouping() {
    try {
        DebugLog("GROUPING", "Starting automatic plugin grouping", 2)
        
        ; Start grouping analysis timer
        SetTimer(AnalyzeAutomaticGrouping, 3000)
        
        LogMessage("Automatic plugin grouping started", 3)
        
    } catch Error as e {
        RecordSystemError("Automatic Grouping", "Failed to start: " . e.message)
    }
}

; Analyze and create automatic groups
AnalyzeAutomaticGrouping() {
    global PluginDependencies
    
    try {
        ; Get all plugin windows
        pluginWindows := GetAllPluginWindows()
        
        if (pluginWindows.Length < PluginDependencies["AutoGrouping"]["MinGroupMembers"]) {
            return
        }
        
        ; Find potential groups based on multiple criteria
        potentialGroups := IdentifyPotentialGroups(pluginWindows)
        
        ; Create or update groups
        for groupData in potentialGroups {
            CreateOrUpdatePluginGroup(groupData)
        }
        
        ; Clean up invalid groups
        CleanupInvalidGroups()
        
    } catch Error as e {
        RecordSystemError("Automatic Grouping Analysis", "Failed to analyze grouping: " . e.message)
    }
}

; Identify potential plugin groups
IdentifyPotentialGroups(pluginWindows) {
    try {
        potentialGroups := []
        groupingDistance := PluginDependencies["AutoGrouping"]["GroupingDistance"]
        
        ; Group by spatial proximity
        spatialGroups := GroupByProximity(pluginWindows, groupingDistance)
        potentialGroups.Append(spatialGroups*)
        
        ; Group by plugin type and developer
        typeGroups := GroupByPluginType(pluginWindows)
        potentialGroups.Append(typeGroups*)
        
        ; Group by hierarchy relationships
        hierarchyGroups := GroupByHierarchy(pluginWindows)
        potentialGroups.Append(hierarchyGroups*)
        
        ; Group by creation timing
        timingGroups := GroupByCreationTiming(pluginWindows)
        potentialGroups.Append(timingGroups*)
        
        return potentialGroups
        
    } catch Error as e {
        RecordSystemError("Group Identification", "Failed to identify groups: " . e.message)
        return []
    }
}

; Group windows by spatial proximity
GroupByProximity(windows, maxDistance) {
    try {
        groups := []
        processed := Set()
        
        for baseWindow in windows {
            if (processed.Has(baseWindow["hwnd"])) {
                continue
            }
            
            group := [baseWindow]
            processed.Add(baseWindow["hwnd"])
            
            ; Find nearby windows
            for otherWindow in windows {
                if (processed.Has(otherWindow["hwnd"])) {
                    continue
                }
                
                distance := CalculateWindowDistance(baseWindow, otherWindow)
                if (distance <= maxDistance) {
                    group.Push(otherWindow)
                    processed.Add(otherWindow["hwnd"])
                }
            }
            
            ; Only create group if it has minimum members
            if (group.Length >= PluginDependencies["AutoGrouping"]["MinGroupMembers"]) {
                groups.Push(Map(
                    "type", "Proximity",
                    "members", group,
                    "confidence", 70,
                    "characteristics", Map("maxDistance", maxDistance)
                ))
            }
        }
        
        return groups
        
    } catch Error as e {
        RecordSystemError("Proximity Grouping", "Failed to group by proximity: " . e.message)
        return []
    }
}

; Group windows by plugin type and developer
GroupByPluginType(windows) {
    try {
        groups := []
        typeGroups := Map()
        
        ; Organize windows by type and developer
        for window in windows {
            pluginInfo := GetPluginInfo(window["hwnd"])
            if (!pluginInfo) {
                continue
            }
            
            key := pluginInfo["developer"] . "|" . pluginInfo["category"]
            
            if (!typeGroups.Has(key)) {
                typeGroups[key] := []
            }
            
            typeGroups[key].Push(window)
        }
        
        ; Create groups from type collections
        for key, windowList in typeGroups {
            if (windowList.Length >= PluginDependencies["AutoGrouping"]["MinGroupMembers"]) {
                parts := StrSplit(key, "|")
                groups.Push(Map(
                    "type", "PluginType",
                    "members", windowList,
                    "confidence", 85,
                    "characteristics", Map(
                        "developer", parts[1],
                        "category", parts[2]
                    )
                ))
            }
        }
        
        return groups
        
    } catch Error as e {
        RecordSystemError("Type Grouping", "Failed to group by type: " . e.message)
        return []
    }
}

; Create or update plugin group
CreateOrUpdatePluginGroup(groupData) {
    global PluginDependencies
    
    try {
        ; Generate group ID
        groupId := GenerateGroupId(groupData)
        
        ; Check if group already exists
        existingGroup := PluginDependencies["PluginGroups"].Get(groupId, "")
        
        if (existingGroup) {
            UpdateExistingGroup(groupId, groupData)
        } else {
            CreateNewGroup(groupId, groupData)
        }
        
        DebugLog("GROUPING", "Created/updated group " . groupId . " with " . groupData["members"].Length . " members", 3)
        
    } catch Error as e {
        RecordSystemError("Group Creation", "Failed to create/update group: " . e.message)
    }
}

; Generate unique group ID
GenerateGroupId(groupData) {
    try {
        ; Create ID based on group characteristics
        baseId := groupData["type"]
        
        if (groupData.Has("characteristics")) {
            chars := groupData["characteristics"]
            if (chars.Has("developer")) {
                baseId .= "_" . chars["developer"]
            }
            if (chars.Has("category")) {
                baseId .= "_" . chars["category"]
            }
        }
        
        ; Add timestamp to ensure uniqueness
        baseId .= "_" . A_TickCount
        
        return baseId
        
    } catch Error as e {
        RecordSystemError("Group ID Generation", "Failed to generate ID: " . e.message)
        return "Group_" . A_TickCount
    }
}

; Create new plugin group
CreateNewGroup(groupId, groupData) {
    global PluginDependencies
    
    try {
        ; Determine group type based on plugin characteristics
        groupType := DetermineGroupType(groupData)
        
        ; Create group object
        group := Map(
            "id", groupId,
            "type", groupType,
            "members", [],
            "leader", "",
            "created", A_Now,
            "lastUpdated", A_Now,
            "behavior", PluginGroupTypes[groupType],
            "physics", Map(
                "cohesion", PluginGroupTypes[groupType]["movementCoherence"],
                "formation", PluginGroupTypes[groupType]["positioningStrategy"]
            ),
            "state", "Active"
        )
        
        ; Add members
        for member in groupData["members"] {
            AddMemberToGroup(group, member["hwnd"])
        }
        
        ; Select group leader (typically largest or first window)
        SelectGroupLeader(group)
        
        ; Store group
        PluginDependencies["PluginGroups"][groupId] := group
        
        ; Apply group behaviors
        ApplyGroupBehaviors(group)
        
        LogMessage("Created plugin group: " . groupId . " (" . groupType . ")", 2)
        
    } catch Error as e {
        RecordSystemError("New Group Creation", "Failed to create group: " . e.message)
    }
}

; Determine appropriate group type
DetermineGroupType(groupData) {
    try {
        if (!groupData.Has("characteristics")) {
            return "InstrumentRack"  ; Default
        }
        
        chars := groupData["characteristics"]
        
        ; Determine by plugin category
        if (chars.Has("category")) {
            switch chars["category"] {
                case "Synth", "Sampler":
                    return "InstrumentRack"
                case "Effect":
                    return "EffectChain"
                case "DrumMachine":
                    return "DrumKit"
                case "Mixer":
                    return "MixerSection"
                default:
                    return "InstrumentRack"
            }
        }
        
        ; Determine by member count
        memberCount := groupData["members"].Length
        if (memberCount > 10) {
            return "DrumKit"
        } else if (memberCount > 6) {
            return "InstrumentRack"
        } else {
            return "EffectChain"
        }
        
    } catch Error as e {
        RecordSystemError("Group Type Determination", "Failed to determine type: " . e.message)
        return "InstrumentRack"
    }
}

; Add member to group
AddMemberToGroup(group, hwnd) {
    try {
        ; Check if already a member
        for member in group["members"] {
            if (member["hwnd"] == hwnd) {
                return false
            }
        }
        
        ; Get window info
        WinGetPos(&x, &y, &w, &h, "ahk_id " . hwnd)
        
        member := Map(
            "hwnd", hwnd,
            "joinedAt", A_Now,
            "role", "Member",
            "position", Map("x", x, "y", y, "width", w, "height", h),
            "constraints", Map(
                "followLeader", true,
                "maintainFormation", true,
                "allowIndependentMovement", false
            )
        )
        
        group["members"].Push(member)
        group["lastUpdated"] := A_Now
        
        return true
        
    } catch Error as e {
        RecordSystemError("Add Group Member", "Failed to add member: " . e.message)
        return false
    }
}

; Select group leader
SelectGroupLeader(group) {
    try {
        if (group["members"].Length == 0) {
            return
        }
        
        ; Find the largest window as leader
        largestArea := 0
        leaderHwnd := ""
        
        for member in group["members"] {
            pos := member["position"]
            area := pos["width"] * pos["height"]
            
            if (area > largestArea) {
                largestArea := area
                leaderHwnd := member["hwnd"]
            }
        }
        
        ; Set leader
        group["leader"] := leaderHwnd
        
        ; Update member roles
        for member in group["members"] {
            if (member["hwnd"] == leaderHwnd) {
                member["role"] := "Leader"
            }
        }
        
        DebugLog("GROUPING", "Selected leader " . leaderHwnd . " for group " . group["id"], 3)
        
    } catch Error as e {
        RecordSystemError("Leader Selection", "Failed to select leader: " . e.message)
    }
}

; Apply group behaviors to physics system
ApplyGroupBehaviors(group) {
    try {
        behavior := group["behavior"]
        
        ; Apply cohesion settings to physics
        for member in group["members"] {
            ; Set group-specific physics parameters
            ApplyGroupPhysicsToWindow(member["hwnd"], group)
        }
        
        ; Set up formation maintenance
        if (behavior.Has("positioningStrategy")) {
            InitializeGroupFormation(group)
        }
        
        DebugLog("GROUPING", "Applied behaviors to group " . group["id"], 3)
        
    } catch Error as e {
        RecordSystemError("Group Behavior Application", "Failed to apply behaviors: " . e.message)
    }
}

; Apply group-specific physics to window
ApplyGroupPhysicsToWindow(hwnd, group) {
    global g
    
    try {
        ; Find window in main window list
        for win in g["Windows"] {
            if (win["hwnd"] == hwnd) {
                ; Set group-specific properties
                win["groupId"] := group["id"]
                win["groupRole"] := GetMemberRole(group, hwnd)
                win["groupCohesion"] := group["physics"]["cohesion"]
                win["groupFormation"] := group["physics"]["formation"]
                
                break
            }
        }
        
    } catch Error as e {
        RecordSystemError("Group Physics Application", "Failed to apply physics: " . e.message)
    }
}

; Get member role in group
GetMemberRole(group, hwnd) {
    try {
        for member in group["members"] {
            if (member["hwnd"] == hwnd) {
                return member["role"]
            }
        }
        return "Member"
    } catch {
        return "Member"
    }
}

; Group-aware physics modifications
ApplyGroupPhysicsModifications(win) {
    global PluginDependencies, Config
    
    try {
        if (!win.Has("groupId")) {
            return  ; Not in a group
        }
        
        group := PluginDependencies["PluginGroups"].Get(win["groupId"], "")
        if (!group) {
            return
        }
        
        ; Apply group cohesion forces
        ApplyGroupCohesionForces(win, group)
        
        ; Apply formation maintenance forces
        ApplyFormationMaintenanceForces(win, group)
        
        ; Apply leader-follower dynamics
        if (win["groupRole"] != "Leader") {
            ApplyFollowerForces(win, group)
        }
        
    } catch Error as e {
        RecordSystemError("Group Physics Modifications", "Failed to apply modifications: " . e.message)
    }
}

; Apply cohesion forces to keep group together
ApplyGroupCohesionForces(win, group) {
    try {
        cohesionStrength := group["physics"]["cohesion"] * Config["RepulsionForce"] * 0.5
        
        ; Calculate center of group
        groupCenter := CalculateGroupCenter(group)
        
        ; Apply attraction to group center
        WinGetPos(&x, &y, &w, &h, "ahk_id " . win["hwnd"])
        centerX := x + w / 2
        centerY := y + h / 2
        
        dx := groupCenter["x"] - centerX
        dy := groupCenter["y"] - centerY
        distance := Sqrt(dx*dx + dy*dy)
        
        if (distance > 0) {
            force := cohesionStrength / (distance + 1)
            win["vx"] += (dx / distance) * force
            win["vy"] += (dy / distance) * force
        }
        
    } catch Error as e {
        RecordSystemError("Group Cohesion Forces", "Failed to apply cohesion: " . e.message)
    }
}

; Calculate center point of group
CalculateGroupCenter(group) {
    try {
        totalX := 0
        totalY := 0
        count := 0
        
        for member in group["members"] {
            if (IsWindowValid(member["hwnd"])) {
                WinGetPos(&x, &y, &w, &h, "ahk_id " . member["hwnd"])
                totalX += x + w / 2
                totalY += y + h / 2
                count++
            }
        }
        
        if (count > 0) {
            return Map("x", totalX / count, "y", totalY / count)
        }
        
        return Map("x", 0, "y", 0)
        
    } catch Error as e {
        RecordSystemError("Group Center Calculation", "Failed to calculate center: " . e.message)
        return Map("x", 0, "y", 0)
    }
}

; Lifecycle monitoring for plugin windows
StartLifecycleMonitoring() {
    try {
        DebugLog("LIFECYCLE", "Starting plugin lifecycle monitoring", 2)
        
        ; Start window lifecycle timer
        SetTimer(MonitorPluginLifecycle, 1000)
        
        LogMessage("Plugin lifecycle monitoring started", 3)
        
    } catch Error as e {
        RecordSystemError("Lifecycle Monitoring", "Failed to start: " . e.message)
    }
}

; Monitor plugin window lifecycle events
MonitorPluginLifecycle() {
    global PluginDependencies
    
    try {
        ; Track new plugin windows
        TrackNewPluginWindows()
        
        ; Update existing window states
        UpdateExistingWindowStates()
        
        ; Cleanup closed windows
        CleanupClosedWindows()
        
        ; Update group memberships
        UpdateGroupMemberships()
        
    } catch Error as e {
        RecordSystemError("Lifecycle Monitoring", "Failed to monitor lifecycle: " . e.message)
    }
}

; Track newly created plugin windows
TrackNewPluginWindows() {
    global PluginDependencies
    
    try {
        allPluginWindows := GetAllPluginWindows()
        lifecycle := PluginDependencies["LifecycleTracking"]
        
        for window in allPluginWindows {
            hwnd := window["hwnd"]
            
            if (!lifecycle.Has(hwnd)) {
                ; New window detected
                lifecycle[hwnd] := Map(
                    "created", A_Now,
                    "pluginInfo", GetPluginInfo(hwnd),
                    "state", "Active",
                    "groupCandidate", true,
                    "lastSeen", A_Now
                )
                
                DebugLog("LIFECYCLE", "New plugin window tracked: " . hwnd, 3)
                
                ; Trigger grouping analysis for new window
                if (PluginDependencies["AutoGrouping"]["Enabled"]) {
                    SetTimer(() => AnalyzeNewWindowForGrouping(hwnd), -500)
                }
            } else {
                ; Update last seen time
                lifecycle[hwnd]["lastSeen"] := A_Now
            }
        }
        
    } catch Error as e {
        RecordSystemError("New Window Tracking", "Failed to track new windows: " . e.message)
    }
}

; Analyze new window for potential grouping
AnalyzeNewWindowForGrouping(hwnd) {
    try {
        if (!IsWindowValid(hwnd)) {
            return
        }
        
        ; Check if window matches any existing groups
        matchingGroups := FindMatchingGroupsForWindow(hwnd)
        
        if (matchingGroups.Length > 0) {
            ; Add to best matching group
            bestGroup := SelectBestMatchingGroup(matchingGroups, hwnd)
            if (bestGroup) {
                AddMemberToGroup(bestGroup, hwnd)
                ApplyGroupBehaviors(bestGroup)
                
                LogMessage("Added window " . hwnd . " to existing group " . bestGroup["id"], 3)
            }
        }
        
    } catch Error as e {
        RecordSystemError("New Window Group Analysis", "Failed to analyze for grouping: " . e.message)
    }
}

; Plugin session state persistence
SavePluginSessionState() {
    global PluginDependencies
    
    try {
        sessionFile := A_ScriptDir . "\Data\PluginSession.json"
        
        ; Create session data
        sessionData := Map(
            "timestamp", A_Now,
            "groups", [],
            "hierarchies", [],
            "preferences", Map()
        )
        
        ; Save group information
        for groupId, group in PluginDependencies["PluginGroups"] {
            groupData := Map(
                "id", groupId,
                "type", group["type"],
                "memberTitles", [],
                "formation", group["physics"]["formation"]
            )
            
            ; Save member titles for matching
            for member in group["members"] {
                try {
                    title := WinGetTitle("ahk_id " . member["hwnd"])
                    groupData["memberTitles"].Push(title)
                } catch {
                    continue
                }
            }
            
            sessionData["groups"].Push(groupData)
        }
        
        ; Save session to file
        if (!DirExist(A_ScriptDir . "\Data")) {
            DirCreate(A_ScriptDir . "\Data")
        }
        
        ; Use the corrected JSON stringify function
        jsonText := StringifyJSON(sessionData, 2)
        FileAppend(jsonText, sessionFile)
        
        DebugLog("SESSION", "Plugin session state saved", 2)
        
    } catch as e {
        RecordSystemError("SavePluginSessionState", e)
    }
}

; Load plugin session state
LoadPluginSessionState() {
    try {
        sessionFile := A_ScriptDir . "\Data\PluginSession.json"
        
        if (!FileExist(sessionFile)) {
            return false
        }
        
        ; Load and parse session data
        sessionText := FileRead(sessionFile)
        sessionData := JSON.parse(sessionText)
        
        ; Restore groups (implementation would match windows by title)
        ; This is a simplified version - full implementation would be more robust
        
        DebugLog("SESSION", "Plugin session state loaded", 2)
        return true
        
    } catch Error as e {
        RecordSystemError("Session Load", "Failed to load session state: " . e.message)
        return false
    }
}

; Integration hotkeys for dependency management
^!+z:: {  ; Ctrl+Alt+Shift+Z - Show plugin dependencies
    ShowPluginDependencyStatus()
}

^!+x:: {  ; Ctrl+Alt+Shift+X - Toggle automatic grouping
    global PluginDependencies
    
    PluginDependencies["AutoGrouping"]["Enabled"] := !PluginDependencies["AutoGrouping"]["Enabled"]
    status := PluginDependencies["AutoGrouping"]["Enabled"] ? "enabled" : "disabled"
    
    if (PluginDependencies["AutoGrouping"]["Enabled"]) {
        StartAutomaticGrouping()
    }
    
    ShowNotification("Plugin Dependencies", "Automatic grouping " . status, "info")
}

; Show plugin dependency status
ShowPluginDependencyStatus() {
    global PluginDependencies
    
    try {
        statusText := "Plugin Dependency Status`n`n"
        
        ; Group information
        groupCount := PluginDependencies["PluginGroups"].Count
        statusText .= "Active Groups: " . groupCount . "`n"
        
        for groupId, group in PluginDependencies["PluginGroups"] {
            statusText .= "  " . groupId . " (" . group["type"] . "): " . group["members"].Length . " members`n"
        }
        
        statusText .= "`n"
        
        ; Hierarchy information
        hierarchyCount := PluginDependencies["WindowHierarchy"].Count
        statusText .= "Window Hierarchies: " . hierarchyCount . "`n"
        
        ; Auto-grouping status
        autoStatus := PluginDependencies["AutoGrouping"]["Enabled"] ? "Enabled" : "Disabled"
        statusText .= "Auto-Grouping: " . autoStatus . "`n"
        
        MsgBox(statusText, "Plugin Dependencies", "OK Icon64")
        
    } catch Error as e {
        RecordSystemError("Dependency Status Display", "Failed to show status: " . e.message)
    }
}

; Helper functions for dependency tracking
GetAllPluginWindows() {
    global g, DAWPluginDatabase
    
    try {
        pluginWindows := []
        
        if (!g.Has("Windows")) {
            return pluginWindows
        }
        
        for win in g["Windows"] {
            if (IsPluginWindow(win["hwnd"])["isPlugin"]) {
                pluginWindows.Push(win)
            }
        }
        
        return pluginWindows
        
    } catch Error as e {
        RecordSystemError("Get Plugin Windows", "Failed to get plugin windows: " . e.message)
        return []
    }
}

; Calculate distance between windows
CalculateWindowDistance(win1, win2) {
    try {
        WinGetPos(&x1, &y1, &w1, &h1, "ahk_id " . win1["hwnd"])
        WinGetPos(&x2, &y2, &w2, &h2, "ahk_id " . win2["hwnd"])
        
        center1X := x1 + w1 / 2
        center1Y := y1 + h1 / 2
        center2X := x2 + w2 / 2
        center2Y := y2 + h2 / 2
        
        return Sqrt((center1X - center2X)**2 + (center1Y - center2Y)**2)
        
    } catch Error as e {
        RecordSystemError("Distance Calculation", "Failed to calculate distance: " . e.message)
        return 999999
    }
}

; Initialize plugin dependencies system during startup
SetTimer(() => {
    InitializePluginDependencies()
}, -4000)  ; Initialize after 4 second delay
