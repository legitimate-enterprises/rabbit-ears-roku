' params.collection is a Collection. Its movies are read in the server's
' order, release date or the household's own, kept as they arrive, and OK on
' one opens its details.
sub init()
    m.top.observeField("focusedChild", "uiRestore")
    m.controls = {}
    m.rings = {}
    m.layout = []
end sub

sub load()
    c = m.top.params.collection
    netLoad("list", { op: "listCollectionMovies", params: { collectionId: c.id }, query: {} }, "onMovies")
end sub

sub onMovies(event as object)
    r = event.getData()
    if not r.ok
        uiLabel(m.top, "Couldn't load this: " + r.message, 30, false, "dim", 96, 96)
        return
    end if
    c = m.top.params.collection
    m.movies = r.data
    uiArt(m.top, c, "poster", 96, 96, 360, 360, uiCollectionArtUrl(c.id, "poster"), "collection")
    title = uiLabel(m.top, c.name, 60, true, "text", 96, 476, 560)
    title.maxLines = 2
    y = 476 + Int(title.boundingRect().height) + 12
    uiFacts(m.top, [{ text: collectionCaption(c) }], 96, y)
    y = y + 56
    if collectionOrdered(c)
        uiChip(m.top, "In your order", "dim", "order", 48, 24).translation = [96, y]
        y = y + 64
    end if
    if c.overview <> invalid and c.overview <> ""
        text = uiLabel(m.top, c.overview, 26, false, "sub", 96, y, 560)
        text.maxLines = 8
    end if
    if m.movies.Count() = 0
        uiLabel(m.top, "Nothing in this collection yet.", 28, false, "dim", 704, 196)
        return
    end if
    list = m.top.CreateChild("MarkupList")
    list.itemComponentName = "EntryItem"
    uiGridLayout(list, 704, 196, 1128, 96, 0, 6)
    list.numRows = 8
    list.vertFocusAnimationStyle = "floatingFocus"
    list.drawFocusFeedback = false
    list.observeFieldScoped("itemSelected", "onMovie")
    m.controls.movies = list
    m.layout = [["movies"]]
    root = CreateObject("roSGNode", "ContentNode")
    addRows(root, m.movies)
    list.content = root
    batchStart(list, r.rest)
    m.current = "movies"
    if m.top.isInFocusChain() then uiFocus(m.current)
end sub

sub batchRows(rows as object)
    m.movies.Append(rows)
    addRows(m.controls.movies.content, rows)
end sub

sub addRows(root as object, movies as object)
    for each item in movies
        n = root.CreateChild("ContentNode")
        n.title = itemTitle(item)
        n.shortDescriptionLine1 = collectionMovieCaption(item)
        n.hdPosterUrl = uiArtUrl(item.id, "poster")
        n.addFields({ itemId: item.id, rowWidth: 1128, glyph: "movie" })
    end for
end sub

sub onMovie(event as object)
    m.top.navigate = { to: "details", item: m.movies[event.getData()] }
end sub
