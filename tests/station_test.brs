' Instants are UTC; the runner sets the local zone to New York.

function stationMovie(title as string, startsAt as string, endsAt as string) as object
    return { itemId: 41, editionId: 9, kind: "movie", startsAt: startsAt, endsAt: endsAt, durationMs: 6000000, item: { id: 41, parsedTitle: LCase(title), metadata: { title: title } } }
end function

function stationSong(title as string, startsAt as string) as object
    return { itemId: 77, editionId: 77, kind: "song", startsAt: startsAt, endsAt: startsAt, durationMs: 215000, song: { id: 77, albumId: 12, title: title } }
end function

sub testOnAirSaysWhatIsOnAndWhatIsNextInLocalTime()
    onAir = { status: "on_air", positionMs: 4328000, now: stationMovie("The Lantern Keeper", "2026-11-13T19:00:00Z", "2026-11-13T20:52:00Z"), next: stationMovie("Salt and Ember", "2026-11-13T21:00:00Z", "2026-11-13T22:40:00Z") }
    assertEqual(stationLines("movies", onAir), ["On now: The Lantern Keeper", "Next: Salt and Ember at 4:00 PM"])
    onAir.Delete("next")
    assertEqual(stationLines("movies", onAir), ["On now: The Lantern Keeper"], "nothing more scheduled")
end sub

sub testBetweenProgramsSaysWhatIsNext()
    onAir = { status: "between_programs", next: stationMovie("Moon Pie", "2026-11-13T21:00:00Z", "2026-11-13T22:30:00Z") }
    assertEqual(stationLines("tv", onAir), ["Up next at 4:00 PM: Moon Pie"])
    assertEqual(stationLines("tv", { status: "between_programs" }), [], "nothing scheduled")
end sub

sub testOffScheduleSaysWhenItIsBack()
    onAir = { status: "off_schedule", next: stationMovie("Moon Pie", "2026-11-21T03:00:00Z", "2026-11-21T04:30:00Z") }
    assertEqual(stationLines("movies", onAir), ["Back Friday at 10:00 PM"])
    assertEqual(stationLines("music", onAir), ["Back Friday at 10:00 PM"], "music keeps the time")
end sub

sub testMusicNextHasNoTime()
    onAir = { status: "on_air", now: stationSong("Paper Lanterns", "2026-11-13T21:00:00Z"), next: stationSong("Slow Tide", "2026-11-13T21:03:38Z") }
    assertEqual(stationLines("music", onAir), ["On now: Paper Lanterns", "Next: Slow Tide"])
end sub

sub testClockIsTheDevicesLocalTimeOfThatInstant()
    assertEqual(stationClock("2026-07-03T20:00:00Z"), "4:00 PM", "daylight time")
    assertEqual(stationClock("2026-11-14T05:00:00Z"), "12:00 AM")
    assertEqual(stationClock("2026-11-14T17:05:00Z"), "12:05 PM")
    assertEqual(stationClock("2026-11-14T15:30:00.000Z"), "10:30 AM", "fractional seconds")
end sub

sub testProgramTitleIsThePlaylistRowsTitle()
    movie = stationMovie("Glass Orchard", "2026-11-13T19:00:00Z", "2026-11-13T21:00:00Z")
    movie.editionName = "Extended"
    assertEqual(stationLines("movies", { status: "on_air", now: movie }), ["On now: Glass Orchard · Extended"])
end sub

sub testArtIsWhatIsOnElseWhatIsNextElseNone()
    now = stationMovie("The Lantern Keeper", "2026-11-13T19:00:00Z", "2026-11-13T20:52:00Z")
    upcoming = { itemId: 52, editionId: 52, kind: "episode", startsAt: "2026-11-13T21:00:00Z", endsAt: "2026-11-13T21:30:00Z", durationMs: 1500000, item: { id: 52, parsedTitle: "Pilot" } }
    assertEqual(stationArt({ status: "on_air", now: now, next: upcoming }), { id: 41, kind: "backdrop" })
    assertEqual(stationArt({ status: "between_programs", next: upcoming }), { id: 52, kind: "poster" })
    assertEqual(stationArt({ status: "on_air", now: stationSong("Paper Lanterns", "2026-11-13T21:00:00Z") }), { id: 12, kind: "poster" }, "a song's album")
    assertEqual(stationArt({ status: "off_schedule" }), invalid)
end sub

sub testTunedInPlaysUntilTheProgramEnds()
    now = stationSeconds("2026-11-13T20:00:00Z")
    onAir = { status: "on_air", positionMs: 3600000, now: stationMovie("The Lantern Keeper", "2026-11-13T19:00:00Z", "2026-11-13T20:52:00Z"), next: stationMovie("Salt and Ember", "2026-11-13T21:00:00Z", "2026-11-13T22:40:00Z") }
    p = stationNext("movies", { stream: { sessionId: 3, positionMs: 3600000 }, onAir: onAir }, now)
    assertEqual(p, { mode: "on_air", askIn: 52 * 60, lines: ["On now: The Lantern Keeper", "Next: Salt and Ember at 4:00 PM"] })
