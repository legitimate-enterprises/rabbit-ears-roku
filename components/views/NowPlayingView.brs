' Draws the MusicPlayer's now and follows it; Back returns to where it was
' opened. Play/pause toggles, rewind and fast forward change track, and
' left and right on the seek bar seek; Stop clears the queue; the options
' key (*) swaps the art for the song's file details and back. A station has only Stop and
' a read-only Up next; off air it shows the station's name and when it is
' back, and Back stops it.
sub init()
    m.top.observeField("focusedChild", "uiRestore")
    m.music = m.global.music
    m.music.observeFieldScoped("now", "onNow")
    m.music.observeFieldScoped("position", "onPosition")
    m.controls = {}
    m.rings = {}
    m.layout = [["shuffle", "repeat", "stop"], ["seek"]]
    m.current = "seek"
    m.clock = invalid
    m.knob = invalid
    m.drawn = false
    m.groups = []
    m.details = false
end sub

sub load()
    draw()
end sub

sub onNow()
    if gone() then return
    draw()
end sub

sub onPosition()
    if gone() then return
    tick()
end sub

' A popped Now playing stops following the music.
function gone() as boolean
    if not uiDetached() then return false
    m.music.unobserveFieldScoped("now")
    m.music.unobserveFieldScoped("position")
    return true
end function

sub draw()
    now = m.music.now
    if now.song = invalid and now.station = invalid
        ' The queue ran out or the station stopped: nothing is left to show.
        if m.drawn then m.top.navigate = { to: "back" }
        return
    end if
    m.drawn = true
    song = now.song
    ' Read before the redraw removes the focused control.
    focused = m.top.isInFocusChain()
    uiClear(m.top)
    m.controls = {}
    m.rings = {}
    m.clock = invalid
    m.knob = invalid
    m.layout = [["shuffle", "repeat", "stop"], ["seek"]]
    if now.station <> invalid then m.layout = [["stop"]]
    if song = invalid
        offAir(now)
        refocus(focused)
        return
    end if
    tint = uiRect(m.top, 0, 0, 1920, 1080, uiArtColor(song.albumId))
    tint.opacity = 0.25
    uiImage(m.top, "fade.png", 0, 0, 1920, 1080)
    m.groups = musicDetails(now.audio)
    if m.details and m.groups.Count() > 0
        detailsPanel(m.groups)
    else
        uiArt(m.top, { id: song.albumId }, "poster", 96, 225, 500, 500, uiArtUrl(song, "poster", song.albumId), "album")
    end if
    x = 652
    if now.station <> invalid
        uiLabel(m.top, "Station · " + now.station, 26, false, "sub", x, 358)
    else if now.from <> ""
        uiLabel(m.top, "Playing from " + now.from, 26, false, "sub", x, 358)
    end if
    ' Title, artist and album sit at fixed heights, the title's two lines
    ' reserved, so the controls below never move between songs.
    title = uiLabel(m.top, song.title, 64, true, "text", x, 395, 480)
    title.maxLines = 2
    oneLine(song.artistName, 36, true, x, 563)
    oneLine(song.albumTitle, 32, false, x, 613)
    if now.station <> invalid
        m.controls.stop = uiButton(m.top, "stop", "Stop", "s", x, 683, true, "stop")
    else
        m.controls.shuffle = uiButton(m.top, "shuffle", "Shuffle", uiPick(now.shuffle, "p", "s"), 0, 0, true, "shuffle")
        m.controls.repeat = uiButton(m.top, "repeat", "Repeat", uiPick(now.repeat, "p", "s"), 0, 0, true, "repeat")
        m.controls.stop = uiButton(m.top, "stop", "Stop", "s", 0, 0, true, "stop")
        uiRow([m.controls.shuffle, m.controls.repeat, m.controls.stop], x, 683, 20)
    end if
    m.clock = uiLabel(m.top, "", 30, false, "text", 96, 764)
    m.left = uiLabel(m.top, "", 30, false, "text", 1012, 764)
    m.left.width = 96
    m.left.horizAlign = "right"
    m.bar = m.top.CreateChild("Group")
    m.bar.translation = [182, 780]
    m.barWidth = 826
    uiRect(m.bar, 0, 0, m.barWidth, 8, "0xFFFFFF40")
    m.fill = uiRect(m.bar, 0, 0, 0, 8, uiColor("accent"))
    if now.station <> invalid
        uiLabel(m.top, "The station sets the order. Songs cannot be skipped.", 26, false, "sub", 96, 824)
    else
        m.knob = m.bar.CreateChild("Group")
        m.knob.focusable = true
        uiImage(m.knob, "disc.png", -14, -10, 28, 28, uiColor("accent"))
        m.controls.seek = m.knob
        m.rings.seek = uiImage(m.knob, "disc-ring.png", -24, -20, 48, 48, uiColor("accent"))
        m.rings.seek.visible = false
        uiLabel(m.top, "Play/pause on the remote. Rewind and fast forward change track; left and right seek.", 26, false, "sub", 96, 824)
    end if
    if m.groups.Count() > 0 then uiLabel(m.top, uiPick(m.details, "* shows the album art.", "* shows the file details."), 26, false, "sub", 96, 864)
    upNext(now.upNext)
    tick()
    refocus(focused)
end sub

