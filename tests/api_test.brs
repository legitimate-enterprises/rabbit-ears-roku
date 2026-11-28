sub testOperationsNameMethodAndPath()
    ops = apiOperations()
    for each name in ops
        op = ops[name]
        assertEqual(op.Count(), 2, name)
        assertTrue(Left(op[1], 1) = "/", name + " path")
    end for
end sub

sub testServerBaseAddsSchemeAndDefaultPort()
    assertEqual(apiServerBase("192.168.1.20"), "http://192.168.1.20:8477")
    assertEqual(apiServerBase(" 192.168.1.20:9000 "), "http://192.168.1.20:9000")
    assertEqual(apiServerBase("https://rabbit.example.com/"), "https://rabbit.example.com")
    assertEqual(apiServerBase("http://rabbit.example.com:8080"), "http://rabbit.example.com:8080")
    assertEqual(apiServerBase("  "), "")
end sub

sub testOnlyReadingLoadsMayBeCancelled()
    assertTrue(apiLoadReads("home"), "home")
    assertTrue(apiLoadReads("details"), "details")
    assertTrue(not apiLoadReads("markAll"), "markAll writes")
    assertTrue(not apiLoadReads("update"), "update writes")
    assertTrue(not apiLoadReads("play"), "play starts a session")
end sub

sub testPlainHttpOnlyReachesTheLocalNetwork()
    assertTrue(apiSecure("https://media.example.com"), "https anywhere")
    assertTrue(apiSecure("http://192.168.1.20:8477"), "private")
    assertTrue(apiSecure("http://10.0.0.1:8477"), "private 10/8")
    assertTrue(apiSecure("http://172.31.0.5:8477"), "private 172.16/12")
    assertTrue(apiSecure("http://169.254.3.4:8477"), "link-local")
    assertTrue(apiSecure("http://127.0.0.1:8477"), "loopback")
    assertTrue(apiSecure("http://localhost:8477"), "localhost")
    assertTrue(apiSecure("http://Den-Mac.local:8477"), "mDNS")
    assertTrue(apiSecure("http://[::1]:8477"), "IPv6 loopback")
    assertTrue(apiSecure("http://[fd12:3456::1]:8477"), "IPv6 unique local")
    assertTrue(apiSecure("http://[fe80::1]:8477"), "IPv6 link-local")
    assertTrue(not apiSecure("http://media.example.com:8477"), "public name")
    assertTrue(not apiSecure("http://8.8.8.8:8477"), "public address")
    assertTrue(not apiSecure("http://172.32.0.5:8477"), "outside 172.16/12")
    assertTrue(not apiSecure("http://10.0.0.1.example.com:8477"), "a name that starts like an address")
    assertTrue(not apiSecure("http://192.168.1.300:8477"), "not an address")
    assertTrue(not apiSecure("http://media.example.com/x.local"), "a path is not the host")
    assertTrue(not apiSecure("http://192.168.1.20@media.example.com"), "user info is not the host")
    assertTrue(not apiSecure("http://[2001:db8::1]:8477"), "public IPv6")
    assertTrue(not apiSecure("http://[fd12::1"), "unclosed IPv6")
    assertTrue(not apiSecure(""), "no server")
end sub

sub testALocalAddressIsLocalOverEitherScheme()
    assertTrue(apiLocal("https://192.168.1.20:8477"), "https at home")
    assertTrue(apiLocal("http://Den-Mac.local:8477"), "mDNS")
    assertTrue(not apiLocal("https://media.example.com"), "a public name")
end sub

sub testRequestSubstitutesPathParams()
    r = apiRequest("getWatchState", { profileId: 3, itemId: 41 })
    assertEqual(r.method, "GET")
    assertEqual(r.path, "/api/v2/profiles/3/watch-state/41")
    assertEqual(r.body, "")
end sub

sub testRequestQueryIsSortedAndEncoded()
    r = apiRequest("listItems", {}, { q: "Dune: Part Two", limit: 50, kind: "movie" })
    assertEqual(r.path, "/api/v2/items?kind=movie&limit=50&q=Dune%3A%20Part%20Two")
end sub

sub testAnArrayQueryValueIsARepeatedParameter()
    r = apiRequest("listEvents", {}, { kinds: ["library", "household"], after: "3.2" })
    assertEqual(r.path, "/api/v2/events?after=3.2&kinds=library&kinds=household")
end sub

