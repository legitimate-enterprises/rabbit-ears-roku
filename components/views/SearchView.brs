' Searches as the viewer types, after a short pause.
sub init()
    m.top.observeField("focusedChild", "onFocus")
    m.controls = {}
    m.rings = {}
    m.keyboard = m.top.CreateChild("MiniKeyboard")
    m.keyboard.translation = [96, 200]
    m.keyboard.observeFieldScoped("text", "onText")
    sectionsInit(680, 1240, "Search")
    netLoad("states", { profileId: m.global.profileId }, "onStates")
    m.wait = m.top.CreateChild("Timer")
    m.wait.duration = 0.3
    m.wait.observeFieldScoped("fire", "onWait")
    m.controls.keyboard = m.keyboard
    m.controls.results = m.results
    m.layout = [["keyboard", "results"]]
    m.current = "keyboard"
end sub

sub onStates(event as object)
    r = event.getData()
    if r.ok then m.states = r.data
end sub

sub onText()
    m.wait.control = "stop"
    m.wait.control = "start"
end sub

sub onWait()
    q = m.keyboard.text.Trim()
    if q = ""
        netDrop("onFound")
        show([])
        return
    end if
    m.query = q
    netCall("search", {}, { q: q, limit: 20 }, invalid, "onFound")
end sub

sub onFound(event as object)
    r = event.getData()
    if not r.ok then return
    sections = searchSections(r.data)
    show(sections)
    if sections.Count() = 0 then m.none.text = "Nothing matches “" + m.query + "”."
end sub

sub onFocus()
    uiBlur()
    if m.top.hasFocus() then uiFocus(m.current)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    ' An empty list would hold focus without drawing a ring.
    if key = "right" and m.sections.Count() = 0 then return true
    return uiArrow(key)
end function
