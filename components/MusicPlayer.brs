' One audio-only session per song: started when the song starts, its
' position reported every 10 seconds, ended when it stops. The queue lives
' here, not on the server. A station sets the queue aside as it was and
' plays what the server has on, one session per song, ignoring every
' command but Stop; Stop brings the queue back held at its song, which
' play resumes where it was. A queue that starts from part of a list grows
' as it plays: the next batch loads when playback nears the end of what is
' queued, one at a time, and the queue lives on when the view that started
' it closes.
sub init()
    m.queue = []
    m.ordered = []
    m.index = -1
    m.from = ""
    m.playlistId = invalid
    m.shuffle = false
    m.repeat = false
    m.stream = invalid
    m.failures = 0
    m.station = invalid
    m.saved = invalid
    m.heldMs = invalid
    m.startMs = 0
    m.more = invalid
    m.loadingMore = false
    m.tuning = false
    m.onAir = invalid
    m.audio = m.top.CreateChild("Audio")
    m.audio.observeFieldScoped("state", "onState")
    m.audio.observeFieldScoped("position", "onPosition")
    m.audio.observeFieldScoped("duration", "onPosition")
    m.report = m.top.CreateChild("Timer")
    m.report.duration = 10
    m.report.repeat = true
    m.report.observeFieldScoped("fire", "onReport")
    m.ends = m.top.CreateChild("Timer")
    m.ends.observeFieldScoped("fire", "onStationEnd")
    m.top.now = {}
end sub

sub onCommand(event as object)
    c = event.getData()
    if c.op = "station"
        tuneIn(c.station)
        return
    end if
    if c.op = "stopStation"
        stopStation()
        return
    end if
    if c.op = "stop"
        stopAll()
        return
    end if
    if m.station <> invalid and c.op <> "play" then return
    if c.op = "play"
        dropStation()
        m.heldMs = invalid
        m.ordered = c.songs
        m.queue = c.songs
        m.index = c.index
        m.from = c.from
        m.playlistId = c.playlistId
        netDrop("onMore")
        m.more = c.more
        m.loadingMore = false
        m.shuffle = c.shuffle = true
        if m.shuffle
            m.queue = musicShuffle(m.ordered, m.index)
            m.index = 0
        end if
        m.failures = 0
        startSong()
    else if m.index < 0
        return
    else if c.op = "toggle" and m.heldMs <> invalid
        startSong()
    else if c.op = "toggle"
        if m.audio.state = "paused" then m.audio.control = "resume" else m.audio.control = "pause"
    else if c.op = "next" or c.op = "previous"
        m.heldMs = invalid
        stepBy = 1
        if c.op = "previous" then stepBy = -1
        ' Previous a few seconds in restarts the song, as players do; a held
        ' song has no stream to seek.
        if stepBy = -1 and m.audio.position > 3 and m.stream <> invalid
            m.audio.seek = 0
            return
        end if
        jump(musicAdvance(m.index, m.queue.Count(), m.repeat, stepBy))
    else if c.op = "seek"
        at = m.audio.position + c.by
        if at < 0 then at = 0
        if m.audio.duration > 0 and at > m.audio.duration then at = m.audio.duration - 1
        m.audio.seek = at
    else if c.op = "shuffle"
        reorder(not m.shuffle)
    else if c.op = "repeat"
        m.repeat = not m.repeat
        publish()
    end if
end sub

' Shuffle on deals the rest of the queue at random after the playing
' song; off goes back to the original order from the playing song.
sub reorder(shuffle as boolean)
    song = m.queue[m.index]
    m.shuffle = shuffle
    if shuffle
        m.queue = musicShuffle(m.queue, m.index)
        m.index = 0
    else
        m.queue = m.ordered
        for i = 0 to m.ordered.Count() - 1
            if m.ordered[i].id = song.id then m.index = i
        end for
    end if
    publish()
end sub

sub jump(index as integer)
    if index < 0
        stopAll()
        return
    end if
    m.index = index
    startSong()
end sub

sub startSong()
    growQueue()
    endSession()
    m.audio.control = "stop"
    publish()
    args = { songId: m.queue[m.index].id, profileId: m.global.profileId }
    if m.playlistId <> invalid then args.playlistId = m.playlistId
    if m.heldMs <> invalid then args.positionMs = m.heldMs
    m.startMs = 0
    if m.heldMs <> invalid then m.startMs = m.heldMs
    m.heldMs = invalid
    netLoad("song", args, "onSong")
