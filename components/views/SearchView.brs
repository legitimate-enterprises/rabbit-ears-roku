' Searches as the viewer types, after a short pause.
sub init()
    m.top.observeField("focusedChild", "onFocus")
    m.controls = {}
    m.rings = {}
    m.keyboard = m.top.CreateChild("MiniKeyboard")
    m.keyboard.translation = [96, 200]
    m.keyboard.observeFieldScoped("text", "onText")
    m.sections = []
    m.results = m.top.CreateChild("RowList")
    m.results.itemComponentName = "TileItem"
    m.results.numRows = 2
    m.results.itemSize = [1240, 410]
    uiRowsAt(m.results, 680, 200, 18)
    m.results.showRowLabel = [true]
    m.results.rowLabelFont = uiFont(30, true)
    m.results.rowLabelColor = uiColor("text")
    m.results.rowFocusAnimationStyle = "floatingFocus"
    m.results.drawFocusFeedback = false
    m.results.observeFieldScoped("rowItemSelected", "onPick")
    m.none = uiLabel(m.top, "", 30, false, "dim", 680, 200, 1144)
    m.wait = m.top.CreateChild("Timer")
    m.wait.duration = 0.3
    m.wait.observeFieldScoped("fire", "onWait")
    m.controls.keyboard = m.keyboard
    m.controls.results = m.results
    m.layout = [["keyboard", "results"]]
    m.current = "keyboard"
end sub

sub onText()
    m.wait.control = "stop"
    m.wait.control = "start"
end sub

sub onWait()
    q = m.keyboard.text.Trim()
    if q = ""
        netDrop("onFound")
        show([])
        return
    end if
    m.query = q
    netCall("search", {}, { q: q, limit: 20 }, invalid, "onFound")
end sub

sub onFound(event as object)
    r = event.getData()
    if not r.ok then return
    sections = searchSections(r.data)
    show(sections)
    if sections.Count() = 0 then m.none.text = "Nothing matches “" + m.query + "”."
end sub

' One row of tiles for each section, sized by what it holds.
sub show(sections as object)
    m.none.text = ""
    m.sections = sections
    root = CreateObject("roSGNode", "ContentNode")
    sizes = []
    heights = []
    today = formatToday()
    for each s in sections
        row = root.CreateChild("ContentNode")
        row.title = s.title
        w = 220
        h = 330
        if s.kind = "videos"
            w = 400
            h = 225
        else if s.kind <> "movies" and s.kind <> "shows"
            h = 220
        end if
        for each x in s.items
            c = row.CreateChild("ContentNode")
            c.addFields({ itemId: x.id, artWidth: w, artHeight: h, badge: "", glyph: s.kind, round: s.kind = "artists" or s.kind = "channels" or s.kind = "people" })
            art = x.id
            if s.kind = "songs" then art = x.albumId
            c.hdPosterUrl = uiArtUrl(art, "poster")
            if s.kind = "people"
                c.hdPosterUrl = uiPersonArtUrl(x.id)
                c.addFields({ tint: formatPersonColor(x.id) })
                c.title = x.name
            else if s.kind = "artists"
                c.title = x.name
                c.shortDescriptionLine1 = formatCountOf(x.albumCount, "album")
            else if s.kind = "channels"
                c.title = x.title
                c.shortDescriptionLine1 = formatCountOf(x.videoCount, "video")
            else if s.kind = "videos"
                c.title = x.title
                c.shortDescriptionLine1 = formatVideoCaption(x, today, true)
                done = libraryResumeFraction({ item: x, state: x, video: true })
                if done <> invalid then c.addFields({ progress: done })
            else if s.kind = "albums" or s.kind = "songs"
                c.title = x.title
                c.shortDescriptionLine1 = x.artistName
            else
                c.title = itemTitle(x)
                c.shortDescriptionLine1 = formatYear(x)
                if x.kind = "episode" then c.shortDescriptionLine1 = formatEpisodeCode(x)
            end if
        end for
        sizes.Push([w, h + 80])
        heights.Push(h + 150)
    end for
    m.results.rowItemSize = uiRowSizes(sizes)
    m.results.rowHeights = heights
    m.results.content = root
end sub

sub onPick(event as object)
    at = event.getData()
    s = m.sections[at[0]]
    x = s.items[at[1]]
    if s.kind = "songs"
        m.global.music.command = { op: "play", songs: s.items, index: at[1], from: "Search", shuffle: false, playlistId: invalid }
        return
    end if
    views = { artists: ["ArtistView", "artist"], albums: ["AlbumView", "album"], channels: ["ChannelView", "channel"], videos: ["VideoView", "video"], people: ["PersonView", "person"] }
    v = views[s.kind]
    if v = invalid
        m.top.navigate = { to: "details", item: x }
    else
        n = { to: "details", view: v[0] }
        n[v[1]] = x
        m.top.navigate = n
    end if
end sub

sub onFocus()
    uiBlur()
    if m.top.hasFocus() then uiFocus(m.current)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    ' An empty list would hold focus without drawing a ring.
    if key = "right" and m.sections.Count() = 0 then return true
    return uiArrow(key)
end function
