' params.item is the movie, show or episode; everything else is loaded.
sub init()
    m.top.observeField("focusedChild", "uiRestore")
    m.global.observeFieldScoped("stateVersion", "reload")
    m.audioTrackId = invalid
    m.editionId = invalid
end sub

sub draw()
    item = m.d.item
    m.file = m.d.file
    m.edition = invalid
    if item.kind <> "show" then togetherStart(m.top.params.item, itemTitle(item))
    if item.kind = "episode"
        drawEpisode(item)
    else if item.kind = "show"
        drawShow(item)
    else
        drawMovie(item)
    end if
    lift(m.liftFor)
end sub

' A page taller than the screen rises while id, the focused control, ends
' past the bottom margin, and settles once focus leaves it.
sub lift(id as dynamic)
    m.liftFor = id
    y = 0
    if id <> invalid and m.controls[id] <> invalid
        r = m.controls[id].boundingRect()
        page = m.top.localBoundingRect()
        if r.y + r.height > 1040 then y = 1040 - page.y - page.height
    end if
    m.top.translation = [0, y]
end sub

' Director, Genres, Audio, Subtitles, Video, as the boards list them.
' Short, under Watch together's note, leaves out Genres, Subtitles and
' Written by, as its board does, and rows that would pass bottom.
function facts(rows as object, x as integer, y as integer, bottom as integer, short as boolean) as integer
    for each r in rows
        menu = (r[0] = "Audio" and m.audio.Count() > 1) or r[0] = "Edition"
        h = 46
        if menu then h = 64
        if short and y + h > bottom then exit for
        if short and (r[0] = "Genres" or r[0] = "Subtitles" or r[0] = "Written by") then r[1] = ""
        if r[1] <> "" or r[0] = "Audio"
            uiLabel(m.top, r[0], 26, false, "dim", x, y)
            if menu
                id = LCase(r[0])
                sel = uiPanel(m.top, id, 12, x + 220, y - 12, 0, 56, "glass")
                l = uiLabel(sel, r[1], 26, false, "text", 20, 0)
                l.height = 56
                l.vertAlign = "center"
                w = l.boundingRect().width + 76
                sel.GetChild(0).width = w
                m.rings[id].width = w + 20
                uiImage(sel, "chevron.png", w - 40, 17, 22, 22, uiColor("text"))
                y = y + 64
            else
                l = uiLabel(m.top, r[1], 26, false, "text", x + 220, y)
                if r[2] <> invalid
                    uiLabel(m.top, r[2], 26, true, r[3], x + 220 + l.boundingRect().width + 14, y)
                end if
                y = y + 46
            end if
        end if
    end for
    return y
end function

function genreNames(item as object) as string
    names = []
    if item.genres <> invalid
        for each g in item.genres
            names.Push(g.name)
        end for
    end if
    return names.Join(", ")
end function

' Audio tracks of the file, Subtitles listed by language, and the video
' line with this device's verdict.
function mediaRows() as object
    m.audio = []
    subs = ""
    audioLabel = ""
    if m.file <> invalid
        for each t in m.file.tracks
            if t.kind = "audio"
                m.audio.Push(t)
                if (m.audioTrackId = invalid and audioLabel = "") or t.id = m.audioTrackId then audioLabel = formatAudio(t)
            end if
        end for
        subs = formatSubtitles(m.file.tracks)
    end if
    verdict = invalid
    tone = "ok"
    if m.d.playability <> invalid
        verdict = qualityVerdict(m.d.playability.verdict)
        if m.d.playability.verdict <> "direct_play" then tone = "accent"
    end if
    video = formatVideo(m.file)
    if verdict <> invalid then video = video + " · "
    return [["Audio", audioLabel], ["Subtitles", subs], ["Video", video, verdict, tone]]
end function

