' params.item is the season; it opens with focus on the episode in
' progress, else the next one to watch.
sub init()
    m.top.observeField("focusedChild", "uiRestore")
    m.global.observeFieldScoped("stateVersion", "reload")
    m.audioTrackId = invalid
end sub

sub draw()
    season = m.d.item
    m.episodes = m.d.episodes[season.id.ToStr()]
    uiArt(m.top, season, "poster", 96, 96, 280, 420)
    name = "Season " + season.seasonNumber.ToStr()
    if season.seasonNumber = 0 then name = "Specials"
    title = uiLabel(m.top, itemTitle(m.d.show) + " · " + name, 48, true, "text", 96, 540, 560)
    title.maxLines = 2
    y = 540 + Int(title.boundingRect().height) + 12
    unwatched = 0
    for each e in m.episodes
        w = m.d.states[e.id.ToStr()]
        if w = invalid or not w.watched then unwatched = unwatched + 1
    end for
    factsLine([{ text: m.episodes.Count().ToStr() + " episodes" }, { text: unwatched.ToStr() + " unwatched" }, { text: formatYear(season) }], 96, y)
    m.focus = libraryNextEpisode(m.episodes, m.d.states)
    m.allWatched = m.focus < 0
    row = []
    m.layout = [[]]
    if not m.allWatched
        e = m.episodes[m.focus]
        label = "Play E" + e.episodeNumber.ToStr()
        if libraryInProgress(m.d.states[e.id.ToStr()]) then label = "Resume E" + e.episodeNumber.ToStr()
        m.controls.play = uiButton(m.top, "play", label, "p", 0, 0, true, "play")
        row.Push(m.controls.play)
        m.layout[0].Push("play")
    end if
    m.controls.shuffle = uiButton(m.top, "shuffle", "Shuffle", "s", 0, 0, true, "shuffle")
    row.Push(m.controls.shuffle)
    m.layout[0].Push("shuffle")
    uiRow(row, 96, y + 62, 20)
    m.controls.watched = uiButton(m.top, "watched", uiPick(m.allWatched, "Mark all unwatched", "Mark all watched"), "s", 96, y + 142, true)
    m.layout.Push(["watched", "list"])
    overview = overviewOf(season)
    if overview = "" then overview = overviewOf(m.d.show)
    l = uiLabel(m.top, overview, 26, false, "sub", 96, y + 230, 560)
    l.maxLines = 4
    list = m.top.CreateChild("MarkupList")
    list.itemComponentName = "EpisodeItem"
    uiGridLayout(list, 712, 96, 1080, 163, 0, 12)
    list.numRows = 5
    list.vertFocusAnimationStyle = "floatingFocus"
    list.drawFocusFeedback = false
    content = CreateObject("roSGNode", "ContentNode")
    for each e in m.episodes
        c = content.CreateChild("ContentNode")
        state = m.d.states[e.id.ToStr()]
        runtime = runtimeOf(e)
        line = formatRuntime(runtime)
        if e.metadata <> invalid and e.metadata.releaseDate <> invalid then line = line + " · " + formatDate(e.metadata.releaseDate)
        if libraryInProgress(state) then line = line + " · " + formatLeft(runtime, state.positionMs)
        number = ""
        if e.episodeNumber <> invalid then number = e.episodeNumber.ToStr() + ". "
        c.title = number + itemTitle(e)
        c.shortDescriptionLine1 = line
        c.description = overviewOf(e)
        c.hdPosterUrl = uiArtUrl(e.id, "poster")
        c.addFields({ itemId: e.id, watched: state <> invalid and state.watched })
        done = libraryResumeFraction({ item: e, state: state, video: false })
        if done <> invalid then c.addFields({ progress: done })
    end for
    list.content = content
    if m.focus > 0 then list.jumpToItem = m.focus
    list.observeFieldScoped("itemSelected", "onPick")
    m.controls.list = list
    ' The list sits right of the column, so right and left cross between them.
    m.layout[0].Push("list")
    m.current = "list"
end sub

sub onPick(event as object)
    m.top.navigate = { to: "details", item: m.episodes[event.getData()] }
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or m.d = invalid then return false
    if key = "OK" and m.current = "play"
        play(m.episodes[m.focus])
        return true
    end if
    if key = "OK" and m.current = "shuffle"
        shuffle(m.episodes, m.d.show)
        return true
    end if
    if key = "OK" and m.current = "watched"
        markAll(m.d.item, not m.allWatched)
        return true
    end if
    if key = "left" and m.current = "list"
        uiFocus(m.layout[0][0])
        return true
    end if
    return uiArrow(key)
end function
