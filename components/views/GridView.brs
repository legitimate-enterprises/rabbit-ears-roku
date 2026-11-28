' params: { kind: "movie" or "show" } loads that library.
sub init()
    m.top.observeField("focusedChild", "onFocus")
    m.controls = {}
    m.rings = {}
    m.layout = []
    m.chip = "all"
    m.genre = invalid
    m.genreIds = invalid
    m.note = ""
    m.all = []
    m.items = []
    m.playlists = []
    m.collections = []
    m.stations = []
    m.totals = {}
    m.kidsOnly = false
    m.grid = invalid
    m.listed = ""
    m.data = { states: {}, progress: {}, genres: [], favorites: {} }
end sub

sub onParams()
    m.sort = libraryStoredSort(CreateObject("roRegistrySection", "RabbitEars").Read(sortKey()))
    m.x = 96
    m.columns = 7
    makeGrid(false)
    m.current = "grid"
    m.bar = m.top.CreateChild("Group")
    m.bar.translation = [0, 172]
    drawBar()
    m.global.observeFieldScoped("stateVersion", "onListingVersion")
    m.global.observeFieldScoped("stationVersion", "onListingVersion")
    m.global.observeFieldScoped("playlistVersion", "onListingVersion")
    load()
end sub

' The stations or playlists showing load again as the server says they
' changed; a view the router dropped stops listening.
sub onListingVersion(event as object)
    if uiDetached()
        m.global.unobserveFieldScoped(event.getField())
        return
    end if
    if event.getField() = "stateVersion"
        load()
        return
    end if
    if m.chip = "stations" and event.getField() = "stationVersion" then loadStations()
    if m.chip = "playlists" and event.getField() = "playlistVersion" then loadPlaylists()
end sub

' Posters, or wide tiles four across with two caption lines for stations.
sub makeGrid(wide as boolean)
    if m.grid <> invalid and m.wide = wide then return
    if m.grid <> invalid then m.top.removeChild(m.grid)
    m.wide = wide
    columns = m.columns
    if wide then columns = 4
    m.width = (1920 - 96 - m.x - (columns - 1) * 28) \ columns
    m.artHeight = Int(m.width * 1.5)
    extra = 80
    if wide
        m.artHeight = Int(m.width * 9 / 16)
        extra = 112
    end if
    m.grid = m.top.CreateChild("MarkupGrid")
    m.grid.itemComponentName = "TileItem"
    m.grid.numColumns = columns
    m.grid.numRows = 2
    uiGridLayout(m.grid, m.x, 260 + barRowY(), m.width, m.artHeight + extra, 28, 36)
    ' Focus stays on the top row, whole on screen, with the next row peeking
    ' below; the last row too comes up to the top.
    m.grid.vertFocusAnimationStyle = "fixedFocus"
    m.grid.drawFocusFeedback = false
    m.grid.observeFieldScoped("itemSelected", "onPick")
    m.controls.grid = m.grid
end sub

' A reload after playback refreshes what the stations have on, too.
sub load()
    m.asked = libraryKidsOnly(m.chip, libraryHides(m.global.me.profiles, m.global.profileId))
    args = { kind: m.top.params.kind, profileId: m.global.profileId, kidsOnly: m.asked }
    if m.genre <> invalid then args.genreId = m.genre.id
    netLoad("grid", args, "onGrid")
    if m.chip = "stations" then loadStations()
end sub

' Whether the chip needs the titles loaded the other way: an adult who
' hides kids' content has the Kids chip's titles from the server, apart from
' the rest.
function rescoped() as boolean
    if m.chip = "playlists" or m.chip = "collections" or m.chip = "stations" then return false
    return libraryKidsOnly(m.chip, libraryHides(m.global.me.profiles, m.global.profileId)) <> m.kidsOnly
end function

sub loadPlaylists()
    kind = { movie: "movies", show: "tv" }[m.top.params.kind]
    netLoad("list", { op: "listPlaylists", params: { profileId: m.global.profileId }, query: { kind: kind } }, "onPlaylists")
end sub

sub loadStations()
    netLoad("list", { op: "listStations", params: {}, query: { kind: { movie: "movies", show: "tv" }[m.top.params.kind] } }, "onStations")
end sub

function barTabs() as object
    adult = false
    for each p in m.global.me.profiles
        if p.id = m.global.profileId and p.kind = "adult" then adult = true
    end for
    return libraryBar(m.top.params.kind, adult, m.chip)
end function

