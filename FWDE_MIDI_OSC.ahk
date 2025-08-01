; ===================================================================
; FWDE MIDI/OSC Control Integration System
; Hardware control surface support for window management operations
; Enhanced with Windows MIDI API and OSC protocol implementation
; ===================================================================

; Windows MIDI API constants
global MIDI_MAPPER := -1
global CALLBACK_WINDOW := 0x10000
global MM_MIM_OPEN := 0x3C1
global MM_MIM_CLOSE := 0x3C2
global MM_MIM_DATA := 0x3C3
global MAXPNAMELEN := 32

; OSC message type constants
global OSC_INT32 := "i"
global OSC_FLOAT32 := "f"
global OSC_STRING := "s"
global OSC_BLOB := "b"

; Enhanced MIDI/OSC control system with real API integration
global MIDIOSCControl := Map(
    "MIDI", Map(
        "Enabled", false,
        "InputDevices", Map(),
        "OutputDevices", Map(),
        "ActiveConnections", Map(),
        "MessageQueue", [],
        "LastActivity", 0,
        "ControlMappings", Map(),
        "APIInitialized", false,
        "CallbackWindow", 0
    ),
    "OSC", Map(
        "Enabled", false,
        "ServerPort", 8000,
        "ClientPort", 8001,
        "ServerSocket", "",
        "ClientSocket", "",
        "MessageQueue", [],
        "LastActivity", 0,
        "AddressMappings", Map(),
        "UDPBuffer", Buffer(1024),
        "ServerActive", false
    ),
    "ControlSurfaces", Map(),
    "CommandBindings", Map(),
    "HardwareProfiles", Map(),
    "Statistics", Map(
        "MIDIMessagesReceived", 0,
        "OSCMessagesReceived", 0,
        "CommandsExecuted", 0,
        "LastResetTime", A_TickCount
    )
)

; Enhanced hardware control surface profiles with detailed mappings
global HardwareProfiles := Map(
    "Generic_MIDI", Map(
        "name", "Generic MIDI Controller",
        "description", "Standard MIDI controller mapping",
        "vendor", "Generic",
        "devicePatterns", ["Generic", "MIDI", "Controller"],
        "mappings", Map(
            "CC1_1", "StartStop",
            "CC1_2", "RefreshWindows", 
            "CC1_3", "OptimizeLayout",
            "CC1_4", "ToggleMonitorMode",
            "CC1_7", "QualityControl",
            "CC1_8", "SaveLayout"
        ),
        "features", ["BasicControl", "LayoutManagement"]
    ),
    "Akai_MPK_Mini", Map(
        "name", "Akai MPK Mini",
        "description", "Akai MPK Mini controller optimized mapping",
        "vendor", "Akai",
        "devicePatterns", ["MPK", "Akai"],
        "mappings", Map(
            "CC1_1", "StartStop",
            "CC1_2", "QualityUp",
            "CC1_3", "QualityDown",
            "CC1_7", "OptimizeLayout",
            "CC1_8", "ToggleMonitorMode",
            "Note1_36", "SaveLayout",
            "Note1_37", "LoadLayout",
            "Note1_38", "RefreshWindows"
        ),
        "features", ["PadControl", "KnobControl", "LayoutManagement"]
    ),
    "Novation_Launchpad", Map(
        "name", "Novation Launchpad",
        "description", "Novation Launchpad grid mapping with visual feedback",
        "vendor", "Novation",
        "devicePatterns", ["Launchpad", "Novation"],
        "mappings", Map(
            "Note1_36", "StartStop",
            "Note1_37", "RefreshWindows",
            "Note1_38", "OptimizeLayout", 
            "Note1_39", "ToggleMonitorMode",
            "Note1_40", "QualityUp",
            "Note1_41", "QualityDown",
            "Note1_42", "SaveLayout",
            "Note1_43", "LoadLayout"
        ),
        "features", ["GridControl", "LEDFeedback", "SceneManagement"],
        "ledMapping", Map(
            "StartStop", Map("note", 36, "color", "green"),
            "OptimizeLayout", Map("note", 38, "color", "blue")
        )
    ),
    "TouchOSC", Map(
        "name", "TouchOSC Mobile App",
        "description", "TouchOSC mobile control surface with custom layout",
        "vendor", "TouchOSC",
        "protocol", "OSC",
        "defaultPort", 8000,
        "mappings", Map(
            "/fwde/physics/toggle", "StartStop",
            "/fwde/windows/refresh", "RefreshWindows",
            "/fwde/layout/optimize", "OptimizeLayout",
            "/fwde/monitor/toggle", "ToggleMonitorMode",
            "/fwde/quality", "QualityControl",
            "/fwde/layout/save", "SaveLayout",
            "/fwde/layout/load", "LoadLayout"
        ),
        "features", ["TouchControl", "CustomLayouts", "Feedback"]
    ),
    "Behringer_X_Touch", Map(
        "name", "Behringer X-Touch",
        "description", "Professional control surface with motorized faders",
        "vendor", "Behringer", 
        "devicePatterns", ["X-Touch", "Behringer"],
        "mappings", Map(
            "CC1_1", "QualityControl",
            "CC1_16", "StartStop",
            "CC1_17", "OptimizeLayout",
            "CC1_18", "ToggleMonitorMode",
            "Note1_89", "SaveLayout",
            "Note1_90", "LoadLayout"
        ),
        "features", ["MotorizedFaders", "TouchSensitive", "OLED", "Professional"]
    )
)

