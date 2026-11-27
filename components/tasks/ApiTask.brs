' Sets response to an apiResult. A composite load runs its requests in
' order and answers with the first failure, or with its parts as data.
sub init()
    m.top.functionName = "work"
end sub

sub work()
    r = m.top.request
    ' shortcut: cachefs: is RAM the system shares, evicts when another app
    ' needs it, and empties at reboot, so a launch after one waits on the
    ' server; no other Roku store holds more than the registry's 32 KB.
    m.cache = cacheContext("cachefs:/", cacheSlot, deliver, m.global.cacheExpired)
    if r.load = invalid
        m.top.response = send(r.op, r.params, r.query, r.body)
        refresh()
        return
    end if
    a = r.args
    if r.load = "home"
        result = loadHome(a)
    else if r.load = "grid"
        result = loadGrid(a)
    else if r.load = "genre"
        result = loadGenre(a)
    else if r.load = "details"
        result = loadDetails(a)
    else if r.load = "play"
        result = loadPlay(a)
    else if r.load = "update"
        result = loadUpdate(a)
    else if r.load = "markAll"
        result = loadMarkAll(a)
    else if r.load = "bif"
        result = loadBif(a)
    else if r.load = "dropBif"
        result = dropBif(a)
    else if r.load = "list"
        offset = 0
        if a.offset <> invalid then offset = a.offset
        result = sendAll(a.op, a.params, a.query, 2000, offset)
        result.rest = apiNextBatch(a.op, a.params, a.query, result.nextOffset)
    else if r.load = "rest"
        result = sendAll(a.op, a.params, a.query, 0, a.offset)
    else if r.load = "playOrder"
        result = sendAll("listPlaylistPlayOrder", { profileId: a.profileId, playlistId: a.playlistId }, {})
    else if r.load = "media"
        result = loadMedia(a)
    else if r.load = "artist"
        result = loadArtist(a)
    else if r.load = "album"
        result = loadAlbum(a)
    else if r.load = "channel"
        result = loadChannel(a)
    else if r.load = "video"
        result = loadVideo(a)
    else if r.load = "song"
        result = loadSong(a)
    else if r.load = "station"
        result = loadStation(a)
    else
        result = loadItem(a)
    end if
    m.top.response = result
    refresh()
end sub

' Asks the server behind the answers read from what is kept; the scene has
' views read again when any changed.
sub refresh()
    if cacheRefresh(m.cache) then m.global.cacheVersion = m.global.cacheVersion + 1
end sub

' The snapshot a playback start or verdict sends, after the local check
' its network group reports.
function checkedSnapshot(quality as object) as object
    now = CreateObject("roDateTime").AsSeconds()
    if homeDue(m.global.server, m.global.home, now) then m.global.home = { url: homeFound(), at: now }
    return deviceSnapshot(quality)
end function

' The server's address on its own network once its reply there proves the
' check's key, as anything may answer at a private address; "" when none
' does within 2 seconds, as an unreachable one never does. No token is sent.
function homeFound() as string
    check = send("startLocalCheck")
    if not check.ok then return ""
    key = CreateObject("roByteArray")
    key.FromBase64String(check.data.key)
    port = CreateObject("roMessagePort")
    tries = {}
    for each base in check.data.addresses
        nonce = CreateObject("roDeviceInfo").GetRandomUUID().Replace("-", "")
        xfer = CreateObject("roUrlTransfer")
        xfer.SetMessagePort(port)
        xfer.SetUrl(base + apiRequest("confirmLocalCheck", { checkId: check.data.id }).path)
        xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        xfer.AddHeader("Content-Type", "application/json")
        xfer.SetRequest("POST")
        if xfer.AsyncPostFromString(FormatJson({ nonce: nonce, proof: homeProof(key, "client:" + nonce) })) then tries[xfer.GetIdentity().ToStr()] = { xfer: xfer, base: base, nonce: nonce }
    end for
    found = ""
    clock = CreateObject("roTimespan")
    while found = "" and tries.Count() > 0 and clock.TotalMilliseconds() < 2000
        msg = Wait(2000 - clock.TotalMilliseconds(), port)
        if Type(msg) <> "roUrlEvent" then exit while
        id = msg.GetSourceIdentity().ToStr()
        t = tries[id]
        tries.Delete(id)
        reply = apiResult(msg.GetResponseCode(), msg.GetString())
        if t <> invalid and reply.ok and reply.data.proof = homeProof(key, "server:" + t.nonce) then found = apiServerBase(t.base)
    end while
    for each id in tries
        tries[id].xfer.AsyncCancel()
    end for
    return found
