' Builds the boards' nodes in code: one palette, the system font at the
' boards' sizes, white 9-patch shapes tinted per use.

function uiColor(name as string) as string
    return {
        ground: "0x1C1C1EFF"
        raised: "0x2A2A2DFF"
        card: "0x232326FF"
        accent: "0xF2B33DFF"
        text: "0xF2F2F7FF"
        sub: "0xC7C7CCFF"
        dim: "0x98989DFF"
        ok: "0x5BD47AFF"
        glass: "0xFFFFFF1F"
        tag: "0xFFFFFF29"
    }[name]
end function

' Placeholder art: a flat block per item, as on the boards.
function uiArtColor(id as integer) as string
    colors = ["0x2E6B8AFF", "0x6B3A2EFF", "0x5B6B3FFF", "0x4A3F5BFF", "0x3F5B8AFF", "0x5A2B2BFF", "0x2B5A4AFF", "0x8A5A2BFF", "0x3B3F55FF", "0x4C4A48FF"]
    return colors[id mod colors.Count()]
end function

function uiFont(size as integer, bold = false as boolean) as object
    f = CreateObject("roSGNode", "Font")
    f.uri = "font:SystemFontFile"
    if bold then f.uri = "font:BoldSystemFontFile"
    f.size = size
    return f
end function

function uiLabel(parent as object, text as string, size as integer, bold as boolean, color as string, x as integer, y as integer, width = 0 as integer) as object
    l = parent.CreateChild("Label")
    l.font = uiFont(size, bold)
    l.color = uiColor(color)
    l.text = text
    l.translation = [x, y]
    if width > 0
        l.width = width
        l.wrap = true
    end if
    return l
end function

function uiRect(parent as object, x as integer, y as integer, w as integer, h as integer, color as string) as object
    r = parent.CreateChild("Rectangle")
    r.translation = [x, y]
    r.width = w
    r.height = h
    r.color = color
    return r
end function

function uiImage(parent as object, name as string, x as integer, y as integer, w as integer, h as integer, blend = "" as string) as object
    p = parent.CreateChild("Poster")
    p.uri = "pkg:/images/" + name
    p.translation = [x, y]
    p.width = w
    p.height = h
    if blend <> "" then p.blendColor = blend
    return p
end function

' A rounded shape of radius 12, 14, 16 or 28, tinted to color.
function uiShape(parent as object, radius as integer, x as integer, y as integer, w as integer, h as integer, color as string) as object
    return uiImage(parent, "fill" + radius.ToStr() + ".9.png", x, y, w, h, color)
end function

' The one focus ring: 5 px goldenrod, 5 px off the shape it marks.
function uiRing(parent as object, x as integer, y as integer, w as integer, h as integer) as object
    r = uiRingReach()
    ring = uiImage(parent, "ring.9.png", x - r, y - r, w + 2 * r, h + 2 * r, uiColor("accent"))
    ring.visible = false
    return ring
end function

' How far a ring reaches past the shape it marks.
function uiRingReach() as integer
    return 10
end function

' A MarkupGrid or MarkupList cuts off whatever its items draw past its
' edges, as a ring does past a tile in the first row or column. Its items,
' which draw uiRingReach() in from their item's corner, are laid out that
' much larger all round so they land where x, y, w, h and the gaps put
' them and their rings stay inside. Gaps under twice the reach go negative,
' which Roku takes as items overlapping.
sub uiGridLayout(grid as object, x as integer, y as integer, w as integer, h as integer, gapX as integer, gapY as integer)
    r = uiRingReach()
    grid.translation = [x - r, y - r]
    grid.itemSize = [w + 2 * r, h + 2 * r]
    grid.itemSpacing = [gapX - 2 * r, gapY - 2 * r]
end sub

' The same room in a RowList of TileItems 28 apart, its tiles' row at x, y
' when it has no labels. A labelled one keeps its translation and labels,
' labelGap above the tiles. Set after itemSize; rowItemSize by uiRowSizes.
sub uiRowsAt(rows as object, x as integer, y as integer, labelGap = -1 as integer)
    r = uiRingReach()
    rows.rowItemSpacing = [[28 - 2 * r, 0]]
    rows.itemSize = [rows.itemSize[0], rows.itemSize[1] + 2 * r]
    if labelGap < 0
        rows.translation = [x - r, y - r]
    else
        rows.translation = [x - r, y]
        rows.rowLabelOffset = [[r, labelGap - r]]
    end if
