' Fixtures follow the WatchTogether schema: Helga (account 2) hosts on her
' iPhone, Joan (account 1) is this TV's profile.
function helga() as object
    return { accountId: uid(2), name: "Helga", role: "host", deviceName: "iPhone", platform: "ios", present: true }
end function

function joan() as object
    return { accountId: uid(1), name: "Joan", role: "guest", deviceName: "Living room", platform: "roku", present: true }
end function

function together(status as string, members as object, playing = false as boolean, positionMs = 0 as integer) as object
    ' In effect from the moment it arrives.
    return { id: uid(7), itemId: uid(41), status: status, members: members, joinMsLeft: 252000, playing: playing, positionMs: positionMs, version: 3, serverTimeMs: 1000, effectiveAtMs: 1000, effectivePositionMs: positionMs }
end function

sub testPickPrefersTheOneTheProfileIsIn()
    mine = together("joined", [helga(), joan()])
    mine.id = uid(8)
    other = together("waiting", [{ accountId: uid(3), name: "Sam", role: "host", deviceName: "Mac", platform: "macos", present: true }])
    assertEqual(togetherPick([other, mine], uid(1)).id, uid(8))
    assertEqual(togetherPick([other], uid(1)).id, uid(7), "someone else's waiting one offers Join")
    assertEqual(togetherPick([together("ended", [joan()])], uid(1)), invalid, "an ended one is none")
    assertEqual(togetherPick([together("joined", [helga(), { accountId: uid(3), name: "Sam", role: "guest" }])], uid(1)), invalid, "two others watching is none")
    assertEqual(togetherPick([], uid(1)), invalid)
end sub

sub testStageFromTheProfilesSide()
    assertEqual(togetherStage(invalid, uid(1)), "none")
    assertEqual(togetherStage(together("waiting", [joan()]), uid(1)), "waiting")
    assertEqual(togetherStage(together("waiting", [helga()]), uid(1)), "join")
    assertEqual(togetherStage(together("joined", [helga(), joan()]), uid(1)), "joined")
    assertEqual(togetherStage(together("ended", [helga(), joan()]), uid(1)), "none")
end sub

sub testNamesTheHostAndTheOtherMember()
    w = together("joined", [helga(), joan()])
    assertEqual(togetherHost(w).name, "Helga")
    assertEqual(togetherOther(w, uid(2)).name, "Joan")
    assertEqual(togetherOther(together("waiting", [joan()]), uid(1)), invalid)
end sub

sub testCountdownRoundsUpAndStopsAtZero()
    w = together("waiting", [helga()])
    assertEqual(togetherCountdown(w, 0), "4:12")
    assertEqual(togetherCountdown(w, 500), "4:12", "a part second still shows")
    assertEqual(togetherCountdown(w, 1000), "4:11")
    assertEqual(togetherCountdown(w, 400000), "0:00")
end sub

sub testNotesAsTheBoardsWriteThem()
    assertEqual(togetherNote(together("waiting", [joan()]), uid(1), "Dune: Part Two", 0), "Someone else who opens Dune: Part Two and chooses Watch together in the next 5 minutes will play in sync with you. Pause and play on either device apply to both.")
    assertEqual(togetherNote(together("waiting", [helga()]), uid(1), "Dune: Part Two", 0), "Helga wants to watch this together. Join in the next 4:12 to play in sync.")
    assertEqual(togetherNote(together("joined", [helga(), joan()]), uid(1), "Dune: Part Two", 0), "Pause and play on either device apply to both. Helga is on iPhone.")
    assertEqual(togetherNote(invalid, uid(1), "Dune: Part Two", 0), "")
end sub

sub testExpectedPositionAdvancesOnlyWhilePlayingFromItsInstant()
    assertEqual(togetherExpected(together("joined", [], true, 60000), 1500), 61500)
    assertEqual(togetherExpected(together("joined", [], false, 60000), 1500), 60000)
    ahead = together("joined", [], true, 60000)
    ahead.effectiveAtMs = 2500
    assertEqual(togetherExpected(ahead, 1000), 60000, "held until its instant")
    assertEqual(togetherExpected(ahead, 1800, 200), 60500, "less the time the answer took to arrive")
end sub

