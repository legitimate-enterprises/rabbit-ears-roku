' Content carries title, shortDescriptionLine1 (what the entry stands
' for), hdPosterUrl, and the added fields itemId, glyph (the kind its
' placeholder shows) and rowWidth.
sub draw()
    uiClear(m.top)
    c = m.top.itemContent
    if c = invalid then return
    ' Inset by the room uiGridLayout gives each row for its ring.
    g = m.top.CreateChild("Group")
    g.translation = [uiRingReach(), uiRingReach()]
    w = c.rowWidth
    m.bg = uiShape(g, 16, 0, 0, w, 96, uiColor("raised"))
    uiRect(g, 8, 8, 80, 80, uiArtColor(c.itemId))
    art = g.CreateChild("Group")
    art.translation = [8, 8]
    uiGlyph(art, c.glyph, 80, 80)
    uiArtPoster(art, 80, 80, c.hdPosterUrl)
    uiLabel(g, c.title, 30, true, "text", 108, 12).width = w - 128
    uiLabel(g, c.shortDescriptionLine1, 24, false, "dim", 108, 54).width = w - 128
    m.ring = uiRing(g, 0, 0, w, 96)
    onFocus()
end sub

sub onFocus()
    if m.ring = invalid then return
    m.ring.visible = m.top.itemHasFocus and m.top.listHasFocus
    m.bg.visible = m.ring.visible
end sub
