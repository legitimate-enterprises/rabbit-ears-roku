sub testAHeldStreamCountsAsPausedBeforeItPlays()
    assertTrue(playerPaused("paused", false), "paused")
    assertTrue(playerPaused("buffering", true), "re-decided while paused, not playing yet")
    assertTrue(not playerPaused("buffering", false), "a stall")
    assertTrue(not playerPaused("playing", false), "playing")
end sub

sub testPositionIsTheStreamsStartUntilItPlays()
    assertEqual(playerPositionMs(4360000, 0), 4360000, "a resumed film still buffering")
    assertEqual(playerPositionMs(0, 0), 0, "from the start")
    assertEqual(playerPositionMs(invalid, 4372.5), 4372500, "playing")
end sub

sub testTheNodesPositionCountsOnceItHasPlayed()
    assertTrue(not playerStarted("buffering", 0), "loading")
    assertTrue(not playerStarted("buffering", 4372.5), "the stream before, still read while the next loads")
    assertTrue(not playerStarted("playing", 0), "playing before its first reading")
    assertTrue(playerStarted("playing", 4372.5), "playing")
    assertTrue(playerStarted("paused", 4372.5), "held to pause as it began")
end sub

sub testUpNextFromAPlaylistPlaysTheAnsweredRowAndKeepsTheRest()
    queue = [{ id: 21 }, { id: 22, editionId: 6 }, { id: 23 }]
    n = playerUpNext({ itemId: 22, editionId: 6, index: 2, item: { id: 22 } }, queue, 0)
    assertEqual(n.item.id, 22, "the row two on, past one skipped")
    assertEqual(n.editionId, 6, "its edition")
    assertEqual(n.index, 2, "its index")
    assertEqual(n.queue.Count(), 1, "the rows after it")
    assertEqual(n.queue[0].id, 23, "the next row")
end sub

sub testUpNextOutsideAPlaylistPlaysTheAnsweredTitle()
    n = playerUpNext({ itemId: 9, kind: "video", video: { id: 9, channelId: 3 } }, [], invalid)
    assertEqual(n.item.channelId, 3, "a video plays as a video")
    assertEqual(n.queue.Count(), 0, "no queue")
    assertTrue(n.index = invalid, "no index")
    n = playerUpNext({ itemId: 8, kind: "episode", item: { id: 8 } }, [], invalid)
    assertEqual(n.item.id, 8, "the episode")
end sub
