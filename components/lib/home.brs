' The local check: a device signed in at the server's public address
' proves it is on the server's own network, then plays as at home, from
' the address that proved it. A check is { url, at }: the address found,
' "" for none, and the second it ran, 0 for never.

' Whether a playback start runs a check first: the server's address is not
' local, and no check ran in the last 10 minutes, whatever it found; the
' server forgets a confirmation after 15.
function homeDue(server as string, home as object, nowSeconds as integer) as boolean
    if apiLocal(server) then return false
    return home.at = 0 or nowSeconds - home.at >= 600
end function

' The base a stream's URL is fetched at.
function homeStreamBase(server as string, home as object) as string
    if home.url <> "" then return home.url
    return server
end function
