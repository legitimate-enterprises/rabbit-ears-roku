' What the browse screens show, from items and the profile's watch state.

function libraryInProgress(state as dynamic) as boolean
    return state <> invalid and state.positionMs > 0
end function

' In minutes; invalid when unknown, as a video without a probed duration.
function libraryRuntimeOf(e as object) as dynamic
    if e.video
        if e.item.durationMs = invalid then return invalid
        return Int(e.item.durationMs / 60000)
    end if
    if e.item.metadata <> invalid then return e.item.metadata.runtimeMinutes
    return invalid
end function

' S2 E4 · Woe's Hollow · 23m left in progress; a next episode not yet
' started reads S4 E1 · 49m, a video Channel · 12m left.
function libraryProgressLine(e as object) as string
    runtime = libraryRuntimeOf(e)
    if e.video
        left = formatLeft(runtime, e.state.positionMs)
        if left = "" then return e.item.channelTitle
        return e.item.channelTitle + " · " + left
    end if
    if not libraryInProgress(e.state)
        line = formatEpisodeCode(e.item)
        if formatRuntime(runtime) <> "" then line = line + " · " + formatRuntime(runtime)
        return line
    end if
    left = formatLeft(runtime, e.state.positionMs)
    if e.item.kind <> "episode" then return left
    line = formatEpisodeCode(e.item) + " · " + itemTitle(e.item)
    if left <> "" then line = line + " · " + left
    return line
end function

' Index of the episode to resume or play next: the one in progress after
' the latest played, else the first unwatched after it; -1 when every
' episode after it is watched. states is keyed by item id.
function libraryNextEpisode(episodes as object, states as object) as integer
    last = -1
    lastAt = ""
    for i = 0 to episodes.Count() - 1
        w = states[episodes[i].id.ToStr()]
        if w <> invalid and (w.watched or libraryInProgress(w)) and w.lastPlayedAt <> invalid and w.lastPlayedAt > lastAt
            last = i
            lastAt = w.lastPlayedAt
        end if
    end for
    if last >= 0 and libraryInProgress(states[episodes[last].id.ToStr()]) then return last
    for i = last + 1 to episodes.Count() - 1
        w = states[episodes[i].id.ToStr()]
        if w = invalid or not w.watched then return i
    end for
    return -1
end function

' The episode after itemId among its season's episodes, in order; invalid
' after the season finale.
function libraryEpisodeAfter(siblings as object, itemId as string) as dynamic
    for i = 0 to siblings.Count() - 2
        if siblings[i].id = itemId then return siblings[i + 1]
    end for
    return invalid
end function

' The season whose first episode follows a finale of seasonNumber: the
' lowest numbered after it, never the specials, season 0; invalid after the
' series finale.
function libraryNextSeason(seasons as object, seasonNumber as integer) as dynamic
    pick = invalid
    for each s in seasons
        if s.seasonNumber > seasonNumber and s.seasonNumber > 0 and (pick = invalid or s.seasonNumber < pick.seasonNumber) then pick = s
    end for
    return pick
end function

' Home's candidates, most recently played first: each state in progress,
' each YouTube video in progress and each played show's next episode
' unless that is in progress, as { itemId, state, showId, video }. state is
' invalid for an unplayed episode; showId is set for an episode that is
' some show's next; video is the YouTube video, which is its own state.
' progress is ShowProgress keyed by show id.
function libraryHomeQueue(states as object, progress as object, videos = [] as object) as object
    byId = {}
    for each w in states
        byId[w.itemId.ToStr()] = w
    end for
    showOf = {}
    queue = []
    taken = {}
    for each v in videos
        if libraryInProgress(v)
            ' A video's own watch state is in states too; the video stands for it.
            taken[v.id.ToStr()] = true
            at = ""
            if v.lastPlayedAt <> invalid then at = v.lastPlayedAt
            queue.Push({ itemId: v.id, state: v, video: v, at: at })
        end if
    end for
    for each key in progress
        p = progress[key]
        if p.nextEpisodeId <> invalid
            showOf[p.nextEpisodeId.ToStr()] = p.showId
            w = byId[p.nextEpisodeId.ToStr()]
            if p.lastPlayedAt <> invalid and not libraryInProgress(w) then queue.Push({ itemId: p.nextEpisodeId, state: w, showId: p.showId, at: p.lastPlayedAt })
        end if
    end for
    for each w in states
        if libraryInProgress(w) and not taken.DoesExist(w.itemId.ToStr())
            at = ""
            if w.lastPlayedAt <> invalid then at = w.lastPlayedAt
            queue.Push({ itemId: w.itemId, state: w, showId: showOf[w.itemId.ToStr()], at: at })
        end if
    end for
    queue.SortBy("at", "r")
    return queue
