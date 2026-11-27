sub init()
    m.top.observeField("focusedChild", "onFocus")
    m.global.observeFieldScoped("stateVersion", "onVersion")
    m.global.observeFieldScoped("stationVersion", "onVersion")
    m.controls = {}
    m.rings = {}
    m.layout = []
    m.rows = invalid
    m.onRows = false
    load()
end sub

' A view the router dropped stops listening.
sub onVersion(event as object)
    if uiDetached() then m.global.unobserveFieldScoped(event.getField()) else load()
end sub

sub load()
    netLoad("home", { profileId: m.global.profileId }, "onHome")
end sub

' One ContentNode per tile, as TileItem draws it.
function tile(item as object, title as string, caption as string, kind as string, w as integer, h as integer) as object
    c = CreateObject("roSGNode", "ContentNode")
    c.title = title
    c.shortDescriptionLine1 = caption
    c.hdPosterUrl = uiArtUrl(item.id, kind)
    glyph = ""
    if item.DoesExist("kind") then glyph = item.kind
    c.addFields({ itemId: item.id, artWidth: w, artHeight: h, badge: "", glyph: glyph })
    return c
end function

' One row of progress tiles.
sub addProgressRow(rows as object, title as string, entries as object, plays = false as boolean)
    row = rows.CreateChild("ContentNode")
    row.title = title
    for each e in entries
        kind = "backdrop"
        if e.video
            name = e.item.title
            kind = "poster"
        else
            name = itemTitle(e.item)
            if e.show <> invalid then name = itemTitle(e.show)
            if e.item.kind = "episode" then kind = "poster"
        end if
        c = tile(e.item, name, libraryProgressLine(e), kind, 400, 225)
        ' A tile that plays says so with an arrow over its art, unless it opens a video's details.
        if plays and not e.video then c.addFields({ plays: true })
        done = libraryResumeFraction(e)
        if done <> invalid then c.addFields({ progress: done })
        row.appendChild(c)
    end for
end sub

' One row of poster tiles: Recently added and each occasion. states, keyed
' by item id, holds the titles' watch states.
sub addTitleRow(rows as object, title as string, items as object, states as object)
    row = rows.CreateChild("ContentNode")
    row.title = title
    for each t in items
        caption = formatYear(t)
        if t.kind = "movie" and t.metadata <> invalid then caption = formatRuntime(t.metadata.runtimeMinutes)
        c = tile(t, itemTitle(t), caption, "poster", 220, 330)
        done = libraryResumeFraction({ item: t, state: states[t.id.ToStr()], video: false })
        if done <> invalid then c.addFields({ progress: done })
        row.appendChild(c)
    end for
end sub

' The tile that ends a row showing part of a longer list, which it opens.
sub addSeeAllTile(row as object, w as integer, h as integer)
    c = row.CreateChild("ContentNode")
    c.title = ""
    c.shortDescriptionLine1 = ""
    c.hdPosterUrl = ""
    c.addFields({ itemId: "", artWidth: w, artHeight: h, badge: "", glyph: "", more: true })
end sub

function alsoItems(entries as object) as object
    items = []
    for each e in entries
        items.Push(e.item)
    end for
    return items
end function

