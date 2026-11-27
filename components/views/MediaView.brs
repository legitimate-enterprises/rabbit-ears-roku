' params.kind is music or youtube. Sorting and filtering are the
' server's, so every chip, sort or filter change reloads the listing.
sub init()
    m.top.observeField("focusedChild", "onFocus")
    m.controls = {}
    m.rings = {}
    m.layout = []
    m.items = []
    m.total = invalid
    m.note = ""
    m.x = 96
    m.filter = invalid
    m.genres = []
    m.channels = []
    m.grid = invalid
    m.shape = ""
    m.chipNode = invalid
    m.keep = invalid
    m.sorts = { albums: "added", songs: "title", videos: "newest", unwatched: "newest", channels: "title" }
end sub

sub onParams()
    m.music = m.top.params.kind = "music"
    m.chip = uiPick(m.music, "albums", "videos")
    m.current = m.chip
    m.bar = m.top.CreateChild("Group")
    m.bar.translation = [0, 172]
    if m.music
        m.chipNode = nowChip()
        placeChip()
        m.global.music.observeFieldScoped("now", "onNow")
        m.global.observeFieldScoped("stationVersion", "onListingVersion")
        m.global.observeFieldScoped("playlistVersion", "onListingVersion")
        nowRow()
    else
        ' Unwatched dots follow playback.
        m.global.observeFieldScoped("stateVersion", "onStateVersion")
        drawBar()
    end if
    load()
end sub

sub placeChip()
    if m.chipNode <> invalid then m.chipNode.translation = [m.top.chipRight, 44]
end sub

' The chip takes a row above the bar while something plays.
sub onNow()
    if uiDetached() then m.global.music.unobserveFieldScoped("now") else nowRow()
end sub

sub nowRow()
    m.above = invalid
    if m.global.music.now.song <> invalid
        m.above = [["chip"]]
    else if m.current = "chip"
        m.current = m.chip
    end if
    drawBar()
end sub

' The stations or playlists showing load again as the server says they
' changed, keeping their place.
sub onListingVersion(event as object)
    if uiDetached()
        m.global.unobserveFieldScoped(event.getField())
    else if m.grid <> invalid and event.getField() = { stations: "stationVersion", playlists: "playlistVersion" }[m.chip]
        m.keep = m.grid.itemFocused
        load()
    end if
end sub

sub onStateVersion()
    if uiDetached() then m.global.unobserveFieldScoped("stateVersion") else load()
end sub

sub load()
    batchStop()
    args = { kind: m.top.params.kind, chip: m.chip, sort: m.sorts[m.chip], profileId: m.global.profileId, genres: m.genres.Count() = 0 }
    if m.filter <> invalid then args.filterId = m.filter.id
    netLoad("media", args, "onMedia")
end sub

sub onMedia(event as object)
    r = event.getData()
    if not r.ok
        m.items = []
        m.note = "Couldn't load: " + r.message
        drawBar()
        return
    end if
    if r.data.genres.Count() > 0 then m.genres = r.data.genres
    m.channels = r.data.channels
    m.items = r.data.items
    m.total = r.data.total
    fill(r.data.rest)
end sub

function barTabs() as object
    adult = false
    for each p in m.global.me.profiles
        if p.id = m.global.profileId and p.kind = "adult" then adult = true
    end for
    return libraryBar(m.top.params.kind, adult, m.chip)
end function

' Each chip's sorts as [value, name], first the default; [] for none.
function sortsOf(chip as string) as object
    videos = [["newest", "Newest"], ["oldest", "Oldest"], ["title", "Title"], ["channel", "Channel"], ["length", "Length"]]
    sorts = {
        albums: [["added", "Recently added"], ["title", "Title"], ["artist", "Artist"], ["year", "Year"]]
        songs: [["title", "Title"], ["artist", "Artist"], ["album", "Album"], ["added", "Recently added"], ["popular", "Popular"]]
        videos: videos
        unwatched: videos
        channels: [["title", "Title"], ["latest", "Latest"]]
    }[chip]
    if sorts = invalid then return []
    return sorts
end function

' Genre filters Music and Channel filters YouTube, but neither filters
' playlists, stations or channels.
function filters() as object
    if m.chip = "playlists" or m.chip = "stations" then return []
    if m.music then return m.genres
    if m.chip <> "channels" then return m.channels
    return []
end function

function barSelects() as object
    selects = []
    for each s in sortsOf(m.chip)
        if s[0] = m.sorts[m.chip] then selects.Push({ id: "sort", text: "Sort  " + s[1] })
    end for
    if filters().Count() > 0
        name = "Any"
        if m.filter <> invalid then name = m.filter.name
        selects.Push({ id: "filter", text: uiPick(m.music, "Genre  ", "Channel  ") + name })
    end if
    return selects
end function

' Artists and channels are round, albums, songs, music playlists and
' stations square, videos wide.
function shapeOf(chip as string) as string
    if chip = "artists" or chip = "channels" then return "round"
    if m.music then return "square"
    return "wide"
end function

sub makeGrid(shape as string)
    if m.grid <> invalid then m.top.removeChild(m.grid)
    m.shape = shape
    columns = 7
    if shape = "wide" then columns = 4
    m.width = (1920 - 2 * m.x - (columns - 1) * 28) \ columns
    m.artHeight = m.width
    if shape = "wide" then m.artHeight = Int(m.width * 9 / 16)
    m.grid = m.top.CreateChild("MarkupGrid")
    m.grid.itemComponentName = "TileItem"
    m.grid.numColumns = columns
    m.grid.numRows = 2
    ' Station tiles have a second caption line.
    uiGridLayout(m.grid, m.x, 260 + barRowY(), m.width, m.artHeight + 112, 28, 36)
    ' Focus stays on the top row, whole on screen, with the next row peeking
    ' below; the last row too comes up to the top.
    m.grid.vertFocusAnimationStyle = "fixedFocus"
    m.grid.drawFocusFeedback = false
    m.grid.observeFieldScoped("itemSelected", "onPick")
    m.controls.grid = m.grid