end function

' Home: the hero is the latest title or video in progress and absent when
' none is; Also in progress a dozen of the other ones in progress, Next up a
' dozen of the next episodes not started, and Recently added the newest
' movies and shows. items, keyed by item id, resolves the queue; an entry without one
' counts for nothing. Entries are { item, state, showId, video }, video
' true when item is a YouTube video.
function libraryHome(states as object, items as object, titles as object, progress as object, videos = [] as object) as object
    home = { hero: invalid, also: [], nextUp: [], recent: librarySort(titles, "added") }
    for each q in libraryHomeQueue(states, progress, videos)
        item = items[q.itemId.ToStr()]
        if item <> invalid
            e = { item: item, state: q.state, showId: q.showId, video: q.video <> invalid }
            if home.hero = invalid and libraryInProgress(q.state)
                home.hero = e
            else if libraryInProgress(q.state)
                if home.also.Count() < 12 then home.also.Push(e)
            else if home.nextUp.Count() < 12
                home.nextUp.Push(e)
            end if
        end if
    end for
    return home
end function

' Home's occasion rows: each active occasion, in the server's order, with the
' titles listed for it; one with no title has no row. The row's title is the
' occasion's headline when it has one, else its name, which the occasion's
' own screen keeps.
function libraryHomeOccasions(active as object, lists as object) as object
    rows = []
    for i = 0 to active.Count() - 1
        if lists[i].Count() > 0
            title = active[i].name
            h = active[i].headline
            if h <> invalid and GetInterface(h, "ifString") <> invalid and h.Trim() <> "" then title = h
            rows.Push({ title: title, name: active[i].name, occasion: active[i], items: lists[i] })
        end if
    end for
    return rows
end function

' A details page's occasion rows, as libraryRelated's shelves: each active
' occasion's titles but itemId, titled with the occasion's name; one left
' with no title has no row.
function libraryOccasionRelated(active as object, lists as object, itemId as string) as object
    rows = []
    for i = 0 to active.Count() - 1
        items = []
        for each t in lists[i]
            if t.id <> itemId then items.Push(t)
        end for
        if items.Count() > 0 then rows.Push({ collection: { name: active[i].name }, items: items })
    end for
    return rows
end function

' An occasion's wash colors as Poster blend colors, 0xRRGGBBFF, from the
' server's #RRGGBB; none unless there are exactly three valid ones.
function libraryWashColors(colors as dynamic) as object
    if colors = invalid or colors.Count() <> 3 then return []
    out = []
    for each c in colors
        if GetInterface(c, "ifString") = invalid or Len(c) <> 7 or Left(c, 1) <> "#" then return []
        for i = 2 to 7
            if Instr(1, "0123456789abcdef", LCase(Mid(c, i, 1))) = 0 then return []
        end for
        out.Push("0x" + UCase(Mid(c, 2)) + "FF")
    end for
    return out
end function

' Whether the home load, as ApiTask's loadHome answers it, has no row and
' no hero to show.
function libraryHomeEmpty(home as object) as boolean
    if home.hero <> invalid then return false
    for each k in ["onNow", "also", "nextUp", "occasions", "recent", "videos"]
        if home[k].Count() > 0 then return false
    end for
    return true
end function

function librarySorts() as object
    return ["added", "title", "watched", "year"]
end function

' A grid's remembered sort, while the grid still offers it; else "added".
function libraryStoredSort(stored as string) as string
    for each s in librarySorts()
        if s = stored then return s
    end for
    return "added"
end function

