' Content carries title, shortDescriptionLine1 (the caption),
' hdPosterUrl, and the added fields itemId, artWidth, artHeight, glyph
' (the kind its placeholder shows), badge
' ("dot" for unwatched, or a count such as "6 new"), round, true for an
' artist, a channel or a person, tint, a round tile's placeholder color
' when not its item's, and plain, true for a station with no art, drawn
' as the brand mark over its name, plays, true for a tile that plays when
' selected, with an arrow over its art, progress, 0 to 1, drawn as a bar along
' the art's foot, and shared, true for a shared playlist, and ordered, true for
' a hand-ordered collection, each marked in the art's bottom trailing corner,
' and more, true for the tile that ends a row and opens the whole list, drawn
' as See all on a raised block.
' shortDescriptionLine2 is a second caption line.
sub draw()
    uiClear(m.top)
    c = m.top.itemContent
    if c = invalid then return
    ' Inset by the room uiGridLayout and uiRowsAt give each tile for its ring.
    g = m.top.CreateChild("Group")
    g.translation = [uiRingReach(), uiRingReach()]
    w = c.artWidth
    h = c.artHeight
    if c.round <> invalid and c.round
        tint = ""
        if c.tint <> invalid then tint = c.tint
        uiRound(g, c.itemId, 0, 0, w, c.glyph, c.hdPosterUrl, tint)
    else if c.more <> invalid and c.more
        uiShape(g, 16, 0, 0, w, h, uiColor("raised"))
        label = uiLabel(g, "See all", 30, true, "text", 0, h \ 2 - 20)
        label.width = w
        label.horizAlign = "center"
    else if c.plain <> invalid and c.plain
        uiShape(g, 16, 0, 0, w, h, uiColor("raised"))
        mark = h \ 4
        uiImage(g, "brand.png", (w - mark) \ 2, h \ 2 - mark - 4, mark, mark)
        name = uiLabel(g, c.title, 30, true, "text", 16, h \ 2 + 12)
        name.width = w - 32
        name.horizAlign = "center"
    else
        uiRect(g, 0, 0, w, h, uiArtColor(c.itemId))
        uiGlyph(g, c.glyph, w, h)
        uiArtPoster(g, w, h, c.hdPosterUrl)
    end if
    ' The bar is the Continue watching hero's: the same track, gold and height.
    if c.progress <> invalid
        uiRect(g, 0, h - 6, w, 6, "0xFFFFFF40")
        uiRect(g, 0, h - 6, Int(w * c.progress), 6, uiColor("accent"))
    end if
    if c.plays <> invalid and c.plays
        uiImage(g, "disc.png", (w - 80) \ 2, (h - 80) \ 2, 80, 80, "0x00000099")
        uiImage(g, "play.png", (w - 40) \ 2, (h - 40) \ 2, 40, 40, uiColor("text"))
    end if
    if c.badge = "dot"
        uiImage(g, "disc.png", w - 32, 14, 18, 18, uiColor("accent"))
    else if c.badge <> ""
        uiBadge(g, c.badge, w - 10, 10)
    end if
    if c.shared <> invalid and c.shared
        uiImage(g, "disc.png", w - 54, h - 54, 40, 40, "0x00000099")
        uiImage(g, "users.png", w - 48, h - 48, 28, 28, uiColor("text"))
    end if
    if c.ordered <> invalid and c.ordered
        uiImage(g, "disc.png", w - 54, h - 54, 40, 40, "0x00000099")
        uiImage(g, "order.png", w - 48, h - 48, 28, 28, uiColor("text"))
    end if
    title = uiLabel(g, c.title, 26, true, "text", 0, h + 12)
    title.width = w
    caption = uiLabel(g, c.shortDescriptionLine1, 24, false, "dim", 0, h + 46)
    caption.width = w
    if c.shortDescriptionLine2 <> "" then uiLabel(g, c.shortDescriptionLine2, 24, false, "dim", 0, h + 78).width = w
    if c.round <> invalid and c.round
        m.ring = uiImage(g, "disc-ring.png", -10, -10, w + 20, h + 20, uiColor("accent"))
        m.ring.visible = false
    else
        m.ring = uiRing(g, 0, 0, w, h)
    end if
    onFocus()
end sub

sub onFocus()
    if m.ring <> invalid then m.ring.visible = m.top.itemHasFocus and (m.top.gridHasFocus or m.top.rowListHasFocus)
end sub
