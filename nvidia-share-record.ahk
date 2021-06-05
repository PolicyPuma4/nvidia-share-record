#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

;@Ahk2Exe-Obey U_bits, = %A_PtrSize% * 8
;@Ahk2Exe-Obey U_type, = "%A_IsUnicode%" ? "Unicode" : "ANSI"
;@Ahk2Exe-ExeName %A_ScriptName~\.[^\.]+$%_%U_type%_%U_bits%

;@Ahk2Exe-SetMainIcon shell32_260.ico

if not A_IsCompiled
{
    Menu, Tray, Icon, shell32_260.ico
}

Game := "arma3_x64.exe"
SleepTime := 15000
RecordingWindow := ""

UpdateConfig()
while not Port or not Secret
{
    Sleep, SleepTime
    UpdateConfig()
}

Loop
{
    if RecordingWindow
    {
        if WinExist("ahk_id " RecordingWindow)
        {
            Sleep, SleepTime
        }
        else
        {
            SetRecordingState(false)
            if (GetRecordingState() = "false")
            {
                RecordingWindow := ""
                Sleep, SleepTime
            }
            else
            {
                Sleep, SleepTime
            }
        }
    }
    else
    {
        WinGet, WindowID, ID, A
        WinGet, ProcessName, ProcessName, ahk_id %WindowID%
        if (ProcessName = Game)
        {
            SetRecordingState(true)
            if (GetRecordingState() = "true")
            {
                RecordingWindow := WindowID
                Sleep, SleepTime
            }
            else
            {
                Sleep, SleepTime
            }
        }
        else
        {
            Sleep, SleepTime
        }
    }
}


UpdateConfig()
{
    FILE_MAP_READ := 4
    ; Opens a named file mapping object
    hMapFile := DllCall("OpenFileMapping", "Ptr", FILE_MAP_READ, "Int", 0, "Str", "{8BA1E16C-FC54-4595-9782-E370A5FBE8DA}")
    if not hMapFile
    {
        return
    }
    ; Maps a view of a file mapping into the address space of a calling process
    pBuf := DllCall("MapViewOfFile", "Ptr", hMapFile, "Int", FILE_MAP_READ, "Int", 0, "Int", 0)
    if not pBuf
    {
        return
    }
    ; Copies a string from a memory address
    String := StrGet(pBuf,, Encoding := "UTF-8")
    ; Unmaps a mapped view of a file from the calling process's address space
    DllCall("UnmapViewOfFile", "Ptr", pBuf)
    ; Closes an open object handle
    DllCall("CloseHandle", "Ptr", hMapFile)

    global Port
    global Secret

    ConfigArray := StrSplit(Trim(String, "{" "}"), ",", """port"":" """secret"":")
    Port := ConfigArray[1]
    Secret := ConfigArray[2]
}


GetRecordingState()
{
    global Port
    global Secret

    try
    {
        Connection := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        Connection.Open("GET", "http://localhost:" Port "/ShadowPlay/v.1.0/Record/Running", true)
        Connection.SetRequestHeader("X_LOCAL_SECURITY_COOKIE", Secret)
        Connection.Send()
        Connection.WaitForResponse()
        Response := Connection.ResponseText
        ResponseStatus := Connection.Status
        if (Response = "{""running"":false}")
        {
            return "false"
        }
        if (Response = "{""running"":true}")
        {
            return "true"
        }
        if not (Connection.Status = 200)
        {
            UpdateConfig()
        }
    }
    catch
    {
        UpdateConfig()
    }
}


SetRecordingState(State)
{
    global Port
    global Secret

    if State
    {
        State := "true"
    }
    else
    {
        State := "false"
    }

    try
    {
        Connection := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        Connection.Open("POST", "http://localhost:" Port "/ShadowPlay/v.1.0/Record/Enable", true)
        Connection.SetRequestHeader("X_LOCAL_SECURITY_COOKIE", Secret)
        Connection.SetRequestHeader("Content-Type", "application/json")
        Connection.Send("{""status"": " State "}")
        Connection.WaitForResponse()
    }
    catch
    {
        UpdateConfig()
    }
}