; Initialize enhanced MIDI/OSC control system
InitializeMIDIOSCControl() {
    try {
        DebugLog("MIDI_OSC", "Initializing enhanced MIDI/OSC control integration", 2)
        
        ; Initialize Windows MIDI API
        if (InitializeMIDIAPI()) {
            MIDIOSCControl["MIDI"]["APIInitialized"] := true
            DetectMIDIDevices()
        }
        
        ; Initialize OSC server with UDP sockets
        if (MIDIOSCControl["OSC"]["Enabled"]) {
            InitializeOSCServer()
        }
        
        ; Load control mappings and profiles
        LoadControlMappings()
        LoadHardwareProfiles()
        
        ; Start message processing with high precision timing
        StartMessageProcessing()
        
        ; Auto-detect and configure connected hardware
        AutoDetectHardware()
        
        ; Initialize statistics tracking
        ResetStatistics()
        
        DebugLog("MIDI_OSC", "Enhanced MIDI/OSC control system initialized successfully", 2)
        ShowNotification("Hardware Control", "Advanced hardware integration enabled", "success", 3000)
        
        return true
        
    } catch Error as e {
        RecordSystemError("InitializeMIDIOSCControl", e)
        return false
    }
}

; Initialize Windows MIDI API with proper callback handling
InitializeMIDIAPI() {
    global MIDIOSCControl
    
    try {
        ; Create hidden window for MIDI callbacks
        callbackWindow := Gui("+LastFound +ToolWindow", "FWDE_MIDI_Callback")
        callbackWindow.OnMessage(MM_MIM_DATA, MIDIDataCallback)
        callbackWindow.Show("Hide")
        
        MIDIOSCControl["MIDI"]["CallbackWindow"] := callbackWindow.Hwnd
        
        DebugLog("MIDI_OSC", "MIDI API initialized with callback window", 3)
        return true
        
    } catch Error as e {
        RecordSystemError("InitializeMIDIAPI", e)
        return false
    }
}

