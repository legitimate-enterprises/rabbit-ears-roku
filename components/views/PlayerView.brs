' params: { item, editionId, positionMs, audioTrackId, together, queue, playlistId,
' index }, or { station } to tune in. index is the playlist row playing.
' At the end Up next offers what the server plays next, Play now focused,
' and with Autoplay on plays it after a countdown; with nothing next, or
' together, the player closes.
' The remote does pause, seek and back; the overlay holds the seek bar,
' the pill, Subtitles and Next episode. The options key is never bound
' here. A Watch together keeps this player in step with the other
' member's; queue is a playlist's play order after this one. A station
' plays what is on with no pause, seek or knob, and between programs and
' off schedule shows its name until it asks again. A title still playing
' on another device of the profile is asked about first: Move here, Watch
' together or Cancel. Another device may in turn take this player's
' session, which closes it, or ask it into a Watch together.
sub init()
    m.quality = { auto: true }
    m.subtitle = "forced"
    m.stalls = 0
    m.played = false
    m.hold = false
    m.startMs = invalid
    m.gone = false
    m.segment = invalid
    m.scrub = invalid
    m.bif = invalid
    m.bifSession = invalid
    m.menu = invalid
    m.tg = invalid
    m.syncKey = ""
    m.syncBusy = false
    m.notice = ""
    m.queue = []
    m.upNext = invalid
    m.station = invalid
    m.tuning = false
    m.knob = invalid
    m.controls = {}
    m.rings = {}
    m.video = m.top.CreateChild("Video")
    m.video.width = 1920
    m.video.height = 1080
    m.video.enableUI = false
    m.video.observeFieldScoped("state", "onState")
    m.video.observeFieldScoped("position", "onPosition")
    m.video.observeFieldScoped("streamingSegment", "onSegment")
    m.loading = uiLabel(m.top, "Loading", 30, true, "sub", 0, 520)
    m.loading.width = 1920
    m.loading.horizAlign = "center"
    m.overlay = m.top.CreateChild("Group")
    m.overlay.visible = false
    m.hide = timer(5, false, "onHide")
    m.report = timer(10, true, "onReport")
    m.watch = CreateObject("roSGNode", "DeviceWatchTask")
    m.watch.observeFieldScoped("changed", "onChanged")
    m.top.observeField("focusedChild", "uiRestore")
end sub

function timer(seconds as integer, again as boolean, handler as string) as object
    t = m.top.CreateChild("Timer")
    t.duration = seconds
    t.repeat = again
    t.observeFieldScoped("fire", handler)
    return t
end function

sub start()
    p = m.top.params
    if p.station <> invalid
        m.station = p.station
        m.ends = timer(1, false, "onProgramEnd")
        m.waiting = m.top.CreateChild("Group")
        tune()
        return
    end if
    m.global.observeFieldScoped("live", "onLive")
    if p.together = invalid
        netCall("listPlaybackSessions", {}, { itemId: p.item.id }, invalid, "onElsewhere")
    else
        begin(p)
    end if
end sub

sub onElsewhere(event as object)
    if m.gone then return
    r = event.getData()
    m.there = invalid
    if r.ok then m.there = liveElsewhere(r.data.items)
    if m.there = invalid
        begin(m.top.params)
        return
    end if
    m.choices = liveChoices()
    m.chose = false
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = liveTitle(m.there)
    d.buttons = m.choices
    d.observeFieldScoped("buttonSelected", "onHandoff")
    d.observeFieldScoped("wasClosed", "onHandoffClosed")
    m.top.getScene().dialog = d
end sub

sub onHandoff(event as object)
    choice = m.choices[event.getData()]
    m.chose = true
    m.top.getScene().dialog.close = true
    if choice = "Move here"
        netCall("movePlaybackSession", { sessionId: m.there.id }, {}, invalid, "onMovedHere")
    else if choice = "Watch together"
        netCall("openWatchTogether", {}, {}, { itemId: m.top.params.item.id, fromSessionId: m.there.id }, "onOpenedThere")
    else
        leave("back")
    end if
end sub

' Back on the dialog is Cancel.
sub onHandoffClosed()
    if not m.chose then leave("back")
end sub

' The session there has ended; this one starts where it was.
sub onMovedHere(event as object)
    r = event.getData()
    if m.gone then return
    if not r.ok
        fail(r.message)
        return
    end if
    p = m.top.params
    p.positionMs = r.data.positionMs
    begin(p)
end sub

' The device there joins by itself and plays for both.
sub onOpenedThere(event as object)
    r = event.getData()
    if m.gone
        if r.ok then netCall("leaveWatchTogether", { watchTogetherId: r.data.id }, {}, invalid, "onReported")
        return
    end if
    if not r.ok
        fail(r.message)
        return
    end if
    p = m.top.params
    p.together = r.data
    p.positionMs = m.there.positionMs
    begin(p)
end sub

sub onLive()
    if m.gone or m.stream = invalid then return
    events = m.global.live.events
    session = m.stream.sessionId
    if liveMoved(events, session) then netCall("getPlaybackSession", { sessionId: session }, {}, invalid, "onTaken")
    asked = liveAsked(events, session)
    if asked <> invalid and m.tg = invalid then netCall("joinWatchTogether", { watchTogetherId: asked }, {}, invalid, "onAsked")
