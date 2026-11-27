' Watch together on Movie, Episode and Video details: the
' button, the waiting pill with Cancel, Join, or the in-sync chip with
' Leave, and the line under them. The view calls togetherStart when it
' draws its title, lays out its button row with togetherRow, hands OK to
' togetherSelect, plays with togetherPlay, and defines redraw(), which a
' change of stage calls. It polls every 5 seconds until the profile is in
' one, then holds a poll for each change; either side's Play together
' opens the player here.

sub togetherStart(item as object, title as string)
    m.tgTitle = title
    ' A redraw clears the view's children, the timer with them; it goes back.
    if m.tgTimer <> invalid and m.tgTimer.getParent() = invalid
        m.top.appendChild(m.tgTimer)
        m.tgTimer.control = "start"
    end if
    if m.tgItem <> invalid then return
    m.tgItem = item
    m.tg = invalid
    m.tgKey = "none"
    m.tgNodes = {}
    m.tgSince = CreateObject("roTimespan")
    m.tgTicks = 0
    m.tgBusy = false
    ' The view's own child, so it goes with the view; a popped view stops it.
    m.tgTimer = m.top.CreateChild("Timer")
    m.tgTimer.duration = 1
    m.tgTimer.repeat = true
    m.tgTimer.observeFieldScoped("fire", "togetherTick")
    m.tgTimer.control = "start"
    m.global.observeFieldScoped("live", "togetherHeard")
    togetherPoll()
end sub

' One opened or ended shows as the server says so, not at the next poll.
sub togetherHeard()
    if m.top.getParent() = invalid
        m.global.unobserveFieldScoped("live")
    else if m.top.visible and not togetherMine() and liveNames(m.global.live.events, "watch_together")
        togetherPoll()
    end if
end sub

function togetherMine() as boolean
    return m.tg <> invalid and togetherMember(m.tg, m.global.profileId) <> invalid
end function

' A popped view stops; one under the player waits, since the player
' follows the Watch together itself.
sub togetherTick()
    if m.top.getParent() = invalid
        m.tgTimer.control = "stop"
        return
    end if
    if not m.top.visible then return
    m.tgTicks = m.tgTicks + 1
    if togetherMine() or m.tgTicks mod 5 = 0 then togetherPoll()
    togetherCount()
end sub

sub togetherPoll()
    if m.tgBusy then return
    if togetherMine()
        togetherAsk("one", "getWatchTogether", { watchTogetherId: m.tg.id }, { "after": m.tg.version })
    else
        togetherAsk("list", "listWatchTogethers", {}, { itemId: m.tgItem.id })
    end if
end sub

' One request at a time: an action replaces a poll in flight, whose answer
' is then never read.
sub togetherAsk(kind as string, op as string, params as object, query as object, body = invalid as dynamic)
    m.tgBusy = true
    m.tgAsk = kind
    netCall(op, params, query, body, "onTogether")
end sub

sub onTogether(event as object)
    m.tgBusy = false
    r = event.getData()
    ask = m.tgAsk
    if r.ok
        if ask = "list" then togetherTake(togetherPick(r.data.items, m.global.profileId))
        if ask = "one" or ask = "act" then togetherTake(r.data)
        if ask = "start" then togetherStarted(r.data)
        if ask = "gone" then togetherTake(invalid)
    else if ask = "one" and r.status = 404
        togetherTake(invalid)
    else if ask = "act" or ask = "gone" or ask = "start"
        d = CreateObject("roSGNode", "StandardMessageDialog")
        d.title = "Watch together"
        d.message = [r.message]
        d.buttons = ["OK"]
        d.observeFieldScoped("buttonSelected", "onTogetherClosed")
        m.top.getScene().dialog = d
    end if
end sub

sub onTogetherClosed()
    m.top.getScene().dialog.close = true
end sub

' A new stage redraws the view, moving focus off a control it removed.
sub togetherTake(now as dynamic)
    if now <> invalid and now.status = "ended" then now = invalid
    if now <> invalid and togetherStale(m.tg, now) then return
    was = m.tg
    m.tg = now
    m.tgSince.Mark()
    ' Not while the player is on top: a held poll may answer then.
    if now <> invalid and togetherStarts(was, now) and m.top.visible then togetherOpen(invalid)
    stage = togetherStage(now, m.global.profileId)
    key = stage
    if now <> invalid
        key = key + now.id.ToStr()
        for each x in now.members
            key = key + "," + x.name + x.deviceName
        end for
    end if
    if key = m.tgKey
        togetherCount()
        return
    end if
    m.tgKey = key
    moved = { none: "together", waiting: "cancel", join: "join", joined: "play" }
    if m.current = "together" or m.current = "cancel" or m.current = "join" or m.current = "leave" then m.current = moved[stage]
    redraw()
end sub

function togetherJoinText(sinceMs as integer) as string
    return "Join " + togetherName(togetherHost(m.tg), m.global.profileId) + " · " + togetherCountdown(m.tg, sinceMs)
end function