' One line, cut with an ellipsis rather than wrapped, so what follows
' stays put.
sub oneLine(text as dynamic, size as integer, bold as boolean, x as integer, y as integer)
    if text = invalid then return
    uiLabel(m.top, text, size, bold, "accent", x, y, 480).maxLines = 1
end sub

' The file details in the art's place, 500 x 500: each group's title over
' its rows, a dim label at the left and the value at the right edge, the
' whole centered.
sub detailsPanel(groups as object)
    uiShape(m.top, 16, 96, 225, 500, 500, uiColor("raised"))
    height = 24 * (groups.Count() - 1)
    for each g in groups
        height = height + 34 + 38 * g.rows.Count()
    end for
    y = 225 + (500 - height) \ 2
    for each g in groups
        uiLabel(m.top, g.title, 24, true, "sub", 128, y)
        y = y + 34
        for each r in g.rows
            uiLabel(m.top, r.label, 26, false, "dim", 128, y)
            v = uiLabel(m.top, r.value, 26, false, r.tone, 0, y)
            right = 564 - Int(v.boundingRect().width)
            v.translation = [right, y]
            if r.tag <> ""
                chip = uiShape(m.top, 12, 0, y + 1, 0, 30, uiColor("tag"))
                l = uiLabel(m.top, r.tag, 22, true, "text", 0, y + 4)
                chip.width = l.boundingRect().width + 20
                chip.translation = [right - 10 - chip.width, y + 1]
                l.translation = [right - chip.width, y + 4]
            end if
            y = y + 38
        end for
        y = y + 24
    end for
end sub

' Focus stays on its control while the screen has it; a station and the
' queue have none in common.
sub refocus(focused as boolean)
    if m.controls[m.current] = invalid then m.current = m.layout[m.layout.Count() - 1][0]
    if focused then uiFocus(m.current)
end sub

' A station with nothing playing: its own image, else the brand mark, in
' the art's place, its name, when it is back or what is next, and Stop.
sub offAir(now as object)
    uiShape(m.top, 16, 96, 225, 500, 500, uiColor("raised"))
    if now.imageUrl <> invalid
        uiArt(m.top, { id: 0 }, "poster", 96, 225, 500, 500, m.global.server + now.imageUrl)
    else
        uiImage(m.top, "brand.png", 266, 395, 160, 160)
    end if
    x = 652
    uiLabel(m.top, "Station", 26, false, "sub", x, 358)
    title = uiLabel(m.top, now.station, 64, true, "text", x, 395, 480)
    title.maxLines = 2
    y = 395 + Int(title.boundingRect().height) + 12
    if now.lines.Count() > 0 then uiLabel(m.top, now.lines[0], 36, false, "sub", x, y)
    m.controls.stop = uiButton(m.top, "stop", "Stop", "s", x, y + 122, true, "stop")
end sub

sub upNext(songs as object)
    if songs.Count() = 0 then return
    uiLabel(m.top, "Up next", 36, true, "text", 1220, 226)
    y = 298
    ' A station's ten rows close up to stay on screen; a queue shows six.
    pitch = 96
    if songs.Count() > 7 then pitch = 742 \ songs.Count()
    for each s in songs
        uiArt(m.top, { id: s.albumId }, "poster", 1220, y, 60, 60, uiArtUrl(s, "poster", s.albumId), "album")
        uiLabel(m.top, s.title, 30, true, "text", 1304, y - 6).width = 400
        uiLabel(m.top, s.artistName, 26, false, "dim", 1304, y + 34).width = 400
        if s.durationMs <> invalid
            d = uiLabel(m.top, formatClock(Int(s.durationMs / 1000)), 30, false, "dim", 1708, y + 10)
            d.width = 100
            d.horizAlign = "right"
        end if
        y = y + pitch
    end for
end sub

sub tick()
    if m.clock = invalid then return
    at = m.music.position
    duration = m.music.duration
    m.clock.text = formatClock(at)
    m.left.text = "-" + formatClock(duration - at)
    x = 0
    if duration > 0 then x = Int(m.barWidth * at / duration)
    if x > m.barWidth then x = m.barWidth
    m.fill.width = x
    if m.knob <> invalid then m.knob.translation = [x, 0]
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    now = m.music.now
    ' Off air, leaving stops the station rather than leave it to start
    ' unseen. The view leaves first, so the stop's redraw cannot leave again.
    if key = "back" and now.station <> invalid and now.song = invalid
        m.top.navigate = { to: "back" }
        m.music.command = { op: "stopStation" }
        return true
    end if
    if key = "options" and now.song <> invalid and m.groups.Count() > 0
        m.details = not m.details
        draw()
        return true
    end if
    if key = "OK" and m.current = "stop"
        m.music.command = { op: uiPick(now.station <> invalid, "stopStation", "stop") }
        return true
    end if
    op = { play: "toggle", rewind: "previous", fastforward: "next" }[key]
    if op = invalid and key = "OK" then op = { seek: "toggle", shuffle: "shuffle", repeat: "repeat" }[m.current]
    if op <> invalid
        m.music.command = { op: op }
        return true
    end if
    if m.current = "seek" and (key = "left" or key = "right")
        by = 10
        if key = "left" then by = -10
        m.music.command = { op: "seek", by: by }
        return true
    end if
    return uiArrow(key)
end function