end function

' The lowercase hex HMAC-SHA256 of text under key.
function homeProof(key as object, text as string) as string
    hmac = CreateObject("roHMAC")
    if hmac.Setup("sha256", key) <> 0 then return ""
    message = CreateObject("roByteArray")
    message.FromAsciiString(text)
    return LCase(hmac.Process(message).ToHexString())
end function

' The profile and server reads are kept under, "" while none is active.
function cacheSlot() as string
    if m.global.locked or m.global.token = "" or m.global.profileId = 0 then return ""
    return m.global.profileId.ToStr() + " " + m.global.server
end function

function transfer(path as string) as object
    xfer = CreateObject("roUrlTransfer")
    xfer.SetMessagePort(CreateObject("roMessagePort"))
    xfer.SetUrl(m.global.server + path)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.RetainBodyOnError(true)
    ' Asks for gzip, which the server sends for JSON, and inflates it.
    xfer.EnableEncodings(true)
    if m.global.token <> "" then xfer.AddHeader("Authorization", "Bearer " + m.global.token)
    return xfer
end function

' The reply of a started transfer, or a timeout as roUrlTransfer's own
' code for one.
function finish(xfer as object, started as boolean, waitMs = 20000 as integer) as object
    msg = invalid
    if started then msg = Wait(waitMs, xfer.GetMessagePort())
    if Type(msg) <> "roUrlEvent"
        xfer.AsyncCancel()
        return { code: -28, text: "", type: "", retryAfter: "" }
    end if
    headers = msg.GetResponseHeaders()
    retry = ""
    kind = ""
    if headers <> invalid and headers["retry-after"] <> invalid then retry = headers["retry-after"]
    if headers <> invalid and headers["content-type"] <> invalid then kind = headers["content-type"]
    return { code: msg.GetResponseCode(), text: msg.GetString(), type: kind, retryAfter: retry }
end function

' Reads go through what is kept; a write the server answered has the next
' read of everything kept ask first.
function send(op as string, params = {} as object, query = {} as object, body = invalid as dynamic) as object
    req = apiRequest(op, params, query, body)
    req.waitMs = apiWaitMs(op, query)
    if req.method = "GET"
        reply = cacheGet(m.cache, op, req)
    else
        reply = deliver(req)
        if cacheMarks(op, reply.code)
            m.cache.expired = CreateObject("roDateTime").AsSeconds()
            m.global.cacheExpired = m.cache.expired
        end if
    end if
    return apiResult(reply.code, reply.text, reply.retryAfter)
end function

' The server's reply to one apiRequest with its waitMs.
function deliver(req as object) as object
    xfer = transfer(req.path)
    xfer.AddHeader("Accept", "application/json")
    xfer.SetRequest(req.method)
    if req.method = "POST" or req.method = "PUT"
        xfer.AddHeader("Content-Type", "application/json")
        reply = finish(xfer, xfer.AsyncPostFromString(req.body))
    else
        reply = finish(xfer, xfer.AsyncGetToString(), req.waitMs)
    end if
    ' The scene answers by showing Who's watching, from whichever view asked.
    if reply.code = 403 and apiLocked(apiResult(reply.code, reply.text)) then m.global.locked = true
    return reply
end function

' Every page of a listing from offset, as one result whose data is the
' items; a max above zero stops after the page that reaches it, with
' nextOffset that of the rows that remain, else invalid; total is the page's
' own, for the lists that carry one.
function sendAll(op as string, params as object, query as object, max = 0 as integer, offset = 0 as dynamic) as object
    items = []
    total = invalid
    while offset <> invalid and (max = 0 or items.Count() < max)
        q = { limit: 200, offset: offset }
        q.Append(query)
        r = send(op, params, q)
        if not r.ok then return r
        items.Append(r.data.items)
        total = r.data.total
        offset = r.data.nextOffset
    end while
    return { ok: true, status: 200, data: items, nextOffset: offset, total: total, code: "", message: "" }
end function

