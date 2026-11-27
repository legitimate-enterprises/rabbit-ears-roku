sub init()
    m.top.observeField("focusedChild", "uiRestore")
    m.values = { server: m.global.server, email: "", password: "" }
    m.found = false
    m.askedEmail = false
    m.message = ""
    m.homes = []
    if m.values.server <> "" and not apiSecure(m.values.server) then m.message = insecure()
    if m.values.server = "" and m.global.servers.Count() > 0
        m.values.server = m.global.servers[0].address
        m.found = true
    end if
    m.global.observeFieldScoped("servers", "onServers")
    m.global.observeFieldScoped("serverName", "onBrand")
    form()
end sub

' Prefills Server with what answered first, unless the viewer typed one.
sub onServers()
    if m.values.server <> "" or m.global.servers.Count() = 0 then return
    m.values.server = m.global.servers[0].address
    m.found = true
    if m.chooser then chooser() else form()
end sub

sub onBrand()
    if m.homes.Count() > 0
        homes()
    else if m.chooser
        chooser()
    else
        form()
    end if
end sub

function field(id as string, label as string, value as string, hint as string, y as integer, placeholder as string) as object
    f = uiPanel(m.top, id, 16, 192, y, 820, 104)
    uiLabel(f, label, 24, false, "dim", 28, 14)
    if value = ""
        uiLabel(f, placeholder, 32, false, "dim", 28, 46)
    else
        uiLabel(f, value, 32, true, "text", 28, 46).width = 560
    end if
    if hint <> ""
        h = uiLabel(f, hint, 24, false, "dim", 0, 0)
        h.width = 792
        h.height = 104
        h.horizAlign = "right"
        h.vertAlign = "center"
    end if
    return f
end function

sub form()
    m.chooser = false
    keep = m.current
    uiClear(m.top)
    m.controls = {}
    m.rings = {}
    uiImage(m.top, "brand.png", 96, 72, 40, 40)
    shown = apiServerBase(m.values.server)
    brandLabel(m.top, shown, 150, 74, 1674)
    heading = uiLabel(m.top, "Sign in to " + brandName(shown, m.global.server, m.global.serverName), 64, true, "text", 192, 200)
    heading.width = 900
    hint = ""
    if m.found then hint = "Found on your network"
    field("server", "Server", m.values.server, hint, 306, "Choose your server")
    emailHint = ""
    if m.emailFromRoku = true then emailHint = "From your Roku account"
    field("email", "Email", m.values.email, emailHint, 432, "Enter your email")
    dots = ""
    for i = 1 to Len(m.values.password)
        dots = dots + "•"
    end for
    field("password", "Password", dots, "", 558, "Enter your password")
    m.controls.signin = uiButton(m.top, "signin", "Sign in", "p", 192, 690)
    m.controls.code = uiButton(m.top, "code", "Use a code instead", "s", 0, 690)
    uiRow([m.controls.signin, m.controls.code], 192, 690, 24)
    if m.message <> "" then uiLabel(m.top, m.message, 26, false, "accent", 192, 790, 820)
    uiShape(m.top, 16, 1132, 332, 596, 300, uiColor("card"))
    uiLabel(m.top, "Easier than the arrow keys", 30, true, "text", 1172, 368)
    uiLabel(m.top, "Press the microphone button on your remote and say each character.", 26, false, "sub", 1172, 418, 516)
    uiLabel(m.top, "Or open the Roku app on your phone and type with its keyboard.", 26, false, "sub", 1172, 518, 516)
    m.layout = [["server"], ["email"], ["password"], ["signin", "code"]]
    if keep = invalid or m.controls[keep] = invalid
        keep = "password"
        if m.values.email = "" then keep = "email"
        if m.values.server = "" then keep = "server"
    end if
    m.current = invalid
    uiFocus(keep)
end sub

