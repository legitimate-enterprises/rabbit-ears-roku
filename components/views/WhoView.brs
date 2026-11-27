sub init()
    m.top.observeField("focusedChild", "uiRestore")
    m.global.observeFieldScoped("serverName", "brandUpdate")
    m.pin = ""
    m.pinFor = invalid
    draw()
    ' Until a profile is picked the server answers this device nothing
    ' but the picker's own calls.
    netCall("lockDevice", {}, {}, invalid, "onLock")
end sub

sub onLock()
end sub

' A launch that remembers a profile with a PIN opens straight at its pad.
sub onParams()
    if m.top.params.pinFor <> invalid then ask(m.top.params.pinFor)
end sub

sub ask(p as object)
    m.pinFor = p
    m.pin = ""
    m.pinError = invalid
    m.current = "5"
    draw()
end sub

function ready() as object
    out = []
    for each p in m.global.me.profiles
        if not p.pending and p.revokedAt = invalid then out.Push(p)
    end for
    return out
end function

function avatar(parent as object, p as object, x as integer, y as integer, size as integer) as object
    g = parent.CreateChild("Group")
    g.translation = [x, y]
    uiImage(g, "disc.png", 0, 0, size, size, formatProfileColor(p.color))
    letter = uiLabel(g, UCase(Left(p.name, 1)), Int(size * 0.42), true, "text", 0, 0)
    letter.width = size
    letter.height = size
    letter.horizAlign = "center"
    letter.vertAlign = "center"
    return g
end function

' The WhoRoku board; with a profile in pinFor, the PinRoku pad over it.
sub draw()
    uiClear(m.top)
    m.controls = {}
    m.rings = {}
    uiImage(m.top, "brand.png", 96, 72, 40, 40)
    brandLabel(m.top, m.global.server, 150, 74, 1674)
    title = uiLabel(m.top, "Who's watching?", 64, true, "text", 0, 300)
    title.width = 1920
    title.horizAlign = "center"
    profiles = ready()
    x = (1920 - (profiles.Count() * 200 + (profiles.Count() - 1) * 80)) \ 2
    row = []
    for each p in profiles
        id = "p" + p.id.ToStr()
        tile = avatar(m.top, p, x, 446, 200)
        tile.focusable = true
        if p.hasPin
            uiImage(tile, "disc.png", 148, 148, 56, 56, uiColor("ground"))
            uiImage(tile, "lock.png", 160, 160, 32, 32, uiColor("accent"))
        end if
        ring = uiImage(tile, "disc-ring.png", -10, -10, 220, 220, uiColor("accent"))
        ring.visible = false
        name = uiLabel(m.top, p.name, 30, true, "text", x - 40, 664)
        name.width = 280
        name.horizAlign = "center"
        m.controls[id] = tile
        m.rings[id] = ring
        row.Push(id)
        x = x + 280
    end for
    owner = m.global.me.account.name
    for each p in m.global.me.profiles
        if m.global.me.household <> invalid and p.id = m.global.me.household.adultId then owner = p.name
    end for
    line = uiLabel(m.top, "This TV is in " + owner + "'s household.", 26, false, "dim", 0, 0)
    m.controls.switch = uiButton(m.top, "switch", "Sign in as someone else", "s", 0, 0, true)
    w = line.boundingRect().width + 28 + m.controls.switch.boundingRect().width
    uiRow([line, m.controls.switch], (1920 - w) \ 2, 790, 28)
    line.translation = [line.translation[0], 806]
    m.layout = [row, ["switch"]]
    if m.pinFor <> invalid then pad()
    if m.current = invalid or m.controls[m.current] = invalid then m.current = row[0]
    uiFocus(m.current)
end sub

sub pad()
    p = m.pinFor
    uiRect(m.top, 0, 0, 1920, 1080, "0x000000B3")
    dialog = m.top.CreateChild("Group")
    dialog.translation = [680, 150]
    uiShape(dialog, 28, 0, 0, 560, 780, uiColor("card"))
    avatar(dialog, p, 220, 48, 120)
    heading = uiLabel(dialog, "Enter " + p.name + "'s PIN", 40, true, "text", 0, 196)
    heading.width = 560
    heading.horizAlign = "center"
    for i = 0 to 3
        color = "0xFFFFFF33"
        if i < Len(m.pin) then color = uiColor("accent")
        uiImage(dialog, "disc.png", 160 + i * 52, 272, 24, 24, color)
    end for
    keys = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["delete", "0", "done"]]
    for r = 0 to 3
        for c = 0 to 2
            k = keys[r][c]
            key = uiPanel(dialog, k, 14, 56 + c * 154, 324 + r * 98, 140, 84, "glass")
            if k = "delete"
                uiImage(key, "backspace.png", 52, 24, 36, 36, uiColor("text"))
            else
                l = uiLabel(key, uiPick(k = "done", "OK", k), 36, true, "text", 0, 0)
                l.width = 140
                l.height = 84
                l.horizAlign = "center"
                l.vertAlign = "center"
            end if
        end for
    end for
    note = "Forgot it? An adult in your household can reset it."
    if m.pinError <> invalid then note = m.pinError
    l = uiLabel(dialog, note, 24, false, "dim", 56, 724, 448)
    l.horizAlign = "center"
    m.layout = keys
    if m.controls[m.current] = invalid then m.current = "5"
end sub

sub unlock(p as object, pin as string)
    body = {}
    if pin <> "" then body = { pin: pin }
    netCall("unlockProfile", { profileId: p.id }, {}, body, "onUnlocked")
end sub

sub onUnlocked(event as object)
    r = event.getData()
    if r.ok
        netCall("getMe", {}, {}, invalid, "onMe")
        return
    end if
    m.pin = ""
    if r.code = "pin_locked"
        m.pinError = "Too many wrong PINs. Try again in 15 minutes."
    else if r.status = 403
        m.pinError = "That PIN is wrong."
    else
        m.pinError = r.message
    end if
    draw()
end sub

sub onMe(event as object)
    r = event.getData()
    if not r.ok then return
    m.global.me = r.data
    m.global.profileId = r.data.activeProfileId
    m.global.locked = false
    m.top.navigate = { to: "TabsView" }
end sub

sub onSignedOut()
    sessionClear()
    m.global.me = {}
    m.global.locked = false
    m.top.navigate = { to: "SignInView" }
end sub

sub onSelect(id as string)
    if id = "switch"
        netCall("signOut", {}, {}, invalid, "onSignedOut")
    else if m.pinFor <> invalid
        if id = "delete"
            if m.pin <> "" then m.pin = Left(m.pin, Len(m.pin) - 1)
        else if id = "done"
            if Len(m.pin) = 4 then unlock(m.pinFor, m.pin)
            return
        else if Len(m.pin) < 4
            m.pin = m.pin + id
        end if
        draw()
    else
        for each p in ready()
            if "p" + p.id.ToStr() = id
                if p.hasPin
                    ask(p)
                else
                    unlock(p, "")
                end if
            end if
        end for
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "OK" and m.current <> invalid
        onSelect(m.current)
        return true
    end if
    if key = "back" and m.pinFor <> invalid
        m.pinFor = invalid
        m.current = invalid
        draw()
        return true
    end if
    return uiArrow(key)
end function