' below: the page rises to show it, so it may start past the screen. Each
' member opens their page; a member's control holds their labels, so the
' page rises far enough to show them.
sub castRow(y as integer, below = false as boolean)
    cast = m.d.credits.cast
    if cast.Count() = 0 or (y > 980 and not below) then return
    uiLabel(m.top, "Cast", 30, true, "text", 96, y)
    x = 96
    ids = []
    for i = 0 to cast.Count() - 1
        if x > 1920 then exit for
        c = cast[i]
        id = "cast" + i.ToStr()
        g = m.top.CreateChild("Group")
        g.translation = [x, y + 56]
        g.focusable = true
        uiRound(g, c.personId, 25, 0, 140, "person", uiPersonArtUrl(c.personId), formatPersonColor(c.personId))
        m.rings[id] = uiImage(g, "disc-ring.png", 15, -10, 160, 160, uiColor("accent"))
        m.rings[id].visible = false
        n = uiLabel(g, c.name, 24, true, "text", 0, 150)
        n.width = 190
        n.horizAlign = "center"
        if c.character <> invalid
            r = uiLabel(g, c.character, 24, false, "dim", 0, 182)
            r.width = 190
            r.horizAlign = "center"
        end if
        m.controls[id] = g
        ids.Push(id)
        x = x + 210
    end for
    m.layout.Push(ids)
end sub

' The title, two lines at most; answers where the line under it starts,
' so everything below moves down with a title that wraps.
function titleLines(text as string, size as integer, x as integer, y as integer, w as integer) as integer
    l = uiLabel(m.top, text, size, true, "text", x, y, w)
    l.maxLines = 2
    return y + Int(l.boundingRect().height) + 24
end function

function overview(item as object, x as integer, y as integer, w as integer) as integer
    text = overviewOf(item)
    if text = "" then return y
    l = uiLabel(m.top, text, 28, false, "sub", x, y, w)
    l.maxLines = 3
    return y + l.boundingRect().height + 24
end function

sub drawMovie(item as object)
    shown = chooseEdition(item)
    art = uiArt(m.top, item, "poster", 96, 96, 400, 600)
    uiProgress(art, 0, 594, 400, libraryResumeFraction({ item: item, state: m.d.state, video: false }, shown))
    x = 552
    top = titleLines(itemTitle(item), 76, x, 90, 1272)
    rating = ""
    if item.metadata <> invalid and item.metadata.contentRating <> invalid then rating = item.metadata.contentRating
    parts = [{ text: formatRuntime(runtimeOf(item)) }, { text: formatYear(item) }, { text: rating }]
    parts.Append(videoTags(m.file))
    factsLine(parts, x, top)
    label = "Play"
    if libraryResumes(m.d.state, shown) then label = "Resume"
    watched = m.d.state <> invalid and m.d.state.watched
    m.controls.play = uiButton(m.top, "play", label, "p", 0, 0, false, "play")
    m.controls.watched = uiButton(m.top, "watched", uiPick(watched, "Mark unwatched", "Mark watched"), "s", 0, 0, false, "check")
    m.layout = [["play", "watched"]]
    extra = togetherRow([m.controls.play, m.controls.watched], x, top + 64, 1100)
    moved = neighborRow(x, top + 160 + extra)
    y = overview(item, x, top + 180 + extra + moved, 1100)
    rows = libraryCrewLines(m.d.credits.crew, m.d.credits.cast, false)
    rows.Push(["Genres", genreNames(item)])
    if m.edition <> invalid then rows.Push(["Edition", libraryEditionLabel(m.edition)])
    rows.Append(mediaRows())
    y = facts(rows, x, y, top + 568, extra > 0)
    if m.controls.edition <> invalid then m.layout.Push(["edition"])
    if m.controls.audio <> invalid then m.layout.Push(["audio"])
    shelved = collectionsRow(item, x, y)
    y = y + shelved
    castY = top + 548
    if y + 24 > castY then castY = y + 24
    related = relatedRows(castY)
    castRow(castY + related, related > 0 or castY > top + 548)
    if m.current = invalid then m.current = "play"
end sub

' Previous and Next, each only when that neighbor exists, on a line of
' their own under the buttons; answers how far the content below moves down.
function neighborRow(x as integer, y as integer) as integer
    m.neighbors = {}
    nodes = []
    ids = []
    for each n in libraryNeighbors(m.d.related)
        b = uiButton(m.top, n.id, n.text, "s", 0, 0, true)
        b.maxWidth = (1824 - x - 16) \ 2
        m.controls[n.id] = b
        m.neighbors[n.id] = n.navigate
        nodes.Push(b)
        ids.Push(n.id)
    end for
    if ids.Count() = 0 then return 0
    uiRow(nodes, x, y, 16)
    m.layout.Push(ids)
    return 84
end function