; Enhanced MIDI device detection using Windows API
DetectMIDIDevices() {
    global MIDIOSCControl
    
    try {
        ; Clear existing device lists
        MIDIOSCControl["MIDI"]["InputDevices"].Clear()
        MIDIOSCControl["MIDI"]["OutputDevices"].Clear()
        
        ; Get number of MIDI input devices
        numInputs := DllCall("winmm.dll\midiInGetNumDevs", "UInt")
        
        ; Enumerate MIDI input devices
        for i in Range(0, numInputs - 1) {
            deviceInfo := Buffer(MAXPNAMELEN + 16)
            result := DllCall("winmm.dll\midiInGetDevCaps", "UPtr", i, "Ptr", deviceInfo, "UInt", deviceInfo.Size)
            
            if (result == 0) {  ; MMSYSERR_NOERROR
                deviceName := StrGet(deviceInfo, MAXPNAMELEN, "UTF-16")
                
                MIDIOSCControl["MIDI"]["InputDevices"][i] := Map(
                    "name", deviceName,
                    "id", i,
                    "connected", false,
                    "handle", 0,
                    "lastActivity", 0,
                    "messageCount", 0
                )
                
                DebugLog("MIDI_OSC", "Found MIDI input: " . deviceName, 3)
            }
        }
        
        ; Get number of MIDI output devices
        numOutputs := DllCall("winmm.dll\midiOutGetNumDevs", "UInt")
        
        ; Enumerate MIDI output devices
        for i in Range(0, numOutputs - 1) {
            deviceInfo := Buffer(MAXPNAMELEN + 16)
            result := DllCall("winmm.dll\midiOutGetDevCaps", "UPtr", i, "Ptr", deviceInfo, "UInt", deviceInfo.Size)
            
            if (result == 0) {
                deviceName := StrGet(deviceInfo, MAXPNAMELEN, "UTF-16")
                
                MIDIOSCControl["MIDI"]["OutputDevices"][i] := Map(
                    "name", deviceName,
                    "id", i,
                    "connected", false,
                    "handle", 0,
                    "lastActivity", 0
                )
                
                DebugLog("MIDI_OSC", "Found MIDI output: " . deviceName, 3)
            }
        }
        
        DebugLog("MIDI_OSC", "Detected " . numInputs . " MIDI inputs, " . numOutputs . " outputs", 2)
        
    } catch Error as e {
        RecordSystemError("DetectMIDIDevices", e)
    }
}

; Initialize OSC server with UDP socket implementation
InitializeOSCServer() {
    global MIDIOSCControl
    
    try {
        serverPort := MIDIOSCControl["OSC"]["ServerPort"]
        
        ; Create UDP socket for OSC server
        socket := DllCall("ws2_32.dll\socket", "Int", 2, "Int", 2, "Int", 17, "Ptr")  ; AF_INET, SOCK_DGRAM, IPPROTO_UDP
        
        if (socket == -1) {
            throw Error("Failed to create UDP socket")
        }
        
        ; Bind socket to server port
        sockaddr := Buffer(16)
        NumPut("UShort", 2, sockaddr, 0)        ; sin_family = AF_INET
        NumPut("UShort", DllCall("ws2_32.dll\htons", "UShort", serverPort), sockaddr, 2)  ; sin_port
        NumPut("UInt", 0, sockaddr, 4)          ; sin_addr = INADDR_ANY
        
        result := DllCall("ws2_32.dll\bind", "Ptr", socket, "Ptr", sockaddr, "Int", 16)
        
        if (result == -1) {
            DllCall("ws2_32.dll\closesocket", "Ptr", socket)
            throw Error("Failed to bind OSC server socket")
        }
        
        ; Set socket to non-blocking mode
        nonBlocking := 1
        DllCall("ws2_32.dll\ioctlsocket", "Ptr", socket, "UInt", 0x8004667E, "Ptr", &nonBlocking)  ; FIONBIO
        
        MIDIOSCControl["OSC"]["ServerSocket"] := socket
        MIDIOSCControl["OSC"]["ServerActive"] := true
        
        DebugLog("MIDI_OSC", "OSC server initialized on port " . serverPort, 2)
        return true
        
    } catch Error as e {
        RecordSystemError("InitializeOSCServer", e)
        return false
    }
}

; MIDI message callback function
MIDIDataCallback(wParam, lParam, msg, hwnd) {
    global MIDIOSCControl
    
    try {
        ; Extract MIDI message data
        status := lParam & 0xFF
        data1 := (lParam >> 8) & 0xFF
        data2 := (lParam >> 16) & 0xFF
        
        ; Determine message type
        messageType := (status & 0xF0) >> 4
        channel := (status & 0x0F) + 1
        
        ; Create message object
        message := Map(
            "timestamp", A_TickCount,
            "status", status,
            "channel", channel,
            "data1", data1,
            "data2", data2,
            "type", "",
            "number", data1,
            "value", data2
        )
        
        ; Classify message type
        switch messageType {
            case 8:  ; Note Off
                message["type"] := "NoteOff"
                message["value"] := 0
            case 9:  ; Note On
                message["type"] := data2 > 0 ? "Note" : "NoteOff"
                message["value"] := data2
            case 11: ; Control Change
                message["type"] := "CC"
            case 14: ; Pitch Bend
                message["type"] := "PitchBend"
                message["value"] := (data2 << 7) | data1
        }
        
        ; Add to message queue for processing
        MIDIOSCControl["MIDI"]["MessageQueue"].Push(message)
        MIDIOSCControl["Statistics"]["MIDIMessagesReceived"]++
        
        return 0
        
    } catch Error as e {
        RecordSystemError("MIDIDataCallback", e)
        return 0
    }
}

