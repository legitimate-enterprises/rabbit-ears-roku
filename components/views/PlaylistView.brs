' params.list is a Playlist of movies, tv or music. Each entry is one row,
' a container too; Play and a row play the play order, which the server
' expands and this view reads whole, from the top or from that entry.
sub init()
    m.top.observeField("focusedChild", "uiRestore")
    m.page = m.top
    m.list = invalid
    m.starting = false
    m.controls = {}
    m.rings = {}
    m.layout = []
end sub

sub load()
    list = m.top.params.list
    m.music = list.kind = "music"
    if m.music then m.global.music.observeFieldScoped("now", "onNow")
    args = { op: "listPlaylistEntries", params: { profileId: m.global.profileId, playlistId: list.id }, query: {} }
    if not m.music then args.statesFor = m.global.profileId
    netLoad("list", args, "onEntries")
end sub

sub onEntries(event as object)
    r = event.getData()
    if not r.ok
        uiLabel(m.top, "Couldn't load this: " + r.message, 30, false, "dim", 96, 96)
        return
    end if
    list = m.top.params.list
    m.entries = r.data
    m.states = {}
    if r.states <> invalid then m.states = r.states
    art = list.artItemId
    if art = invalid then art = list.id
    url = ""
    if list.imageUrl <> invalid then url = m.global.server + list.imageUrl
    uiArt(m.top, { id: art }, "poster", 96, 96, 360, 360, url, "playlist")
    title = uiLabel(m.top, list.name, 60, true, "text", 96, 476, 560)
    title.maxLines = 2
    y = 476 + Int(title.boundingRect().height) + 12
    uiFacts(m.top, [{ text: playlistCaption(list) }, { text: formatDuration(list.durationMs) }], 96, y)
    if m.entries.Count() = 0
        uiLabel(m.top, "Nothing in this playlist yet.", 28, false, "dim", 704, 196)
        return
    end if
    buttons = [uiButton(m.top, "play", "Play", "p", 0, 0, true, "play")]
    m.controls.play = buttons[0]
    if m.music
        m.controls.shuffle = uiButton(m.top, "shuffle", "Shuffle", "s", 0, 0, true, "shuffle")
        buttons.Push(m.controls.shuffle)
    end if
    uiRow(buttons, 96, y + 56, 20)
    m.notice = uiLabel(m.top, "", 26, false, "dim", 96, y + 160, 560)
    m.list = m.top.CreateChild("MarkupList")
    m.list.itemComponentName = "EntryItem"
    uiGridLayout(m.list, 704, 196, 1128, 96, 0, 6)
    m.list.numRows = 8
    m.list.vertFocusAnimationStyle = "floatingFocus"
    m.list.drawFocusFeedback = false
    m.list.observeFieldScoped("itemSelected", "onEntry")
    m.controls.entries = m.list
    root = CreateObject("roSGNode", "ContentNode")
    addRows(root, m.entries)
    m.list.content = root
    batchStart(m.list, r.rest)
    if m.music then nowChip()
    m.current = "play"
    onNow()
    if m.top.isInFocusChain() then uiFocus(m.current)
end sub

sub batchRows(rows as object)
    m.entries.Append(rows)
    addRows(m.list.content, rows)
end sub

sub addRows(root as object, entries as object)
    for each e in entries
        c = root.CreateChild("ContentNode")
        c.title = playlistEntryTitle(e)
        c.shortDescriptionLine1 = playlistEntryCaption(e)
        artId = playlistEntryArtId(e)
        c.hdPosterUrl = uiArtUrl(artId, "poster")
        if e.collectionId <> invalid then c.hdPosterUrl = uiCollectionArtUrl(artId, "poster")
        glyph = "movie"
        if e.collectionId <> invalid then glyph = "collection"
        if e.song <> invalid then glyph = "album"
        c.addFields({ itemId: artId, rowWidth: 1128, glyph: glyph })
        ' A container's row plays its play order, whose first title the entry does not name.
        if e.item <> invalid and (e.kind = "movie" or e.kind = "episode")
            done = libraryResumeFraction({ item: e.item, state: m.states[e.itemId.ToStr()], video: false })
            if done <> invalid then c.addFields({ progress: done })
        end if
    end for
end sub

' The chip rides above the entries while music plays.
sub onNow()
    if uiDetached()
        m.global.music.unobserveFieldScoped("now")
        return
    end if
    if m.list = invalid then return
    row = ["play"]
    if m.music then row.Push("shuffle")
    row.Push("entries")
    m.layout = [row]
    if m.music and m.global.music.now.song <> invalid
        m.layout = [["chip"], row]
    else if m.current = "chip"
        m.current = "play"
        if m.top.isInFocusChain() then uiFocus("play")
    end if
end sub

' entryId invalid plays from the top.
sub play(entryId as dynamic, shuffle as boolean)
    if m.starting then return
    m.starting = true
    m.entryId = entryId
    m.shuffle = shuffle
    m.notice.text = ""
    netLoad("playOrder", { profileId: m.global.profileId, playlistId: m.top.params.list.id }, "onOrder")
end sub

sub onOrder(event as object)
    m.starting = false
    r = event.getData()
    if not r.ok
        m.notice.text = "Couldn't play: " + r.message
        return
    end if
    order = playOrderFrom(r.data, m.entryId)
    count = order.playables.Count()
    if count = 0 then return
    list = m.top.params.list
    if m.music
        at = order.index
        if m.shuffle then at = Rnd(count) - 1
        playSongs(order.playables, at, list.name, m.shuffle, list.id)
        return
    end if
    queue = []
    for i = order.index + 1 to count - 1
        queue.Push(order.playables[i])
    end for
    first = order.playables[order.index]
    m.top.navigate = { to: "player", item: first, editionId: first.editionId, queue: queue, playlistId: list.id, index: order.index }
end sub

sub onEntry(event as object)
    play(m.entries[event.getData()].id, false)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or m.list = invalid then return false
    if key = "OK" and m.current = "play"
        play(invalid, false)
    else if key = "OK" and m.current = "shuffle"
        play(invalid, true)
    else if key = "OK" and m.current = "chip"
        openNowPlaying()
    else
        return uiArrow(key)
    end if
    return true
end function