end sub

' Another device took the session with Move here. The server has ended
' it, so the router is given none to end.
sub onTaken(event as object)
    r = event.getData()
    n = close()
    if n = invalid then return
    name = "another device"
    if r.ok and r.data.movedToDeviceName <> invalid then name = r.data.movedToDeviceName
    n.endSession = invalid
    n.to = "back"
    n.notice = "Moved to " + name
    m.top.navigate = n
end sub

' Joined to the Watch together another device opened from this session,
' the player plays for both from where it is.
sub onAsked(event as object)
    r = event.getData()
    if m.gone or not r.ok or m.tg <> invalid then return
    m.info.nextId = invalid
    syncStart(r.data)
    syncAsk("setWatchTogetherState", { "playing": true, "positionMs": nowMs() })
end sub

sub syncStart(w as object)
    m.tg = w
    m.tgSince = CreateObject("roTimespan")
    m.tgSent = CreateObject("roTimespan")
    m.tgSettle = CreateObject("roTimespan")
    ' Half the quickest round trip of a quick poll, taken as an answer's time to arrive.
    m.tgOneWay = 0
    m.tgBest = -1
    ' The latest quick round trip, which the server leads by; negative until one.
    m.tgTrip = -1
    m.tgSamples = 0
    m.syncWait = false
    m.tgDue = timer(1, false, "onSyncDue")
    m.sync = timer(1, true, "onSyncTick")
    m.sync.control = "start"
    m.noticeTimer = timer(4, false, "onNoticeGone")
    syncPoll()
end sub

sub begin(p as object)
    args = { itemId: p.item.id, profileId: m.global.profileId, quality: m.quality }
    if p.positionMs <> invalid then args.positionMs = p.positionMs
    if p.audioTrackId <> invalid then args.audioTrackId = p.audioTrackId
    if p.editionId <> invalid then args.editionId = p.editionId
    ' Always a boolean: a device will not compare an absent value to true.
    args.video = p.item.channelId <> invalid
    if p.playlistId <> invalid then args.playlistId = p.playlistId
    if p.queue <> invalid then m.queue = p.queue
    if p.together <> invalid then syncStart(p.together)
    netLoad("play", args, "onStarted")
end sub

sub onStarted(event as object)
    r = event.getData()
    if m.gone
        ' Back while loading: nothing plays, and the session the server opened is closed.
        if r.ok then netCall("endPlayback", { sessionId: r.data.stream.sessionId }, {}, invalid, "onReported")
        return
    end if
    if not r.ok
        fail(r.message)
        return
    end if
    m.info = r.data
    ' Together, both stop at the end; a playlist goes on to its next row and
    ' stops after its last, never on to the show's next episode.
    if m.tg <> invalid or m.top.params.playlistId <> invalid then m.info.nextId = invalid
    if m.queue.Count() > 0 then m.info.nextId = m.queue[0].id
    m.watch.control = "run"
    m.report.control = "start"
    ' Joined, the stream waits held for Watch together to start it.
    load(r.data.stream, m.tg <> invalid and m.tg.status = "joined")
    if m.tg <> invalid then syncFollow()
    if r.data.stream.previews <> invalid
        m.bifSession = r.data.stream.sessionId
        netLoad("bif", { url: r.data.stream.previews.bifUrl, sessionId: m.bifSession }, "onBif")
    end if
end sub

sub tune()
    m.tuning = true
    m.loading.visible = true
    netLoad("station", { stationId: m.station.id, quality: m.quality }, "onTuned")
end sub

' Plays what is on until it ends, or shows the station waiting; either way
' m.ends asks again when the server said.
sub onTuned(event as object)
    m.tuning = false
    r = event.getData()
    if m.gone
        if r.ok and r.data.stream <> invalid then netCall("endPlayback", { sessionId: r.data.stream.sessionId }, {}, invalid, "onReported")
        return
    end if
    if not r.ok and stationRetryIn(r) > 0
        ' The station shows the failure while m.ends asks again.
        m.loading.visible = false
        uiClear(m.waiting)
        waiting([r.message])
        m.ends.duration = stationRetryIn(r)
        m.ends.control = "start"
        return
    end if
    if not r.ok
        fail(r.message)
        return
    end if
    plan = stationNext(m.station.kind, r.data, CreateObject("roDateTime").AsSeconds())
    if plan.askIn > 0
        m.ends.duration = plan.askIn
        m.ends.control = "start"
    end if
    uiClear(m.waiting)
    if plan.mode <> "on_air"
        m.loading.visible = false
        waiting(plan.lines)
        return
    end if
    now = r.data.onAir.now
    m.info = r.data
    m.info.title = m.station.name
    m.info.subtitle = plan.lines[0]
    m.info.durationMs = now.durationMs
    m.info.nextId = invalid
    ' A program's subtitle tracks are its own.
    if m.subtitle <> "off" then m.subtitle = "forced"
    if m.watch.state <> "run" then m.watch.control = "run"
    m.report.control = "start"
    load(r.data.stream)
end sub

