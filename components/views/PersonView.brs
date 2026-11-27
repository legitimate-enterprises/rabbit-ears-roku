' params.person is a Person, or a cast member as { id, name }. Its titles
' are the server's items crediting them, and OK on one opens its details.
sub init()
    m.top.observeField("focusedChild", "uiRestore")
    m.controls = {}
    m.rings = {}
    m.layout = []
end sub

sub load()
    p = m.top.params.person
    uiRound(m.top, p.id, 96, 96, 160, "person", uiPersonArtUrl(p.id), formatPersonColor(p.id))
    name = uiLabel(m.top, p.name, 64, true, "text", 296, 110, 1528)
    name.maxLines = 2
    m.below = 110 + Int(name.boundingRect().height) + 20
    m.note = uiLabel(m.top, "", 30, false, "dim", 296, m.below)
    netLoad("list", { op: "listItems", params: {}, query: { personId: p.id } }, "onItems")
end sub

sub onItems(event as object)
    r = event.getData()
    if not r.ok
        m.note.text = "Couldn't load this: " + r.message
        return
    end if
    m.items = r.data
    if m.items.Count() = 0
        m.note.text = formatCountOf(0, "title")
        return
    end if
    ' The library grid's seven posters across.
    m.width = (1920 - 192 - 6 * 28) \ 7
    grid = m.top.CreateChild("MarkupGrid")
    grid.itemComponentName = "TileItem"
    grid.numColumns = 7
    grid.numRows = 2
    uiGridLayout(grid, 96, m.below + 120, m.width, Int(m.width * 1.5) + 80, 28, 36)
    ' Focus stays on the top row, whole on screen, with the next row peeking
    ' below; the last row too comes up to the top.
    grid.vertFocusAnimationStyle = "fixedFocus"
    grid.drawFocusFeedback = false
    grid.observeFieldScoped("itemSelected", "onPick")
    m.controls.grid = grid
    m.layout = [["grid"]]
    grid.content = CreateObject("roSGNode", "ContentNode")
    batchStart(grid, r.rest)
    addTiles(m.items)
    m.current = "grid"
    if m.top.isInFocusChain() then uiFocus(m.current)
end sub

sub batchRows(rows as object)
    m.items.Append(rows)
    addTiles(rows)
end sub

sub addTiles(items as object)
    m.note.text = formatCountOf(m.items.Count(), "title", batchMore())
    root = m.controls.grid.content
    for each item in items
        c = root.CreateChild("ContentNode")
        c.title = itemTitle(item)
        c.shortDescriptionLine1 = formatYear(item)
        if item.kind = "episode" then c.shortDescriptionLine1 = formatEpisodeCode(item)
        c.hdPosterUrl = uiArtUrl(item.id, "poster")
        c.addFields({ itemId: item.id, artWidth: m.width, artHeight: Int(m.width * 1.5), badge: "", glyph: item.kind })
    end for
end sub

sub onPick(event as object)
    m.top.navigate = { to: "details", item: m.items[event.getData()] }
end sub