; Enhanced OSC message processing with proper parsing
ProcessOSCMessages() {
    global MIDIOSCControl
    
    try {
        socket := MIDIOSCControl["OSC"]["ServerSocket"]
        
        if (!socket || !MIDIOSCControl["OSC"]["ServerActive"]) {
            return
        }
        
        ; Check for incoming OSC messages
        buffer := MIDIOSCControl["OSC"]["UDPBuffer"]
        clientAddr := Buffer(16)
        clientAddrLen := 16
        
        bytesReceived := DllCall("ws2_32.dll\recvfrom", 
            "Ptr", socket,
            "Ptr", buffer,
            "Int", buffer.Size,
            "Int", 0,
            "Ptr", clientAddr,
            "Ptr", &clientAddrLen,
            "Int")
        
        if (bytesReceived > 0) {
            ; Parse OSC message
            message := ParseOSCMessage(buffer, bytesReceived)
            
            if (message) {
                MIDIOSCControl["OSC"]["MessageQueue"].Push(message)
                MIDIOSCControl["Statistics"]["OSCMessagesReceived"]++
                HandleOSCMessage(message)
            }
        }
        
    } catch Error as e {
        RecordSystemError("ProcessOSCMessages", e)
    }
}

; Parse OSC message from UDP buffer
ParseOSCMessage(buffer, length) {
    try {
        ; OSC messages start with address pattern
        addressEnd := 0
        for i in Range(0, length - 1) {
            if (NumGet(buffer, i, "UChar") == 0) {
                addressEnd := i
                break
            }
        }
        
        if (addressEnd == 0) {
            return false
        }
        
        address := StrGet(buffer, addressEnd, "UTF-8")
        
        ; Skip padding to 4-byte boundary
        typeTagStart := ((addressEnd + 4) & ~3)
        
        if (typeTagStart >= length) {
            return Map("address", address, "args", [])
        }
        
        ; Find type tag string
        typeTagEnd := typeTagStart
        for i in Range(typeTagStart, length - 1) {
            if (NumGet(buffer, i, "UChar") == 0) {
                typeTagEnd := i
                break
            }
        }
        
        typeTags := StrGet(buffer.Ptr + typeTagStart, typeTagEnd - typeTagStart, "UTF-8")
        
        ; Parse arguments based on type tags
        args := []
        argPos := ((typeTagEnd + 4) & ~3)
        
        for i in Range(2, StrLen(typeTags)) {  ; Skip initial ','
            tag := SubStr(typeTags, i, 1)
            
            switch tag {
                case "i":  ; 32-bit integer
                    if (argPos + 4 <= length) {
                        value := NumGet(buffer, argPos, "Int")
                        args.Push(value)
                        argPos += 4
                    }
                case "f":  ; 32-bit float
                    if (argPos + 4 <= length) {
                        value := NumGet(buffer, argPos, "Float")
                        args.Push(value)
                        argPos += 4
                    }
                case "s":  ; String
                    stringStart := argPos
                    stringEnd := argPos
                    
                    ; Find null terminator
                    for j in Range(argPos, length - 1) {
                        if (NumGet(buffer, j, "UChar") == 0) {
                            stringEnd := j
                            break
                        }
                    }
                    
                    if (stringEnd > stringStart) {
                        value := StrGet(buffer.Ptr + stringStart, stringEnd - stringStart, "UTF-8")
                        args.Push(value)
                    }
                    
                    argPos := ((stringEnd + 4) & ~3)
            }
        }
        
        return Map("address", address, "args", args, "timestamp", A_TickCount)
        
    } catch Error as e {
        RecordSystemError("ParseOSCMessage", e)
        return false
    }
}