' The web grid's sorts: "added" newest first, "title" A to Z, "watched"
' most recently played first by libraryStanding, and "year" newest first by
' parsed year. Unplayed and undated items go last.
function librarySort(items as object, by as string, states = {} as object, progress = {} as object) as object
    list = []
    for each i in items
        key = LCase(itemTitle(i))
        if by = "added" then key = i.addedAt
        if by = "year"
            key = 0
            if i.parsedYear <> invalid then key = i.parsedYear
        end if
        if by = "watched" then key = libraryStanding(i, states, progress).lastPlayedAt
        list.Push({ key: key, item: i })
    end for
    if by = "title"
        list.SortBy("key")
    else
        list.SortBy("key", "r")
    end if
    out = []
    for each e in list
        out.Push(e.item)
    end for
    return out
end function

' How many of the ids the profile has not watched: a show's "N new".
function libraryUnwatched(ids as object, states as object) as integer
    n = 0
    for each id in ids
        w = states[id.ToStr()]
        if w = invalid or not w.watched then n = n + 1
    end for
    return n
end function

' What the grid reads of an item: a movie's own state or a show's
' ShowProgress, from progress keyed by show id, as { unwatched, inProgress,
' lastPlayedAt }. unwatched counts episodes, or 1 for an unwatched movie;
' lastPlayedAt is "" when nothing was played. A show without progress
' counts for nothing.
function libraryStanding(item as object, states as object, progress as object) as object
    out = { unwatched: 0, inProgress: false, lastPlayedAt: "" }
    if item.kind = "show"
        p = progress[item.id.ToStr()]
        if p = invalid then return out
        out.unwatched = p.unwatched
        out.inProgress = p.inProgress
    else
        p = states[item.id.ToStr()]
        out.inProgress = libraryInProgress(p)
        if p = invalid or not p.watched then out.unwatched = 1
        if p = invalid then return out
    end if
    if p.lastPlayedAt <> invalid then out.lastPlayedAt = p.lastPlayedAt
    return out
end function

' The browse tabs: Home and Search always, and each of TV, Movies, Music and
' YouTube when kinds, the kinds of the server's libraries, has its own; every
' one while kinds is invalid, as before the server has answered.
function libraryTabs(kinds as dynamic) as object
    tabs = ["Home"]
    for each t in [["TV", "tv"], ["Movies", "movies"], ["Music", "music"], ["YouTube", "youtube"]]
        if kinds = invalid or libraryHasKind(kinds, t[1]) then tabs.Push(t[0])
    end for
    tabs.Push("Search")
    return tabs
end function

function libraryHasKind(kinds as object, kind as string) as boolean
    for each k in kinds
        if k = kind then return true
    end for
    return false
end function

' A browse screen's view tabs, the id of the one chip shows, and the filter
' chips on it, as [{ id, text }]: screen is movie, show, music or youtube,
' and a filter chip's view is the first. Kids is an adult's shortcut, as a
' kid's library is already filtered; a kid's Playlists holds those shared
' with them. Stations keeps the grid's filters, which choose the library
' again.
function libraryBar(screen as string, adult as boolean, chip as string) as object
    chips = [{ id: "all", text: "All" }, { id: "unwatched", text: "Unwatched" }, { id: "progress", text: "In progress" }]
    if adult then chips.Push({ id: "kids", text: "Kids" })
    if screen = "music"
        views = [{ id: "albums", text: "Albums" }, { id: "artists", text: "Artists" }, { id: "songs", text: "Songs" }]
        views.Push({ id: "playlists", text: "Playlists" })
        views.Push({ id: "stations", text: "Stations" })
        chips = []
    else if screen = "youtube"
        views = [{ id: "videos", text: "Videos" }, { id: "channels", text: "Channels" }]
        chips = [{ id: "unwatched", text: "Unwatched" }]
    else
        views = [{ id: "library", text: { movie: "Movies", show: "Shows" }[screen] }]
        if screen = "movie" then views.Push({ id: "collections", text: "Collections" })
        views.Push({ id: "playlists", text: "Playlists" })
        views.Push({ id: "stations", text: "Stations" })
    end if
    view = chip
    for each f in chips
        if f.id = chip then view = views[0].id
    end for
    if view <> views[0].id and view <> "stations" then chips = []
    return { views: views, view: view, chips: chips }
end function

' The grid's chips: "all", "unwatched", "progress" or "kids". Kids keeps what
' the server marks kidsContent, a title's override or its rating.
function libraryFilter(items as object, chip as string, states as object, progress as object) as object
    out = []
    for each item in items
        keep = (chip = "all")
        if chip = "unwatched" then keep = libraryStanding(item, states, progress).unwatched > 0
        if chip = "progress" then keep = libraryStanding(item, states, progress).inProgress
        if chip = "kids" then keep = item.kidsContent = true
        if keep then out.Push(item)
    end for
    return out