' Each of a movie's collections as a row of its other films' posters
' above the cast, titled with its name; nothing at all without them.
' Answers how far the cast moves down.
function relatedRows(y as integer) as integer
    m.related = []
    m.related.Append(libraryRelated(m.d.related))
    if m.d.occasions <> invalid then m.related.Append(m.d.occasions)
    for i = 0 to m.related.Count() - 1
        top = y + i * 400
        uiLabel(m.top, m.related[i].collection.name, 30, true, "text", 96, top)
        content = CreateObject("roSGNode", "ContentNode")
        row = content.CreateChild("ContentNode")
        for each item in m.related[i].items
            c = row.CreateChild("ContentNode")
            c.title = itemTitle(item)
            c.shortDescriptionLine1 = formatYear(item)
            c.hdPosterUrl = uiArtUrl(item.id, "poster")
            c.addFields({ itemId: item.id, artWidth: 160, artHeight: 240, badge: "", glyph: "movie" })
        end for
        id = "related" + i.ToStr()
        rows = m.top.CreateChild("RowList")
        rows.id = id
        rows.itemComponentName = "TileItem"
        rows.numRows = 1
        rows.itemSize = [1824, 320]
        rows.rowItemSize = uiRowSizes([[160, 320]])
        uiRowsAt(rows, 96, top + 56)
        rows.showRowLabel = [false]
        rows.rowFocusAnimationStyle = "floatingFocus"
        rows.drawFocusFeedback = false
        rows.content = content
        rows.observeFieldScoped("rowItemSelected", "onRelated")
        m.controls[id] = rows
        m.layout.Push([id])
    end for
    return m.related.Count() * 400
end function

sub onRelated(event as object)
    shelf = m.related[event.getRoSGNode().id.Mid(7).ToInt()]
    m.top.navigate = { to: "details", item: shelf.items[event.getData()[1]] }
end sub

' A movie of several editions offers m.edition, the viewer's choice,
' preselected to the one holding the saved position, and describes its
' file. Joining or inside a Watch together offers none: it plays the
' default. Answers the edition shown, invalid for a movie of one.
function chooseEdition(item as object) as dynamic
    if item.editions = invalid or item.editions.Count() < 2 then return invalid
    if togetherStage(m.tg, m.global.profileId) = "none"
        if m.editionId = invalid then m.editionId = libraryPreselectedEdition(item.editions, m.d.state).id
        m.edition = libraryEdition(item.editions, m.editionId)
        shown = m.edition
    else
        shown = libraryEdition(item.editions, invalid)
    end if
    m.file = libraryEditionFile(m.d.files, shown)
    return shown
end function

' The movie's collections, each opening its own screen; answers how far
' the content below moves down.
function collectionsRow(item as object, x as integer, y as integer) as integer
    if item.collections = invalid or item.collections.Count() = 0 then return 0
    uiLabel(m.top, "Collections", 26, false, "dim", x, y + 16)
    row = []
    ids = []
    for i = 0 to item.collections.Count() - 1
        id = "col" + i.ToStr()
        m.controls[id] = uiButton(m.top, id, item.collections[i].name, "s", 0, 0, true)
        row.Push(m.controls[id])
        ids.Push(id)
    end for
    uiRow(row, x + 220, y, 16)
    m.layout.Push(ids)
    return 80
end function

