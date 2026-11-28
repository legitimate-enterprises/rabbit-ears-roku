' The profile's favorites, loaded again whenever its state may have moved,
' as after a star is toggled.
sub init()
    m.top.observeField("focusedChild", "onFocus")
    m.controls = {}
    m.rings = {}
    sectionsInit(96, 1824, "Favorites")
    m.controls.results = m.results
    m.layout = [["results"]]
    m.current = "results"
    m.global.observeFieldScoped("stateVersion", "onStateVersion")
    load()
end sub

' A view the router dropped stops listening.
sub onStateVersion()
    if uiDetached() then m.global.unobserveFieldScoped("stateVersion") else load()
end sub

sub load()
    netLoad("favorites", { profileId: m.global.profileId }, "onFavorites")
end sub

sub onFavorites(event as object)
    r = event.getData()
    if not r.ok
        show([])
        m.none.text = "Couldn't load favorites: " + r.message
        return
    end if
    m.states = r.data.states
    sections = libraryFavoriteSections(r.data.favorites, r.data.items)
    show(sections)
    if sections.Count() = 0 then m.none.text = "Nothing starred yet. Favorite is beside a title's Play."
end sub

sub onFocus()
    uiBlur()
    if m.top.hasFocus() then uiFocus(m.current)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    return uiArrow(key)
end function
