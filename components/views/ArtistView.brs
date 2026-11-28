' params.artist is the MusicArtist; Popular and the albums are loaded.
' Play and Shuffle take every song of the artist, album by album.
sub init()
    m.top.observeField("focusedChild", "uiRestore")
    m.global.music.observeFieldScoped("now", "onNow")
    m.list = invalid
    m.shuffle = false
    m.controls = {}
    m.rings = {}
    m.layout = []
end sub

sub load()
    netLoad("artist", { artistId: m.top.params.artist.id }, "onArtist")
end sub

sub onArtist(event as object)
    r = event.getData()
    if not r.ok
        uiLabel(m.top, "Couldn't load this: " + r.message, 30, false, "dim", 96, 96)
        return
    end if
    a = r.data.artist
    m.artist = a
    m.popular = r.data.popular
    m.albums = r.data.albums
    m.page = m.top.CreateChild("Group")
    uiRound(m.page, a.id, 96, 96, 360, "artist", uiArtUrl(a, "poster"))
    uiLabel(m.page, a.name, 76, true, "text", 512, 90)
    parts = []
    for each f in musicArtistFacts(a)
        parts.Push({ text: f })
    end for
    uiFacts(m.page, parts, 512, 190)
    m.controls.play = uiButton(m.page, "play", "Play", "p", 0, 0, false, "play")
    m.controls.shuffle = uiButton(m.page, "shuffle", "Shuffle", "s", 0, 0, false, "shuffle")
    uiRow([m.controls.play, m.controls.shuffle], 512, 250, 20)
    m.rows = [["play", "shuffle"]]
    y = 360
    if a.overview <> invalid
        l = uiLabel(m.page, a.overview, 28, false, "sub", 512, y, 1100)
        l.maxLines = 2
        y = y + Int(l.boundingRect().height) + 34
    end if
    if m.popular.Count() > 0
        uiLabel(m.page, "Popular", 30, true, "text", 512, y)
        m.list = songList(512, y + 44, 1100, 5)
        m.controls.songs = m.list
        m.rows.Push(["songs"])
    end if
    if m.albums.Count() > 0 then albumRow()
    nowChip()
    m.current = "play"
    onNow()
    if m.top.isInFocusChain() then uiFocus(m.current)
end sub

' The albums, newest first, in one row along the bottom; the page rises
' to show it while it has focus.
sub albumRow()
    uiLabel(m.page, "Albums", 30, true, "text", 96, 890)
    content = CreateObject("roSGNode", "ContentNode")
    row = content.CreateChild("ContentNode")
    for each album in m.albums
        c = row.CreateChild("ContentNode")
        c.title = album.title
        caption = ""
        if album.year <> invalid then caption = album.year.ToStr()
        c.shortDescriptionLine1 = caption
        c.hdPosterUrl = uiArtUrl(album, "poster")
        c.addFields({ itemId: album.id, artWidth: 200, artHeight: 200, badge: "", glyph: "album" })
    end for
    rows = m.page.CreateChild("RowList")
    rows.itemComponentName = "TileItem"
    rows.numRows = 1
    rows.itemSize = [1824, 290]
    rows.rowItemSize = uiRowSizes([[200, 280]])
    uiRowsAt(rows, 96, 946)
    rows.showRowLabel = [false]
    rows.rowFocusAnimationStyle = "floatingFocus"
    rows.drawFocusFeedback = false
    rows.content = content
    rows.observeFieldScoped("rowItemSelected", "onAlbum")
    m.controls.albums = rows
    m.rows.Push(["albums"])
end sub

sub onNow()
    if uiDetached()
        m.global.music.unobserveFieldScoped("now")
        return
    end if
    if m.page = invalid then return
    if m.list <> invalid
        at = m.list.itemFocused
        m.list.content = songRows(m.popular, false)
        if at > 0 then m.list.jumpToItem = at
    end if
    m.layout = []
    if m.global.music.now.song <> invalid
        m.layout.Push(["chip"])
    else if m.current = "chip"
        m.current = "play"
        if m.top.isInFocusChain() then uiFocus("play")
    end if
    m.layout.Append(m.rows)
end sub

sub onSong(event as object)
    playSongs(m.popular, event.getData(), m.artist.name)
end sub

sub onAlbum(event as object)
    m.top.navigate = { to: "details", view: "AlbumView", album: m.albums[event.getData()[1]] }
end sub

sub onAllSongs(event as object)
    r = event.getData()
    if not r.ok or r.data.Count() = 0 then return
    start = 0
    if m.shuffle then start = Rnd(r.data.Count()) - 1
    playSongs(r.data, start, m.artist.name, m.shuffle)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or m.page = invalid then return false
    if key = "OK" and (m.current = "play" or m.current = "shuffle")
        m.shuffle = m.current = "shuffle"
        netLoad("rest", { op: "listMusicSongs", params: {}, query: { artistId: m.artist.id, sort: "album" }, offset: 0 }, "onAllSongs")
        return true
    end if
    if key = "OK" and m.current = "chip"
        openNowPlaying()
        return true
    end if
    moved = uiArrow(key)
    y = 0
    if m.current = "albums" then y = -420
    m.page.translation = [0, y]
    return moved
end function
