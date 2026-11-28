sub init()
    m.top.focusable = true
    m.top.observeField("focusedChild", "onFocus")
    m.global.music.observeFieldScoped("now", "onNow")
    draw()
end sub

sub onNow()
    if uiDetached()
        m.global.music.unobserveFieldScoped("now")
        return
    end if
    draw()
end sub

' Empty and zero wide while nothing plays.
sub draw()
    uiClear(m.top)
    m.ring = invalid
    song = m.global.music.now.song
    if song = invalid then return
    g = m.top.CreateChild("Group")
    shape = uiShape(g, 14, 0, 0, 0, 64, uiColor("raised"))
    uiArt(g, { id: song.albumId }, "poster", 8, 8, 48, 48, uiArtUrl(song, "poster", song.albumId), "album")
    uiImage(g, "bars.png", 72, 19, 26, 26, uiColor("accent"))
    l = uiLabel(g, song.title, 26, true, "text", 108, 0)
    l.height = 64
    l.vertAlign = "center"
    w = 108 + l.boundingRect().width + 18
    if w > 560
        w = 560
        l.width = 560 - 126
    end if
    shape.width = w
    g.translation = [-w, 0]
    m.ring = uiRing(g, 0, 0, w, 64)
    onFocus()
end sub

sub onFocus()
    if m.ring <> invalid then m.ring.visible = m.top.hasFocus()
end sub