' The station's own image or the brand mark, its name and Next or Back, as
' the boards draw a station between programs and off schedule.
sub waiting(lines as object)
    uiRect(m.waiting, 0, 0, 1920, 1080, uiColor("ground"))
    if m.station.imageUrl <> invalid
        uiArt(m.waiting, { id: 0 }, "poster", 760, 152, 400, 400, m.global.server + m.station.imageUrl)
    else
        uiImage(m.waiting, "brand.png", 880, 352, 160, 160)
    end if
    name = uiLabel(m.waiting, m.station.name, 76, true, "text", 0, 572)
    name.width = 1920
    name.horizAlign = "center"
    if lines.Count() = 0 then return
    line = uiLabel(m.waiting, lines[0], 36, false, "sub", 0, 690)
    line.width = 1920
    line.horizAlign = "center"
end sub

' The program ended, by its stream or its endsAt: its session ends and the
' station is asked again, which starts the next program or says when.
sub onProgramEnd()
    if m.gone or m.tuning then return
    m.ends.control = "stop"
    if m.stream <> invalid
        m.report.control = "stop"
        m.video.control = "stop"
        if m.menu <> invalid then m.overlay.removeChild(m.menu)
        m.menu = invalid
        m.overlay.visible = false
        m.top.setFocus(true)
        netCall("endPlayback", { sessionId: m.stream.sessionId }, {}, invalid, "onReported")
        m.stream = invalid
    end if
    tune()
end sub

' Plays a stream from its positionMs, with its sidecars as subtitle tracks;
' hold pauses it once it plays, since a Video node cannot start paused.
' An answer that arrives after the viewer left plays nothing.
sub load(stream as object, hold = false as boolean)
    if m.gone then return
    m.stream = stream
    m.hold = hold
    m.startMs = stream.positionMs
    c = CreateObject("roSGNode", "ContentNode")
    c.url = homeStreamBase(m.global.server, m.global.home) + stream.streamUrl
    c.streamFormat = capabilityStreamFormat(stream.streamKind, m.info.container)
    c.title = m.info.title
    c.playStart = stream.positionMs / 1000
    tracks = []
    for each s in stream.sidecars
        tracks.Push({ Language: s.language, TrackName: m.global.server + s.url, Description: formatLanguage(s.language) })
    end for
    c.subtitleTracks = tracks
    m.sidecars = FormatJson(stream.sidecars)
    ' A new stream's first buffering is not a stall.
    m.played = false
    m.video.content = c
    m.video.control = "play"
    captions()
    drawOverlay()
end sub

' Off hides even the forced track; otherwise the chosen sidecar, or the
' forced one the server always sends.
sub captions()
    pick = invalid
    for each s in m.stream.sidecars
        if (m.subtitle = "forced" and s.forced) or s.trackId.ToStr() = m.subtitle then pick = s
    end for
    if pick = invalid or m.subtitle = "off"
        m.video.globalCaptionMode = "Off"
    else
        m.video.subtitleTrack = m.global.server + pick.url
        m.video.globalCaptionMode = "On"
    end if
end sub

' The rung the player is on, for the pill and the Auto row.
function rungInUse() as dynamic
    r = telemetryRung(m.segment, m.stream.rungs)
    if r.rungBitrate = invalid then return invalid
    return { height: r.rungHeight, bitrate: r.rungBitrate }
end function

sub drawOverlay()
    ' Read before the redraw removes the focused control. A hidden overlay
    ' holds focus too; left on a removed control, no key reaches the player.
    focused = m.overlay.isInFocusChain()
    uiClear(m.overlay)
    m.controls = {}
    m.rings = {}
    uiRect(m.overlay, 0, 0, 1920, 260, "0x00000080")
    uiImage(m.overlay, "fade.png", 0, 640, 1920, 440, "0x000000FF")
    uiLabel(m.overlay, m.info.title, 44, true, "text", 96, 72)
    subtitle = m.info.subtitle
    if m.tg <> invalid and m.tg.status = "joined" and not m.tg.playing then subtitle = uiPick(subtitle = "", "Paused", subtitle + " · Paused")
    uiLabel(m.overlay, subtitle, 28, false, "sub", 96, 130)
    m.clock = uiLabel(m.overlay, "", 28, false, "text", 96, 888)
    m.left = uiLabel(m.overlay, "", 28, false, "text", 1824 - 120, 888)
    m.left.width = 120
    m.left.horizAlign = "right"
    m.bar = m.overlay.CreateChild("Group")
    m.bar.translation = [232, 904]
    m.barWidth = 1456
    uiRect(m.bar, 0, 0, m.barWidth, 8, "0xFFFFFF40")
    m.fill = uiRect(m.bar, 0, 0, 0, 8, uiColor("accent"))
    m.knob = invalid
    if m.station = invalid
        m.knob = m.bar.CreateChild("Group")
        m.knob.focusable = true
        uiImage(m.knob, "disc.png", -14, -10, 28, 28, uiColor("accent"))
        m.controls.seek = m.knob
        m.rings.seek = uiImage(m.knob, "disc-ring.png", -24, -20, 48, 48, uiColor("accent"))
        m.rings.seek.visible = false
    end if
    m.preview = m.bar.CreateChild("Group")
    m.preview.visible = false
    pill = qualityPill(m.stream, rungInUse())
    p = uiPanel(m.overlay, "pill", 28, 0, 952, 0, 64, "glass")
    x = 22
    for each t in pill.tags
        tag = uiShape(p, 12, x, 15, 0, 34, uiColor("tag"))
        l = uiLabel(p, t, 22, true, "text", x + 10, 17)
        tag.width = l.boundingRect().width + 20
        x = x + tag.width + 14
    end for
    l = uiLabel(p, pill.text, 26, true, "text", x, 16)
    x = x + l.boundingRect().width + 14
    l = uiLabel(p, pill.rate, 26, false, "sub", x, 16)
    w = x + l.boundingRect().width + 22
    p.GetChild(0).width = w
    m.rings.pill.width = w + 20
    p.translation = [(1920 - w) \ 2, 952]
    row = ["pill"]
    right = 1824
    if m.info.nextId <> invalid
        nextButton = uiButton(m.overlay, "next", uiPick(m.queue.Count() > 0, "Next", "Next episode"), "s", 0, 952, true, "next")
        right = right - nextButton.boundingRect().width
        nextButton.translation = [right, 952]
        right = right - 20
        m.controls.next = nextButton
    end if
    subs = uiButton(m.overlay, "subtitles", "Subtitles", "s", 0, 952, true, "subtitles")
    subs.translation = [right - subs.boundingRect().width, 952]
    m.controls.subtitles = subs
    row.Push("subtitles")
    if m.controls.next <> invalid then row.Push("next")
    m.layout = [["seek"], row]
    if m.station <> invalid then m.layout = [row]
    togetherOverlay()
    if m.current = invalid or m.controls[m.current] = invalid then m.current = m.layout[0][0]
    tick()
    ' The old controls are gone; focus moves to their replacements.
    if (m.overlay.visible or focused) and m.menu = invalid then uiFocus(m.current)