end sub

' A failed batch leaves the queue as it is; the next song started near the
' end asks again.
sub growQueue()
    if not musicMoreDue(m.index, m.queue.Count(), m.more, m.loadingMore) then return
    m.loadingMore = true
    netLoad("list", m.more, "onMore")
end sub

sub onMore(event as object)
    m.loadingMore = false
    r = event.getData()
    if not r.ok then return
    m.more = r.rest
    musicGrow(m.queue, m.ordered, m.shuffle, r.data)
    publish()
end sub

sub onSong(event as object)
    r = event.getData()
    if m.index < 0 or m.station <> invalid
        ' Stopped or tuned away while it started: the session the server opened is closed.
        if r.ok then netCall("endPlayback", { sessionId: r.data.sessionId }, {}, invalid, "onReported")
        return
    end if
    if r.ok
        play(r.data, m.queue[m.index].title)
    else
        failed(r, r.message)
    end if
end sub

' From the stream's positionMs: a held song's, or a station's live one.
sub play(stream as object, title as string)
    m.stream = stream
    m.failures = 0
    c = CreateObject("roSGNode", "ContentNode")
    c.url = homeStreamBase(m.global.server, m.global.home) + stream.streamUrl
    c.streamFormat = musicStreamFormat(stream)
    c.title = title
    c.playStart = stream.positionMs / 1000
    m.audio.content = c
    m.audio.control = "play"
    m.report.control = "start"
    publish()
end sub

' A song that will not play is skipped; three in a row stop the queue
' with one dialog. A server out of reach holds the queue on the song.
sub failed(r as object, message as string)
    nextIndex = musicAdvance(m.index, m.queue.Count(), m.repeat, 1)
    after = musicAfterFailure(r, m.failures + 1, nextIndex)
    if after = "hold"
        ' Where the song was, or where it was to start when no stream played.
        heldMs = m.startMs
        if m.stream <> invalid then heldMs = nowMs()
        endSession()
        m.audio.control = "stop"
        m.heldMs = heldMs
        publish()
        return
    end if
    m.stream = invalid
    m.failures = m.failures + 1
    if after = "skip"
        jump(nextIndex)
        return
    end if
    stopAll()
    alert(message)
end sub

sub alert(message as string)
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = "Can't play this"
    d.message = [message]
    d.buttons = ["OK"]
    d.observeFieldScoped("buttonSelected", "onDialogClosed")
    m.top.getScene().dialog = d
end sub

sub onDialogClosed()
    m.top.getScene().dialog.close = true
end sub

sub onState()
    state = m.audio.state
    if state = "finished" and m.station <> invalid
        onStationEnd()
    else if state = "finished"
        jump(musicAdvance(m.index, m.queue.Count(), m.repeat, 1))
    else if state = "error" and m.stream <> invalid
        ' The server moves down the plan, or answers 409 when none is left.
        netCall("reportPlaybackEvent", { sessionId: m.stream.sessionId }, {}, { kind: "client_failure", positionMs: nowMs(), reason: Left(m.audio.errorMsg + " (" + m.audio.errorCode.ToStr() + ")", 500) }, "onFailover")
    else if state = "playing" or state = "paused"
        publish()
    end if
end sub

sub onFailover(event as object)
    r = event.getData()
    message = "This song won't play on this TV. " + r.message
    if r.ok and m.station <> invalid
        play(r.data.stream, m.onAir.song.title)
    else if r.ok
        play(r.data.stream, m.queue[m.index].title)
    else if m.station <> invalid
        stopStation()
        alert(message)
    else
        failed(r, message)
    end if
end sub

sub onPosition()
    m.top.position = m.audio.position
    m.top.duration = m.audio.duration
end sub

function nowMs() as integer
    return Int(m.audio.position * 1000)
end function

sub onReport()
    if m.stream = invalid then return
    netCall("reportPlaybackPosition", { sessionId: m.stream.sessionId }, {}, { positionMs: nowMs(), paused: m.audio.state = "paused" }, "onReported")
end sub

sub onReported()
end sub

sub endSession()
    m.report.control = "stop"
    ' A failure answer for the session that ends here is moot, and would play into the next state.
    netDrop("onFailover")
    if m.stream = invalid then return
    netCall("endPlayback", { sessionId: m.stream.sessionId }, { positionMs: nowMs() }, invalid, "onReported")
    m.stream = invalid