' Watch states keyed by item id; with a parentId only those of the episodes
' and seasons under that show or season.
function statesById(profileId as integer, parentId = invalid as dynamic) as object
    query = {}
    if parentId <> invalid then query.AddReplace("parentId", parentId)
    r = sendAll("listWatchStates", { profileId: profileId }, query)
    if not r.ok then return r
    byId = {}
    for each w in r.data
        byId[w.itemId.ToStr()] = w
    end for
    return { ok: true, data: byId }
end function

function done(data as object) as object
    return { ok: true, status: 200, data: data, code: "", message: "" }
end function

function loadItem(a as object) as object
    return send("getItem", { itemId: a.itemId })
end function

' A 404 means the profile has no watch state for the item yet.
function stateOf(profileId as integer, itemId as integer) as dynamic
    r = send("getWatchState", { profileId: profileId, itemId: itemId })
    if r.ok then return r.data
    return invalid
end function

' ShowProgress keyed by show id.
function progressById(profileId as integer) as object
    r = sendAll("listShowProgress", { profileId: profileId }, {})
    if not r.ok then return r
    byId = {}
    for each p in r.data
        byId[p.showId.ToStr()] = p
    end for
    return { ok: true, data: byId }
end function

' Home resolves only what it shows: libraryHomeQueue's items in order,
' each by getItem unless it is a title or a video, until the hero and a
' full Also in progress and Next up are found. An episode the queue names no show for takes it
' from its season.
function loadHome(a as object) as object
    states = sendAll("listWatchStates", { profileId: a.profileId }, {})
    if not states.ok then return states
    progress = progressById(a.profileId)
    if not progress.ok then return progress
    ' The 20 newest of each kind hold the 20 newest of both.
    titles = []
    for each kind in ["movie", "show"]
        r = send("listItems", {}, { kind: kind, sort: "added", limit: 20 })
        if not r.ok then return r
        titles.Append(r.data.items)
    end for
    known = {}
    for each t in titles
        known[t.id.ToStr()] = t
    end for
    ' Continue watching's videos: the 13 latest played fill the hero and Also
    ' in progress, so an older video's state never shows. A failure leaves them out.
    playing = []
    r = send("listYouTubeVideos", {}, { inProgress: true, sort: "played", limit: 13 })
    if r.ok then playing = r.data.items
    items = {}
    hero = false
    rest = 0
    for each q in libraryHomeQueue(states.data, progress.data, playing)
        if hero and rest >= 12 then exit for
        starts = not hero and libraryInProgress(q.state)
        if starts or rest < 12
            key = q.itemId.ToStr()
            if q.video <> invalid then known[key] = q.video
            if known[key] = invalid
                r = send("getItem", { itemId: q.itemId })
                ' A video's state the list left out is older than any shown.
                if r.ok and r.data.kind <> "video" then known[key] = r.data
            end if
            if known[key] <> invalid
                items[key] = known[key]
                if starts then hero = true else rest = rest + 1
            end if
        end if
    end for
    home = libraryHome(states.data, items, titles, progress.data, playing)
    entries = [home.hero]
    entries.Append(home.also)
    entries.Append(home.nextUp)
    for each e in entries
        if e <> invalid and not e.video and e.item.kind = "episode"
            showId = e.showId
            if showId = invalid and e.item.parentId <> invalid
                r = send("getItem", { itemId: e.item.parentId })
                if r.ok then showId = r.data.parentId
            end if
            if showId <> invalid
                key = showId.ToStr()
                if known[key] = invalid
                    r = send("getItem", { itemId: showId })
                    if r.ok then known[key] = r.data
                end if
                e.show = known[key]
            end if
        end if
    end for
    recent = []
    for each t in home.recent
        if recent.Count() >= 20 then exit for
        recent.Push(t)
    end for
    ' Occasions in season on this device's calendar date; a failure leaves the rows out.
    active = []
    lists = []
    r = send("listActiveOccasions", { profileId: a.profileId }, { date: formatToday() })
    if r.ok
        for each o in r.data.items
            r = send("listItems", {}, { occasionId: o.id, limit: 20 })
            if not r.ok then exit for
            active.Push(o)
            lists.Push(r.data.items)
        end for
    end if
    ' New from your channels: a failure leaves the row out.
    videos = []
    r = send("listYouTubeVideos", {}, { sort: "newest", unwatched: true, limit: 20 })
    if r.ok then videos = r.data.items
    ' On now: every kind's stations with something on; a failure leaves the row out.
    onNow = []
    r = sendAll("listStations", {}, {})
    if r.ok
        for each s in r.data
            if s.onAir.status = "on_air" then onNow.Push(s)
        end for
    end if
    return done({ hero: home.hero, onNow: onNow, also: home.also, nextUp: home.nextUp, occasions: libraryHomeOccasions(active, lists), recent: recent, videos: videos })
