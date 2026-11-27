sub init()
    m.top.backgroundURI = ""
    m.top.backgroundColor = uiColor("ground")
    ' stateVersion rises whenever the profile's watch state may have moved;
    ' views that show it reload. locked holds while Who's watching shows.
    m.global.addFields({ server: "", serverName: "", token: "", discovered: false, me: {}, profileId: "", servers: [], decoder: {}, stateVersion: 0, locked: false })
    m.global.observeFieldScoped("locked", "onLocked")
    ' The server's live events: stationVersion and playlistVersion rise as
    ' stateVersion does, and live holds each batch as { events }, for the
    ' player and details to read their own from.
    m.global.addFields({ stationVersion: 0, playlistVersion: 0, libraryVersion: 0, hideVersion: 0 })
    m.global.addField("live", "assocarray", true)
    ' What ApiTask keeps: cacheExpired is the second of the last write the
    ' server answered, and cacheVersion rises when a refresh changed a kept answer.
    m.global.addFields({ cacheExpired: 0, cacheVersion: 0 })
    ' The last local check, as lib/home.brs reads it.
    m.global.addFields({ home: { url: "", at: 0 } })
    m.global.observeFieldScoped("cacheVersion", "onCached")
    m.live = { cursor: "", waitMs: 1000 }
    m.stale = false
    m.liveTimer = m.top.CreateChild("Timer")
    m.liveTimer.observeFieldScoped("fire", "follow")
    m.sayTimer = m.top.CreateChild("Timer")
    m.sayTimer.duration = 4
    m.sayTimer.observeFieldScoped("fire", "onSaid")
    ' Music plays on under every view until a video plays or Who's watching shows.
    m.global.addFields({ music: m.top.CreateChild("MusicPlayer") })
    m.stack = []
    m.pending = invalid
    m.launch = { launched: false, inDialog: false }
    rememberDropStale()
    s = sessionRead()
    ' SignInView says why a stored server that is not secure goes unused.
    if not apiSecure(s.server) then s.token = ""
    sessionUse(s.server, s.token)
    m.global.discovered = s.discovered
    m.global.serverName = s.serverName
    if s.server <> "" then brandRefresh()
    m.discovery = CreateObject("roSGNode", "DiscoveryTask")
    m.discovery.observeFieldScoped("servers", "onServers")
    m.discovery.control = "run"
    if s.token = ""
        root("SignInView", {})
    else
        netCall("getMe", {}, {}, invalid, "onMe")
    end if
end sub

' A server counts as on this network once it answered discovery here, and
' is saved as such for later launches.
sub onServers(event as object)
    m.global.servers = event.getData()
    if m.global.discovered or not discoveryFound(m.global.server, m.global.servers) then return
    m.global.discovered = true
    sessionSave(m.global.server, m.global.token)
end sub

sub onMe(event as object)
    r = event.getData()
    if r.ok
        m.global.me = r.data
        m.global.profileId = r.data.activeProfileId
        start = rememberLaunch(rememberRead(r.data), r.data)
        if start.go = "who"
            pick({})
        else if start.go = "pin"
            pick({ pinFor: start.profile })
        else if start.go = "unlock"
            netCall("unlockProfile", { profileId: start.profile.id }, {}, {}, "onRemembered")
        else
            home()
        end if
    else if apiSignedOut(r)
        sessionClear()
        root("SignInView", {})
    else
        d = CreateObject("roSGNode", "StandardMessageDialog")
        d.title = "Can't reach the server"
        d.message = [m.global.server]
        d.buttons = ["Try again", "Sign in again"]
        d.observeFieldScoped("buttonSelected", "onRetry")
        m.top.dialog = d
        beacons("StandardMessageDialog")
    end if
end sub

sub onRemembered(event as object)
    if event.getData().ok then home() else pick({})
end sub

sub home()
    root("TabsView", {})
    route()
end sub

sub onRetry(event as object)
    m.top.dialog.close = true
    if event.getData() = 0
        netCall("getMe", {}, {}, invalid, "onMe")
    else
        root("SignInView", {})
    end if
end sub

sub onDeepLink(event as object)
    m.pending = deepLinkRoute(event.getData())
    if m.global.me.Count() > 0 and not m.global.locked then route()
end sub

' Who's watching is the only view while the device is locked, so Back
' leaves the app rather than return to browsing.
sub pick(params as object)
    root("WhoView", params)
    m.global.locked = true
end sub

sub onLocked()
    if m.global.locked and m.stack.Peek().subtype() <> "WhoView" then pick({})
end sub

' Follows the server's live events while a profile is active, one held
' poll after another, from when the tabs open; a call drops the poll in
' flight.
sub follow()
    m.liveTimer.control = "stop"
    if m.global.locked or m.global.token = "" then return
    netCall("listEvents", {}, liveQuery(m.live.cursor), invalid, "onEvents")
end sub

sub onEvents(event as object)
    took = liveStep(m.live, event.getData())
    m.live = took.state
    if took.events <> invalid then tell(took.events)
    if took.done then return
    if took.waitMs > 0
        m.liveTimer.duration = took.waitMs / 1000
        m.liveTimer.control = "start"
    else
        follow()
    end if
end sub

' Views reload as their counter rises. Under the player they wait for it
' to close, so that a library is not read again while a title plays.
sub tell(events as object)
    if m.global.locked or m.global.me.device = invalid then return
    m.global.live = { events: events }
    if m.stack.Peek().subtype() = "PlayerView"
        m.stale = true
        return
    end if
    if liveMoves(events, m.global.me.device.id) then m.global.stateVersion = m.global.stateVersion + 1
    if liveNames(events, "station") then m.global.stationVersion = m.global.stationVersion + 1
    if liveNames(events, "playlist") then m.global.playlistVersion = m.global.playlistVersion + 1
    if liveNames(events, "library") then m.global.libraryVersion = m.global.libraryVersion + 1
    if liveNames(events, "household") then netCall("getMe", {}, {}, invalid, "onPreferences")