end sub

sub stopAll()
    netDrop("onMore")
    m.more = invalid
    m.loadingMore = false
    dropStation()
    m.heldMs = invalid
    endSession()
    m.audio.control = "stop"
    m.index = -1
    m.queue = []
    m.ordered = []
    publish()
end sub

' Sets the queue aside as it was and asks the station what is on; Now
' playing shows the station while it answers.
sub tuneIn(station as object)
    if m.station = invalid
        m.saved = { queue: m.queue, ordered: m.ordered, index: m.index, from: m.from, playlistId: m.playlistId, shuffle: m.shuffle, heldMs: m.heldMs }
        if m.heldMs = invalid and m.index >= 0 then m.saved.heldMs = nowMs()
    end if
    endSession()
    m.ends.control = "stop"
    m.audio.control = "stop"
    m.station = station
    m.onAir = { song: invalid, lines: [], upNext: [] }
    publish()
    askStation()
end sub

sub askStation()
    m.tuning = true
    netLoad("station", { stationId: m.station.id, quality: {} }, "onStation")
end sub

' Plays the song on until it ends, or shows when the station is back;
' m.ends asks again when the server said.
sub onStation(event as object)
    m.tuning = false
    r = event.getData()
    if m.station = invalid
        ' Stopped while it tuned in: the session the server opened is closed.
        if r.ok and r.data.stream <> invalid then netCall("endPlayback", { sessionId: r.data.stream.sessionId }, {}, invalid, "onReported")
        return
    end if
    if not r.ok and stationRetryIn(r) > 0
        ' Now playing shows the failure while m.ends asks again.
        m.onAir = { song: invalid, lines: [r.message], upNext: [] }
        publish()
        m.ends.duration = stationRetryIn(r)
        m.ends.control = "start"
        return
    end if
    if not r.ok
        stopStation()
        alert(r.message)
        return
    end if
    plan = stationNext("music", r.data, CreateObject("roDateTime").AsSeconds())
    if plan.askIn > 0
        m.ends.duration = plan.askIn
        m.ends.control = "start"
    end if
    m.onAir = { song: invalid, lines: plan.lines, upNext: stationUpNext(r.data.onAir) }
    if plan.mode = "on_air"
        m.onAir.song = r.data.onAir.now.song
        play(r.data.stream, m.onAir.song.title)
    else
        publish()
    end if
end sub

' The song ended, by its stream or its endsAt: its session ends and the
' station is asked again.
sub onStationEnd()
    if m.station = invalid or m.tuning then return
    m.ends.control = "stop"
    endSession()
    m.audio.control = "stop"
    askStation()
end sub

sub dropStation()
    if m.station = invalid then return
    m.ends.control = "stop"
    m.station = invalid
    m.saved = invalid
end sub

' Ends the station and brings back the queue it set aside, held.
sub stopStation()
    if m.station = invalid then return
    s = m.saved
    dropStation()
    endSession()
    m.audio.control = "stop"
    if s <> invalid and s.index >= 0
        m.queue = s.queue
        m.ordered = s.ordered
        m.index = s.index
        m.from = s.from
        m.playlistId = s.playlistId
        m.shuffle = s.shuffle
        m.heldMs = s.heldMs
    end if
    publish()
end sub

' What the chip, the track lists and Now playing draw; station is the
' station's name while one is tuned in, and song is absent while it is off
' air.
sub publish()
    audio = invalid
    if m.stream <> invalid then audio = m.stream.audio
    if m.station <> invalid
        m.top.now = { song: m.onAir.song, station: m.station.name, imageUrl: m.station.imageUrl, lines: m.onAir.lines, from: "", upNext: m.onAir.upNext, playing: true, shuffle: false, repeat: false, audio: audio }
        return
    end if
    if m.index < 0
        m.top.now = {}
        return
    end if
    upNext = []
    for i = m.index + 1 to m.queue.Count() - 1
        if upNext.Count() < 6 then upNext.Push(m.queue[i])
    end for
    m.top.now = { song: m.queue[m.index], from: m.from, upNext: upNext, playing: m.heldMs = invalid and m.audio.state <> "paused", shuffle: m.shuffle, repeat: m.repeat, audio: audio }
end sub