end function

' A library's titles with what its chips, badges and captions read: watch
' states, each show's progress, and the genres of the titles' libraries by
' name. With kidsOnly, the titles are only kids' content, which an adult who
' hides it is otherwise not listed; a chosen genreId comes with its ids.
function loadGrid(a as object) as object
    q = { kind: a.kind }
    if a.kidsOnly = true then q.AddReplace("kidsContent", true)
    items = sendAll("listItems", {}, q)
    if not items.ok then return items
    states = statesById(a.profileId)
    if not states.ok then return states
    data = { items: items.data, states: states.data, progress: {}, genres: [], genreIds: invalid }
    if a.genreId <> invalid
        ids = loadGenre(a)
        if not ids.ok then return ids
        data.genreIds = ids.data
    end if
    if a.kind = "show"
        progress = progressById(a.profileId)
        if not progress.ok then return progress
        data.progress = progress.data
    end if
    data.genres = genresOf(items.data)
    return done(data)
end function

' The genres of the items' libraries by name. Genres only fill the Genre
' select; failing them leaves it out.
function genresOf(items as object) as object
    genres = []
    libraries = {}
    for each i in items
        libraries[i.libraryId.ToStr()] = i.libraryId
    end for
    seen = {}
    for each key in libraries
        r = sendAll("listGenres", {}, { libraryId: libraries[key] })
        if r.ok
            for each g in r.data
                if not seen.DoesExist(g.name)
                    seen[g.name] = true
                    genres.Push(g)
                end if
            end for
        end if
    end for
    genres.SortBy("name")
    return genres
end function

' The ids of a library's titles in one genre, as a set keyed by id.
function loadGenre(a as object) as object
    q = { kind: a.kind }
    if a.genreId <> invalid then q.AddReplace("genreId", a.genreId)
    if a.kidsOnly = true then q.AddReplace("kidsContent", true)
    r = sendAll("listItems", {}, q)
    if not r.ok then return r
    ids = {}
    for each i in r.data
        ids[i.id.ToStr()] = true
    end for
    return done(ids)
end function

' Every edition's files of the item; empty when they fail to load.
function filesOf(itemId as integer) as object
    r = send("listMediaFiles", {}, { itemId: itemId })
    if r.ok then return r.data.items
    return []
end function

function firstFile(itemId as integer, edition = invalid as dynamic, playing = invalid as dynamic) as dynamic
    return libraryEditionFile(filesOf(itemId), edition, playing)
end function

' The occasions in season the title is in, each with its other titles, as a
' details page's rows; a failure leaves the rows out.
function occasionsOf(a as object, item as object) as object
    r = send("listActiveOccasions", { profileId: a.profileId }, { date: formatToday(), itemId: item.id })
    if not r.ok then return []
    active = []
    lists = []
    for each o in r.data.items
        l = send("listItems", {}, { occasionId: o.id, limit: 21 })
        if not l.ok then return []
        active.Push(o)
        lists.Push(l.data.items)
    end for
    return libraryOccasionRelated(active, lists, item.id)
end function

' Credits, the file, the verdict and what relates only decorate details;
' failing them leaves the screen without those lines.
sub decorate(d as object, a as object, item as object)
    credits = send("getItemCredits", { itemId: item.id })
    if credits.ok then d.credits = credits.data
    related = send("getItemRelated", { itemId: item.id })
    if related.ok then d.related = related.data
    d.files = filesOf(item.id)
    d.file = libraryEditionFile(d.files, invalid)
    d.state = stateOf(a.profileId, item.id)
    verdict = send("checkPlayability", { itemId: item.id }, {}, checkedSnapshot({ auto: true }))
    if verdict.ok then d.playability = verdict.data
end sub

