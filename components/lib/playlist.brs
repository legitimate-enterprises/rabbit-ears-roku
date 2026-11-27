' A profile's playlists and those shared with it as the TV plays them; TVs
' never edit them.

' 48 songs, 12 episodes, 3 movies: what the play order holds, and whose it
' is when someone else's.
function playlistCaption(p as object) as string
    noun = { music: "song", tv: "episode", movies: "movie" }[p.kind]
    text = formatCountOf(p.itemCount, noun)
    if p.access <> invalid and p.access <> "owner" and p.ownerName <> invalid then text = text + " · Shared by " + p.ownerName
    return text
end function

' 3 movies: what a collection holds for this profile.
function collectionCaption(c as object) as string
    return formatCountOf(c.movieCount, "movie")
end function

' Whether the household put the collection's movies in its own order; the
' server lists them in it, so a TV only marks it.
function collectionOrdered(c as object) as boolean
    return c.customOrder <> invalid and c.customOrder
end function

' A collection's movie row: 2h 46m · 2024.
function collectionMovieCaption(item as object) as string
    parts = []
    if item.metadata <> invalid then parts.Push(formatRuntime(item.metadata.runtimeMinutes))
    parts.Push(formatYear(item))
    return formatParts(parts)
end function

function playlistEntryTitle(e as object) as string
    if e.collection <> invalid then return e.collection.name
    if e.artist <> invalid then return e.artist.name
    if e.album <> invalid then return e.album.title
    if e.song <> invalid then return e.song.title
    title = itemTitle(e.item)
    if e.editionName <> invalid then title = title + " · " + e.editionName
    return title
end function

' A container says what it stands for; a single thing gives its facts.
function playlistEntryCaption(e as object) as string
    parts = []
    runtime = formatDuration(e.durationMs)
    noun = { show: "episode", season: "episode", artist: "song", album: "song", collection: "movie" }[e.kind]
    if noun <> invalid
        parts = [formatCountOf(e.itemCount, noun), runtime]
    else if e.kind = "song"
        parts = [e.song.artistName, formatClock(Int(e.durationMs / 1000))]
    else if e.kind = "episode"
        if e.show <> invalid then parts.Push(itemTitle(e.show))
        parts.Push(formatEpisodeCode(e.item))
        parts.Push(runtime)
    else
        parts = [formatYear(e.item), runtime]
    end if
    return formatParts(parts)
end function

' A collection entry has no itemId; its own id only colors the placeholder.
function playlistEntryArtId(e as object) as integer
    if e.collectionId <> invalid then return e.collectionId
    if e.song <> invalid then return e.song.albumId
    return e.itemId
end function

' What the play order plays, an item or a song per row carrying the row's
' editionId, and where an entry's first row sits among them; an unknown or
' absent entry starts at the top.
function playOrderFrom(rows as object, entryId as dynamic) as object
    playables = []
    index = invalid
    for each r in rows
        p = r.item
        if r.kind = "song" then p = r.song
        if p <> invalid
            if r.editionId <> invalid then p.AddReplace("editionId", r.editionId)
            if index = invalid and entryId <> invalid and r.entryId = entryId then index = playables.Count()
            playables.Push(p)
        end if
    end for
    if index = invalid then index = 0
    return { playables: playables, index: index }
end function