sub testHideKidsContentSavesOnTheProfilePreferences()
    r = apiRequest("setProfilePreferences", { profileId: 3 }, {}, { hideKidsContent: true })
    assertEqual(r.method, "PUT")
    assertEqual(r.path, "/api/v2/profiles/3/preferences")
    assertEqual(r.body, "{" + Chr(34) + "hideKidsContent" + Chr(34) + ":true}", "spelled as the spec spells it")
end sub

sub testListItemsAsksForKidsContentByTheSpecsName()
    r = apiRequest("listItems", {}, { kind: "movie", kidsContent: true })
    assertEqual(r.path, "/api/v2/items?kidsContent=true&kind=movie")
end sub

sub testRequestPollTokenInQuery()
    r = apiRequest("pollDeviceLink", { linkId: 7 }, { token: "a/b+c" })
    assertEqual(r.path, "/api/v2/device-links/7?token=a%2Fb%2Bc")
end sub

sub testRequestBodyIsJson()
    r = apiRequest("signIn", {}, {}, { email: "a@example.com", password: "pw", deviceName: "Living room", platform: "roku" })
    assertEqual(r.method, "POST")
    assertEqual(r.path, "/api/v2/auth/sign-in")
    assertEqual(ParseJson(r.body), { deviceName: "Living room", email: "a@example.com", password: "pw", platform: "roku" })
end sub

sub testRequestRefusesUnknownOperationAndMissingParam()
    assertEqual(apiRequest("nope"), invalid, "unknown")
    assertEqual(apiRequest("getItem", {}), invalid, "missing itemId")
end sub

sub testResultParsesSuccess()
    r = apiResult(200, "{""id"": 5, ""kind"": ""movie""}")
    assertTrue(r.ok)
    assertEqual(r.data.kind, "movie")
end sub

sub testResultNoContent()
    r = apiResult(204, "")
    assertTrue(r.ok)
    assertEqual(r.data, invalid)
end sub

sub testResultUnreadableSuccessBodyIsAFailure()
    r = apiResult(200, "<html>sign in to this network</html>")
    assertEqual([r.ok, r.status, r.data, r.code, r.message], [false, 200, invalid, "http", "The server's answer could not be read."])
end sub

sub testResultCarriesErrorCode()
    r = apiResult(403, "{""code"": ""pin_locked"", ""message"": ""too many wrong PINs; try again later""}")
    assertTrue(not r.ok)
    assertEqual(r.status, 403)
    assertEqual(r.code, "pin_locked")
end sub

sub testResultUnreadableErrorBody()
    r = apiResult(502, "<html>bad gateway</html>")
    assertTrue(not r.ok)
    assertEqual(r.code, "http")
end sub

sub testResultNetworkFailure()
    r = apiResult(-28, "")
    assertTrue(not r.ok)
    assertEqual(r.code, "network")
end sub

sub testTooManyAttemptsSaysWhenToTryAgain()
    body = "{""code"": ""rate_limited"", ""message"": ""slow down""}"
    r = apiResult(429, body, "125")
    assertEqual([r.ok, r.code, r.message], [false, "rate_limited", "Too many attempts. Try again in 3 minutes."])
    assertEqual(apiResult(429, body, "30").message, "Too many attempts. Try again in 1 minute.")
    assertEqual(apiResult(429, "", "").message, "Too many attempts. Try again in a few minutes.")
end sub

sub testMusicAndYouTubeRequests()
    assertEqual(apiRequest("listPlaylistEntries", { profileId: 3, playlistId: 9 }).path, "/api/v2/profiles/3/playlists/9/entries")
    assertEqual(apiRequest("listPlaylistPlayOrder", { profileId: 3, playlistId: 9 }).path, "/api/v2/profiles/3/playlists/9/play-order")
    assertEqual(apiRequest("listCollections", {}, { limit: 200, offset: 0 }).path, "/api/v2/collections?limit=200&offset=0")
    assertEqual(apiRequest("listCollectionMovies", { collectionId: 4 }).path, "/api/v2/collections/4/movies")
    assertEqual(apiRequest("getCollectionArtwork", { collectionId: 4, kind: "poster" }).path, "/api/v2/collections/4/artwork/poster")
    assertEqual(apiRequest("getPersonArtwork", { personId: 9 }).path, "/api/v2/people/9/artwork")
    assertEqual(apiRequest("listYouTubeVideos", {}, { sort: "newest", unwatched: true, limit: 20 }).path, "/api/v2/youtube/videos?limit=20&sort=newest&unwatched=true")
    r = apiRequest("putYouTubeChannelWatchState", { profileId: 3, channelId: 41 }, {}, { watched: true })
    assertEqual([r.method, r.path, r.body], ["PUT", "/api/v2/profiles/3/youtube/channels/41/watch-state", "{""watched"":true}"])
