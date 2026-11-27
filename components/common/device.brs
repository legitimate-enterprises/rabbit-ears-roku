' The capability snapshot as of now, read on the thread that asks. The
' decoder group is probed once per launch and kept on m.global.
function deviceSnapshot(quality as object) as object
    di = CreateObject("roDeviceInfo")
    if m.global.decoder.Count() = 0 then m.global.decoder = capabilityDecoder(di)
    return capabilitySnapshot(di, m.global.decoder, deviceAtHome(), quality)
end function

' Whether this device is on the server's own network: the server answered
' discovery here, or a local check found its address there.
function deviceAtHome() as boolean
    return m.global.discovered or m.global.home.url <> ""
end function

' What this device calls itself in the household's device list.
function deviceName() as string
    name = CreateObject("roDeviceInfo").GetFriendlyName().Trim()
    if name = "" then name = "Roku"
    return Left(name, 100)
end function