sub drawShow(item as object)
    art = uiArt(m.top, item, "poster", 96, 96, 400, 600)
    x = 552
    top = titleLines(itemTitle(item), 76, x, 90, 1272)
    n = libraryRegularSeasons(m.d.seasons)
    seasons = n.ToStr() + " seasons"
    if n = 1 then seasons = "1 season"
    rating = ""
    if item.metadata <> invalid and item.metadata.contentRating <> invalid then rating = item.metadata.contentRating
    parts = [{ text: formatRuntime(runtimeOf(item)) }, { text: seasons }, { text: formatYear(item) }, { text: rating }]
    nextEp = m.d.next
    label = "Play"
    if nextEp <> invalid
        state = m.d.states[nextEp.id.ToStr()]
        code = formatEpisodeCode(nextEp)
        label = "Play " + code
        uiProgress(art, 0, 594, 400, libraryResumeFraction({ item: nextEp, state: state, video: false }))
        if libraryInProgress(state)
            label = "Resume " + code
            parts.Push({ text: formatLeft(runtimeOf(nextEp), state.positionMs) + " in " + code, color: "accent" })
        end if
    end if
    factsLine(parts, x, top)
    all = []
    for each s in m.d.seasons
        all.Append(m.d.episodes[s.id.ToStr()])
    end for
    m.episodes = all
    m.allWatched = allWatched(all, m.d.states)
    row = []
    if nextEp <> invalid
        m.controls.play = uiButton(m.top, "play", label, "p", 0, 0, false, "play")
        row.Push(m.controls.play)
    end if
    m.controls.watched = uiButton(m.top, "watched", uiPick(m.allWatched, "Mark all unwatched", "Mark all watched"), "s", 0, 0, false, "check")
    row.Push(m.controls.watched)
    uiRow(row, x, top + 64, 24)
    y = overview(item, x, top + 180, 1100)
    uiLabel(m.top, "Seasons", 30, true, "text", x, y)
    seasonRow = []
    sx = x
    for i = 0 to m.d.seasons.Count() - 1
        s = m.d.seasons[i]
        id = "s" + i.ToStr()
        g = uiPanel(m.top, id, 12, sx, y + 50, 170, 255)
        uiArt(g, s, "poster", 0, 0, 170, 255)
        uiProgress(g, 0, 249, 170, libraryNextEpisodeFraction(m.d.episodes[s.id.ToStr()], m.d.states))
        ids = []
        for each e in m.d.episodes[s.id.ToStr()]
            ids.Push(e.id)
        end for
        unwatched = libraryUnwatched(ids, m.d.states)
        if unwatched > 0 then uiBadge(g, unwatched.ToStr() + " new", 160, 10)
        g.removeChild(m.rings[id])
        g.appendChild(m.rings[id])
        name = "Season " + s.seasonNumber.ToStr()
        if s.seasonNumber = 0 then name = "Specials"
        uiLabel(m.top, name, 26, true, "text", sx, y + 317)
        count = m.d.episodes[s.id.ToStr()].Count()
        uiLabel(m.top, count.ToStr() + " episodes", 24, false, "dim", sx, y + 351)
        seasonRow.Push(id)
        sx = sx + 198
    end for
    m.layout = [["play", "watched"], seasonRow]
    if nextEp = invalid then m.layout[0] = ["watched"]
    related = relatedRows(y + 430)
    castRow(y + 430 + related, related > 0)
    m.current = m.layout[0][0]
end sub

sub drawEpisode(item as object)
    still = uiArt(m.top, item, "poster", 96, 96, 640, 360)
    state = m.d.state
    uiProgress(still, 0, 354, 640, libraryResumeFraction({ item: item, state: state, video: false }))
    x = 792
    uiLabel(m.top, itemTitle(m.d.show) + " · Season " + m.d.season.seasonNumber.ToStr(), 28, true, "dim", x, 90)
    number = ""
    if item.episodeNumber <> invalid then number = item.episodeNumber.ToStr() + ". "
    top = titleLines(number + itemTitle(item), 68, x, 130, 1032)
    date = ""
    if item.metadata <> invalid then date = formatDate(item.metadata.releaseDate)
    parts = [{ text: formatRuntime(runtimeOf(item)) }, { text: date }]
    parts.Append(videoTags(m.file))
    if libraryInProgress(state) then parts.Push({ text: formatLeft(runtimeOf(item), state.positionMs), color: "accent" })
    factsLine(parts, x, top)
    row = []
    m.layout = [[]]
    if libraryInProgress(state)
        m.controls.play = uiButton(m.top, "play", "Resume", "p", 0, 0, false, "play")
        m.controls.start = uiButton(m.top, "start", "Start over", "s", 0, 0)
        row = [m.controls.play, m.controls.start]
        m.layout[0] = ["play", "start"]
    else
        m.controls.play = uiButton(m.top, "play", "Play", "p", 0, 0, false, "play")
        row = [m.controls.play]
        m.layout[0] = ["play"]
    end if
    watched = state <> invalid and state.watched
    m.controls.watched = uiButton(m.top, "watched", uiPick(watched, "Mark unwatched", "Mark watched"), "s", 0, 0, false, "check")
    row.Push(m.controls.watched)
    m.layout[0].Push("watched")
    extra = togetherRow(row, x, top + 66, 1000)
    moved = neighborRow(x, top + 162 + extra)
    y = overview(item, x, top + 176 + extra + moved, 1000)
    rows = libraryCrewLines(m.d.credits.crew, m.d.credits.cast, true)
    rows.Append(mediaRows())
    y = facts(rows, x, y, top + 520, extra > 0)
    if m.controls.audio <> invalid then m.layout.Push(["audio"])
    if m.d.upNext.Count() > 0
        upY = top + 536
        if y + 16 > upY then upY = y + 16
        uiLabel(m.top, "Up next", 30, true, "text", 96, upY)
        upRow = []
        for i = 0 to m.d.upNext.Count() - 1
            e = m.d.upNext[i]
            id = "u" + i.ToStr()
            p = uiPanel(m.top, id, 16, 96 + i * 878, upY + 56, 850, 163, "card")
            uiArt(p, e, "poster", 14, 14, 240, 135)
            uiLabel(p, e.episodeNumber.ToStr() + ". " + itemTitle(e), 30, true, "text", 282, 22).width = 540
            uiLabel(p, formatRuntime(runtimeOf(e)), 24, false, "dim", 282, 64)
            uiLabel(p, overviewOf(e), 24, false, "sub", 282, 100).width = 540
            p.removeChild(m.rings[id])
            p.appendChild(m.rings[id])
            upRow.Push(id)
        end for
        m.layout.Push(upRow)
    end if
    if m.current = invalid then m.current = "play"