end sub

' The clock, remaining time and the bar, at the scrub position while
' scrubbing.
sub tick()
    if m.clock = invalid then return
    duration = m.video.duration
    if m.station <> invalid then duration = m.info.durationMs / 1000
    at = m.video.position
    if m.scrub <> invalid then at = m.scrub
    m.clock.text = formatClock(at)
    m.left.text = "-" + formatClock(duration - at)
    x = 0
    if duration > 0 then x = Int(m.barWidth * at / duration)
    if x > m.barWidth then x = m.barWidth
    m.fill.width = x
    if m.knob <> invalid then m.knob.translation = [x, 0]
end sub

sub onPosition()
    if playerStarted(m.video.state, m.video.position) then m.startMs = invalid
    if m.overlay.visible then tick()
end sub

sub show()
    m.overlay.visible = true
    if m.menu = invalid then uiFocus(m.current)
    m.hide.control = "stop"
    m.hide.control = "start"
end sub

sub onHide()
    if m.menu = invalid and m.scrub = invalid and m.video.state = "playing"
        m.overlay.visible = false
        m.top.setFocus(true)
    end if
end sub

sub onState()
    state = m.video.state
    m.loading.visible = state = "buffering"
    if state = "playing"
        m.played = true
        if m.hold
            m.hold = false
            m.video.control = "pause"
        end if
    else if state = "buffering" and m.played
        m.stalls = m.stalls + 1
        onReport()
    else if state = "error"
        netCall("reportPlaybackEvent", { sessionId: m.stream.sessionId }, {}, { kind: "client_failure", positionMs: nowMs(), reason: Left(m.video.errorMsg + " (" + m.video.errorCode.ToStr() + ")", 500) }, "onFailed")
    else if state = "finished" and m.station <> invalid
        onProgramEnd()
    else if state = "finished" and m.tg <> invalid
        leave("back")
    else if state = "finished"
        askUpNext()
    end if
end sub

sub askUpNext()
    if m.upNext <> invalid or m.gone then return
    p = m.top.params
    query = {}
    if p.playlistId <> invalid then query.playlistId = p.playlistId
    if p.playlistId <> invalid and p.index <> invalid then query.index = p.index
    netCall("getUpNext", { profileId: m.global.profileId, itemId: p.item.id }, query, invalid, "onUpNext")
end sub

sub onUpNext(event as object)
    if m.gone then return
    r = event.getData()
    if not r.ok or r.data = invalid
        leave("back")
        return
    end if
    m.upNext = playerUpNext(r.data, m.queue, m.top.params.index)
    m.upNext.title = r.data.title
    m.autoplay = true
    for each p in m.global.me.profiles
        if p.id = m.global.profileId and p.autoplay <> invalid and p.autoplay = false then m.autoplay = false
    end for
    m.overlay.visible = false
    m.hide.control = "stop"
    m.countdown = timer(1, true, "onCountdown")
    m.secondsLeft = 10
    if m.autoplay then m.countdown.control = "start"
    drawUpNext()
    uiFocus("upPlay")
end sub

