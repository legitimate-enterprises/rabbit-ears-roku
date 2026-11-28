' params.occasion is an ActiveOccasion. Its titles are read in the server's
' order, kept as they arrive, and OK on one opens its details. Three soft
' spots of its colors sit behind everything, at the top corners and top edge.
sub init()
    m.top.observeField("focusedChild", "uiRestore")
    m.controls = {}
    m.rings = {}
    m.layout = []
end sub

sub load()
    o = m.top.params.occasion
    wash(libraryWashColors(o.colors))
    netLoad("list", { op: "listItems", params: {}, query: { occasionId: o.id }, statesFor: m.global.profileId }, "onTitles")
end sub

' One spot.png per color, scaled far past the screen and tinted, a little
' stronger at the top edge, where the title is. Static, and drawn first so
' every control sits over it. With fewer than three colors nothing is drawn.
sub wash(colors as object)
    if colors.Count() <> 3 then return
    size = 1400
    xs = [0, 960, 1920]
    strengths = [0.25, 0.3, 0.25]
    for i = 0 to 2
        spot = uiImage(m.top, "spot.png", xs[i] - size \ 2, -size \ 2, size, size, colors[i])
        spot.opacity = strengths[i]
    end for
end sub

sub onTitles(event as object)
    r = event.getData()
    if not r.ok
        uiLabel(m.top, "Couldn't load this: " + r.message, 30, false, "dim", 96, 96)
        return
    end if
    o = m.top.params.occasion
    m.titles = r.data
    m.states = r.states
    title = uiLabel(m.top, o.name, 60, true, "text", 96, 96, 560)
    title.maxLines = 2
    if m.titles.Count() = 0
        uiLabel(m.top, "Nothing in this occasion yet.", 28, false, "dim", 704, 196)
        return
    end if
    list = m.top.CreateChild("MarkupList")
    list.itemComponentName = "EntryItem"
    uiGridLayout(list, 704, 196, 1128, 96, 0, 6)
    list.numRows = 8
    list.vertFocusAnimationStyle = "floatingFocus"
    list.drawFocusFeedback = false
    list.observeFieldScoped("itemSelected", "onTitle")
    m.controls.titles = list
    m.layout = [["titles"]]
    root = CreateObject("roSGNode", "ContentNode")
    addRows(root, m.titles)
    list.content = root
    batchStart(list, r.rest)
    m.current = "titles"
    if m.top.isInFocusChain() then uiFocus(m.current)
end sub

sub batchRows(rows as object)
    m.titles.Append(rows)
    addRows(m.controls.titles.content, rows)
end sub

sub addRows(root as object, titles as object)
    for each item in titles
        n = root.CreateChild("ContentNode")
        n.title = itemTitle(item)
        n.shortDescriptionLine1 = collectionMovieCaption(item)
        n.hdPosterUrl = uiArtUrl(item, "poster")
        n.addFields({ itemId: item.id, rowWidth: 1128, glyph: item.kind })
        done = libraryResumeFraction({ item: item, state: m.states[item.id.ToStr()], video: false })
        if done <> invalid then n.addFields({ progress: done })
    end for
end sub

sub onTitle(event as object)
    m.top.navigate = { to: "details", item: m.titles[event.getData()] }
end sub