end sub

sub testArtIsTheAddressTheDataCarries()
    item = { id: uid(4), posterUrl: "/api/v2/artwork/w500/abc.jpg", backdropUrl: "/api/v2/artwork/w1280/def.jpg" }
    assertEqual(apiArtPath(item, "backdropUrl", "getItemArtwork", { itemId: uid(4), kind: "backdrop" }), "/api/v2/artwork/w1280/def.jpg")
    assertEqual(apiArtPath({ personId: uid(9), headshotUrl: "/api/v2/artwork/w185/p.jpg" }, "headshotUrl", "getPersonArtwork", { personId: uid(9) }), "/api/v2/artwork/w185/p.jpg")
end sub

' A reply from a server before 0.24.0, or kept from before the upgrade,
' lacks the field; so does one for something with no image, whose id
' address misses and leaves the placeholder.
sub testArtWithoutTheFieldIsTheIdAddress()
    assertEqual(apiArtPath({ id: uid(4) }, "posterUrl", "getItemArtwork", { itemId: uid(4), kind: "poster" }), "/api/v2/items/" + uid(4) + "/artwork/poster")
    assertEqual(apiArtPath({ id: 5 }, "backdropUrl", "getCollectionArtwork", { collectionId: 5, kind: "backdrop" }), "/api/v2/collections/5/artwork/backdrop")
    assertEqual(apiArtPath(invalid, "posterUrl", "getItemArtwork", { itemId: 7, kind: "poster" }), "/api/v2/items/7/artwork/poster", "no object at all")
end sub

sub testWatchTogetherStateIsAPutWithItsPosition()
    r = apiRequest("setWatchTogetherState", { watchTogetherId: 7 }, {}, { playing: false, positionMs: 4360000 })
    assertEqual(r.method, "PUT")
    assertEqual(r.path, "/api/v2/watch-together/7/state")
    assertEqual(ParseJson(r.body), { playing: false, positionMs: 4360000 })
end sub

sub testPlaybackBodyNamesTheEditionOnlyWhenChosen()
    snap = { decoder: {} }
    plain = apiPlaybackBody({ profileId: 3, itemId: 41 }, snap)
    assertEqual(plain, { itemId: 41, profileId: 3, snapshot: snap }, "no edition, position, track or playlist")
    cut = apiPlaybackBody({ profileId: 3, itemId: 41, editionId: 9, positionMs: 0, audioTrackId: 5, playlistId: 2 }, snap)
    assertEqual(cut, { audioTrackId: 5, editionId: 9, itemId: 41, playlistId: 2, positionMs: 0, profileId: 3, snapshot: snap })
    assertEqual(cut.mediaFileId, invalid, "the server picks the file")
    assertTrue(Instr(1, FormatJson(cut), """editionId""") > 0, "camel case on the wire")
end sub

