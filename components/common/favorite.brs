' The details views' Favorite button. m.favorite is whether the item is a
' favorite of the profile, and m.controls.favorite is the button.

function favoriteControl(parent as object, small = false as boolean) as object
    f = favoriteButton(m.favorite)
    m.controls.favorite = uiButton(parent, "favorite", f.text, f.kind, 0, 0, small, f.icon)
    return m.controls.favorite
end function

' Stars the item of kind, or unstars it while it is a favorite.
sub favoriteToggle(kind as string, itemId as string)
    c = favoriteCall(kind, m.global.profileId, itemId, not m.favorite)
    if c <> invalid then netCall(c.op, c.params, {}, invalid, "onFavorited")
end sub

' Once the server has it, the button turns where it stands, and the views
' that read the profile's state, Favorites among them, read it again. A
' failure leaves it as it was.
sub onFavorited(event as object)
    if not event.getData().ok then return
    m.favorite = not m.favorite
    old = m.controls.favorite
    parent = old.getParent()
    if parent <> invalid
        b = favoriteControl(parent, old.small)
        b.translation = old.translation
        parent.removeChild(old)
        if m.current = "favorite" and m.top.isInFocusChain() then uiFocus("favorite")
    end if
    m.global.stateVersion = m.global.stateVersion + 1
end sub