end sub

' A RowList's rowItemSize from its tiles' sizes, with the room of uiRowsAt.
function uiRowSizes(sizes as object) as object
    r = uiRingReach()
    out = []
    for each s in sizes
        out.Push([s[0] + 2 * r, s[1] + 2 * r])
    end for
    return out
end function

' The top navigation's tabs, and a screen's view tabs: labels 30 bold
' from x, spacing apart plus their widths, the current one white over a 4 px
' accent bar and the rest dim. Each as { node, ring }, the ring hidden.
function uiTabs(parent as object, texts as object, current as integer, x as integer, y as integer, spacing as integer) as object
    tabs = []
    for i = 0 to texts.Count() - 1
        l = uiLabel(parent, texts[i], 30, true, uiPick(i = current, "text", "dim"), x, y)
        l.focusable = true
        w = l.boundingRect().width
        if i = current then uiRect(parent, x, y + 46, w, 4, uiColor("accent"))
        tabs.Push({ node: l, ring: uiRing(parent, x - 6, y - 4, w + 12, 50) })
        x = x + w + spacing
    end for
    return tabs
end function

' Artwork from the server over its placeholder block and kind's glyph.
' Posters send the scene's Authorization header, set at sign in. url
' overrides the item's own artwork, as a collection's; glyph names the
' kind of what it shows when the item has no kind of its own.
function uiArt(parent as object, item as object, kind as string, x as integer, y as integer, w as integer, h as integer, url = "" as string, glyph = "" as string) as object
    if url = "" then url = uiArtUrl(item.id, kind)
    if glyph = "" and item.DoesExist("kind") then glyph = item.kind
    g = parent.CreateChild("Group")
    g.translation = [x, y]
    uiRect(g, 0, 0, w, h, uiArtColor(item.id))
    uiGlyph(g, glyph, w, h)
    uiArtPoster(g, w, h, url)
    return g
end function

' The icon of a kind, or of the plural a tab or section names, centered on a
' tile of w by h; none for a kind without one.
sub uiGlyph(parent as object, kind as dynamic, w as integer, h as integer)
    if type(kind) <> "roString" and type(kind) <> "String" then return
    names = { movie: "movie", movies: "movie", show: "show", shows: "show", season: "show", episode: "show", episodes: "show", album: "album", songs: "album", albums: "album", artist: "artist", artists: "artist", song: "album", channel: "channel", channels: "channel", video: "video", videos: "video", unwatched: "video", playlist: "playlist", playlists: "playlist", collection: "collection", collections: "collection", person: "person", people: "person", station: "station", tv: "show", music: "album" }
    name = LCase(kind)
    if not names.DoesExist(name) then return
    side = w
    if h < side then side = h
    side = Int(side * 0.4)
    if side < 32 then side = 32
    if side > 96 then side = 96
    uiImage(parent, "ph-" + names[name] + ".png", (w - side) \ 2, (h - side) \ 2, side, side, "0xFFFFFF99")
end sub

' A Poster for server artwork: clear until its image is ready, then faded
' in over the placeholder beneath it. One that fails stays clear.
function uiArtPoster(parent as object, w as integer, h as integer, url as string) as object
    p = parent.CreateChild("Poster")
    if m.artSeq = invalid then m.artSeq = 0
    m.artSeq = m.artSeq + 1
    p.id = "art" + m.artSeq.ToStr()
    p.width = w
    p.height = h
    ' The artwork endpoint serves one size; decoding at the drawn size keeps the texture small.
    p.loadWidth = w
    p.loadHeight = h
    p.loadDisplayMode = "scaleToZoom"
    p.opacity = 0
    p.observeFieldScoped("loadStatus", "onArtStatus")
    p.uri = url
    return p
end function

sub onArtStatus(event as object)
    p = event.getRoSGNode()
    if p.loadStatus <> "ready" then return
    p.unobserveFieldScoped("loadStatus")
    fade = p.CreateChild("Animation")
    fade.duration = 0.2
    fade.easeFunction = "linear"
    fadeStep = fade.CreateChild("FloatFieldInterpolator")
    fadeStep.fieldToInterp = p.id + ".opacity"
    fadeStep.key = [0.0, 1.0]
    fadeStep.keyValue = [0.0, 1.0]
    fade.control = "start"
end sub