sub testDueCountsToTheInstantOnTheServersClock()
    w = together("joined", [], true, 60000)
    w.effectiveAtMs = 2500
    assertEqual(togetherDue(w, 0, 0), 1500)
    assertEqual(togetherDue(w, 400, 100), 1000)
    assertEqual(togetherDue(w, 2000, 0), -500)
end sub

sub testFollowWaitsForTheInstantThenSeeksPastHalfASecond()
    playing = together("joined", [helga(), joan()], true, 60000)
    assertEqual(togetherFollow(playing, 0, 0, true, 60000), { "play": true, "pause": false, "seekMs": -1, "waitMs": 0, "hold": false })
    assertEqual(togetherFollow(playing, 0, 0, false, 60400), { "play": false, "pause": false, "seekMs": -1, "waitMs": 0, "hold": false }, "0.4 s off stays")
    assertEqual(togetherFollow(playing, 1000, 0, false, 60200), { "play": false, "pause": false, "seekMs": 61000, "waitMs": 0, "hold": false }, "0.8 s behind seeks")
    paused = together("joined", [helga(), joan()], false, 60000)
    assertEqual(togetherFollow(paused, 5000, 0, false, 60300), { "play": false, "pause": true, "seekMs": -1, "waitMs": 0, "hold": false })
    ahead = together("joined", [helga(), joan()], true, 30000)
    ahead.effectiveAtMs = 2500
    assertEqual(togetherFollow(ahead, 0, 100, true, 0), { "play": false, "pause": false, "seekMs": -1, "waitMs": 1400, "hold": false }, "nothing until its instant")
    assertEqual(togetherFollow(together("waiting", [joan()], true, 0), 0, 0, true, 90000), { "play": false, "pause": false, "seekMs": -1, "waitMs": 0, "hold": false }, "nothing to follow until joined")
end sub

sub testAPausedStateSeeksThenHoldsUntilTheSeekPlays()
    paused = together("joined", [helga(), joan()], false, 60000)
    assertEqual(togetherFollow(paused, 5000, 0, false, 65000), { "play": false, "pause": false, "seekMs": 60000, "waitMs": 0, "hold": true }, "playing here")
    assertEqual(togetherFollow(paused, 5000, 0, true, 50000), { "play": false, "pause": false, "seekMs": 60000, "waitMs": 0, "hold": true }, "paused here")
end sub

sub testOnlyALocalChangeIsSent()
    w = together("joined", [helga(), joan()], true, 60000)
    assertTrue(not togetherLocal(w, 0, 0, false, 61500), "following the shared state")
    assertTrue(togetherLocal(w, 0, 0, true, 60500), "the viewer paused")
    assertTrue(togetherLocal(w, 0, 0, false, 90000), "the viewer seeked")
    assertTrue(not togetherLocal(together("waiting", [joan()]), 0, 0, true, 0), "not joined")
    w.effectiveAtMs = 2500
    assertTrue(not togetherLocal(w, 0, 0, true, 60000), "a change still ahead moves this player itself")
end sub

sub testPausedByNamesOnlyTheOtherSide()
    w = together("joined", [helga(), joan()])
    w.pausedById = uid(2)
    w.pausedByName = "Helga"
    assertEqual(togetherPausedBy(w, uid(1)), "Helga paused")
    assertEqual(togetherPausedBy(w, uid(2)), "")
    w.playing = true
    assertEqual(togetherPausedBy(w, uid(1)), "")
end sub

sub testTheOtherSidesPlayOpensThePlayer()
    was = together("joined", [helga(), joan()], false)
    now = together("joined", [helga(), joan()], true)
    assertTrue(togetherStarts(was, now))
    assertTrue(not togetherStarts(now, now), "already playing")
    assertTrue(not togetherStarts(invalid, now), "first seen playing")
    assertTrue(not togetherStarts(together("waiting", [joan()]), together("waiting", [joan()], true)), "not joined")
end sub

sub testAnOlderAnswerIsDropped()
    w = together("joined", [helga(), joan()])
    older = together("joined", [helga(), joan()])
    older.version = 2
    assertTrue(togetherStale(w, older))
    assertTrue(not togetherStale(w, w))
    assertTrue(not togetherStale(invalid, older))
    other = together("waiting", [joan()])
    other.id = uid(9)
    other.version = 1
    assertTrue(not togetherStale(w, other), "another Watch together")