' The first episode of the season after a finale of season, never the
' specials; invalid after the series finale or when a lookup fails.
function nextSeasonPremiere(season as object) as dynamic
    seasons = sendAll("listItems", {}, { parentId: season.parentId })
    if not seasons.ok then return invalid
    later = libraryNextSeason(seasons.data, season.seasonNumber)
    if later = invalid then return invalid
    eps = send("listItems", {}, { parentId: later.id, limit: 1 })
    if eps.ok and eps.data.items.Count() > 0 then return eps.data.items[0]
    return invalid
end function

function loadDetails(a as object) as object
    r = send("getItem", { itemId: a.itemId })
    if not r.ok then return r
    item = r.data
    d = { item: item, credits: { cast: [], crew: [] } }
    if item.kind = "movie" or item.kind = "show" then d.occasions = occasionsOf(a, item)
    if item.kind = "movie"
        decorate(d, a, item)
    else if item.kind = "episode"
        season = send("getItem", { itemId: item.parentId })
        if not season.ok then return season
        show = send("getItem", { itemId: season.data.parentId })
        if not show.ok then return show
        siblings = sendAll("listItems", {}, { parentId: item.parentId })
        if not siblings.ok then return siblings
        d.season = season.data
        d.show = show.data
        d.upNext = []
        for i = 0 to siblings.data.Count() - 1
            if siblings.data[i].id = item.id
                for j = i + 1 to i + 2
                    if j < siblings.data.Count() then d.upNext.Push(siblings.data[j])
                end for
            end if
        end for
        if d.upNext.Count() = 0
            premiere = nextSeasonPremiere(season.data)
            if premiere <> invalid then d.upNext.Push(premiere)
        end if
        decorate(d, a, item)
    else
        if item.kind = "season"
            show = send("getItem", { itemId: item.parentId })
            if not show.ok then return show
            d.show = show.data
            d.seasons = [item]
        else
            credits = send("getItemCredits", { itemId: item.id })
            if credits.ok then d.credits = credits.data
            seasons = sendAll("listItems", {}, { parentId: item.id })
            if not seasons.ok then return seasons
            ' Specials, season 0, list last.
            d.seasons = []
            specials = []
            for each s in seasons.data
                if s.seasonNumber = 0 then specials.Push(s) else d.seasons.Push(s)
            end for
            d.seasons.Append(specials)
        end if
        d.episodes = {}
        all = []
        for each s in d.seasons
            eps = sendAll("listItems", {}, { parentId: s.id })
            if not eps.ok then return eps
            d.episodes[s.id.ToStr()] = eps.data
            all.Append(eps.data)
        end for
        states = statesById(a.profileId, item.id)
        if not states.ok then return states
        d.states = states.data
        d.next = invalid
        n = libraryNextEpisode(all, d.states)
        if n >= 0 then d.next = all[n]
    end if
    return done(d)
end function

' Starts the session with a fresh snapshot, and gathers what the player
' shows around the stream: titles, the file's facts and the next episode.
function loadPlay(a as object) as object
    ' Item operations serve only movies and TV; a YouTube video has its own.
    if a.video
        r = send("getYouTubeVideo", { videoId: a.itemId })
    else
        r = send("getItem", { itemId: a.itemId })
    end if
    if not r.ok then return r
    item = r.data
    p = { item: item, title: "", subtitle: "", nextId: invalid, source: {}, subtitles: [], chapters: [], audio: [] }
    if a.video
        p.title = item.title
        p.subtitle = item.channelTitle
    else
        p.title = itemTitle(item)
    end if
    ' A video has no kind to compare.
    if not a.video and item.kind = "episode"
        season = send("getItem", { itemId: item.parentId })
        if season.ok
            show = send("getItem", { itemId: season.data.parentId })
            if show.ok then p.title = itemTitle(show.data)
        end if
        p.subtitle = formatEpisodeCode(item) + " · " + itemTitle(item)
        siblings = sendAll("listItems", {}, { parentId: item.parentId })
        nextUp = invalid
        if siblings.ok then nextUp = libraryEpisodeAfter(siblings.data, item.id)
        if siblings.ok and nextUp = invalid and season.ok then nextUp = nextSeasonPremiere(season.data)
        if nextUp <> invalid then p.nextId = nextUp.id
    end if
    s = send("startPlayback", {}, {}, apiPlaybackBody(a, checkedSnapshot(a.quality)))
    if not s.ok then return s
    p.stream = s.data
    describeFile(p, item, a.editionId, s.data.mediaFileId)
    return done(p)
