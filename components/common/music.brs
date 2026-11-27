' Shared by Music, Artist and Album: track lists, starting the queue and
' the now-playing chip.

' A MarkupList of SongItem rows; its content comes from songRows.
function songList(x as integer, y as integer, w as integer, rows as integer) as object
    list = m.page.CreateChild("MarkupList")
    list.itemComponentName = "SongItem"
    uiGridLayout(list, x, y, w, 72, 0, 6)
    list.numRows = rows
    list.vertFocusAnimationStyle = "floatingFocus"
    list.drawFocusFeedback = false
    list.observeFieldScoped("itemSelected", "onSong")
    m.listWidth = w
    return list
end function

' Rows for songs, numbered by track or by position, the playing one marked.
function songRows(songs as object, byTrack as boolean) as object
    playing = m.global.music.now.song
    content = CreateObject("roSGNode", "ContentNode")
    for i = 0 to songs.Count() - 1
        s = songs[i]
        c = content.CreateChild("ContentNode")
        c.title = s.title
        number = (i + 1).ToStr()
        if byTrack then number = musicSongNumber(s, i)
        duration = ""
        if s.durationMs <> invalid then duration = formatClock(Int(s.durationMs / 1000))
        c.addFields({ number: number, duration: duration, playing: playing <> invalid and playing.id = s.id, rowWidth: m.listWidth })
    end for
    return content
end function

' more, the "list" load's args for the songs after these, makes the queue grow
' as it plays; it is the whole list when those are the first of it.
sub playSongs(songs as object, index as integer, from as string, shuffle = false as boolean, playlistId = invalid as dynamic, more = invalid as dynamic)
    if songs.Count() = 0 then return
    m.global.music.command = { op: "play", songs: songs, index: index, from: from, shuffle: shuffle, playlistId: playlistId, more: more }
end sub

' The chip at the top right; m.layout gains a row for it while it shows.
function nowChip() as object
    chip = m.top.CreateChild("NowChip")
    chip.translation = [1824, 64]
    m.controls.chip = chip
    return chip
end function

sub openNowPlaying()
    m.top.navigate = { to: "details", view: "NowPlayingView" }
end sub
