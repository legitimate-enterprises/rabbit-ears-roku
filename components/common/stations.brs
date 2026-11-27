' Station tiles and tuning in, shared by Home, the library grids and Music.
' A tile tunes in; TVs have no station page.

' The art of what is on, else of what is next, else the plain tile with
' the station's name; captioned by stationLines.
function stationTile(s as object, w as integer, h as integer, homeRow = false as boolean) as object
    c = CreateObject("roSGNode", "ContentNode")
    c.title = s.name
    if homeRow then c.title = stationOnNowName(s)
    lines = stationLines(s.kind, s.onAir)
    if lines.Count() > 0 then c.shortDescriptionLine1 = lines[0]
    if lines.Count() > 1 then c.shortDescriptionLine2 = lines[1]
    art = stationArt(s.onAir)
    colorId = s.id
    if s.imageUrl <> invalid
        c.hdPosterUrl = m.global.server + s.imageUrl
    else if art <> invalid
        c.hdPosterUrl = uiArtUrl(art.id, art.kind)
        colorId = art.id
    end if
    c.addFields({ itemId: colorId, artWidth: w, artHeight: h, badge: "", plain: c.hdPosterUrl = "", glyph: s.kind })
    ' Home's On now plays when selected, and shows how far through the program it is.
    if homeRow
        c.addFields({ plays: true })
        done = stationOnNowProgress(s.onAir)
        if done <> invalid then c.addFields({ progress: done })
    end if
    return c
end function

' A video station plays in the player; a music one in the music player,
' shown on Now playing.
sub stationTuneIn(s as object)
    if s.kind = "music"
        m.global.music.command = { op: "station", station: s }
        m.top.navigate = { to: "details", view: "NowPlayingView" }
    else
        m.top.navigate = { to: "player", station: s }
    end if
end sub