' The countdowns, once a second.
sub togetherCount()
    stage = togetherStage(m.tg, m.global.profileId)
    since = m.tgSince.TotalMilliseconds()
    if stage = "waiting" and m.tgNodes.pill <> invalid then m.tgNodes.pill.text = "Waiting for someone to join · " + togetherCountdown(m.tg, since)
    if stage = "join" and m.tgNodes.join <> invalid
        m.tgNodes.join.text = togetherJoinText(since)
        m.tgNodes.note.text = togetherNote(m.tg, m.global.profileId, m.tgTitle, since)
    end if
end sub

function togetherButton(id as string, text as string, kind as string, icon as string) as object
    b = uiButton(m.top, id, text, kind, 0, 0, false, icon)
    m.controls[id] = b
    return b
end function

' Lays out the view's button row, row[0] its Play, with Watch together's
' part after it, or on a line of its own when the row would pass the
' right margin, then the note. m.layout[0] holds the row's ids. Answers
' how far the content below moves down.
function togetherRow(row as object, x as integer, y as integer, width as integer) as integer
    m.tgNodes = {}
    me = m.global.profileId
    stage = togetherStage(m.tg, me)
    since = m.tgSince.TotalMilliseconds()
    part = []
    ids = []
    if stage = "none"
        part.Push(togetherButton("together", "Watch together", "s", "users"))
        ids.Push("together")
    else if stage = "waiting"
        pill = uiChip(m.top, "Waiting for someone to join · " + togetherCountdown(m.tg, since), "accent", "dot", 76, 28)
        m.tgNodes.pill = pill.GetChild(2)
        part.Push(pill)
        part.Push(togetherButton("cancel", "Cancel", "s", ""))
        ids.Push("cancel")
    else if stage = "join"
        m.tgNodes.join = togetherButton("join", togetherJoinText(since), "o", "users")
        part.Push(m.tgNodes.join)
        ids.Push("join")
    else if stage = "joined"
        row[0].text = "Play together"
        name = ""
        other = togetherOther(m.tg, me)
        if other <> invalid then name = togetherName(other, me)
        part.Push(uiChip(m.top, "In sync with " + name, "ok", "users", 76, 30))
        part.Push(togetherButton("leave", "Leave", "s", ""))
        ids.Push("leave")
    end if
    uiRow(row, x, y, 24)
    last = row[row.Count() - 1]
    right = last.translation[0] + last.boundingRect().width
    w = 0
    for each n in part
        w = w + n.boundingRect().width + 24
    end for
    extra = 0
    if right + w > 1824
        uiRow(part, x, y + 96, 24)
        m.layout.Push(ids)
        extra = 96
    else
        uiRow(part, right + 24, y, 24)
        m.layout[0].Append(ids)
    end if
    note = togetherNote(m.tg, me, m.tgTitle, since)
    if note <> ""
        l = uiLabel(m.top, note, 24, false, "dim", x, y + 104 + extra, width)
        m.tgNodes.note = l
        extra = extra + Int(l.boundingRect().height) + 18
    end if
    return extra
end function

' OK on one of Watch together's controls; false for any other.
function togetherSelect(id as string) as boolean
    if id = "together"
        togetherAsk("act", "openWatchTogether", {}, {}, { itemId: m.tgItem.id })
    else if id = "join"
        togetherAsk("act", "joinWatchTogether", { watchTogetherId: m.tg.id }, {})
    else if id = "cancel" or id = "leave"
        togetherAsk("gone", "leaveWatchTogether", { watchTogetherId: m.tg.id }, {})
    else
        return false
    end if
    return true
end function

' Plays the title. Joined, Play together plays for both, and each side's
' player opens as the shared state turns to playing.
sub togetherPlay(positionMs as dynamic)
    if positionMs = invalid and togetherMine() and m.tg.status = "joined"
        at = togetherExpected(m.tg, m.tgSince.TotalMilliseconds())
        togetherAsk("start", "setWatchTogetherState", { watchTogetherId: m.tg.id }, {}, { "playing": true, "positionMs": at })
        return
    end if
    togetherOpen(positionMs)
end sub

' Play together's answer; one that was already playing opens no player
' by itself.
sub togetherStarted(now as object)
    playing = m.tg <> invalid and m.tg.playing
    togetherTake(now)
    if playing and m.tg <> invalid and m.tg.playing then togetherOpen(invalid)
end sub

' Opens the player. In a Watch together it follows it, from the shared
' position once joined unless positionMs says otherwise.
sub togetherOpen(positionMs as dynamic)
    n = { to: "player", item: m.tgItem }
    if togetherMine()
        n.together = m.tg
        if positionMs = invalid and m.tg.status = "joined" then positionMs = togetherExpected(m.tg, m.tgSince.TotalMilliseconds())
    end if
    if positionMs <> invalid then n.positionMs = positionMs
    if m.audioTrackId <> invalid then n.audioTrackId = m.audioTrackId
    ' A Watch together plays the default edition.
    if m.edition <> invalid and not togetherMine() then n.editionId = m.edition.id
    m.top.navigate = n
end sub