; Enhanced hardware auto-detection with confidence scoring
AutoDetectHardware() {
    global MIDIOSCControl, HardwareProfiles
    
    try {
        detectedProfiles := []
        
        ; Check MIDI devices against known profiles
        for deviceId, device in MIDIOSCControl["MIDI"]["InputDevices"] {
            deviceName := device["name"]
            bestMatch := ""
            bestScore := 0
            
            ; Score each profile against device name
            for profileName, profile in HardwareProfiles {
                if (!profile.Has("devicePatterns")) {
                    continue
                }
                
                score := 0
                for pattern in profile["devicePatterns"] {
                    if (InStr(deviceName, pattern)) {
                        score += StrLen(pattern)
                    }
                }
                
                if (score > bestScore) {
                    bestScore := score
                    bestMatch := profileName
                }
            }
            
            ; Apply profile if confidence is high enough
            if (bestScore >= 3) {  ; Minimum match threshold
                detectedProfiles.Push(Map(
                    "profile", bestMatch,
                    "device", deviceName,
                    "deviceId", deviceId,
                    "protocol", "MIDI",
                    "confidence", bestScore
                ))
                
                ; Connect and configure device
                if (ConnectMIDIDevice(deviceId)) {
                    ApplyHardwareProfile(bestMatch, deviceId, "MIDI")
                }
            }
        }
        
        ; Report detected hardware
        if (detectedProfiles.Length > 0) {
            profileNames := []
            for profile in detectedProfiles {
                profileNames.Push(profile["profile"] . " (" . profile["confidence"] . ")")
            }
            
            ShowNotification("Hardware Control", 
                "Detected: " . profileNames.Join(", "), 
                "success", 5000)
        }
        
        MIDIOSCControl["ControlSurfaces"] := detectedProfiles
        
        DebugLog("MIDI_OSC", "Auto-detected " . detectedProfiles.Length . " control surfaces", 2)
        
    } catch Error as e {
        RecordSystemError("AutoDetectHardware", e)
    }
}

; Connect to MIDI input device
ConnectMIDIDevice(deviceId) {
    global MIDIOSCControl
    
    try {
        device := MIDIOSCControl["MIDI"]["InputDevices"][deviceId]
        callbackWindow := MIDIOSCControl["MIDI"]["CallbackWindow"]
        
        ; Open MIDI input device
        handle := 0
        result := DllCall("winmm.dll\midiInOpen",
            "Ptr*", &handle,
            "UInt", deviceId,
            "Ptr", callbackWindow,
            "Ptr", 0,
            "UInt", CALLBACK_WINDOW)
        
        if (result == 0) {  ; MMSYSERR_NOERROR
            device["handle"] := handle
            device["connected"] := true
            
            ; Start receiving messages
            DllCall("winmm.dll\midiInStart", "Ptr", handle)
            
            MIDIOSCControl["MIDI"]["ActiveConnections"][deviceId] := handle
            
            DebugLog("MIDI_OSC", "Connected to MIDI device: " . device["name"], 2)
            return true
        } else {
            DebugLog("MIDI_OSC", "Failed to connect to MIDI device " . deviceId . " (error " . result . ")", 2)
            return false
        }
        
    } catch Error as e {
        RecordSystemError("ConnectMIDIDevice", e, deviceId)
        return false
    }
}

; Enhanced message processing with statistics
ProcessMIDIMessages() {
    global MIDIOSCControl
    
    try {
        messageQueue := MIDIOSCControl["MIDI"]["MessageQueue"]
        
        while (messageQueue.Length > 0) {
            message := messageQueue.RemoveAt(1)
            HandleMIDIMessage(message)
        }
        
        ; Clean up old messages to prevent memory leaks
        if (messageQueue.Length > 1000) {
            messageQueue.RemoveAt(1, messageQueue.Length - 500)
        }
        
    } catch Error as e {
        RecordSystemError("ProcessMIDIMessages", e)
    }
}