end function

' The player's facts of the file in play, the stream's mediaFileId:
' container, chapters, the video codec and the subtitles the viewer may
' pick. A stream that names no file is taken to play the edition's first.
sub describeFile(p as object, item as object, editionId as dynamic, playing as dynamic)
    edition = invalid
    if editionId <> invalid then edition = libraryEdition(item.editions, editionId)
    file = firstFile(item.id, edition, playing)
    if file = invalid then return
    p.container = file.container
    p.chapters = file.chapters
    for each t in file.tracks
        if t.kind = "video" and p.source.codec = invalid then p.source = { codec: t.codec, hdrFormat: t.hdrFormat }
        if t.kind = "subtitle" and t.subtitleIsText = true and not t.isForced then p.subtitles.Push(t)
    end for
end sub

' Tunes in with a fresh snapshot: the stream and what is on, with a video
' program's file facts; or, answered off_air, what the station is doing and
' resumesAt. A song needs no facts.
function loadStation(a as object) as object
    r = send("startStationPlayback", { stationId: a.stationId }, {}, apiStationBody(a, checkedSnapshot(a.quality)))
    if r.ok
        p = { stream: r.data.stream, onAir: r.data.onAir, source: {}, subtitles: [], chapters: [] }
        now = r.data.onAir.now
        if now.item <> invalid
            ' Only getItem names the editions.
            item = send("getItem", { itemId: now.itemId })
            if item.ok then describeFile(p, item.data, now.editionId, p.stream.mediaFileId) else describeFile(p, now.item, invalid, p.stream.mediaFileId)
        end if
        return done(p)
    end if
    if r.code <> "off_air" then return r
    s = send("getStation", { stationId: a.stationId })
    if not s.ok then return s
    return done({ onAir: s.data.onAir, resumesAt: r.data.resumesAt })
end function

' A mid-playback change: the position first, since group updates carry
' none and the server resumes a restarted stream from it, then each
' { op, body } in order. The last update carries the stream to play.
function loadUpdate(a as object) as object
    path = { sessionId: a.sessionId }
    send("reportPlaybackPosition", path, {}, { positionMs: a.positionMs, paused: a.paused = true })
    r = invalid
    for each u in a.updates
        r = send(u.op, path, {}, u.body)
        if not r.ok then return r
    end for
    return r
end function

function loadMarkAll(a as object) as object
    ' One request, so the server publishes one event and nothing is half marked.
    r = send("putWatchStates", { profileId: a.profileId }, {}, { itemIds: a.itemIds, watched: a.watched })
    if not r.ok then return r
    return done({})
end function

' Fetches the stream's BIF to tmp: and cuts every frame to its
' bifFrameFile, which the player shows as it is. The render thread may not
' touch files, so this task does all of it; the BIF itself goes once cut.
function loadBif(a as object) as object
    file = bifFile(a.sessionId)
    xfer = transfer(a.url)
    reply = finish(xfer, xfer.AsyncGetToFile(file))
    if reply.code <> 200 then return apiResult(reply.code, "")
    head = CreateObject("roByteArray")
    head.ReadFile(file, 0, 64)
    if head.Count() < 64 then return apiResult(0, "")
    bytes = CreateObject("roByteArray")
    bytes.ReadFile(file, 0, bifHeaderBytes(head))
    index = bifIndex(bytes)
    if index = invalid then return apiResult(0, "")
    for n = 0 to index.frames.Count() - 1
        frame = index.frames[n]
        bytes.ReadFile(file, frame.offset, frame.length)
        bytes.WriteFile(bifFrameFile(a.sessionId, n))
    end for
    DeleteFile(file)
    return done({ file: file, index: index })
end function

' Deletes a session's BIF and frames from tmp:, which outlives the player.
function dropBif(a as object) as object
    fs = CreateObject("roFileSystem")
    for each pattern in bifPatterns(a.sessionId)
        for each name in fs.Match("tmp:/", pattern)
            fs.Delete("tmp:/" + name)
        end for
    end for
    return done({})
end function

