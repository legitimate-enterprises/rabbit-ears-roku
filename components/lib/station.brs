' Stations as a TV shows them: the server decides what is on and when;
' these only word its answer and say when to ask again. Instants are UTC
' and read in the device's local time.

' Seconds since 1970 of a UTC instant, its fraction dropped.
function stationSeconds(iso as string) as integer
    d = CreateObject("roDateTime")
    d.FromISO8601String(Left(iso, 19) + "Z")
    return d.AsSeconds()
end function

function stationLocal(iso as string) as object
    d = CreateObject("roDateTime")
    d.FromSeconds(stationSeconds(iso))
    d.ToLocalTime()
    return d
end function

' 4:00 PM.
function stationClock(iso as string) as string
    d = stationLocal(iso)
    h = d.GetHours()
    half = "AM"
    if h >= 12 then half = "PM"
    h = h mod 12
    if h = 0 then h = 12
    return h.ToStr() + ":" + formatTwo(d.GetMinutes()) + " " + half
end function

' A tile's caption and the player's lines: On now and Next on air, Up next
' at its time between programs, Back off schedule. A music station's Next has
' no time.
function stationLines(kind as string, onAir as object) as object
    lines = []
    upcoming = onAir["next"]
    if onAir.status = "on_air" and onAir.now <> invalid then lines.Push("On now: " + playlistEntryTitle(onAir.now))
    if upcoming = invalid then return lines
    if onAir.status = "off_schedule"
        lines.Push("Back " + stationLocal(upcoming.startsAt).GetWeekday() + " at " + stationClock(upcoming.startsAt))
    else if onAir.status = "between_programs"
        lines.Push("Up next at " + stationClock(upcoming.startsAt) + ": " + playlistEntryTitle(upcoming))
    else if kind = "music"
        lines.Push("Next: " + playlistEntryTitle(upcoming))
    else
        lines.Push("Next: " + playlistEntryTitle(upcoming) + " at " + stationClock(upcoming.startsAt))
    end if
    return lines
end function

' The artwork a tile shows, of what is on else what is next, as { id,
' path }, id coloring its placeholder; invalid when neither, for the plain
' named tile.
function stationArt(onAir as object) as dynamic
    p = onAir.now
    if p = invalid then p = onAir["next"]
    if p = invalid then return invalid
    if p.song <> invalid then return { id: p.song.albumId, path: apiArtPath(p.song, "posterUrl", "getItemArtwork", { itemId: p.song.albumId, kind: "poster" }) }
    kind = "poster"
    if p.kind = "movie" then kind = "backdrop"
    return { id: p.itemId, path: apiArtPath(p.item, kind + "Url", "getItemArtwork", { itemId: p.itemId, kind: kind }) }
end function

' What a tune-in answer, { stream, onAir, resumesAt }, means at nowSeconds:
' play until the program ends, or wait between programs or off schedule
' for resumesAt. askIn is when to ask again, at least a second away so a
' slow device clock never asks in a loop, or -1 when nothing is scheduled.
function stationNext(kind as string, d as object, nowSeconds as integer) as object
    mode = d.onAir.status
    at = d.resumesAt
    if d.stream <> invalid
        mode = "on_air"
        at = d.onAir.now.endsAt
    else if mode <> "off_schedule"
        mode = "between_programs"
    end if
    askIn = -1
    if at <> invalid
        askIn = stationSeconds(at) - nowSeconds
        if askIn < 1 then askIn = 1
    end if
    ' Worded by mode: onAir read after a 409 may already show the next program on.
    shown = { status: mode, now: d.onAir.now }
    shown["next"] = d.onAir["next"]
    return { mode: mode, askIn: askIn, lines: stationLines(kind, shown) }
end function

' Seconds until a failed tune-in, r, is asked again: soon when the server
' failed or could not be reached; -1 for a refusal, which stands.
function stationRetryIn(r as object) as integer
    if r.status <= 0 or r.status >= 500 then return 5
    return -1
end function

' A music station's read-only Up next: the songs of upNext, in the order
' they play.
function stationUpNext(onAir as object) as object
    songs = []
    for each p in onAir.upNext
        if p.song <> invalid then songs.Push(p.song)
    end for
    return songs
end function

' Nobody pauses, seeks or skips a station.
function stationIgnores(key as string) as boolean
    return key = "play" or key = "rewind" or key = "fastforward" or key = "replay"
end function

' Home's On now tile names a station with its kind: Movies: Marvel.
function stationOnNowName(s as object) as string
    kinds = { movies: "Movies", tv: "TV", music: "Music" }
    return kinds[s.kind] + ": " + s.name
end function

' How far through the program on, 0 to 1, as the server answered; invalid
' with none on or no length.
function stationOnNowProgress(onAir as object) as dynamic
    if onAir.now = invalid or onAir.positionMs = invalid then return invalid
    length = onAir.now.durationMs
    if length = invalid or length <= 0 then return invalid
    done = onAir.positionMs / length
    if done > 1 then done = 1.0
    return done
end function