; Process incoming MIDI messages
ProcessMIDIMessages() {
    global MIDIOSCControl
    
    try {
        ; Check for new MIDI messages
        ; Note: This is a placeholder - real implementation would read from MIDI input buffers
        
        messageQueue := MIDIOSCControl["MIDI"]["MessageQueue"]
        
        while (messageQueue.Length > 0) {
            message := messageQueue.RemoveAt(1)
            HandleMIDIMessage(message)
        }
        
    } catch Error as e {
        RecordSystemError("ProcessMIDIMessages", e)
    }
}

; Process incoming OSC messages
ProcessOSCMessages() {
    global MIDIOSCControl
    
    try {
        socket := MIDIOSCControl["OSC"]["ServerSocket"]
        
        if (!socket || !MIDIOSCControl["OSC"]["ServerActive"]) {
            return
        }
        
        ; Check for incoming OSC messages
        buffer := MIDIOSCControl["OSC"]["UDPBuffer"]
        clientAddr := Buffer(16)
        clientAddrLen := 16
        
        bytesReceived := DllCall("ws2_32.dll\recvfrom", 
            "Ptr", socket,
            "Ptr", buffer,
            "Int", buffer.Size,
            "Int", 0,
            "Ptr", clientAddr,
            "Ptr", &clientAddrLen,
            "Int")
        
        if (bytesReceived > 0) {
            ; Parse OSC message
            message := ParseOSCMessage(buffer, bytesReceived)
            
            if (message) {
                MIDIOSCControl["OSC"]["MessageQueue"].Push(message)
                MIDIOSCControl["Statistics"]["OSCMessagesReceived"]++
                HandleOSCMessage(message)
            }
        }
        
    } catch Error as e {
        RecordSystemError("ProcessOSCMessages", e)
    }
}

; Handle incoming MIDI message
HandleMIDIMessage(message) {
    global MIDIOSCControl, WindowManagementCommands
    
    try {
        ; Create mapping key from MIDI message
        mappingKey := "MIDI_" . message["type"] . message["channel"] . "_" . message["number"]
        
        ; Find command mapping
        if (MIDIOSCControl["MIDI"]["ControlMappings"].Has(mappingKey)) {
            mapping := MIDIOSCControl["MIDI"]["ControlMappings"][mappingKey]
            
            ; Execute mapped function based on message value
            if (message["value"] > 0) {  ; Only trigger on positive values
                ExecuteControlCommand(mapping["function"], message["value"])
                
                DebugLog("MIDI_OSC", "Executed MIDI command: " . mapping["command"], 3)
                MIDIOSCControl["MIDI"]["LastActivity"] := A_TickCount
            }
        }
        
    } catch Error as e {
        RecordSystemError("HandleMIDIMessage", e)
    }
}

; Handle incoming OSC message
HandleOSCMessage(message) {
    global MIDIOSCControl, WindowManagementCommands
    
    try {
        address := message["address"]
        
        ; Find address mapping
        if (MIDIOSCControl["OSC"]["AddressMappings"].Has(address)) {
            mapping := MIDIOSCControl["OSC"]["AddressMappings"][address]
            
            ; Execute mapped function
            value := message.Has("value") ? message["value"] : 1
            ExecuteControlCommand(mapping["function"], value)
            
            DebugLog("MIDI_OSC", "Executed OSC command: " . mapping["command"], 3)
            MIDIOSCControl["OSC"]["LastActivity"] := A_TickCount
        }
        
    } catch Error as e {
        RecordSystemError("HandleOSCMessage", e)
    }
}