' The card: its title, Play now, Cancel and the Autoplay checkbox, with the
' seconds left while Autoplay is on.
sub drawUpNext()
    if m.card = invalid then m.card = m.top.CreateChild("Group")
    uiClear(m.card)
    m.card.translation = [1180, 760]
    uiShape(m.card, 16, 0, 0, 660, 240, uiColor("raised"))
    title = uiLabel(m.card, "Up next: " + m.upNext.title, 30, true, "text", 32, 28, 596)
    title.wrap = false
    left = ""
    if m.autoplay and m.secondsLeft <> invalid then left = "Plays in " + m.secondsLeft.ToStr() + "s"
    uiLabel(m.card, left, 24, false, "sub", 32, 76)
    play = uiButton(m.card, "upPlay", "Play now", "p", 0, 0)
    cancel = uiButton(m.card, "upCancel", "Cancel", "s", 0, 0)
    auto = uiButton(m.card, "upAuto", uiPick(m.autoplay, "Autoplay", "Autoplay off"), "s", 0, 0, false, uiPick(m.autoplay, "check", ""))
    uiRow([play, cancel, auto], 32, 140, 20)
    m.controls.upPlay = play
    m.controls.upCancel = cancel
    m.controls.upAuto = auto
    m.layout = [["upPlay", "upCancel", "upAuto"]]
    if m.current = "upPlay" or m.current = "upCancel" or m.current = "upAuto" then uiFocus(m.current)
end sub

sub onCountdown()
    m.secondsLeft = m.secondsLeft - 1
    if m.secondsLeft <= 0
        m.countdown.control = "stop"
        leave("next")
        return
    end if
    drawUpNext()
end sub

' The checkbox saves Autoplay for the profile, as Preferences would, and
' starts or stops the countdown.
sub flipAutoplay()
    m.autoplay = not m.autoplay
    m.secondsLeft = 10
    if m.autoplay then m.countdown.control = "start" else m.countdown.control = "stop"
    body = {}
    body.AddReplace("autoplay", m.autoplay)
    netCall("setProfilePreferences", { profileId: m.global.profileId }, {}, body, "onAutoplaySaved")
    drawUpNext()
end sub

sub onAutoplaySaved(event as object)
    r = event.getData()
    if not r.ok then return
    who = m.global.me
    for each p in who.profiles
        if p.id = m.global.profileId then p.AddReplace("autoplay", m.autoplay)
    end for
    m.global.me = who
end sub

function nowMs() as integer
    return playerPositionMs(m.startMs, m.video.position)
end function

' In Auto the pill follows the rung the player moved to.
sub onSegment(event as object)
    segment = event.getData()
    ' segType is an integer; 1 is an audio-only segment.
    if segment = invalid or segment.segType = 1 then return
    moved = m.segment = invalid or m.segment.segBitrateBps <> segment.segBitrateBps
    m.segment = segment
    if moved and m.stream.auto = true and m.overlay.visible and m.menu = invalid then drawOverlay()
end sub

' Position and throughput every 10 seconds and on every stall.
sub onReport()
    if m.stream = invalid then return
    path = { sessionId: m.stream.sessionId }
    measured = 0
    info = m.video.streamInfo
    if info <> invalid and info.measuredBitrate <> invalid then measured = info.measuredBitrate
    ' shortcut: the Video node reports no buffer level, so bufferMs is 0; read downloadedSegment if the server ever weighs it.
    sample = telemetrySample(measured, 0, m.stalls, telemetryRung(m.segment, m.stream.rungs), nowMs())
    ' Its own handler: sharing onUpdate would drop the answer to a pending update.
    netCall("reportPlaybackThroughput", path, {}, sample, "onThroughput")
end sub

sub onThroughput(event as object)
    onUpdate(event)
end sub

sub onReported()
end sub

' A changed group, a quality pick or a subtitle pick: the server answers
' continue or a new stream at the same position.
sub update(updates as object)
    netLoad("update", { sessionId: m.stream.sessionId, positionMs: nowMs(), paused: playerPaused(m.video.state, m.hold), updates: updates }, "onUpdate")
end sub

sub onChanged(event as object)
    changed = event.getData()
    updates = []
    if changed.display <> invalid then updates.Push({ op: "updatePlaybackDisplay", body: changed.display })
    if changed.audioRoute <> invalid then updates.Push({ op: "updatePlaybackAudioRoute", body: changed.audioRoute })
    if changed.network <> invalid then updates.Push({ op: "updatePlaybackNetwork", body: capabilityNetwork(deviceAtHome(), m.quality) })
    if updates.Count() > 0 and m.stream <> invalid then update(updates)
end sub

sub onUpdate(event as object)
    r = event.getData()
    ' An answer for a station program that has since ended plays nothing.
    if r = invalid or not r.ok or m.stream = invalid then return
    if r.data.action = "restart" or FormatJson(r.data.stream.sidecars) <> m.sidecars
        ' New sidecars mean new subtitle tracks, which only a new content node carries.
        if r.data.action <> "restart" then r.data.stream.positionMs = nowMs()
        load(r.data.stream, playerPaused(m.video.state, m.hold))
    else
        m.stream = r.data.stream
        captions()
        if m.menu = invalid then drawOverlay()
    end if
end sub

' A client failure marks the entry bad; the server moves down the plan or
' answers 409 when none is left.
sub onFailed(event as object)
    if m.gone then return
    r = event.getData()
    if r.ok
        load(r.data.stream, m.hold)
    else
        fail("This won't play on this TV. " + r.message)
    end if
end sub