end sub

' A profile's Hide kids' content saved on another device applies here as
' the profile menu's own toggle does: the tabs rebuild as the server now answers.
sub onPreferences(event as object)
    r = event.getData()
    if not r.ok or m.global.locked or m.global.me.activeProfileId = invalid then return
    if not liveHideMoved(m.global.me, r.data) then return
    m.global.me = r.data
    m.global.hideVersion = m.global.hideVersion + 1
end sub

' Views read again what a refresh changed, as on a resync.
sub onCached()
    tell([])
end sub

' A line over whatever is up for a few seconds, as Moved to Living Room.
sub say(text as string)
    onSaid()
    m.said = m.top.CreateChild("Group")
    shape = uiShape(m.said, 16, 0, 0, 0, 88, uiColor("raised"))
    l = uiLabel(m.said, text, 36, true, "text", 40, 0)
    l.height = 88
    l.vertAlign = "center"
    w = Int(l.boundingRect().width) + 80
    shape.width = w
    m.said.translation = [(1920 - w) \ 2, 900]
    m.sayTimer.control = "start"
end sub

sub onSaid()
    if m.said <> invalid then m.top.removeChild(m.said)
    m.said = invalid
end sub

' Opens a waiting deep link once a profile is active.
sub route()
    if m.pending = invalid then return
    netCall("getItem", { itemId: m.pending.itemId }, {}, invalid, "onDeepItem")
end sub

sub onDeepItem(event as object)
    r = event.getData()
    link = m.pending
    m.pending = invalid
    if not r.ok or link = invalid then return
    while m.stack.Count() > 1
        pop()
    end while
    push(deepLinkView(link, r.data), { item: r.data, itemId: r.data.id })
end sub

sub onEnded()
    m.global.stateVersion = m.global.stateVersion + 1
end sub

sub onLeft()
end sub

sub onNavigate(event as object)
    n = event.getData()
    release(n)
    if n.to = "back"
        pop()
        if n.notice <> invalid then say(n.notice)
    else if n.to = "details" or n.to = "player"
        ' A replacing view takes the asking one's place, so Back skips it.
        if n.replace <> invalid and n.replace then pop()
        push(n.to, n)
    else if n.to = "WhoView"
        pick({})
    else if n.to = "next"
        pop()
        push("player", n)
    else
        root(n.to, n)
        if n.to = "TabsView" then route()
    end if
end sub

' Ends what a leaving view held open, { endSession, endPositionMs,
' leaveTogether }. The player may be gone before its session's end is sent.
sub release(n as object)
    if n.endSession <> invalid then netCall("endPlayback", { sessionId: n.endSession }, { positionMs: n.endPositionMs }, invalid, "onEnded")
    if n.leaveTogether <> invalid then netCall("leaveWatchTogether", { watchTogetherId: n.leaveTogether }, {}, invalid, "onLeft")
end sub

function make(name as string, params as object) as object
    if name = "details"
        name = "DetailsView"
        if params.item <> invalid and params.item.kind = "season" then name = "SeasonView"
        if params.view <> invalid then name = params.view
    else if name = "player"
        name = "PlayerView"
    end if
    v = CreateObject("roSGNode", name)
    v.observeFieldScoped("navigate", "onNavigate")
    v.params = params
    return v
end function

sub push(name as string, params as object)
    if name = "player" then m.global.music.command = { op: "stop" }
    v = make(name, params)
    if m.stack.Count() > 0 then m.stack.Peek().visible = false
    m.top.appendChild(v)
    m.stack.Push(v)
    v.setFocus(true)
    beacons(name)
end sub

sub beacons(view as string)
    for each b in launchBeacons(m.launch, view)
        m.top.signalBeacon(b)
    end for
end sub

sub pop()
    if m.stack.Count() < 2 then return
    drop(m.stack.Pop())
    top = m.stack.Peek()
    top.visible = true
    top.setFocus(true)
    if m.stale
        m.stale = false
        tell([])
    end if
end sub

' A view taken off the screen may still hear an answer or an observer;
' whatever it asks for then is not followed. One with a close function
' stops there and names what it held open.
sub drop(v as object)
    v.unobserveFieldScoped("navigate")
    held = v.callFunc("close")
    if held <> invalid then release(held)
    m.top.removeChild(v)
end sub

sub root(name as string, params as object)
    m.global.music.command = { op: "stop" }
    for each v in m.stack
        drop(v)
    end for
    m.stack = []
    push(name, params)
    if name = "TabsView" then follow()
end sub

' Back climbs one level; at the bottom of the stack it leaves the app.
' Transport keys no view used go to the music.
function onKeyEvent(key as string, press as boolean) as boolean
    op = { play: "toggle", rewind: "previous", fastforward: "next" }[key]
    if press and op <> invalid and m.global.music.now.song <> invalid
        m.global.music.command = { op: op }
        return true
    end if
    if not press or key <> "back" then return false
    if m.stack.Count() > 1
        pop()
    else
        m.top.exit = true
    end if
    return true
end function

' Deletes what rememberStale names from the registry.
sub rememberDropStale()
    r = CreateObject("roRegistrySection", "RabbitEars")
    stale = rememberStale(r.GetKeyList())
    for each key in stale
        r.Delete(key)
    end for
    if stale.Count() > 0 then r.Flush()
end sub