; Execute control command function
ExecuteControlCommand(functionName, value := 1) {
    global MIDIOSCControl
    
    try {
        commandExecuted := false
        
        switch functionName {
            case "TogglePhysicsEngine":
                TogglePhysics()
                commandExecuted := true
            case "RefreshWindowList":
                RefreshWindows()
                commandExecuted := true
            case "OptimizeWindowPositions":
                OptimizeLayout()
                commandExecuted := true
            case "ToggleSeamlessMonitorFloat":
                ToggleMultiMonitorMode()
                commandExecuted := true
            case "IncreaseQualityLevel":
                IncreaseQualityLevel()
                commandExecuted := true
            case "DecreaseQualityLevel":
                DecreaseQualityLevel()
                commandExecuted := true
            case "QuickSaveLayout":
                QuickSaveCurrentLayout()
                commandExecuted := true
            case "QuickLoadLayout":
                QuickLoadLastLayout()
                commandExecuted := true
            case "QualityControl":
                ; Value-based quality control (0-127 MIDI range)
                qualityPercent := value / 127.0
                SetQualityByPercent(qualityPercent)
                commandExecuted := true
            default:
                DebugLog("MIDI_OSC", "Unknown control function: " . functionName, 2)
        }
        
        if (commandExecuted) {
            MIDIOSCControl["Statistics"]["CommandsExecuted"]++
            
            ; Send feedback to control surfaces
            SendControlSurfaceFeedback(functionName, value)
        }
        
    } catch Error as e {
        RecordSystemError("ExecuteControlCommand", e, functionName)
    }
}

; Send visual feedback to control surfaces
SendControlSurfaceFeedback(commandName, value := 1) {
    global MIDIOSCControl, HardwareProfiles
    
    try {
        ; Send LED feedback to devices that support it
        for surface in MIDIOSCControl["ControlSurfaces"] {
            profileName := surface["profile"]
            
            if (!HardwareProfiles.Has(profileName)) {
                continue
            }
            
            profile := HardwareProfiles[profileName]
            
            ; Check if profile supports LED feedback
            if (profile.Has("ledMapping") && profile["ledMapping"].Has(commandName)) {
                ledInfo := profile["ledMapping"][commandName]
                
                if (surface["protocol"] == "MIDI" && surface.Has("deviceId")) {
                    SendMIDIFeedback(surface["deviceId"], ledInfo, value)
                }
            }
        }
        
    } catch Error as e {
        RecordSystemError("SendControlSurfaceFeedback", e)
    }
}

; Send MIDI feedback to output device
SendMIDIFeedback(deviceId, ledInfo, value) {
    global MIDIOSCControl
    
    try {
        ; Find corresponding output device
        outputDevice := ""
        for outId, device in MIDIOSCControl["MIDI"]["OutputDevices"] {
            inputDevice := MIDIOSCControl["MIDI"]["InputDevices"][deviceId]
            if (InStr(device["name"], inputDevice["name"])) {
                outputDevice := device
                break
            }
        }
        
        if (!outputDevice) {
            return
        }
        
        ; Open output device if not connected
        if (!outputDevice["connected"]) {
            handle := 0
            result := DllCall("winmm.dll\midiOutOpen",
                "Ptr*", &handle,
                "UInt", outId,
                "Ptr", 0,
                "Ptr", 0,
                "UInt", 0)
            
            if (result == 0) {
                outputDevice["handle"] := handle
                outputDevice["connected"] := true
            } else {
                return
            }
        }
        
        ; Send LED control message
        note := ledInfo["note"]
        velocity := value > 0 ? 127 : 0  ; Full on/off
        
        ; Note On message: 0x90 | channel, note, velocity
        midiMessage := 0x90 | (note << 8) | (velocity << 16)
        
        DllCall("winmm.dll\midiOutShortMsg", "Ptr", outputDevice["handle"], "UInt", midiMessage)
        
    } catch Error as e {
        RecordSystemError("SendMIDIFeedback", e)
    }
}

; Quality control by percentage
SetQualityByPercent(percent) {
    global PerformanceScaling
    
    try {
        ; Map percentage to quality levels
        if (percent <= 0.2) {
            targetQuality := "Minimal"
        } else if (percent <= 0.4) {
            targetQuality := "Low"
        } else if (percent <= 0.6) {
            targetQuality := "Medium"
        } else if (percent <= 0.8) {
            targetQuality := "High"
        } else {
            targetQuality := "Ultra"
        }
        
        ApplyQualityLevel(targetQuality)
        ShowNotification("Performance", "Quality: " . targetQuality . " (" . Round(percent * 100) . "%)", "info", 2000)
        
    } catch Error as e {
        RecordSystemError("SetQualityByPercent", e)
    }
}

; Reset and display statistics
ResetStatistics() {
    global MIDIOSCControl
    
    MIDIOSCControl["Statistics"]["MIDIMessagesReceived"] := 0
    MIDIOSCControl["Statistics"]["OSCMessagesReceived"] := 0
    MIDIOSCControl["Statistics"]["CommandsExecuted"] := 0
    MIDIOSCControl["Statistics"]["LastResetTime"] := A_TickCount
}