end sub

sub testBetweenProgramsAsksAgainAtResumesAt()
    now = stationSeconds("2026-11-13T20:52:00Z")
    onAir = { status: "between_programs", next: stationMovie("Salt and Ember", "2026-11-13T21:00:00Z", "2026-11-13T22:40:00Z") }
    p = stationNext("movies", { onAir: onAir, resumesAt: "2026-11-13T21:00:00Z" }, now)
    assertEqual(p, { mode: "between_programs", askIn: 8 * 60, lines: ["Up next at 4:00 PM: Salt and Ember"] })
end sub

sub testOffScheduleAsksAgainAtResumesAt()
    now = stationSeconds("2026-11-15T17:00:00Z")
    onAir = { status: "off_schedule", next: stationMovie("Moon Pie", "2026-11-21T03:00:00Z", "2026-11-21T04:30:00Z") }
    p = stationNext("movies", { onAir: onAir, resumesAt: "2026-11-21T03:00:00Z" }, now)
    assertEqual(p, { mode: "off_schedule", askIn: stationSeconds("2026-11-21T03:00:00Z") - now, lines: ["Back Friday at 10:00 PM"] })
end sub

sub testNothingScheduledNeverAsksAgain()
    p = stationNext("tv", { onAir: { status: "between_programs" } }, stationSeconds("2026-11-15T17:00:00Z"))
    assertEqual(p, { mode: "between_programs", askIn: -1, lines: [] })
end sub

sub testAPassedInstantAsksAgainInASecond()
    now = stationSeconds("2026-11-13T21:00:05Z")
    onAir = { status: "between_programs", next: stationMovie("Salt and Ember", "2026-11-13T21:00:00Z", "2026-11-13T22:40:00Z") }
    assertEqual(stationNext("movies", { onAir: onAir, resumesAt: "2026-11-13T21:00:00Z" }, now).askIn, 1, "a slow device clock never asks in a loop")
    onAir = { status: "on_air", now: stationMovie("The Lantern Keeper", "2026-11-13T19:00:00Z", "2026-11-13T20:52:00Z") }
    assertEqual(stationNext("movies", { stream: {}, onAir: onAir }, now).askIn, 1)
end sub

sub testATuneInTheServerCouldNotAnswerIsAskedAgainSoon()
    assertEqual(stationRetryIn(apiResult(502, "<html>502 Bad Gateway</html>")), 5, "a failing server")
    assertEqual(stationRetryIn(apiResult(-28, "")), 5, "out of reach")
    assertEqual(stationRetryIn(apiResult(404, "{""code"": ""not_found"", ""message"": ""no""}")), -1, "a station gone")
    assertEqual(stationRetryIn(apiResult(403, "{""code"": ""forbidden"", ""message"": ""no""}")), -1, "refused")
end sub

sub testTransportKeysDoNothingOnAStation()
    for each key in ["play", "rewind", "fastforward", "replay"]
        assertTrue(stationIgnores(key), key)
    end for
    for each key in ["OK", "back", "left", "right", "up", "down", "options"]
        assertTrue(not stationIgnores(key), key)
    end for
end sub

sub testMusicUpNextIsEveryProgramAfterNowInOrder()
    first = stationSong("Slow Tide", "2026-11-13T21:03:38Z")
    second = stationSong("Tin Roof Weather", "2026-11-13T21:07:19Z")
    second.song.id = 78
    onAir = { status: "on_air", now: stationSong("Paper Lanterns", "2026-11-13T21:00:00Z"), next: first, upNext: [first, second] }
    assertEqual(stationUpNext(onAir), [first.song, second.song])
    assertEqual(stationUpNext({ status: "off_schedule", upNext: [] }), [], "nothing scheduled")
end sub

sub testHomesOnNowTileNamesTheStationWithItsKind()
    assertEqual(stationOnNowName({ kind: "movies", name: "Marvel" }), "Movies: Marvel")
    assertEqual(stationOnNowName({ kind: "tv", name: "Cartoons" }), "TV: Cartoons")
    assertEqual(stationOnNowName({ kind: "music", name: "Kitchen Radio" }), "Music: Kitchen Radio")
end sub

sub testHomesOnNowBarIsTheLivePositionOverTheProgramsLength()
    now = stationMovie("The Lantern Keeper", "2026-11-13T19:00:00Z", "2026-11-13T20:52:00Z")
    now.durationMs = 6000000
    assertEqual(stationOnNowProgress({ status: "on_air", positionMs: 1500000, now: now }), 0.25)
    assertEqual(stationOnNowProgress({ status: "on_air", positionMs: 9000000, now: now }), 1.0, "never past the end")
    assertEqual(stationOnNowProgress({ status: "on_air", now: now }), invalid, "no position")
    assertEqual(stationOnNowProgress({ status: "between_programs", next: now }), invalid, "no program on")
    now.durationMs = 0
    assertEqual(stationOnNowProgress({ status: "on_air", positionMs: 0, now: now }), invalid, "no length")
end sub