' The SignInRokuServer board: what answered discovery, an address, or a
' new search.
sub chooser()
    m.chooser = true
    uiClear(m.top)
    m.controls = {}
    m.rings = {}
    uiImage(m.top, "brand.png", 96, 72, 40, 40)
    brandLabel(m.top, apiServerBase(m.values.server), 150, 74, 1674)
    uiLabel(m.top, "Choose your server", 64, true, "text", 192, 200)
    servers = m.global.servers
    m.layout = []
    if servers.Count() = 0
        uiLabel(m.top, "No server answered on this network.", 28, false, "dim", 192, 300)
    else
        uiLabel(m.top, "Rabbit Ears servers found on this network.", 28, false, "dim", 192, 300)
    end if
    y = 380
    for i = 0 to servers.Count() - 1
        id = "s" + i.ToStr()
        p = uiPanel(m.top, id, 16, 192, y, 900, 120)
        uiImage(p, "brand.png", 32, 34, 52, 52)
        uiLabel(p, servers[i].name, 34, true, "text", 112, 18)
        uiLabel(p, servers[i].address.Split(":")[0] + " · on this network", 26, false, "dim", 112, 66)
        m.layout.Push([id])
        y = y + 148
    end for
    m.controls.address = uiButton(m.top, "address", "Enter an address", "s", 0, 0)
    m.controls.again = uiButton(m.top, "again", "Search again", "s", 0, 0)
    uiRow([m.controls.address, m.controls.again], 192, y + 8, 24)
    m.layout.Push(["address", "again"])
    m.current = invalid
    uiFocus(m.layout[0][0])
end sub

' Which household is this Roku in, for an adult in more than one: theirs
' is chosen until another is.
sub homes()
    uiClear(m.top)
    m.controls = {}
    m.rings = {}
    uiImage(m.top, "brand.png", 96, 72, 40, 40)
    brandLabel(m.top, m.base, 150, 74, 1674)
    uiLabel(m.top, "Which household is this Roku in?", 64, true, "text", 192, 200)
    uiLabel(m.top, "You are in more than one. Who's watching shows the profiles of the household you pick.", 28, false, "dim", 192, 300)
    m.layout = []
    y = 380
    for i = 0 to m.homes.Count() - 1
        id = "h" + i.ToStr()
        p = uiPanel(m.top, id, 16, 192, y, 900, 120)
        if i = m.home then uiImage(p, "check.png", 32, 34, 52, 52, uiColor("accent"))
        uiLabel(p, m.homes[i].name, 34, true, "text", 112, 18)
        uiLabel(p, m.homes[i].label, 26, false, "dim", 112, 66)
        m.layout.Push([id])
        y = y + 148
    end for
    m.controls.confirm = uiButton(m.top, "confirm", "Continue", "p", 192, y + 8)
    m.layout.Push(["confirm"])
    uiLabel(m.top, "Asked once, after signing in. Sign out to change it.", 26, false, "dim", 192, y + 120)
    if m.message <> "" then uiLabel(m.top, m.message, 26, false, "accent", 192, y + 170, 820)
    keep = m.current
    if keep = invalid or m.controls[keep] = invalid then keep = "confirm"
    m.current = invalid
    uiFocus(keep)
end sub

sub onSelect(id as string)
    if id = "confirm"
        if m.home = 0
            m.top.navigate = { to: "WhoView" }
        else
            netCall("moveDevice", {}, {}, { householdId: m.homes[m.home].id }, "onMoved")
        end if
    else if m.homes.Count() > 0
        m.home = id.Mid(1).ToInt()
        homes()
    else if id = "server"
        chooser()
    else if id = "email"
        if not m.askedEmail
            ' Roku asks the viewer before it shares the account's email.
            m.askedEmail = true
            m.store = CreateObject("roSGNode", "ChannelStore")
            m.store.requestedUserData = "email"
            m.store.observeFieldScoped("userData", "onUserData")
            m.store.command = "getUserData"
        else
            m.editing = "email"
            uiKeyboard("Email", m.values.email, false, "onKeyboard")
        end if
    else if id = "password"
        m.editing = "password"
        uiKeyboard("Password", "", true, "onKeyboard")
    else if id = "signin"
        signIn()
    else if id = "code"
        if m.values.server = ""
            m.message = "Choose your server first."
            form()
        else if useServer()
            markDiscovered()
            m.top.navigate = { to: "LinkView" }
        end if
    else if id = "address"
        m.editing = "server"
        uiKeyboard("Server address", m.values.server, false, "onKeyboard")
    else if id = "again"
        m.search = CreateObject("roSGNode", "DiscoveryTask")
        m.search.observeFieldScoped("servers", "onSearch")
        m.search.control = "run"
    else
        m.values.server = m.global.servers[id.Mid(1).ToInt()].address
        m.found = true
        m.current = "email"
        form()
    end if