ShowHardwareStatistics() {
    global MIDIOSCControl
    
    try {
        stats := MIDIOSCControl["Statistics"]
        uptime := Round((A_TickCount - stats["LastResetTime"]) / 1000)
        
        statusText := "Hardware Control Statistics`n`n"
        statusText .= "Uptime: " . uptime . " seconds`n"
        statusText .= "MIDI Messages: " . stats["MIDIMessagesReceived"] . "`n"
        statusText .= "OSC Messages: " . stats["OSCMessagesReceived"] . "`n"
        statusText .= "Commands Executed: " . stats["CommandsExecuted"] . "`n`n"
        
        ; Message rates
        if (uptime > 0) {
            midiRate := Round(stats["MIDIMessagesReceived"] / uptime, 2)
            oscRate := Round(stats["OSCMessagesReceived"] / uptime, 2)
            statusText .= "MIDI Rate: " . midiRate . " msg/sec`n"
            statusText .= "OSC Rate: " . oscRate . " msg/sec`n"
        }
        
        MsgBox(statusText, "Hardware Statistics", "OK Icon64")
        
    } catch Error as e {
        RecordSystemError("ShowHardwareStatistics", e)
    }
}

; Enhanced hotkeys with new functionality
^!+m:: {  ; Ctrl+Alt+Shift+M - Toggle MIDI control
    global MIDIOSCControl
    
    MIDIOSCControl["MIDI"]["Enabled"] := !MIDIOSCControl["MIDI"]["Enabled"]
    status := MIDIOSCControl["MIDI"]["Enabled"] ? "enabled" : "disabled"
    ShowNotification("MIDI Control", "MIDI control " . status, "info")
}

^!+o:: {  ; Ctrl+Alt+Shift+O - Toggle OSC control
    global MIDIOSCControl
    
    MIDIOSCControl["OSC"]["Enabled"] := !MIDIOSCControl["OSC"]["Enabled"]
    status := MIDIOSCControl["OSC"]["Enabled"] ? "enabled" : "disabled"
    
    if (MIDIOSCControl["OSC"]["Enabled"]) {
        InitializeOSCServer()
    }
    
    ShowNotification("OSC Control", "OSC control " . status, "info")
}

^!+h:: {  ; Ctrl+Alt+Shift+H - Show hardware status
    ShowHardwareControlStatus()
}

^!+j:: {  ; Ctrl+Alt+Shift+J - Show hardware statistics
    ShowHardwareStatistics()
}

^!+r:: {  ; Ctrl+Alt+Shift+R - Reset statistics
    ResetStatistics()
    ShowNotification("Statistics", "Hardware statistics reset", "info")
}

; Cleanup function for proper shutdown
CleanupMIDIOSCControl() {
    global MIDIOSCControl
    
    try {
        ; Close MIDI connections
        for deviceId, handle in MIDIOSCControl["MIDI"]["ActiveConnections"] {
            DllCall("winmm.dll\midiInStop", "Ptr", handle)
            DllCall("winmm.dll\midiInClose", "Ptr", handle)
        }
        
        ; Close output devices
        for deviceId, device in MIDIOSCControl["MIDI"]["OutputDevices"] {
            if (device["connected"] && device["handle"]) {
                DllCall("winmm.dll\midiOutClose", "Ptr", device["handle"])
            }
        }
        
        ; Close OSC socket
        if (MIDIOSCControl["OSC"]["ServerSocket"]) {
            DllCall("ws2_32.dll\closesocket", "Ptr", MIDIOSCControl["OSC"]["ServerSocket"])
        }
        
        DebugLog("MIDI_OSC", "MIDI/OSC control system cleaned up", 2)
        
    } catch Error as e {
        RecordSystemError("CleanupMIDIOSCControl", e)
    }
}

; Initialize during startup with delay
SetTimer(() => {
    InitializeMIDIOSCControl()
}, -5000)  ; Initialize after 5 second delay

; Cleanup on exit
OnExit(CleanupMIDIOSCControl)
