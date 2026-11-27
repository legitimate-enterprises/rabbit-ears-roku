' Fixtures follow the EventPage and PlaybackSession schemas; this TV is
' device 4, its player's session 7.
function answer(cursor as string, events as object, resync = false as boolean) as object
    return { ok: true, status: 200, data: { cursor: cursor, resync: resync, events: events } }
end function

function failure(status as integer) as object
    return { ok: false, status: status, data: invalid }
end function

function session(id as integer, thisDevice as boolean, positionMs as integer) as object
    return { id: id, itemId: 20, deviceId: 9, deviceName: "Kitchen iPad", platform: "ios", thisDevice: thisDevice, positionMs: positionMs }
end function

sub testAnAnswerMovesTheCursorAndTellsItsEvents()
    took = liveStep({ cursor: "", waitMs: 4000 }, answer("3.0", []))
    assertEqual(took.state, { cursor: "3.0", waitMs: 1000 })
    assertEqual(took.events, invalid, "a first answer or a hold run out tells nothing")
    assertEqual(took.waitMs, 0)
    assertTrue(not took.done)
    took = liveStep(took.state, answer("3.2", [{ kind: "watch_state", itemId: 20 }, { kind: "station", stationId: 4 }]))
    assertEqual(took.state.cursor, "3.2")
    assertEqual(took.events.Count(), 2)
    took = liveStep(took.state, answer("5.0", [], true))
    assertEqual(took.events, [], "a resync tells an empty batch: everything loads again")
end sub

sub testAFailureWaitsLongerEachTimeFromTheSameCursor()
    state = { cursor: "3.2", waitMs: 1000 }
    waits = []
    for i = 1 to 7
        took = liveStep(state, failure(503))
        waits.Push(took.waitMs)
        state = took.state
    end for
    assertEqual(waits, [1000, 2000, 4000, 8000, 16000, 30000, 30000])
    assertEqual(state.cursor, "3.2")
    assertEqual(liveStep(state, failure(-28)).waitMs, 30000, "the server not reached is tried again")
    assertTrue(not liveStep(state, failure(0)).done)
end sub

sub testSignedOutLockedOrAServerWithoutTheStreamStops()
    for each status in [401, 403, 404]
        assertTrue(liveStep({ cursor: "3.2", waitMs: 1000 }, failure(status)).done, status.ToStr())
    end for
end sub

sub testAPollAlsoAsksForFinishedScansAndHouseholdChanges()
    assertEqual(liveQuery(""), { kinds: ["library", "household"] })
    assertEqual(liveQuery("3.2"), { kinds: ["library", "household"], after: "3.2" })
    assertEqual(apiRequest("listEvents", {}, liveQuery("3.2")).path, "/api/v2/events?after=3.2&kinds=library&kinds=household")
    assertTrue(liveMoves([{ kind: "library", libraryId: 2 }], 4), "a scan reloads the views")
end sub

sub testABatchReloadsTheViewsUnlessItIsThisDevicesOwnPlayback()
    assertTrue(liveMoves([], 4), "a resync")
    assertTrue(liveMoves([{ kind: "watch_state", itemId: 20 }], 4))
    assertTrue(liveMoves([{ kind: "station", stationId: 2 }], 4))
    assertTrue(liveMoves([{ kind: "playlist", playlistId: 2 }], 4))
    assertTrue(liveMoves([{ kind: "playback", change: "ended", sessionId: 8, deviceId: 9, itemId: 20 }], 4), "another device stopped")
    assertTrue(not liveMoves([{ kind: "playback", change: "started", sessionId: 8, deviceId: 9 }], 4), "a start moves no watch state")
    assertTrue(not liveMoves([{ kind: "playback", change: "ended", sessionId: 7, deviceId: 4 }], 4), "the app reloads after its own playback")
    assertTrue(not liveMoves([{ kind: "watch_together", change: "opened", watchTogetherId: 5 }], 4), "details asks for those itself")
end sub

sub testAHouseholdChangeDoesNotReloadTheViews()
    assertTrue(not liveMoves([{ kind: "household" }], 4), "the app reads /me and acts on a moved flag")
    assertTrue(liveMoves([{ kind: "household" }, { kind: "station", stationId: 2 }], 4), "another kind in the batch still does")
    assertTrue(liveNames([{ kind: "household" }], "household"))
    assertTrue(liveNames([], "household"), "a resync reads /me again")
end sub

sub testOnlyAMovedHideFlagOfTheActiveProfileRebuildsTheTabs()
    bea = { id: 1, kind: "adult", hideKidsContent: false }
    jason = { id: 2, kind: "kid" }
    was = { activeProfileId: 1, profiles: [bea, jason] }
    hid = { activeProfileId: 1, profiles: [{ id: 1, kind: "adult", hideKidsContent: true }, jason] }
    assertTrue(liveHideMoved(was, hid), "hidden elsewhere")
    assertTrue(liveHideMoved(hid, was), "shown elsewhere")
    assertTrue(not liveHideMoved(was, { activeProfileId: 1, profiles: [bea, { id: 2, kind: "kid", name: "Jackson" }] }), "another change in the household")
    other = { activeProfileId: 2, profiles: [{ id: 1, kind: "adult", hideKidsContent: true }, jason] }
    assertTrue(not liveHideMoved(was, other), "another active profile boots, not rebuilds")
    elsewhere = { activeProfileId: 1, profiles: [bea, { id: 3, kind: "adult", hideKidsContent: true }] }
    assertTrue(not liveHideMoved(was, elsewhere), "another adult's flag")
end sub

sub testNamesAKind()
    assertTrue(liveNames([{ kind: "station" }, { kind: "watch_together", change: "opened" }], "watch_together"))
    assertTrue(not liveNames([{ kind: "station" }], "watch_together"))
    assertTrue(liveNames([], "watch_together"), "a resync names every kind")
end sub

sub testThePlayerHearsOnlyOfItsOwnSession()
    moved = { kind: "playback", change: "moved", sessionId: 7, deviceId: 4, itemId: 20 }
    ended = { kind: "playback", change: "ended", sessionId: 7, deviceId: 4, itemId: 20 }
    opened = { kind: "watch_together", change: "opened", watchTogetherId: 5, sessionId: 7 }
    assertTrue(liveMoved([ended, moved], 7))
    assertTrue(not liveMoved([moved], 8))
    assertTrue(not liveMoved([ended, opened, { kind: "station" }], 7))
    assertEqual(liveAsked([moved, opened], 7), 5)
    assertEqual(liveAsked([opened], 8), invalid)
    assertEqual(liveAsked([{ kind: "watch_together", change: "joined", watchTogetherId: 5, sessionId: 7 }], 7), invalid)
end sub

sub testATitlePlayingOnAnotherDeviceIsAskedAbout()
    there = liveElsewhere([session(3, true, 1000), session(9, false, 2472000)])
    assertEqual(there.id, 9)
    assertEqual(liveTitle(there), "Playing on Kitchen iPad at 41:12")
    assertEqual(liveElsewhere([session(3, true, 1000)]), invalid, "this TV's own session is not asked about")
    assertEqual(liveElsewhere([]), invalid)
end sub

sub testMoveHereComesFirstAndEveryProfileIsOfferedWatchTogether()
    assertEqual(liveChoices(), ["Move here", "Watch together", "Cancel"])
end sub
