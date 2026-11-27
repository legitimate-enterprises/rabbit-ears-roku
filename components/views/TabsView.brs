sub init()
    m.profile = invalid
    for each p in m.global.me.profiles
        if p.id = m.global.profileId then m.profile = p
    end for
    if m.profile = invalid then m.profile = m.global.me.account
    m.tabs = libraryTabs(sectionsRead())
    m.global.observeFieldScoped("libraryVersion", "onLibraryVersion")
    m.global.observeFieldScoped("hideVersion", "onHideChanged")
    m.views = {}
    m.tab = 0
    m.onBar = false
    m.top.observeField("focusedChild", "onFocus")
    m.global.observeFieldScoped("serverName", "onServerName")
    m.page = m.top.CreateChild("Group")
    m.bar = m.top.CreateChild("Group")
    show(0)
    loadLibraries()
end sub

' A view the router dropped stops listening.
sub onLibraryVersion()
    if uiDetached() then m.global.unobserveFieldScoped("libraryVersion") else loadLibraries()
end sub

sub loadLibraries()
    netLoad("list", { op: "listLibraries", params: {}, query: {} }, "onLibraries")
end sub

' A failed answer keeps the tabs as they are. The tab shown stays unless its
' library is gone, and then Home takes its place.
sub onLibraries(event as object)
    r = event.getData()
    if not r.ok then return
    kinds = []
    for each l in r.data
        kinds.Push(l.kind)
    end for
    sectionsSave(kinds)
    tabs = libraryTabs(kinds)
    if FormatJson(tabs) = FormatJson(m.tabs) then return
    shown = m.tabs[m.tab]
    old = m.tabs.Count()
    m.tabs = tabs
    ' The profile sits after the last tab on the bar.
    if m.barIndex <> invalid
        if m.barIndex >= old or m.barIndex > tabs.Count() then m.barIndex = tabs.Count()
    end if
    m.tab = 0
    for i = 0 to tabs.Count() - 1
        if tabs[i] = shown then m.tab = i
    end for
    show(m.tab)
    if m.onBar then focusBar() else focusPage()
end sub

sub onServerName()
    if uiDetached() then m.global.unobserveFieldScoped("serverName") else drawBar()
end sub

' The bar's own focus: a ring around the tab or the profile while the bar
' has it.
sub drawBar()
    uiClear(m.bar)
    uiImage(m.bar, "brand.png", 96, 64, 40, 40)
    brand = brandLabel(m.bar, m.global.server, 150, 66, 480)
    x = 150 + brand.boundingRect().width + 64
    m.tabNodes = []
    for each t in uiTabs(m.bar, m.tabs, m.tab, x, 66, 40)
        m.tabNodes.Push(t.ring)
    end for
    profile = m.profile
    name = uiLabel(m.bar, profile.name, 26, true, "sub", 0, 74)
    nameW = name.boundingRect().width
    name.translation = [1920 - 96 - nameW, 74]
    ax = 1920 - 96 - nameW - 14 - 52
    uiImage(m.bar, "disc.png", ax, 62, 52, 52, formatProfileColor(profile.color))
    initial = uiLabel(m.bar, UCase(Left(profile.name, 1)), 26, true, "text", ax, 62)
    initial.width = 52
    initial.height = 52
    initial.horizAlign = "center"
    initial.vertAlign = "center"
    m.tabNodes.Push(uiRing(m.bar, ax, 62, 1920 - 96 - ax, 52))
    ' Music draws its now-playing chip in the bar, left of the profile.
    if m.views.Music <> invalid then m.views.Music.chipRight = ax - 32
    markBar()
end sub

sub markBar()
    for i = 0 to m.tabNodes.Count() - 1
        m.tabNodes[i].visible = m.onBar and i = m.barIndex
    end for
end sub

sub show(i as integer)
    m.tab = i
    for each name in m.views
        m.views[name].visible = false
    end for
    key = m.tabs[i]
    v = m.views[key]
    if v = invalid
        if key = "Home"
            v = CreateObject("roSGNode", "HomeView")
        else if key = "Search"
            v = CreateObject("roSGNode", "SearchView")
        else if key = "Music" or key = "YouTube"
            v = CreateObject("roSGNode", "MediaView")
            v.params = { kind: LCase(key) }
        else
            v = CreateObject("roSGNode", "GridView")
            v.params = { kind: { TV: "show", Movies: "movie" }[key] }
        end if
        v.observeFieldScoped("navigate", "onNavigate")
        m.page.appendChild(v)
        m.views[key] = v
    end if
    v.visible = true
    drawBar()
