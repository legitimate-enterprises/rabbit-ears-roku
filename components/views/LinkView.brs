sub init()
    m.top.observeField("focusedChild", "uiRestore")
    m.global.observeFieldScoped("serverName", "brandUpdate")
    m.poll = m.top.CreateChild("Timer")
    m.poll.duration = 5
    m.poll.repeat = true
    m.pollingId = invalid
    m.poll.observeFieldScoped("fire", "onPoll")
    m.tick = m.top.CreateChild("Timer")
    m.tick.duration = 1
    m.tick.repeat = true
    m.tick.observeFieldScoped("fire", "onTick")
    m.top.observeField("visible", "onVisible")
    start()
end sub

sub start()
    m.link = invalid
    draw("Asking the server for a code.")
    netCall("createDeviceLink", {}, {}, { deviceName: deviceName(), platform: "roku" }, "onCreated")
end sub

sub onCreated(event as object)
    r = event.getData()
    if not r.ok
        if r.status = 429
            draw(r.message)
        else
            draw("Couldn't get a code: " + r.message)
        end if
        return
    end if
    m.link = r.data
    m.expires = CreateObject("roDateTime")
    m.expires.FromISO8601String(r.data.expiresAt)
    draw("")
    m.poll.control = "start"
    m.tick.control = "start"
end sub

function secondsLeft() as integer
    now = CreateObject("roDateTime")
    return m.expires.AsSeconds() - now.AsSeconds()
end function

' The SignInRokuCode board. status replaces the footer's waiting line.
sub draw(status as string)
    uiClear(m.top)
    m.controls = {}
    m.rings = {}
    uiImage(m.top, "brand.png", 96, 72, 40, 40)
    brandLabel(m.top, m.global.server, 150, 74, 1674)
    uiLabel(m.top, "Sign in with your phone", 64, true, "text", 192, 210)
    host = m.global.server.Mid(Instr(1, m.global.server, "://") + 2)
    steps = ["Scan the code, or open " + host + "/link", "Sign in as an adult in your household", "Enter this code"]
    for i = 0 to 2
        y = 330 + i * 76
        uiShape(m.top, 28, 192, y, 52, 52, uiColor("raised"))
        n = uiLabel(m.top, (i + 1).ToStr(), 28, true, "text", 192, y)
        n.width = 52
        n.height = 52
        n.horizAlign = "center"
        n.vertAlign = "center"
        uiLabel(m.top, steps[i], 32, false, "sub", 268, y + 6)
    end for
    if m.link <> invalid
        parts = m.link.code.Split("-")
        code = uiLabel(m.top, parts[0], 128, true, "text", 268, 570)
        dash = uiLabel(m.top, "-", 128, true, "accent", 268 + code.boundingRect().width + 6, 570)
        uiLabel(m.top, parts[1], 128, true, "text", 268 + code.boundingRect().width + dash.boundingRect().width + 12, 570)
        qr = m.top.CreateChild("Poster")
        qr.translation = [1268, 250]
        qr.width = 460
        qr.height = 460
        ' The poll token rides in the query: a Poster cannot set headers.
        qr.uri = m.global.server + apiRequest("getDeviceLinkQr", { linkId: m.link.id }, { token: m.link.pollToken }).path
        if status = "" then status = "Waiting for approval. This code expires in " + formatClock(secondsLeft()) + "."
    end if
    m.status = uiLabel(m.top, status, 26, false, "dim", 96, 962)
    m.controls.again = uiButton(m.top, "again", "Get a new code", "s", 0, 0, true)
    m.controls.password = uiButton(m.top, "password", "Use a password instead", "s", 0, 0, true)
    w = m.controls.again.boundingRect().width + 24 + m.controls.password.boundingRect().width
    uiRow([m.controls.again, m.controls.password], 1920 - 96 - w, 952, 24)
    m.layout = [["again", "password"]]
    m.current = invalid
    uiFocus("again")
end sub

sub onTick()
    left = secondsLeft()
    if left > 0
        m.status.text = "Waiting for approval. This code expires in " + formatClock(left) + "."
    else
        stopTimers()
        draw("This code expired.")
    end if
end sub

' One poll at a time, even across a new code: a newer one would drop the
' answer that carries the token.
sub onPoll()
    if m.link = invalid or m.pollingId <> invalid then return
    m.pollingId = m.link.id
    netCall("pollDeviceLink", { linkId: m.link.id }, { token: m.link.pollToken }, invalid, "onPolled")
end sub

sub onPolled(event as object)
    r = event.getData()
    shown = invalid
    if m.link <> invalid then shown = m.link.id
    outcome = linkOutcome(shown, m.pollingId, r)
    m.pollingId = invalid
    if outcome = "wait" or outcome = "stale" then return
    stopTimers()
    if outcome = "signIn"
        sessionSave(m.global.server, r.data.signIn.token)
        m.global.me = r.data.signIn.me
        m.global.profileId = r.data.signIn.me.activeProfileId
        m.top.navigate = { to: "WhoView" }
    else if outcome = "denied"
        draw("This code was turned down.")
    else
        draw("This code expired.")
    end if
end sub

sub stopTimers()
    m.poll.control = "stop"
    m.tick.control = "stop"
end sub

sub onVisible()
    if not m.top.visible then stopTimers()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "OK" and m.current = "again"
        stopTimers()
        start()
        return true
    end if
    if key = "OK" or key = "back"
        stopTimers()
        m.top.navigate = { to: "SignInView" }
        return true
    end if
    return uiArrow(key)
end function
