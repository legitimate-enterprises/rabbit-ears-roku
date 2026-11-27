' Link a TV: what a poll's answer means for the code on screen.

' "signIn" for the one answer that carries the device token, whichever link
' it was for, since the server hands it over once. Otherwise an answer for a
' link other than shownId, the one on screen, is "stale"; "wait" while it is
' pending, or when the server was not reached or failed; "denied"; and
' "expired" for anything else, such as the 404 of a link that expired or
' was handed over.
function linkOutcome(shownId as dynamic, polledId as dynamic, r as object) as string
    if r.ok and r.data.signIn <> invalid then return "signIn"
    if shownId = invalid or shownId <> polledId then return "stale"
    if r.code = "network" or r.status >= 500 then return "wait"
    if r.ok and r.data.status = "pending" then return "wait"
    if r.ok and r.data.status = "denied" then return "denied"
    return "expired"
end function
