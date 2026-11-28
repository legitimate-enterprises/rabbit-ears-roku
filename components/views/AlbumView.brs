' params.album is the MusicAlbum; its songs are loaded.
sub init()
    m.top.observeField("focusedChild", "uiRestore")
    m.global.music.observeFieldScoped("now", "onNow")
    m.page = m.top
    m.list = invalid
    m.controls = {}
    m.rings = {}
    m.layout = []
end sub

sub load()
    netLoad("album", { albumId: m.top.params.album.id, profileId: m.global.profileId }, "onAlbum")
end sub

sub onAlbum(event as object)
    r = event.getData()
    if not r.ok
        uiLabel(m.top, "Couldn't load this: " + r.message, 30, false, "dim", 96, 96)
        return
    end if
    a = r.data.album
    m.songs = r.data.songs
    facts = musicAlbumFacts(a)
    m.album = a
    uiArt(m.top, a, "poster", 96, 96, 360, 360, "", "album")
    title = uiLabel(m.top, a.title, 60, true, "text", 96, 476, 560)
    title.maxLines = 2
    y = 476 + Int(title.boundingRect().height) + 12
    fx = 96
    if a.artistName <> ""
        artist = uiLabel(m.top, a.artistName, 28, true, "accent", 96, y)
        fx = 96 + Int(artist.boundingRect().width) + 18
    end if
    parts = []
    for each f in facts
        parts.Push({ text: f })
    end for
    if a.lossless then parts.Push({ text: "Lossless", tag: true })
    uiFacts(m.top, parts, fx, y)
    m.controls.play = uiButton(m.top, "play", "Play", "p", 0, 0, true, "play")
    m.controls.shuffle = uiButton(m.top, "shuffle", "Shuffle", "s", 0, 0, true, "shuffle")
    m.favorite = r.data.favorite
    uiRow([m.controls.play, m.controls.shuffle, favoriteControl(m.top, true)], 96, y + 56, 20)
    if a.overview <> invalid
        l = uiLabel(m.top, a.overview, 26, false, "sub", 96, y + 160, 560)
        l.maxLines = 5
    end if
    m.list = songList(704, 196, 1128, 11)
    m.controls.songs = m.list
    nowChip()
    m.current = "play"
    onNow()
    if m.top.isInFocusChain() then uiFocus(m.current)
end sub

' The playing song's row and the chip follow the queue.
sub onNow()
    if uiDetached()
        m.global.music.unobserveFieldScoped("now")
        return
    end if
    if m.list = invalid then return
    at = m.list.itemFocused
    m.list.content = songRows(m.songs, true)
    if at > 0 then m.list.jumpToItem = at
    m.layout = [["play", "shuffle", "favorite", "songs"]]
    if m.global.music.now.song <> invalid
        m.layout = [["chip"], ["play", "shuffle", "favorite", "songs"]]
    else if m.current = "chip"
        m.current = "play"
        if m.top.isInFocusChain() then uiFocus("play")
    end if
end sub

sub onSong(event as object)
    playSongs(m.songs, event.getData(), m.album.title)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or m.list = invalid then return false
    if key = "OK" and m.current = "play"
        playSongs(m.songs, 0, m.album.title)
    else if key = "OK" and m.current = "shuffle" and m.songs.Count() > 0
        playSongs(m.songs, Rnd(m.songs.Count()) - 1, m.album.title, true)
    else if key = "OK" and m.current = "favorite"
        favoriteToggle("album", m.album.id)
    else if key = "OK" and m.current = "chip"
        openNowPlaying()
    else
        return uiArrow(key)
    end if
    return true
end function