end sub

sub testTheSideAlreadyPlayingSetsTheSharedStateWhenJoined()
    waiting = together("waiting", [helga()])
    joined = together("joined", [helga(), joan()], false, 0)
    assertEqual(togetherArrival(waiting, joined, false, 90000), { playing: true, positionMs: 90000 })
    assertEqual(togetherArrival(waiting, joined, true, 1800000), { playing: false, positionMs: 1800000 }, "paused there stays paused there")
    assertEqual(togetherArrival(joined, joined, false, 90000), invalid, "only on the join")
    assertEqual(togetherArrival(waiting, waiting, false, 90000), invalid, "nobody joined yet")
end sub

' Joan's own iPad and this TV, as "Playing on" pairs them.
function ipad(role as string) as object
    return { accountId: uid(1), name: "Joan", role: role, deviceName: "Kitchen iPad", platform: "ios", present: true, thisDevice: false }
end function

function tv(role as string) as object
    return { accountId: uid(1), name: "Joan", role: role, deviceName: "Living room", platform: "roku", present: true, thisDevice: true }
end function

sub testOneProfileOnTwoDevicesIsAMemberPerDevice()
    waiting = together("waiting", [ipad("host")])
    assertEqual(togetherMember(waiting, uid(1)), invalid, "the iPad waits; this TV is not in it")
    assertEqual(togetherStage(waiting, uid(1)), "join")
    assertEqual(togetherPick([waiting], uid(1)).id, uid(7))
    assertEqual(togetherName(togetherHost(waiting), uid(1)), "Kitchen iPad")
    assertEqual(togetherNote(waiting, uid(1), "Dune", 0), "Kitchen iPad wants to watch this together. Join in the next 4:12 to play in sync.")
    assertEqual(togetherStage(together("waiting", [tv("host")]), uid(1)), "waiting")
    joined = together("joined", [ipad("host"), tv("guest")])
    assertEqual(togetherMember(joined, uid(1)).deviceName, "Living room")
    assertEqual(togetherOther(joined, uid(1)).deviceName, "Kitchen iPad")
    assertEqual(togetherName(togetherOther(joined, uid(1)), uid(1)), "Kitchen iPad")
    assertEqual(togetherNote(joined, uid(1), "Dune", 0), "Pause and play on either device apply to both. Also playing on Kitchen iPad.")
    assertEqual(togetherName(helga(), uid(1)), "Helga")
end sub

sub testTheReportCarriesTheLatestQuickRoundTripAndThePlayersFloor()
    assertEqual(togetherReport(-1), {}, "nothing before a round trip is measured")
    r = togetherReport(35)
    assertEqual(r.Count(), 2)
    assertEqual(r["rttMs"], 35)
    assertEqual(r["floorMs"], 600)
    q = apiRequest("getWatchTogether", { watchTogetherId: 3 }, r)
    assertTrue(Instr(1, q.path, "rttMs=35") > 0, "spelled as the spec spells it: " + q.path)
    assertTrue(Instr(1, q.path, "floorMs=600") > 0, "spelled as the spec spells it: " + q.path)
end sub

sub testAHoldThatRanOutIsAskedAgainAtOnce()
    assertTrue(togetherAsksAgain(true, true, false, 40), "a change")
    assertTrue(togetherAsksAgain(true, false, false, 25000), "a hold that ran out")
    assertTrue(not togetherAsksAgain(true, false, false, 40), "unchanged and quick")
    assertTrue(not togetherAsksAgain(true, false, true, 1500), "a quick sample waits for the tick")
    assertTrue(not togetherAsksAgain(false, true, false, 25000), "a failure waits")
end sub

sub testAChangeAheadOfAnyLengthWaitsForItsInstant()
    w = together("joined", [helga(), joan()], true, 30000)
    w.effectiveAtMs = 1300
    assertEqual(togetherFollow(w, 0, 20, true, 0), { "play": false, "pause": false, "seekMs": -1, "waitMs": 280, "hold": false }, "a lead of 0.3 s")
    assertEqual(togetherFollow(w, 290, 20, true, 0), { "play": true, "pause": false, "seekMs": 30010, "waitMs": 0, "hold": false }, "at its instant it plays and lands on the shared position")
end sub