sub fail(message as string)
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = "Can't play this"
    d.message = [message]
    d.buttons = ["OK"]
    d.observeFieldScoped("buttonSelected", "onFailClosed")
    m.top.getScene().dialog = d
end sub

sub onFailClosed()
    m.top.getScene().dialog.close = true
    leave("back")
end sub

sub onBif(event as object)
    r = event.getData()
    ' Frames cut after close are dropped as close drops them.
    if m.gone and r.ok then netLoad("dropBif", { sessionId: m.bifSession }, "onReported")
    if r.ok and m.stream <> invalid and r.data.file = bifFile(m.stream.sessionId) then m.bif = r.data
end sub

' Stops the player and answers what the router ends for it, { endSession,
' endPositionMs, leaveTogether }, or invalid once stopped. The router asks
' every view it drops, so a deep link closes a player as Back does.
function close() as dynamic
    if m.gone then return invalid
    m.gone = true
    m.global.unobserveFieldScoped("live")
    at = nowMs()
    if m.video.state = "finished" then at = Int(m.video.duration * 1000)
    m.report.control = "stop"
    m.watch.active = false
    m.video.control = "stop"
    ' A closed player leaves no BIF or frame in RAM-backed tmp:.
    if m.bifSession <> invalid then netLoad("dropBif", { sessionId: m.bifSession }, "onReported")
    n = { endPositionMs: at }
    if m.stream <> invalid then n.endSession = m.stream.sessionId
    ' Back leaves Watch together; it ends for both.
    if m.tg <> invalid
        m.sync.control = "stop"
        n.leaveTogether = m.tg.id
    end if
    return n
end function

' The router ends the session after recording where the viewer stopped.
sub leave(target as string)
    n = close()
    if n = invalid then return
    n.to = target
    if target = "next" then n.item = { id: m.info.nextId }
    if target = "next" and m.upNext <> invalid
        n.item = m.upNext.item
        n.editionId = m.upNext.editionId
        n.queue = m.upNext.queue
        n.index = m.upNext.index
        n.playlistId = invalid
        if n.index <> invalid then n.playlistId = m.top.params.playlistId
    else if target = "next" and m.queue.Count() > 0
        n.item = m.queue[0]
        n.editionId = m.queue[0].editionId
        n.queue = []
        for i = 1 to m.queue.Count() - 1
            n.queue.Push(m.queue[i])
        end for
        n.playlistId = m.top.params.playlistId
        if m.top.params.index <> invalid then n.index = m.top.params.index + 1
    end if
    m.top.navigate = n
end sub

' The frame nearest the scrub position, which the BIF load cut.
sub drawPreview()
    uiClear(m.preview)
    if m.bif = invalid or m.scrub = invalid
        m.preview.visible = false
        return
    end if
    path = bifFrameFile(m.bifSession, bifFrameAt(m.bif.index, m.scrub))
    x = m.fill.width - 200
    uiShape(m.preview, 16, x, -311, 400, 275, uiColor("ground"))
    image = m.preview.CreateChild("Poster")
    image.uri = path
    image.translation = [x, -311]
    image.width = 400
    image.height = 225
    image.loadDisplayMode = "scaleToFit"
    uiLabel(m.preview, formatClock(m.scrub), 26, true, "text", x + 16, -80)
    chapter = chapterAt(m.scrub)
    if chapter <> ""
        l = uiLabel(m.preview, chapter, 26, false, "sub", x + 16, -80)
        l.width = 368
        l.horizAlign = "right"
    end if
    m.preview.visible = true
end sub

function chapterAt(seconds as float) as string
    for each c in m.info.chapters
        if c.title <> invalid and seconds * 1000 >= c.startMs and seconds * 1000 < c.endMs then return c.title
    end for
    return ""
end function

sub scrubBy(seconds as integer)
    if m.scrub = invalid then m.scrub = m.video.position
    m.scrub = m.scrub + seconds
    if m.scrub < 0 then m.scrub = 0
    if m.video.duration > 0 and m.scrub > m.video.duration then m.scrub = m.video.duration
    tick()
    drawPreview()
end sub

sub endScrub(commit as boolean, resume = false as boolean)
    if commit
        seekTo(m.scrub)
        if resume
            m.hold = false
            m.video.control = "resume"
        end if
        syncLocal(resume or not playerPaused(m.video.state, m.hold), Int(m.scrub * 1000))
    end if
    m.scrub = invalid
    drawPreview()
    tick()
end sub

sub openMenu(kind as string)
    m.menuKind = kind
    m.menu = m.overlay.CreateChild("OptionMenu")
    if kind = "quality"
        m.options = qualityOptions(m.stream, m.quality, m.info.source, rungInUse())
        if m.stream.away = true then m.menu.heading = "Away from home"
        m.menu.options = m.options
        h = m.menu.boundingRect().height
        m.menu.translation = [(1920 - 660) \ 2, 928 - h]
    else
        m.options = [{ key: "off", label: "Off", checked: m.subtitle = "off", disabled: false }]
        m.options.Push({ key: "forced", label: "Only for non-English", detail: "Shows the forced track when another language is spoken", checked: m.subtitle = "forced", disabled: false })
        for each t in m.info.subtitles
            detail = ""
            if Instr(1, formatSubtitle(t), "SDH") > 0 then detail = "Includes sound cues"
            m.options.Push({ key: t.id.ToStr(), label: formatSubtitle(t), detail: detail, checked: m.subtitle = t.id.ToStr(), disabled: false })
        end for
        m.menu.menuWidth = 640
        m.menu.options = m.options
        h = m.menu.boundingRect().height
        m.menu.translation = [1824 - 640, 928 - h]
    end if
    m.menu.observeFieldScoped("chosen", "onChosen")
    m.menu.observeFieldScoped("cancelled", "closeMenu")
    m.menu.setFocus(true)
    m.hide.control = "stop"
