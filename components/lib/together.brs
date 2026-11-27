' Watch together as the TV follows it: which stage details shows, its
' lines, and the timing and drift rules the player keeps. sinceMs is the
' time since the server's answer arrived.

' The one a details screen shows: the one the profile is in, else one
' someone else waits in; invalid for none.
function togetherPick(items as object, me as string) as dynamic
    pick = invalid
    for each w in items
        if w.status <> "ended"
            if togetherMember(w, me) <> invalid then return w
            if pick = invalid and w.status = "waiting" then pick = w
        end if
    end for
    return pick
end function

' The member this TV is: one profile may watch with itself on two devices,
' and this TV is then only the member the server marks as this device.
function togetherMember(w as object, accountId as string) as dynamic
    for each x in w.members
        if x.accountId = accountId and not togetherElsewhere(x) then return x
    end for
    return invalid
end function

function togetherElsewhere(x as object) as boolean
    return x.thisDevice <> invalid and x.thisDevice = false
end function

' A member as the chip and the lines name them: someone else by name, the
' profile's other device by that device's name.
function togetherName(x as object, me as string) as string
    if x.accountId = me then return x.deviceName
    return x.name
end function

function togetherHost(w as object) as dynamic
    for each x in w.members
        if x.role = "host" then return x
    end for
    return invalid
end function

' The other member: someone else, else the profile's other device.
function togetherOther(w as object, me as string) as dynamic
    for each x in w.members
        if x.accountId <> me then return x
    end for
    for each x in w.members
        if togetherElsewhere(x) then return x
    end for
    return invalid
end function

' none; waiting while the profile waits for someone; join while someone
' else does; joined.
function togetherStage(w as dynamic, me as string) as string
    if w = invalid or w.status = "ended" then return "none"
    if w.status = "joined" then return "joined"
    if togetherMember(w, me) <> invalid then return "waiting"
    return "join"
end function

' The window to join as m:ss, never negative.
function togetherCountdown(w as object, sinceMs as integer) as string
    left = w.joinMsLeft - sinceMs
    if left < 0 then left = 0
    return formatClock((left + 999) \ 1000)
end function

' The line under details' buttons.
function togetherNote(w as dynamic, me as string, title as string, sinceMs as integer) as string
    stage = togetherStage(w, me)
    if stage = "waiting" then return "Someone else who opens " + title + " and chooses Watch together in the next 5 minutes will play in sync with you. Pause and play on either device apply to both."
    if stage = "join" then return togetherName(togetherHost(w), me) + " wants to watch this together. Join in the next " + togetherCountdown(w, sinceMs) + " to play in sync."
    if stage <> "joined" then return ""
    note = "Pause and play on either device apply to both."
    other = togetherOther(w, me)
    if other <> invalid and other.accountId = me then return note + " Also playing on " + other.deviceName + "."
    if other <> invalid then note = note + " " + other.name + " is on " + other.deviceName + "."
    return note
end function

' Milliseconds until the answer's change takes effect, sinceMs after it
' arrived, on the server's clock less oneWayMs, half the quickest round
' trip, the time the answer took to arrive; zero or less once it has.
' Server instants may pass 32 bits, so only their difference is used.
function togetherDue(w as object, sinceMs as integer, oneWayMs as dynamic) as dynamic
    return w.effectiveAtMs - w.serverTimeMs - oneWayMs - sinceMs
end function

' The shared position: as of the latest change, advancing from its
' instant while playing.
function togetherExpected(w as object, sinceMs as integer, oneWayMs = 0 as dynamic) as dynamic
    past = -togetherDue(w, sinceMs, oneWayMs)
    if w.playing and past > 0 then return w.effectivePositionMs + past
    return w.effectivePositionMs
end function

' What a member's player does to follow the shared state: wait waitMs for
' a change still ahead, else play or pause to match it and seek to seekMs
' (else -1) when more than half a second off. A seek plays even a paused
' Video node, so a seek into a paused state is a hold, a pause once the
' seek plays, in place of the pause.
function togetherFollow(w as object, sinceMs as integer, oneWayMs as dynamic, paused as boolean, atMs as integer) as object
    ' Quoted keys and AddReplace keep their case; unquoted or dot-assigned ones lowercase.
    r = { "play": false, "pause": false, "seekMs": -1, "waitMs": 0, "hold": false }
    if w.status <> "joined" then return r
    due = togetherDue(w, sinceMs, oneWayMs)
    if due > 0
        r.AddReplace("waitMs", due)
        return r
    end if
    r.play = w.playing and paused
    r.pause = not w.playing and not paused
    expected = togetherExpected(w, sinceMs, oneWayMs)
    if Abs(atMs - expected) <= 500 then return r
    r.AddReplace("seekMs", expected)
    r.hold = not w.playing
    r.pause = false
    return r
end function

' Whether the viewer's own play, pause or seek is sent; a player that only
' follows the shared state, or meets a change still ahead, sends nothing.
' Nearer than 2 seconds is the player catching up, not a seek.
function togetherLocal(w as object, sinceMs as integer, oneWayMs as dynamic, paused as boolean, atMs as integer) as boolean
    if w.status <> "joined" or togetherDue(w, sinceMs, oneWayMs) > 0 then return false
    return w.playing = paused or Abs(atMs - togetherExpected(w, sinceMs, oneWayMs)) > 2000
end function

' Helga paused, while the other member's pause holds.
function togetherPausedBy(w as object, me as string) as string
    if w.playing or w.pausedById = invalid or w.pausedById = me or w.pausedByName = invalid then return ""
    return w.pausedByName + " paused"
end function

' The other side's Play: a member not in the player opens it.
function togetherStarts(was as dynamic, now as object) as boolean
    if was = invalid or was.id <> now.id then return false
    return now.status = "joined" and not was.playing and now.playing
end function

' An answer older than the state already taken, which polls crossing an
' action's answer can bring.
function togetherStale(was as dynamic, now as object) as boolean
    return was <> invalid and was.id = now.id and now.version < was.version
end function

' The state a member already in the player sends when the other member
' joins, so the shared state takes its play or pause and position rather
' than the position it opened at; invalid for any other answer.
function togetherArrival(was as object, now as object, paused as boolean, atMs as integer) as dynamic
    if now.status <> "joined" or was.status = "joined" then return invalid
    return { playing: not paused, positionMs: atMs }
end function

' What a poll or an action tells the server this TV needs, so it leads no
' further ahead than the slowest member: tripMs, the latest round trip of a
' request that was not held (negative before one), and the least a Roku's
' player takes to start on time. Nothing before a round trip is measured,
' for which the server leads the full second.
function togetherReport(tripMs as integer) as object
    r = {}
    if tripMs < 0 then return r
    r.AddReplace("rttMs", tripMs)
    r.AddReplace("floorMs", 600)
    return r
end function

' Whether the next poll goes at once: after a change, and after a held poll
' that ran out its hold, so no change falls in a gap nobody listens in. A
' failure, or an unchanged answer that came back quick, waits for the tick.
function togetherAsksAgain(answered as boolean, changed as boolean, quick as boolean, tripMs as integer) as boolean
    if not answered then return false
    return changed or (not quick and tripMs >= 1000)
end function