end sub

sub onAudioChosen(event as object)
    m.audioTrackId = m.audio[event.getData()].id
    closeMenu()
    m.current = "audio"
    reload()
end sub

' The tracks belong to the edition's file, so its audio choice goes.
sub onEditionChosen(event as object)
    m.editionId = m.d.item.editions[event.getData()].id
    m.audioTrackId = invalid
    closeMenu()
    m.current = "edition"
    redraw()
end sub

sub closeMenu()
    if m.menu = invalid then return
    m.top.removeChild(m.menu)
    m.menu = invalid
    uiFocus(m.current)
end sub

sub openAudio()
    options = []
    for each t in m.audio
        options.Push({ label: formatAudio(t), checked: t.id = m.audioTrackId or (m.audioTrackId = invalid and options.Count() = 0), disabled: false })
    end for
    m.menu = m.top.CreateChild("OptionMenu")
    m.menu.heading = "Audio"
    m.menu.options = options
    m.menu.translation = [(1920 - 660) \ 2, 200]
    m.menu.observeFieldScoped("chosen", "onAudioChosen")
    m.menu.observeFieldScoped("cancelled", "closeMenu")
    m.menu.setFocus(true)
end sub

sub openEdition()
    options = []
    for each e in m.d.item.editions
        options.Push({ label: libraryEditionLabel(e), checked: e.id = m.editionId, disabled: false })
    end for
    m.menu = m.top.CreateChild("OptionMenu")
    m.menu.heading = "Edition"
    m.menu.options = options
    m.menu.translation = [(1920 - 660) \ 2, 200]
    m.menu.observeFieldScoped("chosen", "onEditionChosen")
    m.menu.observeFieldScoped("cancelled", "closeMenu")
    m.menu.setFocus(true)
end sub

sub onSelect(id as string)
    item = m.d.item
    if id = "play" and item.kind = "show"
        play(m.d.next)
    else if id = "play"
        togetherPlay(invalid)
    else if id = "start"
        togetherPlay(0)
    else if togetherSelect(id)
        return
    else if id = "watched"
        if item.kind = "show"
            markAll(m.d.item, not m.allWatched)
        else
            markWatched(item, not (m.d.state <> invalid and m.d.state.watched))
        end if
    else if id = "audio"
        openAudio()
    else if id = "edition"
        openEdition()
    else if id = "previous" or id = "next"
        m.top.navigate = m.neighbors[id]
    else if Left(id, 4) = "cast"
        c = m.d.credits.cast[id.Mid(4).ToInt()]
        m.top.navigate = { to: "details", view: "PersonView", person: { id: c.personId, name: c.name } }
    else if Left(id, 3) = "col"
        m.top.navigate = { to: "details", view: "CollectionView", collection: item.collections[id.Mid(3).ToInt()] }
    else if Left(id, 1) = "s"
        m.top.navigate = { to: "details", item: m.d.seasons[id.Mid(1).ToInt()] }
    else if Left(id, 1) = "u"
        m.top.navigate = { to: "details", item: m.d.upNext[id.Mid(1).ToInt()] }
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or m.d = invalid then return false
    if key = "OK" and m.current <> invalid
        onSelect(m.current)
        return true
    end if
    moved = uiArrow(key)
    lift(m.current)
    return moved
end function
