; =================================================================
; Module: Window & Application Management Extension (External Config)
; Environment: AutoHotkey v2.0
; Description: Handles app switching, snapping, and templates with JSON support.
; =================================================================

#Include lib\JSON.ahk

; --- Default Configuration (Fallback if JSON is missing) ---
global GlobalConfig := {
    Apps: [
        { Key: "!t", ID: "ahk_class CASCADIA_HOSTING_WINDOW_CLASS", Path: "wt.exe" },
    ],
    Templates: [
        { Key: "^!m", Ext: ".md",  Tpl: "# {{Name}}`n`nCreated: {{Time}}`n`n" },
        { Key: "^!c", Ext: ".cpp", Tpl: "#include <iostream>`n`nint main() {`n    std::cout << `"Hello World`" << std::endl;`n    return 0;`n}" },
        { Key: "^!p", Ext: ".py",  Tpl: "import os`n`ndef main():`n    print(`"Hello World`")`n`nif __name__ == '__main__':`n    main()" },
        { Key: "^!k", Ext: ".ahk", Tpl: "; AutoHotkey v2 Script`n`n!j::MsgBox(`"Hello`")" }
    ],
    Settings: {
        SwitchThreshold: 800,
        SnapRatios: [0.618, 0.50, 0.382],
        CenterRatio: 0.7
    }
}

/**
 * Loads configuration and converts Map to Object for property access compatibility.
 */
LoadExternalConfig() {
    configPath := A_ScriptDir . "\Config.json"
    
    if !FileExist(configPath) {
        try {
            FileAppend(JSON.stringify(GlobalConfig, "  "), configPath, "UTF-8")
        }
    } else {
        try {
            fileContent := FileRead(configPath, "UTF-8")
            if (Trim(fileContent) == "") 
                return

            ; Parse JSON into a Map (default behavior of thqby's library)
            externalData := JSON.parse(fileContent)
            
            ; 1. Merge Settings
            if externalData.Has("Settings") {
                for k, v in externalData["Settings"]
                    GlobalConfig.Settings.%k% := v
            }

            ; 2. Merge Apps (Convert Map to Object here!)
            if externalData.Has("Apps") {
                GlobalConfig.Apps := [] 
                for appMap in externalData["Apps"] {
                    ; Create a standard Object from the Map
                    obj := {}
                    for k, v in appMap
                        obj.%k% := v
                    GlobalConfig.Apps.Push(obj)
                }
            }

            ; 3. Merge Templates
            if externalData.Has("Templates") {
                GlobalConfig.Templates := []
                for tplMap in externalData["Templates"] {
                    obj := {}
                    for k, v in tplMap
                        obj.%k% := v
                    GlobalConfig.Templates.Push(obj)
                }
            }
        } catch Any as e {
            MsgBox("Config Load Error: " . e.Message, "Error", 16)
        }
    }
}


/**
 * Main Initialization logic: Loads config and binds hotkeys dynamically.
 */
InitWindowExtensions() {
    LoadExternalConfig()

    ; Bind Application Hotkeys
    for app in GlobalConfig.Apps {
        ( (a) => Hotkey(a.Key, (k) => GetKeyState("n", "P") ? RunNewInstance(a.Path) : SmartActivate(a.ID, a.Path)) )(app)
    }

    ; Bind Template Hotkeys
    for tpl in GlobalConfig.Templates {
        ( (t) => Hotkey(t.Key, (k) => NewFileFromExplorer(t.Ext, t.Tpl)) )(tpl)
    }
}

; Execute Startup Initialization
InitWindowExtensions()

; --- Global Interaction Layer ---
#HotIf ; Reset conditions
!x:: (active := WinExist("A")) ? WinClose(active) : 0
!Up:: WinMaximize("A")
!Down:: CenterWindow("A")
!a:: ToggleAlwaysOnTop("A")
!Left:: CycleSnap("Left")
!Right:: CycleSnap("Right")

global lastSwitchTime := 0
global switchIndex := 1
!f:: CycleTaskWindows()
#HotIf

; --- Business Logic Layer ---

CycleTaskWindows() {
    global lastSwitchTime, switchIndex
    currentTime := A_TickCount
    
    if (currentTime - lastSwitchTime > GlobalConfig.Settings.SwitchThreshold)
        switchIndex := 1

    validWindows := GetSwitchableWindows()
    if (validWindows.Length == 0)
        return

    activeHWnd := WinExist("A")
    if (switchIndex > validWindows.Length)
        switchIndex := 1

    targetHwnd := validWindows[switchIndex]

    if (targetHwnd == activeHWnd && validWindows.Length > 1) {
        switchIndex := Mod(switchIndex, validWindows.Length) + 1
        targetHwnd := validWindows[switchIndex]
    }

    try {
        if WinGetMinMax(targetHwnd) == -1
            WinRestore(targetHwnd)
        WinActivate(targetHwnd)
        switchIndex := Mod(switchIndex, validWindows.Length) + 1
        lastSwitchTime := currentTime
    }
}

SmartActivate(TargetIdentifier, PathOrEXE := "") {
    static LastIDMap := Map()
    if !LastIDMap.Has(TargetIdentifier)
        LastIDMap[TargetIdentifier] := 0

    try {
        fullList := WinGetList(TargetIdentifier)
        
        if (fullList.Length == 0) {
            if (PathOrEXE == "") 
                throw Error("No path provided for activation.")
            return RunNewInstance(PathOrEXE)
        }
        activeID := WinExist("A")

        isCurrentInGroup := false
        for id in fullList {
            if (id == activeID) {
                isCurrentInGroup := true
                break
            }
        }

        if (isCurrentInGroup) {
            isTopmost := WinGetExStyle(activeID) & 0x8
            if (isTopmost) {
                if (fullList.Length > 1) {
                    nextIndex := 1
                    for index, id in fullList {
                        if (id == activeID) {
                            nextIndex := Mod(index, fullList.Length) + 1
                            break
                        }
                    }
                    targetID := fullList[nextIndex]
                    if WinGetMinMax(targetID) == -1 
                        WinRestore(targetID)
                    WinActivate(targetID)
                    LastIDMap[TargetIdentifier] := targetID
                } else {
                    ToolTip("📍 Only one window exists and is pinned")
                    SetTimer () => ToolTip(), -1000
                }
            } else {
                WinMinimize(activeID)
                return 
            }
        } else {
            nextIndex := 1
            for index, id in fullList {
                if (id == LastIDMap[TargetIdentifier]) {
                    nextIndex := Mod(index, fullList.Length) + 1
                    break
                }
            }
            targetID := fullList[nextIndex]
            if WinGetMinMax(targetID) == -1 
                WinRestore(targetID)
            WinActivate(targetID)
            LastIDMap[TargetIdentifier] := targetID
        }
    } catch Any as e {
        NotifyError("Operation Failed: " e.Message)
    }
}

CycleSnap(Side) {
    static POS_MAP := Map("Left", 0, "Right", 0)
    if !(hwnd := WinExist("A"))
        return

    POS_MAP[Side] := Mod(POS_MAP[Side], GlobalConfig.Settings.SnapRatios.Length) + 1
    ratio := GlobalConfig.Settings.SnapRatios[POS_MAP[Side]]
    
    MonitorGetWorkArea(GetMonitorIndexFromWindow(hwnd), &L, &T, &R, &B)
    
    targetW := (R - L) * ratio
    targetH := B - T
    targetX := (Side == "Left") ? L : R - targetW
    
    MoveWindowIgnoreBorders(hwnd, targetX, T, targetW, targetH)
}

CenterWindow(winTitle) {
    if !(hwnd := WinExist(winTitle))
        return
    if (WinGetMinMax(hwnd) != 0)
        WinRestore(hwnd)
    
    MonitorGetWorkArea(GetMonitorIndexFromWindow(hwnd), &L, &T, &R, &B)
    ratio := GlobalConfig.Settings.CenterRatio
    
    targetW := (R - L) * ratio
    targetH := (B - T) * ratio
    targetX := L + (R - L - targetW) / 2
    targetY := T + (B - T - targetH) / 2
    
    MoveWindowIgnoreBorders(hwnd, targetX, targetY, targetW, targetH)
}

NewFileFromExplorer(Extension, TemplateContent := "") {
    try {
        shellApp := ComObject("Shell.Application")
        activeHwnd := WinExist("A")
        targetPath := ""
        
        for window in shellApp.Windows {
            if (window.HWND == activeHwnd) {
                targetPath := window.Document.Folder.Self.Path
                break
            }
        }

        if (targetPath == "") {
            MsgBox("Use this function within a valid File Explorer window.", "Notice")
            return
        }

        userInput := InputBox("Enter filename (without extension):", "New " Extension, "w300 h130")
        if (userInput.Result == "Cancel") 
            return
        
        fileName := (userInput.Value == "") ? "NewFile" : userInput.Value
        if (fileName ~= '[\\/:*?"<>|]') {
            MsgBox("Invalid characters in filename!", "Error")
            return
        }

        fullPath := targetPath . "\" . fileName . Extension
        if FileExist(fullPath) {
            MsgBox("File already exists!", "Warning")
            return
        }

        content := StrReplace(TemplateContent, "{{Name}}", fileName)
        content := StrReplace(content, "{{Time}}", FormatTime(, "yyyy-MM-dd HH:mm"))

        FileAppend(content, fullPath, "UTF-8")
        try {
            Run('code -r "' . fullPath . '"')
        } catch {
            Run('"' . fullPath . '"')
        }
    } catch Any as e {
        NotifyError("New File Failed: " e.Message)
    }
}

ToggleAlwaysOnTop(winTitle) {
    if !(hwnd := WinExist(winTitle))
        return
    WinSetAlwaysOnTop(-1, hwnd)
    isTop := WinGetExStyle(hwnd) & 0x8
    ToolTip(isTop ? "📌 Window Pinned" : "🔓 Pinned Cancelled")
    SetTimer () => ToolTip(), -1500
}

; --- System Call Layer ---

MoveWindowIgnoreBorders(hwnd, x, y, w, h) {
    if !IsNumber(hwnd)
        hwnd := WinExist(hwnd)
    if !hwnd
        return
    Rect := Buffer(16)
    DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", 9, "ptr", Rect, "uint", 16)
    
    WinGetPos(,, &rW, &rH, hwnd)
    vW := NumGet(Rect, 8, "int") - NumGet(Rect, 0, "int")
    vH := NumGet(Rect, 12, "int") - NumGet(Rect, 4, "int")
    
    offsetX := (rW - vW) / 2
    borderBottom := (rH - vH) 
    WinMove(Floor(x - offsetX), Floor(y), Floor(w + (rW - vW)), Floor(h + borderBottom), hwnd)
}

GetSwitchableWindows() {
    allWindows := WinGetList()
    validWindows := []
    for hwnd in allWindows {
        style := WinGetStyle(hwnd)
        exStyle := WinGetExStyle(hwnd)
        title := WinGetTitle(hwnd)
        if (title != "" && (style & 0x10000000) && !(exStyle & 0x80) && WinGetMinMax(hwnd) != -1) {
            if !(title ~= "Program Manager|Taskbar|SearchHost")
                validWindows.Push(hwnd)
        }
    }
    return validWindows
}

RunNewInstance(Path) {
    try {
        Run('"' Path '"')
    } catch Any as e {
        NotifyError("Launch Failed: " e.Message)
    }
}

GetMonitorIndexFromWindow(hwnd) {
    WinGetPos(&x, &y, &w, &h, hwnd)
    midX := x + w/2, midY := y + h/2
    loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &mL, &mT, &mR, &mB)
        if (midX >= mL && midX <= mR && midY >= mT && midY <= mB)
            return A_Index
    }
    return 1
}

NotifyError(msg) {
    ToolTip("Error: " msg)
    SetTimer () => ToolTip(), -3000
}