sub testTrackBodyKeepsTheAudioTrackTheViewerChose()
    assertEqual(apiTrackBody(uid(5), uid(812)), { audioTrackId: uid(5), subtitleTrackId: uid(812) })
    assertEqual(apiTrackBody(uid(5), "off"), { audioTrackId: uid(5) }, "off names no subtitle track")
    assertEqual(apiTrackBody(invalid, "forced"), {}, "the server's audio track, forced subtitles only")
    assertTrue(Instr(1, FormatJson(apiTrackBody(uid(5), uid(812))), """audioTrackId"":""" + uid(5) + """,""subtitleTrackId"":""" + uid(812) + """") > 0, "camel case on the wire")
end sub

sub testStationRequests()
    assertEqual(apiRequest("listStations", {}, { kind: "movies", limit: 200, offset: 0 }).path, "/api/v2/stations?kind=movies&limit=200&offset=0")
    assertEqual(apiRequest("getStation", { stationId: 4 }).path, "/api/v2/stations/4")
    r = apiRequest("startStationPlayback", { stationId: 4 }, {}, apiStationBody({}, { decoder: {} }))
    assertEqual([r.method, r.path], ["POST", "/api/v2/stations/4/playback"])
end sub

sub testStationBodyIsTheSnapshotAndChosenTracksOnly()
    snap = { decoder: {} }
    assertEqual(apiStationBody({ stationId: 4, profileId: 3, quality: { auto: true } }, snap), { snapshot: snap }, "the server picks the program and position")
    picked = apiStationBody({ stationId: 4, itemId: 41, positionMs: 5, audioTrackId: 7, subtitleTrackId: 8 }, snap)
    assertEqual(picked, { audioTrackId: 7, snapshot: snap, subtitleTrackId: 8 })
end sub

sub testOffAirCarriesWhenTheStationResumes()
    r = apiResult(409, "{""code"": ""off_air"", ""message"": ""nothing is on"", ""resumesAt"": ""2026-11-13T21:00:00Z""}")
    assertEqual([r.ok, r.code, r.data.resumesAt], [false, "off_air", "2026-11-13T21:00:00Z"])
end sub

sub testNextBatchKeepsTheListsQueryFromWhereTheLastStopped()
    q = { genreId: 4, sort: "title" }
    assertEqual(apiNextBatch("listMusicSongs", {}, q, 2000), { offset: 2000, op: "listMusicSongs", params: {}, query: { genreId: 4, sort: "title" } })
    assertEqual(apiNextBatch("listMusicSongs", {}, q, invalid), invalid, "no rows remain")
end sub

sub testBatchIsDueOnlyNearTheEndWithRowsLeftAndNoneLoading()
    rest = apiNextBatch("listYouTubeVideos", {}, {}, 2000)
    assertTrue(apiBatchDue(1850, 2000, rest, false), "within reach of the end")
    assertTrue(not apiBatchDue(1000, 2000, rest, false), "far from the end")
    assertTrue(not apiBatchDue(1999, 2000, rest, true), "a batch in flight")
    assertTrue(not apiBatchDue(1999, 2000, invalid, false), "every row loaded")
end sub

sub testOnlyADeviceLockedReplyGoesToThePicker()
    locked = apiResult(403, "{""code"": ""device_locked"", ""message"": ""pick a profile""}")
    assertTrue(apiLocked(locked), "device_locked")
    assertTrue(not apiLocked(apiResult(403, "{""code"": ""forbidden"", ""message"": ""no""}")), "another 403")
    assertTrue(not apiLocked(apiResult(-28, "")), "the server never reached")
    assertTrue(not apiLocked(apiResult(204, "")), "a success")
    assertEqual(apiRequest("lockDevice"), { body: "", method: "POST", path: "/api/v2/me/lock" })
end sub

sub testTheHandoffCheckWaitsThreeSecondsAndAHeldPollItsHold()
    assertEqual(apiWaitMs("listPlaybackSessions", { itemId: 20 }), 3000, "a late answer plays the title unasked")
    assertEqual(apiWaitMs("listEvents", { after: "c1" }), 35000, "the server holds a poll 25 seconds")
    assertEqual(apiWaitMs("getItem", {}), 20000)
end sub

' A proxy or auth layer in front of the server may answer 401 with a body of its own.
sub testOnlyTheServersOwnRefusalSignsTheDeviceOut()
    assertTrue(apiSignedOut(apiResult(401, "{""code"": ""unauthorized"", ""message"": ""unknown device""}")), "the server's")
    assertTrue(not apiSignedOut(apiResult(401, "<html>401 Authorization Required</html>")), "a proxy's")
    assertTrue(not apiSignedOut(apiResult(401, "")), "no body")
    assertTrue(not apiSignedOut(apiResult(-28, "")), "the server never reached")
end sub

' A Roku stores a literal's unquoted keys in lower case, as these are written.
sub testRequestSpellsNamesAsTheSpec()
    r = apiRequest("getWatchState", { "profileid": 3, "itemid": 9 })
    assertEqual(r.path, "/api/v2/profiles/3/watch-state/9")
    r = apiRequest("listYouTubeVideos", {}, { "inprogress": true })
    assertEqual(r.path, "/api/v2/youtube/videos?inProgress=true")
    r = apiRequest("startPlayback", {}, {}, { "positionms": 5, snapshot: { decoder: { "videocodecs": [] } }, tracks: [{ "audiotrackid": 1 }] })
    assertTrue(Instr(1, r.body, """positionMs"":5") > 0, r.body)
    assertTrue(Instr(1, r.body, """videoCodecs""") > 0, r.body)
    assertTrue(Instr(1, r.body, """audioTrackId"":1") > 0, r.body)
end sub
