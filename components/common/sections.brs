' Rows of tiles, one per section of items, as searchSections gives them,
' shared by Search and Favorites. A tile opens its details; a song plays
' its section from it.

' The rows at x, w wide, under the bar; from names where a song plays from.
sub sectionsInit(x as integer, w as integer, from as string)
    m.sections = []
    m.states = {}
    m.from = from
    m.results = m.top.CreateChild("RowList")
    m.results.itemComponentName = "TileItem"
    m.results.numRows = 2
    m.results.itemSize = [w, 410]
    uiRowsAt(m.results, x, 200, 18)
    m.results.showRowLabel = [true]
    m.results.rowLabelFont = uiFont(30, true)
    m.results.rowLabelColor = uiColor("text")
    m.results.rowFocusAnimationStyle = "floatingFocus"
    m.results.drawFocusFeedback = false
    m.results.observeFieldScoped("rowItemSelected", "onPick")
    m.none = uiLabel(m.top, "", 30, false, "dim", x, 200, w - 96)
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
            c.hdPosterUrl = uiArtUrl(x, "poster", art)
            if s.kind = "people"
                c.hdPosterUrl = uiPersonArtUrl(x, x.id)
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
                ' Favorites name a season's or episode's show, as showTitle.
                if x.kind = "episode" and x.showTitle <> invalid then c.shortDescriptionLine1 = x.showTitle + " · " + c.shortDescriptionLine1
                if x.kind = "season" and x.showTitle <> invalid
                    c.title = x.showTitle
                    c.shortDescriptionLine1 = uiPick(x.seasonNumber = 0, "Specials", "Season " + x.seasonNumber.ToStr())
                end if
                done = libraryResumeFraction({ item: x, state: m.states[x.id.ToStr()], video: false })
                if done <> invalid then c.addFields({ progress: done })
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
        m.global.music.command = { op: "play", songs: s.items, index: at[1], from: m.from, shuffle: false, playlistId: invalid }
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