end sub

sub closeMenu()
    if m.menu = invalid then return
    m.overlay.removeChild(m.menu)
    m.menu = invalid
    show()
end sub

sub onChosen(event as object)
    o = m.options[event.getData()]
    kind = m.menuKind
    closeMenu()
    if kind = "quality"
        m.quality = o.network
        update([{ op: "updatePlaybackNetwork", body: capabilityNetwork(deviceAtHome(), m.quality) }])
        return
    end if
    m.subtitle = o.key
    update([{ op: "selectPlaybackTracks", body: apiTrackBody(m.top.params.audioTrackId, o.key) }])
end sub

' The buffering a seek causes is not a stall.
sub seekTo(seconds as dynamic)
    m.played = false
    m.video.seek = seconds
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or key = "options" then return false
    if key = "back"
        if m.scrub <> invalid
            endScrub(false)
        else
            leave("back")
        end if
        return true
    end if
    ' Nothing to control or draw until the stream starts.
    if m.stream = invalid then return true
    if m.upNext <> invalid
        if key = "OK" and m.current = "upPlay" then leave("next")
        if key = "OK" and m.current = "upCancel" then leave("back")
        if key = "OK" and m.current = "upAuto" then flipAutoplay()
        if key = "left" or key = "right" then uiArrow(key)
        return true
    end if
    if m.station <> invalid and stationIgnores(key) then return true
    if m.station <> invalid and not m.overlay.visible
        show()
        return true
    end if
    if key = "play" and m.scrub <> invalid
        endScrub(true, true)
    else if key = "play"
        toggle(playerPaused(m.video.state, m.hold))
    else if key = "replay"
        at = m.video.position - 10
        if at < 0 then at = 0
        seekTo(at)
        syncLocal(not playerPaused(m.video.state, m.hold), Int(at * 1000))
    else if key = "rewind" or key = "fastforward"
        if key = "rewind" then scrubBy(-30) else scrubBy(30)
        m.current = "seek"
    else if not m.overlay.visible
        if key = "left" or key = "right"
            if key = "left" then scrubBy(-10) else scrubBy(10)
            m.current = "seek"
        else if key = "OK"
            toggle(false)
        end if
    else if m.current = "seek" and (key = "left" or key = "right")
        if key = "left" then scrubBy(-10) else scrubBy(10)
    else if key = "OK"
        if m.current = "seek" and m.scrub <> invalid
            endScrub(true)
        else if m.current = "seek"
            toggle(playerPaused(m.video.state, m.hold))
        else if m.current = "pill"
            openMenu("quality")
            return true
        else if m.current = "subtitles"
            openMenu("subtitles")
            return true
        else if m.current = "next"
            leave("next")
            return true
        end if
    else
        if m.scrub <> invalid then endScrub(false)
        uiArrow(key)
    end if
    show()
    return true
end function

' Play or pause from the remote; in a Watch together it applies to both.
sub toggle(play as boolean)
    ' In sync, a play waits for the instant both start at.
    if play and m.tg <> invalid and m.tg.status = "joined"
        syncLocal(true, nowMs())
        return
    end if
    if m.hold
        ' Nothing plays yet: Play only lets the held stream run.
        m.hold = not play
    else if play
        m.video.control = "resume"
    else
        m.video.control = "pause"
    end if
    syncLocal(play, nowMs())
end sub

' Once a second: a poll that answered with no change, or failed, goes
' again, and a playing player that drifted seeks back, left 3 seconds to
' buffer after each seek.
sub onSyncTick()
    if m.tg = invalid then return
    if m.syncWait and not m.syncBusy then syncPoll()
    if m.video.state = "playing" and m.tgSettle.TotalMilliseconds() > 3000 then syncFollow()
end sub

' A few quick polls sample the round trip; then each poll is held by the
' server until the next change.
sub syncPoll()
    m.syncWait = false
    if m.tgSamples < 3
        m.tgSamples = m.tgSamples + 1
        syncAsk("getWatchTogether", invalid, {})
    else
        syncAsk("getWatchTogether", invalid, { "after": m.tg.version })
    end if
end sub

' One request at a time: sending replaces a poll in flight, whose answer
' is then never read.
sub syncAsk(op as string, body as dynamic, query = {} as object)
    m.syncBusy = true
    m.syncQuick = not query.DoesExist("after")
    report = togetherReport(m.tgTrip)
    for each key in report
        query.AddReplace(key, report[key])
    end for
    m.tgSent.Mark()
    netCall(op, { watchTogetherId: m.tg.id }, query, body, "onSync")
