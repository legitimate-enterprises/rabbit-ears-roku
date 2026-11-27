' Music as the TV screens show and play it: the file details, the queue
' and the facts lines.

' The details panel's groups from a song session's audio object, [{ title,
' rows: [{ label, value, tone, tag }] }], a row left out when the server has
' no value for it and a group when it has no rows. tone is a uiColor name;
' tag is a chip drawn before the value, or "".
function musicDetails(audio as dynamic) as object
    if audio = invalid then return []
    s = audio.source
    d = audio.delivered
    source = []
    if s.codec <> invalid
        tag = ""
        if s.lossless <> invalid and s.lossless then tag = "Lossless"
        source.Push(musicDetailRow("Format", formatCodec(s.codec), "text", tag))
    end if
    if s.bitrate <> invalid then source.Push(musicDetailRow("Bitrate", musicKbps(s.bitrate)))
    if s.sampleRateHz <> invalid then source.Push(musicDetailRow("Sample rate", musicKhz(s.sampleRateHz)))
    if s.bitDepth <> invalid then source.Push(musicDetailRow("Bit depth", s.bitDepth.ToStr() + "-bit"))
    if s.channels <> invalid then source.Push(musicDetailRow("Channels", musicChannels(s.channels)))
    if s.sizeBytes <> invalid then source.Push(musicDetailRow("Size", musicMegabytes(s.sizeBytes)))
    tone = "accent"
    if d.verdict = "direct_play" or d.verdict = "remux" then tone = "ok"
    delivered = [musicDetailRow("Playback", qualityVerdict(d.verdict), tone), musicDetailRow("Codec", formatCodec(d.codec))]
    if d.bitrate <> invalid then delivered.Push(musicDetailRow("Bitrate", musicKbps(d.bitrate)))
    groups = []
    if source.Count() > 0 then groups.Push({ title: "Source", rows: source })
    groups.Push({ title: "Delivered", rows: delivered })
    return groups
end function

function musicDetailRow(label as string, value as string, tone = "text" as string, tag = "" as string) as object
    return { label: label, value: value, tone: tone, tag: tag }
end function

' 2,116 kb/s from bits per second.
function musicKbps(bps as dynamic) as string
    kbps = Int(bps / 1000 + 0.5)
    text = (kbps mod 1000).ToStr()
    if kbps < 1000 then return text + " kb/s"
    if Len(text) < 3 then text = string(3 - Len(text), "0") + text
    return (kbps \ 1000).ToStr() + "," + text + " kb/s"
end function

' 96 kHz, 44.1 kHz, 22.05 kHz, exact to the hertz.
function musicKhz(hz as integer) as string
    text = (hz \ 1000).ToStr()
    rest = hz mod 1000
    fraction = ""
    for i = 1 to 3
        if rest = 0 then exit for
        fraction = fraction + (rest \ 100).ToStr()
        rest = (rest mod 100) * 10
    end for
    if fraction <> "" then text = text + "." + fraction
    return text + " kHz"
end function

function musicChannels(n as integer) as string
    if n = 1 then return "Mono"
    if n = 2 then return "Stereo"
    return n.ToStr() + " channels"
end function

' 67.4 MB from bytes.
function musicMegabytes(bytes as dynamic) as string
    tenths = Int(bytes / 100000 + 0.5)
    return (tenths \ 10).ToStr() + "." + (tenths mod 10).ToStr() + " MB"
end function

' The Audio node's streamFormat for what the server delivers.
function musicStreamFormat(stream as object) as string
    if stream.streamKind = "hls" then return "hls"
    format = { flac: "flac", mp3: "mp3" }[apiText(stream.negotiated.audioCodec)]
    if format = invalid then return "mp4"
    return format
end function

' The queue index a step of 1 or -1 lands on: -1 past the end without
' repeat; previous on the first song restarts it.
function musicAdvance(index as integer, count as integer, repeat as boolean, stepBy as integer) as integer
    if count = 0 then return -1
    i = index + stepBy
    if i >= count
        if repeat then return 0
        return -1
    end if
    if i < 0
        if repeat then return count - 1
        return 0
    end if
    return i
end function

' What follows a song that would not play, from the failed reply r and the
' failures in a row with it: "hold" while the server cannot be reached,
' which stops the queue on the song for play to start it again; "skip" to
' the song at nextIndex; or "stop" at the third, or with no song after it.
function musicAfterFailure(r as object, failures as integer, nextIndex as integer) as string
    if r.code = "network" then return "hold"
    if failures < 3 and nextIndex >= 0 then return "skip"
    return "stop"
end function

' The queue with the playing song first and the rest in random order.
function musicShuffle(songs as object, index as integer) as object
    rest = []
    for i = 0 to songs.Count() - 1
        if i <> index then rest.Push(songs[i])
    end for
    out = [songs[index]]
    out.Append(musicDeal(rest))
    return out
end function

' The songs in random order; the argument is emptied.
function musicDeal(songs as object) as object
    out = []
    while songs.Count() > 0
        j = Rnd(songs.Count()) - 1
        out.Push(songs[j])
        songs.Delete(j)
    end while
    return out
end function

' Whether the next batch of a queue that grows as it plays loads now: more,
' the "list" load's args for it, is set, none is in flight, and playback is
' within a few songs of the end of what is queued.
function musicMoreDue(index as integer, count as integer, more as dynamic, loading as boolean) as boolean
    return more <> invalid and not loading and index >= count - 20
end function

' Adds a loaded batch to the end of the queue. ordered is the order the
' songs came in; queue is the same array until shuffle deals it, so only a
' shuffled queue takes the batch separately, dealt at random after the
' songs already queued: shuffle covers what is loaded and extends with each
' batch.
sub musicGrow(queue as object, ordered as object, shuffle as boolean, batch as object)
    ordered.Append(batch)
    if shuffle then queue.Append(musicDeal(batch))
end sub

' 2007, 10 songs, 42m: Album details' facts before the Lossless tag.
function musicAlbumFacts(album as object) as object
    facts = []
    if album.year <> invalid then facts.Push(album.year.ToStr())
    facts.Push(formatCountOf(album.songCount, "song"))
    if formatDuration(album.durationMs) <> "" then facts.Push(formatDuration(album.durationMs))
    return facts
end function

' 9 albums, 112 songs, Alternative rock.
function musicArtistFacts(artist as object) as object
    facts = [formatCountOf(artist.albumCount, "album"), formatCountOf(artist.songCount, "song")]
    if artist.genres <> invalid and artist.genres.Count() > 0 then facts.Push(artist.genres[0].name)
    return facts
end function

' A track list's number column: the track number, else the position.
function musicSongNumber(song as object, index as integer) as string
    if song.trackNumber <> invalid then return song.trackNumber.ToStr()
    return (index + 1).ToStr()
end function
