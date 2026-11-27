' params.channel is a YouTubeChannel.
sub init()
    m.top.observeField("focusedChild", "uiRestore")
    m.global.observeFieldScoped("stateVersion", "onStateVersion")
    m.page = invalid
    m.controls = {}
    m.rings = {}
    m.layout = []
end sub

' A popped view stops reloading.
sub onStateVersion()
    if uiDetached() then m.global.unobserveFieldScoped("stateVersion") else load()
end sub

sub load()
    netLoad("channel", { channelId: m.top.params.channel.id }, "onChannel")
end sub

sub onChannel(event as object)
    r = event.getData()
    focused = m.top.isInFocusChain()
    uiClear(m.top)
    batchStop()
    m.controls = {}
    m.rings = {}
    if not r.ok
        m.page = invalid
        uiLabel(m.top, "Couldn't load this: " + r.message, 30, false, "dim", 96, 96)
        ' The focused control is gone; the view keeps focus so Back still works.
        if focused then m.top.setFocus(true)
        return
    end if
    m.channel = r.data.channel
    m.videos = r.data.videos
    today = formatToday()
    m.page = m.top.CreateChild("Group")
    c = m.channel
    uiRound(m.page, c.id, 96, 96, 280, "channel")
    overview = c.overview
    facts = [formatCountOf(c.videoCount, "video"), formatCount(c.unwatchedCount) + " unwatched"]
    if c.lastVideoOn <> invalid then facts.Push("Last video " + formatAgo(c.lastVideoOn, today))
    x = 432
    uiLabel(m.page, c.title, 76, true, "text", x, 90)
    parts = []
    for each f in facts
        parts.Push({ text: f })
    end for
    uiFacts(m.page, parts, x, 192)
    row = []
    m.layout = [[]]
    if m.videos.Count() > 0
        m.controls.play = uiButton(m.page, "play", "Play newest", "p", 0, 0, false, "play")
        row.Push(m.controls.play)
        m.layout[0].Push("play")
    end if
    m.allWatched = c.unwatchedCount = 0
    m.controls.watched = uiButton(m.page, "watched", uiPick(m.allWatched, "Mark all unwatched", "Mark all watched"), "s", 0, 0, false, "check")
    row.Push(m.controls.watched)
    m.layout[0].Push("watched")
    uiRow(row, x, 250, 24)
    if overview <> invalid
        l = uiLabel(m.page, overview, 28, false, "sub", x, 360, 1100)
        l.maxLines = 2
    end if
    if m.videos.Count() > 0 then videoGrid(r.data.rest)
    if m.current = invalid or m.controls[m.current] = invalid then m.current = m.layout[0][0]
    if focused and m.current <> invalid then uiFocus(m.current)
end sub

sub videoGrid(rest as dynamic)
    uiLabel(m.page, "Videos", 30, true, "text", 96, 470)
    m.tileWidth = (1920 - 192 - 3 * 28) \ 4
    m.tileHeight = Int(m.tileWidth * 9 / 16)
    grid = m.page.CreateChild("MarkupGrid")
    grid.itemComponentName = "TileItem"
    grid.numColumns = 4
    grid.numRows = 3
    uiGridLayout(grid, 96, 524, m.tileWidth, m.tileHeight + 80, 28, 36)
    ' Focus stays on the top row, whole on screen, with the next row peeking
    ' below; the last row too comes up to the top.
    grid.vertFocusAnimationStyle = "fixedFocus"
    grid.drawFocusFeedback = false
    root = CreateObject("roSGNode", "ContentNode")
    addTiles(root, m.videos)
    grid.content = root
    grid.observeFieldScoped("itemSelected", "onPick")
    m.controls.grid = grid
    m.layout.Push(["grid"])
    batchStart(grid, rest)
end sub

sub batchRows(rows as object)
    m.videos.Append(rows)
    addTiles(m.controls.grid.content, rows)
end sub

sub addTiles(root as object, videos as object)
    today = formatToday()
    for each v in videos
        t = root.CreateChild("ContentNode")
        t.title = v.title
        t.shortDescriptionLine1 = formatVideoCaption(v, today, false)
        badge = uiPick(v.watched <> invalid and v.watched, "", "dot")
        t.hdPosterUrl = uiArtUrl(v.id, "poster")
        t.addFields({ itemId: v.id, artWidth: m.tileWidth, artHeight: m.tileHeight, badge: badge, glyph: "video" })
    end for
end sub

sub onPick(event as object)
    m.top.navigate = { to: "details", view: "VideoView", video: m.videos[event.getData()] }
end sub

sub onMarked()
    m.global.stateVersion = m.global.stateVersion + 1
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or m.page = invalid then return false
    if key = "OK" and m.current = "play"
        m.top.navigate = { to: "player", item: m.videos[0] }
        return true
    end if
    if key = "OK" and m.current = "watched"
        netCall("putYouTubeChannelWatchState", { profileId: m.global.profileId, channelId: m.channel.id }, {}, { watched: not m.allWatched }, "onMarked")
        return true
    end if
    moved = uiArrow(key)
    ' The page rises to give the grid the screen while it has focus.
    y = 0
    if m.current = "grid" then y = -430
    m.page.translation = [0, y]
    return moved
end function