end sub

' The viewer played, paused or seeked; following the shared state sends
' nothing.
sub syncLocal(playing as boolean, atMs as integer)
    if m.tg = invalid then return
    if not togetherLocal(m.tg, m.tgSince.TotalMilliseconds(), m.tgOneWay, not playing, atMs) then return
    syncAsk("setWatchTogetherState", { "playing": playing, "positionMs": atMs })
end sub

sub onSync(event as object)
    m.syncBusy = false
    r = event.getData()
    ' An answer that arrives after the viewer left moves nothing.
    if m.tg = invalid or m.gone then return
    trip = m.tgSent.TotalMilliseconds()
    if r.ok and m.syncQuick
        m.tgTrip = trip
        if m.tgBest < 0 or trip < m.tgBest
            m.tgBest = trip
            m.tgOneWay = trip \ 2
        end if
    end if
    version = m.tg.version
    if r.ok
        syncTake(r.data)
    else if r.status = 404
        syncEnd()
    end if
    if m.tg = invalid or m.syncBusy then return
    ' A change, or a hold that ran out, asks again at once; anything else waits for the next tick.
    if togetherAsksAgain(r.ok, m.tg.version <> version, m.syncQuick, trip) then syncPoll() else m.syncWait = true
end sub

' The shared state's change reaches its instant.
sub onSyncDue()
    if m.tg <> invalid then syncFollow()
end sub

' Brings the player to the shared state: a change still ahead waits for
' its instant; a held stream runs on Play.
sub syncFollow()
    state = m.video.state
    if m.scrub <> invalid then return
    f = togetherFollow(m.tg, m.tgSince.TotalMilliseconds(), m.tgOneWay, playerPaused(state, m.hold), nowMs())
    if f.waitMs > 0
        m.tgDue.control = "stop"
        m.tgDue.duration = f.waitMs / 1000
        m.tgDue.control = "start"
        return
    end if
    if f.play
        ' A held stream yet to play starts by itself; a paused one resumes.
        if not m.hold or state = "paused" then m.video.control = "resume"
        m.hold = false
    end if
    if f.pause then m.video.control = "pause"
    if f.hold then m.hold = true
    if f.seekMs >= 0 and (state = "playing" or state = "paused")
        seekTo(f.seekMs / 1000)
        m.tgSettle.Mark()
    end if
end sub

sub syncTake(w as object)
    if togetherStale(m.tg, w) then return
    if w.status = "ended"
        syncEnd()
        return
    end if
    was = m.tg
    m.tg = w
    m.tgSince.Mark()
    state = m.video.state
    arrival = invalid
    if state = "playing" or state = "paused" then arrival = togetherArrival(was, w, state = "paused", nowMs())
    if arrival <> invalid
        syncAsk("setWatchTogetherState", arrival)
    else if m.stream <> invalid
        syncFollow()
    end if
    paused = togetherPausedBy(w, m.global.profileId)
    key = w.status + uiPick(w.playing, " playing ", " paused ") + paused
    if key = m.syncKey then return
    m.syncKey = key
    if m.stream <> invalid and m.menu = invalid then drawOverlay()
    if paused <> "" and m.stream <> invalid then show()
end sub

' The other member left, or nobody joined in time: play on alone, saying
' so if they had joined.
sub syncEnd()
    other = invalid
    if m.tg.status = "joined" then other = togetherOther(m.tg, m.global.profileId)
    m.tg = invalid
    m.sync.control = "stop"
    if other = invalid or m.stream = invalid then return
    m.notice = togetherName(other, m.global.profileId) + " left"
    m.noticeTimer.control = "start"
    if m.menu = invalid then drawOverlay()
    show()
end sub

sub onNoticeGone()
    m.notice = ""
    if m.stream <> invalid and m.menu = invalid then drawOverlay()
end sub

' In sync with Helga at the top right, who paused in the middle, and while
' paused what Play and Back do.
sub togetherOverlay()
    if m.notice <> "" then notice(m.notice, "")
    if m.tg = invalid or m.tg.status <> "joined" then return
    me = m.global.profileId
    other = togetherOther(m.tg, me)
    name = ""
    if other <> invalid then name = togetherName(other, me)
    chip = uiChip(m.overlay, "In sync with " + name, "ok", "users", 64, 28)
    chip.translation = [1824 - Int(chip.boundingRect().width), 72]
    if m.tg.playing then return
    uiLabel(m.overlay, "Play resumes for both. Back leaves Watch together.", 26, false, "sub", 96, 968)
    paused = togetherPausedBy(m.tg, me)
    if paused <> "" then notice(paused, "pause")
end sub

sub notice(text as string, icon as string)
    g = m.overlay.CreateChild("Group")
    shape = uiShape(g, 16, 0, 0, 0, 88, uiColor("ground"))
    x = 40
    if icon <> ""
        uiImage(g, icon + ".png", x, 31, 26, 26, uiColor("text"))
        x = x + 46
    end if
    l = uiLabel(g, text, 36, true, "text", x, 0)
    l.height = 88
    l.vertAlign = "center"
    w = x + Int(l.boundingRect().width) + 40
    shape.width = w
    g.translation = [(1920 - w) \ 2, 486]
end sub
