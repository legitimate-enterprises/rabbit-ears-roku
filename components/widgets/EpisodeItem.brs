' Content carries title, shortDescriptionLine1 (facts), description,
' hdPosterUrl, and the added fields itemId, watched and progress, 0 to 1,
' absent unless the episode resumes.
sub draw()
    uiClear(m.top)
    c = m.top.itemContent
    if c = invalid then return
    ' Inset by the room uiGridLayout gives each row for its ring.
    g = m.top.CreateChild("Group")
    g.translation = [uiRingReach(), uiRingReach()]
    m.bg = uiShape(g, 16, 0, 0, 1080, 163, uiColor("raised"))
    still = g.CreateChild("Group")
    still.translation = [14, 14]
    uiRect(still, 0, 0, 240, 135, uiArtColor(c.itemId))
    uiGlyph(still, "show", 240, 135)
    uiArtPoster(still, 240, 135, c.hdPosterUrl)
    if c.watched
        uiImage(still, "disc.png", 194, 10, 36, 36, "0x000000AA")
        uiImage(still, "check.png", 200, 16, 24, 24, uiColor("ok"))
    end if
    uiProgress(still, 0, 129, 240, c.progress)
    uiLabel(g, c.title, 30, true, "text", 282, 22).width = 780
    uiLabel(g, c.shortDescriptionLine1, 24, false, "dim", 282, 64).width = 780
    uiLabel(g, c.description, 24, false, "sub", 282, 100).width = 780
    m.ring = uiRing(g, 0, 0, 1080, 163)
    onFocus()
end sub

sub onFocus()
    if m.ring = invalid then return
    on = m.top.itemHasFocus and m.top.listHasFocus
    m.ring.visible = on
    m.bg.visible = m.top.itemHasFocus
end sub