' A Music or YouTube tab's chip: its listing in the chosen sort and
' filter, the Genre select's genres for Music, and every channel for
' YouTube's Channel select and captions. Music's Playlists are the
' profile's own.
function loadMedia(a as object) as object
    ' AddReplace keeps a key's case; dot assignment would lowercase it.
    q = {}
    if a.sort <> invalid then q.sort = a.sort
    rest = invalid
    if a.kind = "music"
        if a.filterId <> invalid then q.AddReplace("genreId", a.filterId)
        ops = { albums: "listMusicAlbums", artists: "listMusicArtists", songs: "listMusicSongs" }
        if a.chip = "playlists"
            r = sendAll("listPlaylists", { profileId: a.profileId }, { kind: "music" })
        else if a.chip = "stations"
            r = sendAll("listStations", {}, { kind: "music" })
        else
            r = sendAll(ops[a.chip], {}, q, 2000)
            rest = apiNextBatch(ops[a.chip], {}, q, r.nextOffset)
        end if
        if not r.ok then return r
        data = { items: r.data, rest: rest, genres: [], channels: [], total: r.total }
        if a.genres = true then data.genres = genresOf(r.data)
        return done(data)
    end if
    channels = sendAll("listYouTubeChannels", {}, { sort: "title" })
    if not channels.ok then return channels
    if a.chip = "channels"
        r = done(channels.data)
        if a.sort = "latest" then r = sendAll("listYouTubeChannels", {}, q)
    else
        if a.filterId <> invalid then q.AddReplace("channelId", a.filterId)
        if a.chip = "unwatched" then q.unwatched = true
        r = sendAll("listYouTubeVideos", {}, q, 2000)
        rest = apiNextBatch("listYouTubeVideos", {}, q, r.nextOffset)
    end if
    if not r.ok then return r
    return done({ items: r.data, rest: rest, genres: [], channels: channels.data })
end function

' Artist details: the artist, Popular's five and the albums newest first.
function loadArtist(a as object) as object
    artist = send("getMusicArtist", { artistId: a.artistId })
    if not artist.ok then return artist
    popular = send("listMusicSongs", {}, { artistId: a.artistId, sort: "popular", limit: 5 })
    if not popular.ok then return popular
    albums = sendAll("listMusicAlbums", {}, { artistId: a.artistId, sort: "year" })
    if not albums.ok then return albums
    return done({ artist: artist.data, popular: popular.data.items, albums: albums.data })
end function

' Album details: the album and its songs in disc then track order.
function loadAlbum(a as object) as object
    album = send("getMusicAlbum", { albumId: a.albumId })
    if not album.ok then return album
    songs = sendAll("listMusicSongs", {}, { albumId: a.albumId })
    if not songs.ok then return songs
    return done({ album: album.data, songs: songs.data })
end function

' Channel details: the channel and its videos newest first.
function loadChannel(a as object) as object
    r = send("getYouTubeChannel", { channelId: a.channelId })
    if not r.ok then return r
    q = { channelId: a.channelId, sort: "newest" }
    videos = sendAll("listYouTubeVideos", {}, q, 2000)
    if not videos.ok then return videos
    return done({ channel: r.data, videos: videos.data, rest: apiNextBatch("listYouTubeVideos", {}, q, videos.nextOffset) })
end function

' Video details: the video, its file and this device's verdict, and four
' more from its channel.
function loadVideo(a as object) as object
    r = send("getYouTubeVideo", { videoId: a.videoId })
    if not r.ok then return r
    d = { video: r.data, file: firstFile(a.videoId), playability: invalid, more: [] }
    verdict = send("checkPlayability", { itemId: a.videoId }, {}, checkedSnapshot({ auto: true }))
    if verdict.ok then d.playability = verdict.data
    more = send("listYouTubeVideos", {}, { channelId: r.data.channelId, sort: "newest", limit: 5 })
    if more.ok
        for each v in more.data.items
            if v.id <> a.videoId and d.more.Count() < 4 then d.more.Push(v)
        end for
    end if
    return done(d)
end function

' An audio-only session for one song from its start, or from positionMs
' for a song held when a station stopped; playlistId stamps the playlist as
' recently played.
function loadSong(a as object) as object
    body = { profileId: a.profileId, itemId: a.songId, positionMs: 0, snapshot: checkedSnapshot({}) }
    if a.positionMs <> invalid then body.AddReplace("positionMs", a.positionMs)
    if a.playlistId <> invalid then body.AddReplace("playlistId", a.playlistId)
    return send("startPlayback", {}, {}, body)
end function