' Details' facts: text and tags ({ text, tag: true }) in one line, left to
' right, 18 apart; color is a uiColor name for text.
sub uiFacts(parent as object, parts as object, x as integer, y as integer)
    for each p in parts
        if p.tag <> invalid and p.tag
            t = uiShape(parent, 12, x, y + 2, 0, 34, uiColor("tag"))
            l = uiLabel(parent, p.text, 22, true, "text", x + 10, y + 4)
            t.width = l.boundingRect().width + 20
            x = x + t.width + 18
        else if p.text <> ""
            color = "dim"
            if p.color <> invalid then color = p.color
            l = uiLabel(parent, p.text, 28, false, color, x, y)
            x = x + l.boundingRect().width + 18
        end if
    end for
end sub

' Round artwork, an artist's, a channel's or a person's, over its
' placeholder disc. url and color, when given, replace the item's poster
' and placeholder color; a url of "" shows the placeholder alone.
function uiRound(parent as object, itemId as integer, x as integer, y as integer, d as integer, glyph = "" as string, url = invalid as dynamic, color = "" as string) as object
    g = parent.CreateChild("MaskGroup")
    g.maskUri = "pkg:/images/disc.png"
    g.maskSize = [d, d]
    g.translation = [x, y]
    if color = "" then color = uiArtColor(itemId)
    uiImage(g, "disc.png", 0, 0, d, d, color)
    uiGlyph(g, glyph, d, d)
    if url = invalid then url = uiArtUrl(itemId, "poster")
    uiArtPoster(g, d, d, url)
    return g
end function

function uiPersonArtUrl(personId as integer) as string
    return m.global.server + apiRequest("getPersonArtwork", { personId: personId }).path
end function

function uiArtUrl(itemId as integer, kind as string) as string
    return m.global.server + apiRequest("getItemArtwork", { itemId: itemId, kind: kind }).path
end function

function uiCollectionArtUrl(collectionId as integer, kind as string) as string
    return m.global.server + apiRequest("getCollectionArtwork", { collectionId: collectionId, kind: kind }).path
end function

' The boards' "N new" marker, its right edge at `right`.
sub uiBadge(parent as object, text as string, right as integer, y as integer)
    shape = uiShape(parent, 16, 0, y, 0, 34, uiColor("accent"))
    l = uiLabel(parent, text, 22, true, "ground", 0, y)
    l.height = 34
    l.vertAlign = "center"
    w = l.boundingRect().width + 24
    shape.width = w
    shape.translation = [right - w, y]
    l.translation = [right - w + 12, y]
end sub

' A pill that is no control, as Waiting for someone to join and In sync
' with Helga: tone is a uiColor name, icon an image name or "dot". Its
' label is the third child.
function uiChip(parent as object, text as string, tone as string, icon as string, h as integer, size as integer) as object
    g = parent.CreateChild("Group")
    color = uiColor(tone)
    shape = uiShape(g, 14, 0, 0, 0, h, Left(color, 8) + "29")
    x = 30
    if icon = "dot"
        uiImage(g, "disc.png", x, (h - 14) \ 2, 14, 14, color)
        x = x + 30
    else
        uiImage(g, icon + ".png", x, (h - 26) \ 2, 26, 26, color)
        x = x + 40
    end if
    l = uiLabel(g, text, size, true, tone, x, 0)
    l.height = h
    l.vertAlign = "center"
    shape.width = x + l.boundingRect().width + 30
    return g
end function

function uiButton(parent as object, id as string, text as string, kind as string, x as integer, y as integer, small = false as boolean, icon = "" as string) as object
    b = parent.CreateChild("Button")
    b.id = id
    b.small = small
    b.icon = icon
    b.kind = kind
    b.text = text
    b.translation = [x, y]
    return b
end function

' Lays out nodes left to right from their own widths.
sub uiRow(nodes as object, x as integer, y as integer, gap as integer)
    for each n in nodes
        n.translation = [x, y]
        x = x + n.boundingRect().width + gap
    end for
end sub

' Whether this component is off the scene, as a view the router dropped
' that still hears the observers it set; it then stops listening.
function uiDetached() as boolean
    n = m.top
    while n.getParent() <> invalid
        n = n.getParent()
    end while
    return not n.isSubtype("Scene")
end function

sub uiClear(group as object)
    group.RemoveChildrenIndex(group.GetChildCount(), 0)
end sub


function uiPick(condition as boolean, yes as string, no as string) as string
    if condition then return yes
    return no
end function
