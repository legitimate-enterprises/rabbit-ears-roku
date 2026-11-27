' Content carries title, and the added fields number, duration, playing
' and rowWidth.
sub draw()
    uiClear(m.top)
    c = m.top.itemContent
    if c = invalid then return
    ' Inset by the room uiGridLayout gives each row for its ring.
    g = m.top.CreateChild("Group")
    g.translation = [uiRingReach(), uiRingReach()]
    w = c.rowWidth
    m.bg = uiShape(g, 16, 0, 0, w, 72, uiColor("raised"))
    color = "text"
    if c.playing
        color = "accent"
        uiImage(g, "bars.png", 42, 23, 26, 26, uiColor("accent"))
    else
        n = uiLabel(g, c.number, 28, false, "dim", 0, 0)
        n.width = 70
        n.height = 72
        n.horizAlign = "right"
        n.vertAlign = "center"
    end if
    title = uiLabel(g, c.title, 30, true, color, 92, 0)
    title.width = w - 92 - 140
    title.height = 72
    title.vertAlign = "center"
    d = uiLabel(g, c.duration, 28, false, "dim", w - 140, 0)
    d.width = 116
    d.height = 72
    d.horizAlign = "right"
    d.vertAlign = "center"
    m.playing = c.playing
    m.ring = uiRing(g, 0, 0, w, 72)
    onFocus()
end sub

sub onFocus()
    if m.ring = invalid then return
    m.ring.visible = m.top.itemHasFocus and m.top.listHasFocus
    m.bg.visible = m.playing or m.ring.visible
end sub