' Built whole on every load; focus returns to the control that had it.
sub onHome(event as object)
    r = event.getData()
    ' Read before the redraw removes the focused control.
    focused = m.top.isInFocusChain()
    ' A reload keeps the tile in focus while its row stays listed.
    was = invalid
    if m.rows <> invalid and m.rows.content <> invalid
        at = m.rows.rowItemFocused
        if at.Count() = 2 and at[0] >= 0 and at[1] >= 0 and at[0] < m.rows.content.getChildCount() then was = { title: m.rows.content.getChild(at[0]).title, index: at[1] }
    end if
    m.rows = invalid
    uiClear(m.top)
    m.controls = {}
    m.rings = {}
    m.layout = []
    if not r.ok
        uiLabel(m.top, "Couldn't load Home: " + r.message, 30, false, "dim", 96, 200)
        if focused then m.top.setFocus(true)
        return
    end if
    if libraryHomeEmpty(r.data)
        uiLabel(m.top, "Nothing here yet.", 30, false, "dim", 96, 200)
        m.current = invalid
        if focused then m.top.setFocus(true)
        return
    end if
    m.data = r.data
    hero = r.data.hero
    top = 190
    if hero <> invalid
        m.heroItem = hero.item
        m.heroEditionId = hero.state.editionId
        m.heroDetails = hero.item
        m.heroVideo = hero.video
        if hero.video
            title = hero.item.title
            artKind = "poster"
        else
            title = itemTitle(hero.item)
            artKind = "backdrop"
        end if
        if hero.show <> invalid
            m.heroDetails = hero.show
            title = itemTitle(hero.show)
        end if
        art = m.top.CreateChild("Poster")
        art.width = 1920
        art.height = 600
        art.loadDisplayMode = "scaleToZoom"
        art.uri = uiArtUrl(m.heroDetails.id, artKind)
        uiImage(m.top, "fade.png", 0, 0, 1920, 600)
        uiLabel(m.top, "Continue watching", 24, true, "accent", 96, 190)
        uiLabel(m.top, title, 76, true, "text", 96, 220, 1500)
        uiLabel(m.top, libraryProgressLine(hero), 30, false, "sub", 96, 318)
        uiProgress(m.top, 96, 372, 520, libraryResumeFraction(hero))
        m.controls.resume = uiButton(m.top, "resume", "Resume", "p", 0, 0, false, "play")
        m.controls.details = uiButton(m.top, "details", "Details", "s", 0, 0)
        uiRow([m.controls.resume, m.controls.details], 96, 400, 24)
        m.layout = [["resume", "details"]]
        top = 540
    end if
    rows = CreateObject("roSGNode", "ContentNode")
    sizes = []
    heights = []
    m.rowItems = []
    m.stationRow = -1
    m.alsoRow = -1
    if r.data.also.Count() > 0
        m.alsoRow = m.rowItems.Count()
        addProgressRow(rows, "Also in progress", r.data.also)
        m.rowItems.Push(alsoItems(r.data.also))
        sizes.Push([400, 305])
        heights.Push(380)
    end if
    m.nextUpRow = -1
    if r.data.nextUp.Count() > 0
        m.nextUpRow = m.rowItems.Count()
        addProgressRow(rows, "Next up", r.data.nextUp, true)
        m.rowItems.Push(alsoItems(r.data.nextUp))
        sizes.Push([400, 305])
        heights.Push(380)
    end if
    if r.data.onNow.Count() > 0
        row = rows.CreateChild("ContentNode")
        row.title = "On now"
        for each s in r.data.onNow
            row.appendChild(stationTile(s, 400, 225, true))
        end for
        m.stationRow = m.rowItems.Count()
        m.rowItems.Push(r.data.onNow)
        sizes.Push([400, 337])
        heights.Push(412)
    end if
    for each o in r.data.occasions
        addTitleRow(rows, o.title, o.items, r.data.states)
        addSeeAllTile(rows.getChild(rows.getChildCount() - 1), 220, 330)
        entries = []
        entries.Append(o.items)
        entries.Push({ seeAll: true, occasion: o.occasion })
        m.rowItems.Push(entries)
        sizes.Push([220, 410])
        heights.Push(480)
    end for
    addTitleRow(rows, "Recently added", r.data.recent, r.data.states)
    m.rowItems.Push(r.data.recent)
    sizes.Push([220, 410])
    heights.Push(480)
    m.videoRow = -1
    if r.data.videos.Count() > 0
        row = rows.CreateChild("ContentNode")
        row.title = "New from your channels"
        today = formatToday()
        for each v in r.data.videos
            c = tile(v, v.title, formatVideoCaption(v, today, true), "poster", 400, 225)
            c.glyph = "video"
            c.badge = "dot"
            done = libraryResumeFraction({ item: v, state: v, video: true })
            if done <> invalid then c.addFields({ progress: done })
            row.appendChild(c)
        end for
        m.videoRow = m.rowItems.Count()
        m.rowItems.Push(r.data.videos)
        sizes.Push([400, 305])
        heights.Push(380)
    end if
    m.rows = m.top.CreateChild("RowList")
    m.rows.itemComponentName = "TileItem"
    m.rows.numRows = 2
    m.rows.itemSize = [1824, 410]
    m.rows.rowItemSize = uiRowSizes(sizes)
    m.rows.rowHeights = heights
    uiRowsAt(m.rows, 96, top, 18)
    m.rows.showRowLabel = [true]
    m.rows.rowLabelFont = uiFont(30, true)
    m.rows.rowLabelColor = uiColor("text")
    m.rows.rowFocusAnimationStyle = "floatingFocus"
    m.rows.drawFocusFeedback = false
    m.rows.content = rows
    if was <> invalid
        for i = 0 to rows.getChildCount() - 1
            if rows.getChild(i).title = was.title and was.index < rows.getChild(i).getChildCount() then m.rows.jumpToRowItem = [i, was.index]
        end for
    end if
    m.rows.observeFieldScoped("rowItemSelected", "onPick")
    m.controls.rows = m.rows
    m.layout.Push(["rows"])
    if m.current = invalid or m.controls[m.current] = invalid then m.current = m.layout[0][0]
    if focused then uiFocus(m.current)
end sub

sub onFocus()
    uiBlur()
    if not m.top.hasFocus() or m.layout.Count() = 0 then return
    if m.current = invalid then m.current = m.layout[0][0]
    uiFocus(m.current)
end sub

sub onPick(event as object)
    at = event.getData()
    item = m.rowItems[at[0]][at[1]]
    if item.DoesExist("seeAll")
        m.top.navigate = { to: "details", view: "OccasionView", occasion: item.occasion }
    else if at[0] = m.stationRow
        stationTuneIn(item)
    else if at[0] = m.nextUpRow
        m.top.navigate = libraryNextUpRoute(m.data.nextUp[at[1]])
    else if at[0] = m.videoRow or (at[0] = m.alsoRow and m.data.also[at[1]].video)
        m.top.navigate = { to: "details", view: "VideoView", video: item }
    else
        m.top.navigate = { to: "details", item: item }
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "OK" and m.current = "resume"
        m.top.navigate = { to: "player", item: m.heroItem, editionId: m.heroEditionId }
        return true
    end if
    if key = "OK" and m.current = "details" and m.heroVideo
        m.top.navigate = { to: "details", view: "VideoView", video: m.heroDetails }
        return true
    end if
    if key = "OK" and m.current = "details"
        m.top.navigate = { to: "details", item: m.heroDetails }
        return true
    end if
    return uiArrow(key)
end function