end sub

sub onNavigate(event as object)
    m.top.navigate = event.getData()
end sub

sub focusPage()
    m.onBar = false
    markBar()
    m.views[m.tabs[m.tab]].setFocus(true)
end sub

sub focusBar()
    m.onBar = true
    m.barIndex = m.tab
    m.bar.setFocus(true)
    markBar()
end sub

sub onFocus()
    if not m.top.hasFocus() then return
    if m.onBar then focusBar() else focusPage()
end sub

' An adult's profile menu: Switch profile, the profile's Hide kids' content,
' and this device's Remember profile with Skip PIN under it.
sub openProfile()
    s = rememberRead(m.global.me)
    options = [{ label: "Switch profile", checked: false, disabled: false }]
    options.Push({ label: "Hide kids' content", detail: "Leave kids' titles out of what you browse", checked: libraryHides(m.global.me.profiles, m.profile.id), disabled: false })
    options.Push({ label: "Remember profile", detail: "Start as the last profile, not Who's watching", checked: s.remember, disabled: false })
    if s.remember then options.Push({ label: "Skip PIN", detail: "Start without asking for its PIN", checked: s.skipPin, disabled: false })
    if m.menu = invalid
        m.menu = m.top.CreateChild("OptionMenu")
        m.menu.heading = m.profile.name
        m.menu.translation = [1920 - 96 - 660, 130]
        m.menu.observeFieldScoped("chosen", "onProfileChosen")
        m.menu.observeFieldScoped("cancelled", "closeMenu")
    end if
    m.menu.options = options
    m.menu.setFocus(true)
end sub

sub onProfileChosen(event as object)
    i = event.getData()
    if i = 0
        closeMenu()
        m.top.navigate = { to: "WhoView" }
        return
    end if
    if i = 1
        m.hide = not libraryHides(m.global.me.profiles, m.profile.id)
        body = {}
        body.AddReplace("hideKidsContent", m.hide)
        netCall("setProfilePreferences", { profileId: m.profile.id }, {}, body, "onHideSaved")
        return
    end if
    s = rememberRead(m.global.me)
    if i = 2 then s.remember = not s.remember else s.skipPin = not s.skipPin
    rememberSave(m.global.me, s)
    openProfile()
end sub

' The profile keeps the choice, and every tab loads again as the server now
' answers; a failed save leaves the menu as it was.
sub onHideSaved(event as object)
    if not event.getData().ok then return
    who = m.global.me
    for each p in who.profiles
        if p.id = m.profile.id then p.AddReplace("hideKidsContent", m.hide)
    end for
    m.global.me = who
    onHideChanged()
end sub

' Every tab loads again, as when this device's own toggle saved.
sub onHideChanged()
    if uiDetached()
        m.global.unobserveFieldScoped("hideVersion")
        return
    end if
    for each name in m.views
        m.page.removeChild(m.views[name])
    end for
    m.views = {}
    show(m.tab)
    if m.menu <> invalid then openProfile()
end sub

sub closeMenu()
    m.top.removeChild(m.menu)
    m.menu = invalid
    focusBar()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if m.onBar
        if key = "left" and m.barIndex > 0
            m.barIndex = m.barIndex - 1
        else if key = "right" and m.barIndex < m.tabs.Count()
            m.barIndex = m.barIndex + 1
        else if key = "down" or (key = "OK" and m.barIndex < m.tabs.Count())
            focusPage()
            return true
        else if key = "OK" and m.profile.kind = "adult"
            openProfile()
            return true
        else if key = "OK"
            m.top.navigate = { to: "WhoView" }
            return true
        else if key = "back" and m.tab <> 0
            show(0)
            focusPage()
            return true
        else
            return key = "up"
        end if
        if m.barIndex < m.tabs.Count() then show(m.barIndex)
        markBar()
        return true
    end if
    if key = "up"
        focusBar()
        return true
    end if
    ' Back climbs one level: a tab returns to Home, Home leaves the app.
    if key = "back" and m.tab <> 0
        show(0)
        focusPage()
        return true
    end if
    return false
end function
