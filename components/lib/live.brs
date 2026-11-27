' The server's live events as the TV follows them, and "Playing on": a
' title still playing on another device of the profile is asked about
' before it plays here. An event names a kind and ids; what changed is
' read again through the ordinary operations.

' The query of a poll from cursor, "" for a first one: a finished scan and
' a household's changed preferences are heard only by a client that names
' their kinds.
function liveQuery(cursor as string) as object
    query = { kinds: ["library", "household"] }
    if cursor <> "" then query["after"] = cursor
    return query
end function

' What following does after one answer to listEvents, from state { cursor,
' waitMs }: the state to go on from; events to tell, invalid for none and
' empty for a resync, when everything loads again; waitMs before the next
' poll, which a failure doubles to 30 seconds; and done, for a device
' signed out or locked or a server without the stream.
function liveStep(state as object, r as object) as object
    if r.ok
        events = invalid
        if r.data.events.Count() > 0 or r.data.resync then events = r.data.events
        return { state: { cursor: r.data.cursor, waitMs: 1000 }, events: events, waitMs: 0, done: false }
    end if
    longer = state.waitMs * 2
    if longer > 30000 then longer = 30000
    return { state: { cursor: state.cursor, waitMs: longer }, events: invalid, waitMs: state.waitMs, done: r.status > 0 and r.status < 500 }
end function

' Whether a batch changes what the browsing views show. This device's own
' playback does not, since the app reloads after it; nor a start, which
' moves no watch state; nor Watch together, which details asks about; nor
' a household's change, which the app reads /me for and acts on only when
' the profile's Hide kids' content moved.
function liveMoves(events as object, deviceId as dynamic) as boolean
    if events.Count() = 0 then return true
    for each e in events
        if e.kind = "playback"
            if e.change <> "started" and (e.deviceId = invalid or e.deviceId <> deviceId) then return true
        else if e.kind <> "watch_together" and e.kind <> "household"
            return true
        end if
    end for
    return false
end function

' Whether the active profile's Hide kids' content differs between two
' answers of getMe; another active profile is a change the app boots for.
function liveHideMoved(was as object, now as object) as boolean
    if was.activeProfileId <> now.activeProfileId then return false
    return liveHides(was) <> liveHides(now)
end function

function liveHides(me as object) as boolean
    for each p in me.profiles
        if p.id = me.activeProfileId then return p.kind = "adult" and p.hideKidsContent = true
    end for
    return false
end function

' Whether a batch has an event of kind, as an empty one, a resync, has of
' every kind.
function liveNames(events as object, kind as string) as boolean
    for each e in events
        if e.kind = kind then return true
    end for
    return events.Count() = 0
end function

function liveHas(events as object, kind as string, change as string, sessionId as dynamic) as dynamic
    for each e in events
        if e.kind = kind and e.change <> invalid and e.change = change and e.sessionId <> invalid and e.sessionId = sessionId then return e
    end for
    return invalid
end function

' Whether another device took the player's session with Move here.
function liveMoved(events as object, sessionId as dynamic) as boolean
    return liveHas(events, "playback", "moved", sessionId) <> invalid
end function

' The Watch together another device opened from the player's session, for
' the player to join; invalid for none.
function liveAsked(events as object, sessionId as dynamic) as dynamic
    e = liveHas(events, "watch_together", "opened", sessionId)
    if e = invalid then return invalid
    return e.watchTogetherId
end function

' The profile's session on the title on another device; invalid for none.
function liveElsewhere(sessions as object) as dynamic
    for each s in sessions
        if not s.thisDevice then return s
    end for
    return invalid
end function

' Playing on Living Room at 41:12.
function liveTitle(there as object) as string
    return "Playing on " + there.deviceName + " at " + formatClock(there.positionMs \ 1000)
end function

' What "Playing on" offers, Move here first so that it has focus.
function liveChoices() as object
    return ["Move here", "Watch together", "Cancel"]
end function
