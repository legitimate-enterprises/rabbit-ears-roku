' Shared by Details and Season: loading, the facts line, and the
' watched, play and shuffle actions.

sub load()
    netLoad("details", { itemId: m.top.params.item.id, profileId: m.global.profileId }, "onDetails")
end sub

' A popped view stops reloading.
sub reload()
    if uiDetached()
        m.global.unobserveFieldScoped("stateVersion")
        return
    end if
    netLoad("details", { itemId: m.top.params.item.id, profileId: m.global.profileId }, "onDetails")
end sub

sub onDetails(event as object)
    r = event.getData()
    if not r.ok
        focused = m.top.isInFocusChain()
        uiClear(m.top)
        uiLabel(m.top, "Couldn't load this: " + r.message, 30, false, "dim", 96, 96)
        ' The focused control is gone; the view keeps focus so Back still works.
        if focused then m.top.setFocus(true)
        return
    end if
    m.d = r.data
    redraw()
end sub

' Draws m.d again, keeping focus on the same control while it exists.
sub redraw()
    m.controls = {}
    m.rings = {}
    keep = m.current
    m.current = invalid
    ' Read before the redraw removes the focused control.
    focused = m.top.isInFocusChain()
    uiClear(m.top)
    draw()
    if keep <> invalid and m.controls[keep] <> invalid then m.current = keep
    if focused then uiFocus(m.current)
end sub

sub factsLine(parts as object, x as integer, y as integer)
    uiFacts(m.top, parts, x, y)
end sub

function videoTags(file as dynamic) as object
    tags = []
    if file = invalid then return tags
    for each t in file.tracks
        if t.kind = "video"
            if formatResolution(t.width, t.height) = "4K" then tags.Push({ text: "4K", tag: true })
            if t.hdrFormat <> invalid then tags.Push({ text: "HDR", tag: true })
            exit for
        end if
    end for
    return tags
end function

function runtimeOf(item as object) as dynamic
    if item.metadata = invalid then return invalid
    return item.metadata.runtimeMinutes
end function

function overviewOf(item as object) as string
    if item.metadata = invalid or item.metadata.overview = invalid then return ""
    return item.metadata.overview
end function

' Playing resumes from the watch state unless positionMs says otherwise.
sub play(item as object, positionMs = invalid as dynamic)
    n = { to: "player", item: item }
    if positionMs <> invalid then n.positionMs = positionMs
    if m.audioTrackId <> invalid then n.audioTrackId = m.audioTrackId
    m.top.navigate = n
end sub

' Plays items, the episodes of the show series or of one of its seasons,
' once each in random order.
sub shuffle(items as object, series as object)
    n = libraryQueueNext(libraryShuffle(items, series, libraryDraw))
    if n = invalid then return
    n.to = "player"
    m.top.navigate = n
end sub

sub markWatched(item as object, watched as boolean)
    netCall("putWatchState", { profileId: m.global.profileId, itemId: item.id }, {}, { watched: watched, positionMs: 0 }, "onMarked")
end sub

' A show or season stands for its episodes, so one id is one request however many there are.
sub markAll(parent as object, watched as boolean)
    netLoad("markAll", { profileId: m.global.profileId, itemIds: [parent.id], watched: watched }, "onMarked")
end sub

sub onMarked()
    m.global.stateVersion = m.global.stateVersion + 1
end sub

function allWatched(episodes as object, states as object) as boolean
    for each e in episodes
        w = states[e.id.ToStr()]
        if w = invalid or not w.watched then return false
    end for
    return true
end function