end function

' Whether the Kids chip loads its titles from the server: an adult who hides
' kids' content has none in the unfiltered listing.
function libraryKidsOnly(chip as string, hides as boolean) as boolean
    return chip = "kids" and hides
end function

' Whether the profile is an adult who hides kids' content.
function libraryHides(profiles as object, profileId as string) as boolean
    for each p in profiles
        if p.id = profileId then return p.kind = "adult" and p.hideKidsContent = true
    end for
    return false
end function

' The edition with this id, else the default; invalid without editions.
function libraryEdition(editions as dynamic, id as dynamic) as dynamic
    if editions = invalid or editions.Count() = 0 then return invalid
    found = editions[0]
    for each e in editions
        if id <> invalid and e.id = id then return e
        if e.isDefault and not found.isDefault then found = e
    end for
    return found
end function

' The edition the saved position belongs to, else the default.
function libraryPreselectedEdition(editions as dynamic, state as dynamic) as dynamic
    id = invalid
    if libraryInProgress(state) then id = state.editionId
    return libraryEdition(editions, id)
end function

' Resume is offered only on the edition the position belongs to; a
' position naming none belongs to the default. Without a chosen edition
' it is the title's own progress.
function libraryResumes(state as dynamic, edition as dynamic) as boolean
    if not libraryInProgress(state) then return false
    if edition = invalid then return true
    if state.editionId = invalid then return edition.isDefault
    return state.editionId = edition.id
end function

' A resume bar's fill, 0 to 1, for e as libraryRuntimeOf reads it: invalid
' unless playing it, in edition when one is chosen, resumes, or when its
' runtime is unknown. A show resumes an episode, never itself.
function libraryResumeFraction(e as object, edition = invalid as dynamic) as dynamic
    if not libraryResumes(e.state, edition) then return invalid
    ms = invalid
    if e.video
        ms = e.item.durationMs
    else if e.item.kind = "show"
        return invalid
    else if edition <> invalid and edition.runtimeMs <> invalid
        ms = edition.runtimeMs
    else if e.item.metadata <> invalid and e.item.metadata.runtimeMinutes <> invalid
        ms = e.item.metadata.runtimeMinutes * 60000
    end if
    if ms = invalid or ms <= 0 then return invalid
    if e.state.positionMs >= ms then return 1
    return e.state.positionMs / ms
end function

' A show's or season's resume bar: that of the episode libraryNextEpisode
' picks, which its play action plays.
function libraryNextEpisodeFraction(episodes as object, states as object) as dynamic
    i = libraryNextEpisode(episodes, states)
    if i < 0 then return invalid
    return libraryResumeFraction({ item: episodes[i], state: states[episodes[i].id.ToStr()], video: false })
end function

' Extended · 3h 48m · 4K, 1080p: the cut, its runtime and its copies.
function libraryEditionLabel(edition as object) as string
    parts = [edition.name]
    if edition.runtimeMs <> invalid then parts.Push(formatDuration(edition.runtimeMs))
    qualities = []
    seen = {}
    for each c in edition.copies
        if c.quality <> invalid and not seen.DoesExist(c.quality)
            seen.AddReplace(c.quality, true)
            qualities.Push(c.quality)
        end if
    end for
    parts.Push(qualities.Join(", "))
    return formatParts(parts)
end function

' The file whose tracks details and the player describe: the one a stream
' names as playing, since the server picks the copy; before a stream, the
' chosen edition's first copy, else the item's first file.
function libraryEditionFile(files as object, edition as dynamic, playing = invalid as dynamic) as dynamic
    if files.Count() = 0 then return invalid
    ids = []
    if playing <> invalid then ids.Push(playing)
    if edition <> invalid and edition.copies.Count() > 0 then ids.Push(edition.copies[0].mediaFileId)
    for each id in ids
        for each f in files
            if f.id = id then return f
        end for
    end for
    return files[0]
end function

