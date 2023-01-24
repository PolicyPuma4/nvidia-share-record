#Requires AutoHotkey v2.0


match(haystack, needle) {
    RegExMatch(haystack, needle, &match)
    return match[1]
}


get_secret() {
    FILE_MAP_READ := 0x4
    ; Opens a named file mapping object
    hFileMappingObject := DllCall("OpenFileMapping", "Ptr", FILE_MAP_READ, "Int", false, "Str", "{8BA1E16C-FC54-4595-9782-E370A5FBE8DA}")
    if not hFileMappingObject{
        return
    }

    ; Maps a view of a file mapping into the address space of a calling process
    lpMapAddress := DllCall("MapViewOfFile", "Ptr", hFileMappingObject, "Int", FILE_MAP_READ, "Int", 0, "Int", 0)
    if not lpMapAddress {
        return
    }

    ; Copies a string from a memory address
    string := StrGet(lpMapAddress,, Encoding := "UTF-8")
    ; Unmaps a mapped view of a file from the calling process's address space
    DllCall("UnmapViewOfFile", "Ptr", lpMapAddress)
    ; Closes an open object handle
    DllCall("CloseHandle", "Ptr", hFileMappingObject)

    port := match(string, "`"port`"\s*:\s*([0-9]*)")
    secret := match(string, "`"secret`"\s*:\s*`"([A-Z0-9]*)")
    if not port or not secret {
        return
    }

    return {
        port: port,
        secret: secret,
    }
}


get_recording_state() {
    credentials := get_secret()
    if not credentials {
        return
    }

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", "http://localhost:" credentials.port "/ShadowPlay/v.1.0/Record/Running", true)
        whr.SetRequestHeader("X_LOCAL_SECURITY_COOKIE", credentials.secret)
        whr.Send()
        whr.WaitForResponse()
    } catch {
        return
    }

    status := whr.Status
    if not status = 200 {
        return
    }

    response := whr.ResponseText
    status := match(response, "`"running`"\s*:\s*(true|false)")
    return status = "true"
}


set_recording_state(state) {
    credentials := get_secret()
    if not credentials {
        return
    }

    state := state ? "true" : "false"
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", "http://localhost:" credentials.port "/ShadowPlay/v.1.0/Record/Enable", true)
        whr.SetRequestHeader("X_LOCAL_SECURITY_COOKIE", credentials.secret)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.Send("{`"status`":" state "}")
        whr.WaitForResponse()
    } catch {
        return
    }
}


if not A_IsCompiled {
    TraySetIcon("shell32.dll", 207)
}

game_paths := [
    "C:\Program Files\Example\Example.exe",
]

sleep_time := 15000
recording_window := ""

Loop {
    if A_Index > 1 {
        Sleep(sleep_time)
    }

    if not recording_window {
        window_id := WinExist("A")
        if not window_id {
            continue
        }

        process_path := WinGetProcessPath(window_id)
        for path in game_paths {
            if not path = process_path {
                continue
            }

            set_recording_state(true)
            if not get_recording_state() {
                break
            }

            recording_window := window_id
        }

        continue
    }

    if WinExist(recording_window) {
        continue
    }

    set_recording_state(false)
    if get_recording_state() {
        continue
    }

    recording_window := ""
}
