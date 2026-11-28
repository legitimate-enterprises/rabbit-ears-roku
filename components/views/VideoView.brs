' params.video is the YouTubeVideo; its file, this device's verdict and
' more from its channel are loaded.
sub init()
    m.top.observeField("focusedChild", "uiRestore")
    m.global.observeFieldScoped("stateVersion", "onStateVersion")
    m.d = invalid
    m.controls = {}
    m.rings = {}
    m.layout = []
end sub

' A popped view stops reloading.
sub onStateVersion()
    if uiDetached() then m.global.unobserveFieldScoped("stateVersion") else load()
end sub

sub load()
    netLoad("video", { videoId: m.top.params.video.id }, "onVideo")
end sub

sub onVideo(event as object)
    r = event.getData()
    if not r.ok
        focused = m.top.isInFocusChain()
        uiClear(m.top)
        m.controls = {}
        m.rings = {}
        m.d = invalid
        uiLabel(m.top, "Couldn't load this: " + r.message, 30, false, "dim", 96, 96)
        ' The focused control is gone; the view keeps focus so Back still works.
        if focused then m.top.setFocus(true)
        return
    end if
    m.d = r.data
    redraw()
end sub

' Watch together's answers may land while the error shows; nothing to draw.
sub redraw()
    if m.d = invalid then return
    focused = m.top.isInFocusChain()
    uiClear(m.top)
    m.controls = {}
    m.rings = {}
    v = m.d.video
    togetherStart(m.top.params.video, v.title)
    started = v.positionMs > 0
    still = uiArt(m.top, v, "poster", 96, 96, 640, 360, "", "video")
    uiProgress(still, 0, 354, 640, libraryResumeFraction({ item: v, state: v, video: true }))
    x = 792
    uiRound(m.top, v.channelId, x, 96, 36, "channel", m.global.server + libraryChannelArtPath(v))
    uiLabel(m.top, v.channelTitle, 28, true, "accent", x + 48, 98)
    title = uiLabel(m.top, v.title, 68, true, "text", x, 140, 1032)
    title.maxLines = 2
    y = 140 + Int(title.boundingRect().height) + 12
    parts = [{ text: formatDuration(v.durationMs) }, { text: formatDate(v.publishedOn) }]
    if v.height <> invalid then parts.Push({ text: formatResolution(Int(v.height * 16 / 9), v.height), tag: true })
    uiFacts(m.top, parts, x, y)
    m.controls.play = uiButton(m.top, "play", uiPick(started, "Resume", "Play"), "p", 0, 0, false, "play")
    row = [m.controls.play]
    m.layout = [["play"]]
    if started
        m.controls.start = uiButton(m.top, "start", "Start over", "s", 0, 0)
        row.Push(m.controls.start)
        m.layout[0].Push("start")
    end if
    m.controls.watched = uiButton(m.top, "watched", uiPick(v.watched, "Mark unwatched", "Mark watched"), "s", 0, 0, false, "check")
    row.Push(m.controls.watched)
    m.layout[0].Push("watched")
    extra = togetherRow(row, x, y + 62, 1000)
    y = y + 178 + extra
    if v.overview <> invalid
        l = uiLabel(m.top, v.overview, 28, false, "sub", x, y, 1000)
        l.maxLines = 3
        y = y + Int(l.boundingRect().height) + 24
    end if
    facts(x, y, extra > 0)
    more()
    if m.current = invalid or m.controls[m.current] = invalid then m.current = "play"
    if focused then uiFocus(m.current)
end sub

' Chapters, Subtitles and the video line with this device's verdict.
' Short, under Watch together's note, is the video line alone, and only
' while it ends above More from.
sub facts(x as integer, y as integer, short as boolean)
    file = m.d.file
    if file = invalid then return
    chapters = ""
    if file.chapters <> invalid and file.chapters.Count() > 0 then chapters = file.chapters.Count().ToStr()
    rows = [["Chapters", chapters], ["Subtitles", formatSubtitles(file.tracks)], ["Video", formatVideo(file)]]
    if short then rows = [rows[2]]
    for each r in rows
        if short and y + 44 > 674 then exit for
        if r[1] <> ""
            uiLabel(m.top, r[0], 28, false, "dim", x, y)
            l = uiLabel(m.top, r[1], 28, false, "text", x + 138, y)
            if r[0] = "Video" and m.d.playability <> invalid
                lx = x + 138 + Int(l.boundingRect().width)
                verdict = m.d.playability.verdict
                v = uiLabel(m.top, " · " + qualityVerdict(verdict), 28, false, uiPick(verdict = "direct_play", "ok", "accent"), lx, y)
                uiLabel(m.top, " on this device", 28, false, "text", lx + Int(v.boundingRect().width), y)
            end if
            y = y + 44
        end if
    end for
end sub

sub more()
    if m.d.more.Count() = 0 then return
    uiLabel(m.top, "More from " + m.d.video.channelTitle, 30, true, "text", 96, 690)
    w = (1920 - 192 - 3 * 28) \ 4
    h = Int(w * 9 / 16)
    today = formatToday()
    row = []
    for i = 0 to m.d.more.Count() - 1
        v = m.d.more[i]
        id = "m" + i.ToStr()
        px = 96 + i * (w + 28)
        p = uiPanel(m.top, id, 16, px, 746, w, h, "card")
        uiArt(p, v, "poster", 0, 0, w, h, "", "video")
        uiProgress(p, 0, h - 6, w, libraryResumeFraction({ item: v, state: v, video: true }))
        if not v.watched then uiImage(p, "disc.png", w - 32, 14, 18, 18, uiColor("accent"))
        p.removeChild(m.rings[id])
        p.appendChild(m.rings[id])
        uiLabel(m.top, v.title, 26, true, "text", px, 746 + h + 12).width = w
        uiLabel(m.top, formatVideoCaption(v, today, false), 24, false, "dim", px, 746 + h + 46).width = w
        row.Push(id)
    end for
    m.layout.Push(row)
end sub

sub onMarked()
    m.global.stateVersion = m.global.stateVersion + 1
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or m.d = invalid then return false
    v = m.d.video
    if key = "OK" and m.current = "play"
        togetherPlay(invalid)
    else if key = "OK" and m.current = "start"
        togetherPlay(0)
    else if key = "OK" and togetherSelect(m.current)
        return true
    else if key = "OK" and m.current = "watched"
        netCall("putWatchState", { profileId: m.global.profileId, itemId: v.id }, {}, { watched: not v.watched, positionMs: 0 }, "onMarked")
    else if key = "OK" and Left(m.current, 1) = "m"
        m.top.navigate = { to: "details", view: "VideoView", video: m.d.more[m.current.Mid(1).ToInt()] }
    else
        return uiArrow(key)
    end if
    return true
end function