function barSelects() as object
    if m.chip = "playlists" or m.chip = "collections" or m.chip = "stations" then return []
    selects = [{ id: "sort", text: "Sort  " + sortName(m.sort) }]
    if m.data.genres.Count() > 0
        name = "Any"
        if m.genre <> invalid then name = m.genre.name
        selects.Push({ id: "genre", text: "Genre  " + name })
    end if
    return selects
end function

sub onGrid(event as object)
    r = event.getData()
    if not r.ok
        m.note = "Couldn't load: " + r.message
        drawBar()
        return
    end if
    ' The boards open a library on its first poster; a reload after
    ' playback keeps the same title in focus while it stays listed.
    was = invalid
    at = m.grid.itemFocused
    if m.grid.content = invalid
        m.current = "grid"
    else if at >= 0 and at < m.items.Count()
        was = m.items[at].id
    end if
    m.data = r.data
    m.kidsOnly = m.asked
    m.genreIds = r.data.genreIds
    m.all = r.data.items
    fill()
    for i = 0 to m.items.Count() - 1
        if m.items[i].id = was then m.grid.jumpToItem = i
    end for
end sub

' Captions lead with runtime: 2h 46m · 2024, or 58m · 4 seasons.
function caption(item as object) as string
    parts = []
    if item.metadata <> invalid and item.metadata.runtimeMinutes <> invalid then parts.Push(formatRuntime(item.metadata.runtimeMinutes))
    if item.kind = "show"
        p = m.data.progress[item.id.ToStr()]
        if p <> invalid and p.seasons = 1 then parts.Push("1 season")
        if p <> invalid and p.seasons > 1 then parts.Push(p.seasons.ToStr() + " seasons")
    else if item.kind = "episode"
        parts.Push(formatEpisodeCode(item))
    else
        year = formatYear(item)
        if year <> "" then parts.Push(year)
    end if
    return parts.Join(" · ")
end function

sub fill()
    listing = { playlists: m.playlists, collections: m.collections, stations: m.stations }[m.chip]
    if listing <> invalid
        fillListing(listing)
        return
    end if
    makeGrid(false)
    m.listed = ""
    list = libraryFilter(m.all, m.chip, m.data.states, m.data.progress, m.data.favorites)
    if m.genreIds <> invalid
        kept = []
        for each item in list
            if m.genreIds.DoesExist(item.id.ToStr()) then kept.Push(item)
        end for
        list = kept
    end if
    list = librarySort(list, m.sort, m.data.states, m.data.progress)
    m.items = list
    m.note = formatCountOf(list.Count(), m.top.params.kind)
    drawBar()
    root = CreateObject("roSGNode", "ContentNode")
    h = m.artHeight
    for each item in m.items
        c = root.CreateChild("ContentNode")
        c.title = itemTitle(item)
        c.shortDescriptionLine1 = caption(item)
        c.hdPosterUrl = uiArtUrl(item, "poster")
        badge = ""
        unwatched = libraryStanding(item, m.data.states, m.data.progress).unwatched
        if unwatched > 0
            if item.kind = "show" then badge = unwatched.ToStr() + " new"
            if item.kind = "movie" then badge = "dot"
        end if
        c.addFields({ itemId: item.id, artWidth: m.width, artHeight: h, badge: badge, glyph: item.kind })
        done = libraryResumeFraction({ item: item, state: m.data.states[item.id.ToStr()], video: false })
        if done <> invalid then c.addFields({ progress: done })
    end for
    m.grid.content = root
end sub

' The profile's playlists of this tab's kind or the collections it may see,
' as posters, or this tab's kind of stations, as wide tiles.
sub fillListing(items as object)
    makeGrid(m.chip = "stations")
    ' A listing loaded again keeps its place.
    at = -1
    if m.listed = m.chip then at = m.grid.itemFocused
    m.listed = m.chip
    m.items = items
    countNote()
    root = CreateObject("roSGNode", "ContentNode")
    addTiles(root, m.items)
    m.grid.content = root
    if at > 0 and at < m.items.Count() then m.grid.jumpToItem = at
end sub

' m.items is the chip's own list, so the batch joins it too.
sub batchRows(rows as object)
    m.items.Append(rows)
    addTiles(m.grid.content, rows)
    countNote()
end sub

sub countNote()
    noun = { playlists: "playlist", collections: "collection", stations: "station" }[m.chip]
    m.note = formatCountOfTotal(m.totals[m.chip], m.items.Count(), noun, batchMore())
    drawBar()
end sub