end sub

sub fill(rest as dynamic)
    if shapeOf(m.chip) <> m.shape then makeGrid(shapeOf(m.chip))
    batchStart(m.grid, rest)
    root = CreateObject("roSGNode", "ContentNode")
    addTiles(root, m.items)
    m.grid.content = root
    if m.keep <> invalid and m.keep > 0 and m.keep < m.items.Count() then m.grid.jumpToItem = m.keep
    m.keep = invalid
    countNote()
end sub

sub batchRows(rows as object)
    m.items.Append(rows)
    addTiles(m.grid.content, rows)
    countNote()
end sub

sub countNote()
    noun = { albums: "album", artists: "artist", playlists: "playlist", songs: "song", stations: "station", videos: "video", unwatched: "video", channels: "channel" }[m.chip]
    m.note = formatCountOfTotal(m.total, m.items.Count(), noun, batchMore())
    drawBar()
end sub

sub addTiles(root as object, rows as object)
    today = formatToday()
    if m.chip = "stations"
        for each x in rows
            root.appendChild(stationTile(x, m.width, m.artHeight))
        end for
        return
    end if
    for each x in rows
        t = { title: x.title, caption: "", artId: x.id, badge: "" }
        if m.chip = "albums" or m.chip = "songs" then t.caption = x.artistName
        if m.chip = "songs" then t.artId = x.albumId
        if m.chip = "artists" then t = { title: x.name, caption: formatCountOf(x.albumCount, "album"), artId: x.id, badge: "" }
        if m.chip = "channels" then t.caption = formatCountOf(x.videoCount, "video")
        if m.chip = "playlists" then t = { title: x.name, caption: playlistCaption(x), artId: x.artItemId, badge: "" }
        if m.chip = "videos" or m.chip = "unwatched"
            t.caption = formatVideoCaption(x, today, true)
            if not x.watched then t.badge = "dot"
        end if
        c = root.CreateChild("ContentNode")
        c.title = t.title
        c.shortDescriptionLine1 = t.caption
        ' A playlist with no art keeps its placeholder block.
        c.hdPosterUrl = ""
        colorId = x.id
        if m.chip = "playlists" and x.imageUrl <> invalid
            c.hdPosterUrl = m.global.server + x.imageUrl
        else if t.artId <> invalid
            c.hdPosterUrl = uiArtUrl(t.artId, "poster")
            colorId = t.artId
        end if
        c.addFields({ itemId: colorId, artWidth: m.width, artHeight: m.artHeight, badge: t.badge, glyph: m.chip, round: shapeOf(m.chip) = "round", shared: m.chip = "playlists" and x.shared })
    end for
end sub

sub onFocus()
    uiBlur()
    if m.top.hasFocus() and m.current <> invalid then uiFocus(m.current)
end sub

sub onPick(event as object)
    i = event.getData()
    x = m.items[i]
    views = { albums: ["AlbumView", "album"], artists: ["ArtistView", "artist"], videos: ["VideoView", "video"], unwatched: ["VideoView", "video"], channels: ["ChannelView", "channel"] }
    views.playlists = ["PlaylistView", "list"]
    v = views[m.chip]
    if v <> invalid
        n = { to: "details", view: v[0] }
        n[v[1]] = x
        m.top.navigate = n
    else if m.chip = "songs"
        ' A copy: the player appends the rows it loads as the queue plays.
        songs = []
        songs.Append(m.items)
        more = invalid
        if batchMore() then more = m.batch.rest
        playSongs(songs, i, "Songs", false, invalid, more)
    else if m.chip = "stations"
        stationTuneIn(x)
    end if
end sub

sub openSorts()
    m.options = []
    for each s in sortsOf(m.chip)
        m.options.Push({ label: s[1], sort: s[0], checked: s[0] = m.sorts[m.chip], disabled: false })
    end for
    openMenu("onSort")
end sub

sub onSort(event as object)
    m.sorts[m.chip] = m.options[event.getData()].sort
    closeMenu()
    load()
end sub

sub openFilters()
    m.options = [{ label: "Any", checked: m.filter = invalid, disabled: false }]
    for each f in filters()
        name = f.name
        if name = invalid then name = f.title
        m.options.Push({ label: name, filter: { id: f.id, name: name }, checked: m.filter <> invalid and m.filter.id = f.id, disabled: false })
    end for
    openMenu("onFilter")
end sub

sub onFilter(event as object)
    m.filter = m.options[event.getData()].filter
    closeMenu()
    load()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "OK" and m.current = "sort"
        openSorts()
    else if key = "OK" and m.current = "filter"
        openFilters()
    else if key = "OK" and m.current = "chip"
        openNowPlaying()
    else if key = "OK" and m.current <> "grid"
        ' Unwatched, the one filter of videos, turns off as it turns on.
        if m.current = "unwatched" and m.chip = "unwatched" then m.chip = "videos" else m.chip = m.current
        m.items = []
        m.note = ""
        if m.grid <> invalid then m.grid.content = invalid
        drawBar()
        load()
    else
        return uiArrow(key)
    end if
    return true
end function