' Search's sections for SearchResult's non-empty lists, as { title, kind,
' items }; kind names the list. Shows and episodes share one section.
function searchSections(r as object) as object
    out = []
    shows = []
    shows.Append(r.episodes)
    shows.Append(r.shows)
    ' Movies, TV, music, YouTube, then people; within each, the most specific kind first.
    for each s in [["Movies", "movies", r.movies], ["TV", "shows", shows], ["Songs", "songs", r.songs], ["Albums", "albums", r.albums], ["Artists", "artists", r.artists], ["Videos", "videos", r.videos], ["Channels", "channels", r.channels], ["People", "people", r.people]]
        if s[2].Count() > 0 then out.Push({ title: s[0], kind: s[1], items: s[2] })
    end for
    return out
end function

' The shelves of an ItemRelated, one { collection, items } per collection
' in order. None while the answer is still to come or after it failed
' (invalid).
function libraryRelated(related as dynamic) as object
    if related = invalid then return []
    return related.collections
end function

' Previous and Next of an ItemRelated, as { id, text, navigate } for each
' neighbor it names. The text names the destination, since the audio guide
' reads only a button's text; navigate replaces the page, so Back skips it.
function libraryNeighbors(related as dynamic) as object
    out = []
    if related = invalid then return out
    for each n in [["previous", "Previous"], ["next", "Next"]]
        item = related[n[0]]
        if item <> invalid
            name = itemTitle(item)
            if item.kind = "episode" then name = formatEpisodeCode(item)
            out.Push({ id: n[0], text: n[1] + ": " + name, navigate: { to: "details", item: item, replace: true } })
        end if
    end for
    return out
end function

' Each crew job once, in credit order, with everyone who held it. An
' episode words Director and Writer as its board does and adds its first
' three cast as Guest stars.
function libraryCrewLines(crew as object, cast as object, episode as boolean) as object
    order = []
    names = {}
    for each c in crew
        job = "Crew"
        if c.job <> invalid then job = c.job
        if episode and job = "Director" then job = "Directed by"
        if episode and job = "Writer" then job = "Written by"
        if not names.DoesExist(job)
            order.Push(job)
            names[job] = []
        end if
        names[job].Push(c.name)
    end for
    lines = []
    for each job in order
        lines.Push([job, names[job].Join(", ")])
    end for
    if episode and cast.Count() > 0
        guests = []
        for i = 0 to cast.Count() - 1
            if i = 3 then exit for
            guests.Push(cast[i].name)
        end for
        lines.Push(["Guest stars", guests.Join(", ")])
    end if
    return lines
end function

' A show's seasons as its caption counts them: Specials are no season.
function libraryRegularSeasons(seasons as object) as integer
    n = 0
    for each s in seasons
        if s.seasonNumber <> 0 then n = n + 1
    end for
    return n
end function

' Where selecting a Next up entry goes: an episode plays, in the edition it
' left off in; a video opens its details.
function libraryNextUpRoute(e as object) as object
    if e.video then return { to: "details", view: "VideoView", video: e.item }
    editionId = invalid
    if e.state <> invalid then editionId = e.state.editionId
    return { to: "player", item: e.item, editionId: editionId }
end function

' Shuffle's rows for items, the episodes of the show series or of one of
' its seasons, or with series invalid a collection's movies: every title
' whose files are not all missing, watched or not, as { id, title } in one
' random order, title what the Up next card names. random(n) answers 0 to
' n - 1.
function libraryShuffle(items as object, series as dynamic, random as function) as object
    rows = []
    for each item in items
        if item.unavailable = invalid or not item.unavailable
            title = itemTitle(item)
            if series <> invalid then title = itemTitle(series) + " · " + formatEpisodeCode(item) + " · " + title
            rows.Push({ id: item.id, title: title })
        end if
    end for
    for i = rows.Count() - 1 to 1 step -1
        j = random(i + 1)
        t = rows[i]
        rows[i] = rows[j]
        rows[j] = t
    end for
    return rows
end function

function libraryDraw(n as integer) as integer
    return Rnd(n) - 1
end function

' The player's params for the first of a Shuffle's rows, with the rest
' queued after it; invalid with none. Every row plays from its start, which
' positionMs 0 asks of startPlayback, where an absent one resumes.
function libraryQueueNext(rows as object) as dynamic
    if rows.Count() = 0 then return invalid
    rest = []
    for i = 1 to rows.Count() - 1
        rest.Push(rows[i])
    end for
    return { item: rows[0], title: rows[0].title, queue: rest, shuffle: true, positionMs: 0 }
end function