sub addTiles(root as object, rows as object)
    for each x in rows
        if m.chip = "stations"
            root.appendChild(stationTile(x, m.width, m.artHeight))
        else if m.chip = "playlists"
            c = root.CreateChild("ContentNode")
            c.title = x.name
            c.shortDescriptionLine1 = playlistCaption(x)
            ' A playlist with no art keeps its placeholder block.
            c.hdPosterUrl = ""
            colorId = x.id
            if x.imageUrl <> invalid
                c.hdPosterUrl = m.global.server + x.imageUrl
            else if x.artItemId <> invalid
                c.hdPosterUrl = uiArtUrl(x, "poster", x.artItemId)
                colorId = x.artItemId
            end if
            c.addFields({ itemId: colorId, artWidth: m.width, artHeight: m.artHeight, badge: "", glyph: "playlist", shared: x.shared })
        else
            c = root.CreateChild("ContentNode")
            c.title = x.name
            c.shortDescriptionLine1 = collectionCaption(x)
            c.hdPosterUrl = uiCollectionArtUrl(x, "poster")
            c.addFields({ itemId: x.id, artWidth: m.width, artHeight: m.artHeight, badge: "", glyph: "collection", ordered: collectionOrdered(x) })
        end if
    end for
end sub

sub onStations(event as object)
    r = event.getData()
    if r.ok then m.stations = r.data
    listed("stations", r)
end sub

sub onCollections(event as object)
    r = event.getData()
    if r.ok then m.collections = r.data
    listed("collections", r)
end sub

sub onPlaylists(event as object)
    r = event.getData()
    if r.ok then m.playlists = r.data
    listed("playlists", r)
end sub

' The chip's further batches load while it shows. Choosing the chip drew
' its grid, so fill keeps the m.grid the batches watch.
sub listed(chip as string, r as object)
    if r.ok then m.totals[chip] = r.total
    if r.ok and m.chip = chip then batchStart(m.grid, r.rest)
    fill()
end sub

sub onFocus()
    uiBlur()
    if m.top.hasFocus() and m.current <> invalid then uiFocus(m.current)
end sub

sub onPick(event as object)
    x = m.items[event.getData()]
    if m.chip = "playlists"
        m.top.navigate = { to: "details", view: "PlaylistView", list: x }
    else if m.chip = "collections"
        m.top.navigate = { to: "details", view: "CollectionView", collection: x }
    else if m.chip = "stations"
        stationTuneIn(x)
    else
        m.top.navigate = { to: "details", item: x }
    end if
end sub

' Each library's sort is this device's, kept across launches.
function sortKey() as string
    return "grid." + m.top.params.kind + ".sort"
end function

function sortName(sort as string) as string
    return { added: "Recently added", title: "Title", watched: "Last watched", year: "Released" }[sort]
end function

' The Sort select's menu: the web grid's four sorts.
sub openSorts()
    m.options = []
    for each sort in librarySorts()
        m.options.Push({ label: sortName(sort), sort: sort, checked: sort = m.sort, disabled: false })
    end for
    openMenu("onSort")
end sub

sub onSort(event as object)
    m.sort = m.options[event.getData()].sort
    r = CreateObject("roRegistrySection", "RabbitEars")
    r.Write(sortKey(), m.sort)
    r.Flush()
    closeMenu()
    fill()
end sub

' The Genre select's menu: Any, then the libraries' genres by name.
sub openGenres()
    m.options = [{ label: "Any", checked: m.genre = invalid, disabled: false }]
    for each g in m.data.genres
        m.options.Push({ label: g.name, genre: g, checked: m.genre <> invalid and m.genre.id = g.id, disabled: false })
    end for
    openMenu("onGenre")
end sub

sub onGenre(event as object)
    m.genre = m.options[event.getData()].genre
    m.genreIds = invalid
    closeMenu()
    if m.genre = invalid
        fill()
    else
        netLoad("genre", { kind: m.top.params.kind, genreId: m.genre.id, kidsOnly: m.kidsOnly }, "onGenreItems")
    end if
end sub

sub onGenreItems(event as object)
    r = event.getData()
    if r.ok
        m.genreIds = r.data
    else
        m.genre = invalid
    end if
    fill()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "OK" and m.current = "sort"
        openSorts()
        return true
    end if
    if key = "OK" and m.current = "genre"
        openGenres()
        return true
    end if
    if key = "OK" and m.current <> "grid"
        chip = m.current
        ' The library's tab shows it unfiltered, unless it shows already.
        if chip = "library" and barTabs().view = "library" then return true
        if chip = "library" then chip = "all"
        batchStop()
        m.chip = chip
        if m.chip = "playlists" then loadPlaylists()
        if m.chip = "collections" then netLoad("list", { op: "listCollections", params: {}, query: {} }, "onCollections")
        if m.chip = "stations" then loadStations()
        if rescoped() then load() else fill()
        return true
    end if
    return uiArrow(key)
end function