end sub

sub onSearch(event as object)
    m.global.servers = event.getData()
    chooser()
end sub

sub onUserData(event as object)
    data = event.getData()
    if data <> invalid and data.email <> invalid and data.email <> ""
        m.values.email = data.email
        m.emailFromRoku = true
        m.current = "password"
        form()
    else
        m.editing = "email"
        uiKeyboard("Email", m.values.email, false, "onKeyboard")
    end if
end sub

sub onKeyboard(event as object)
    d = m.top.getScene().dialog
    d.close = true
    if event.getData() <> 0 then return
    m.values[m.editing] = d.text.Trim()
    if m.editing = "email" then m.emailFromRoku = false
    if m.editing = "server"
        m.found = false
        m.current = "email"
    else if m.editing = "email"
        m.current = "password"
    else
        m.current = "signin"
    end if
    form()
end sub

sub signIn()
    if m.values.server = "" or m.values.email = "" or m.values.password = ""
        m.message = "Fill in all three fields."
        form()
        return
    end if
    if not useServer() then return
    netCall("signIn", {}, {}, { email: m.values.email, password: m.values.password, deviceName: deviceName(), platform: "roku" }, "onSignedIn")
end sub

sub onSignedIn(event as object)
    r = event.getData()
    if r.ok
        m.values.password = ""
        markDiscovered()
        sessionSave(m.base, r.data.token)
        m.global.me = r.data.me
        m.global.profileId = r.data.me.activeProfileId
        m.homes = householdChoices(r.data)
        if m.homes.Count() > 0
            m.home = 0
            m.message = ""
            m.current = invalid
            homes()
        else
            m.top.navigate = { to: "WhoView" }
        end if
        return
    end if
    if r.status = 401 or r.status = 403
        m.message = "Email or password is wrong."
    else if r.code = "network"
        m.message = "Can't reach " + m.base + "."
    else
        m.message = r.message
    end if
    form()
end sub

' The device is in the other household now, so its profiles come anew.
sub onMoved(event as object)
    r = event.getData()
    if r.ok
        netCall("getMe", {}, {}, invalid, "onMe")
    else
        homeFailed(r)
    end if
end sub

sub onMe(event as object)
    r = event.getData()
    if not r.ok
        homeFailed(r)
        return
    end if
    m.global.me = r.data
    m.global.profileId = r.data.activeProfileId
    m.top.navigate = { to: "WhoView" }
end sub

sub homeFailed(r as object)
    m.message = r.message
    if r.code = "network" then m.message = "Can't reach " + m.base + "."
    homes()
end sub

function insecure() as string
    return "Use https:// for a server outside your home network."
end function

' Plain HTTP beyond the local network would carry the password, link code
' and token in the clear; a server found by discovery is checked the same.
function useServer() as boolean
    m.base = apiServerBase(m.values.server)
    if not apiSecure(m.base)
        m.message = insecure()
        form()
        return false
    end if
    sessionUse(m.base, "")
    brandRefresh()
    return true
end function

sub markDiscovered()
    if discoveryFound(m.base, m.global.servers) then m.global.discovered = true
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "OK" and m.current <> invalid
        onSelect(m.current)
        return true
    end if
    if key = "back" and m.chooser
        form()
        return true
    end if
    return uiArrow(key)
end function
