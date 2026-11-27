' The server's answers kept on the device, read through by every load.

' A cache in tmp: for profile 1, whose fake server answers each path from
' routes and records it in asked.
function cacheFixture() as object
    for each f in ListDir("tmp:/")
        DeleteFile("tmp:/" + f)
    end for
    g = GetGlobalAA()
    g.slot = "1 http://tv.local:8477"
    g.asked = []
    g.routes = {}
    g.onAsk = invalid
    cacheServes("/api/v2/items", cacheMovies(20))
    return cacheFresh()
end function

' The context one ApiTask run starts with, the profile now active.
function cacheFresh(expired = 0 as integer) as object
    return cacheContext("tmp:/", cacheFakeSlot, cacheFakeFetch, expired)
end function

function cacheFakeSlot() as string
    return GetGlobalAA().slot
end function

function cacheFakeFetch(req as object) as object
    g = GetGlobalAA()
    g.asked.Push(req.path)
    if g.onAsk <> invalid then g.slot = g.onAsk
    r = g.routes[req.path]
    if r = invalid then return { code: 404, text: "{""code"": ""not_found"", ""message"": ""no""}", type: "application/json", retryAfter: "" }
    return r
end function

sub cacheServes(path as string, text as string, code = 200 as integer, kind = "application/json" as string)
    GetGlobalAA().routes[path] = { code: code, text: text, type: kind, retryAfter: "" }
end sub

function cacheMovies(id as integer) as string
    return FormatJson({ items: [{ id: id }], nextoffset: invalid })
end function

function cacheTimesAsked(path = "/api/v2/items" as string) as integer
    n = 0
    for each p in GetGlobalAA().asked
        if p = path then n = n + 1
    end for
    return n
end function

' The ids a listing read through ctx answered, or its status when it failed.
function cacheList(ctx as object) as dynamic
    reply = cacheGet(ctx, "listItems", { method: "GET", path: "/api/v2/items" })
    r = apiResult(reply.code, reply.text)
    if not r.ok then return r.status
    ids = []
    for each i in r.data.items
        ids.Push(i.id)
    end for
    return ids
end function

sub testAKeptAnswerIsReadAtOnceAndTheServersChangeIsKeptAndSignalledOnce()
    ctx = cacheFixture()
    assertEqual(cacheList(ctx), [20], "the server's, with nothing kept")
    assertTrue(not cacheRefresh(ctx), "nothing was read from what is kept")
    cacheServes("/api/v2/items", cacheMovies(21))
    ctx = cacheFresh()
    assertEqual(cacheList(ctx), [20], "the kept answer, before the server is asked")
    assertEqual(cacheTimesAsked(), 1)
    assertTrue(cacheRefresh(ctx), "the server's change signals")
    assertEqual(cacheTimesAsked(), 2, "the server is asked behind the read")
    assertTrue(not cacheRefresh(ctx), "once")
end sub

sub testAnswersRefreshedTogetherSignalOnce()
    ctx = cacheFixture()
    cacheServes("/api/v2/profiles/1/watch-state", cacheMovies(5))
    states = { method: "GET", path: "/api/v2/profiles/1/watch-state" }
    cacheList(ctx)
    cacheGet(ctx, "listWatchStates", states)
    cacheServes("/api/v2/items", cacheMovies(21))
    cacheServes("/api/v2/profiles/1/watch-state", cacheMovies(6))
    ctx = cacheFresh()
    cacheList(ctx)
    cacheGet(ctx, "listWatchStates", states)
    assertTrue(cacheRefresh(ctx), "one signal for both")
    ctx = cacheFresh()
    assertEqual(cacheList(ctx), [21])
    assertEqual(apiResult(200, cacheGet(ctx, "listWatchStates", states).text).data.items[0].id, 6)
end sub

sub testTheSameAnswerFromTheServerSignalsNothing()
    ctx = cacheFixture()
    cacheList(ctx)
    ctx = cacheFresh()
    cacheList(ctx)
    assertTrue(not cacheRefresh(ctx), "unchanged")
    ctx = cacheFresh()
    cacheList(ctx)
    cacheRefresh(ctx)
    assertEqual(cacheTimesAsked(), 3, "each read asks behind it again")
end sub

sub testReadingAgainOnTheSignalTakesTheNewAnswerWithoutAskingAgain()
    ctx = cacheFixture()
    cacheList(ctx)
    cacheServes("/api/v2/items", cacheMovies(21))
    ctx = cacheFresh()
    cacheList(ctx)
    cacheRefresh(ctx)
    ctx = cacheFresh()
    assertEqual(cacheList(ctx), [21])
    assertTrue(not cacheRefresh(ctx), "nothing to ask behind it")
    assertEqual(cacheTimesAsked(), 2, "the read on the signal is answered from what the refresh kept")
end sub

sub testWithTheServerGoneAKeptAnswerIsReadAtOnceAndStays()
    ctx = cacheFixture()
    cacheList(ctx)
    cacheServes("/api/v2/items", "", -28, "")
    ctx = cacheFresh()
    assertEqual(cacheList(ctx), [20])
    assertTrue(not cacheRefresh(ctx), "nothing changed")
    ctx = cacheFresh()
    assertEqual(cacheList(ctx), [20], "nothing kept is dropped")
end sub

sub testAnErrorFromTheServerDropsTheKeptAnswerAndSignals()
    ctx = cacheFixture()
    cacheList(ctx)
    GetGlobalAA().routes.Delete("/api/v2/items")
    ctx = cacheFresh()
    assertEqual(cacheList(ctx), [20])
    assertTrue(cacheRefresh(ctx), "the drop signals")
    ctx = cacheFresh()
    assertEqual(cacheList(ctx), 404, "the dropped answer is not read again")
    assertEqual(cacheTimesAsked(), 3, "with nothing kept the read waits on the server")
end sub

sub testAServerThatFailsLeavesTheKeptAnswerAsOneThatIsGoneDoes()
    ctx = cacheFixture()
    cacheList(ctx)
    cacheServes("/api/v2/items", "{""code"": ""unavailable"", ""message"": ""no""}", 503)
    ctx = cacheFresh()
    assertEqual(cacheList(ctx), [20])
    assertTrue(not cacheRefresh(ctx), "a failing server changes nothing")
    ctx = cacheFresh(CreateObject("roDateTime").AsSeconds())
    assertEqual(cacheList(ctx), [20], "the kept one, though asked for first")
    assertEqual(cacheTimesAsked(), 3)
end sub

sub testAfterAWriteTheServerAnsweredTheNextReadAsksFirst()
    ctx = cacheFixture()
    cacheList(ctx)
    cacheServes("/api/v2/items", cacheMovies(21))
    assertTrue(cacheMarks("putWatchState", 200), "a write the server answered")
    assertTrue(cacheMarks("putWatchState", 500), "with anything")
    ctx = cacheFresh(CreateObject("roDateTime").AsSeconds())
    assertEqual(cacheList(ctx), [21], "the server's answer, waited on")
    assertTrue(not cacheRefresh(ctx), "nothing asked behind it")
    cacheServes("/api/v2/items", "", -28, "")
    ctx = cacheFresh(CreateObject("roDateTime").AsSeconds())
    assertEqual(cacheList(ctx), [21], "the kept one while the server is gone")
end sub

sub testAWriteThatNeverReachedTheServerOrOnlyAskedMarksNothing()
    assertTrue(not cacheMarks("putWatchState", -28), "never reached")
    for each op in ["reportPlaybackPosition", "reportPlaybackEvent", "reportPlaybackThroughput", "updatePlaybackNetwork", "updatePlaybackDisplay", "updatePlaybackAudioRoute", "checkPlayability"]
        assertTrue(not cacheMarks(op, 204), op)
    end for
    assertTrue(cacheMarks("startPlayback", 201), "a session started")
    assertTrue(cacheMarks("endPlayback", 204), "a session ended")
end sub

sub testOnlyTheServersSuccessfulJsonReadsAreKept()
    ctx = cacheFixture()
    cacheServes("/api/v2/items", "{""code"": ""internal"", ""message"": ""no""}", 500)
    assertEqual(cacheList(ctx), 500)
    cacheServes("/api/v2/items", "<html>sign in</html>", 200, "text/html")
    cacheList(ctx)
    cacheServes("/api/v2/items", cacheMovies(20))
    assertEqual(cacheList(ctx), [20])
    assertEqual(cacheTimesAsked(), 3, "an error and another's page are not kept")

    paths = { getMe: "/api/v2/me", listEvents: "/api/v2/events", getWatchState: "/api/v2/profiles/1/watch-state/20", getPlaybackSession: "/api/v2/playback/sessions/7", listStations: "/api/v2/stations", getHealth: "/api/v2/health" }
    for each op in paths
        cacheServes(paths[op], "{}")
        cacheGet(ctx, op, { method: "GET", path: paths[op] })
        cacheGet(ctx, op, { method: "GET", path: paths[op] })
        assertEqual(cacheTimesAsked(paths[op]), 2, op + " is asked each time")
    end for
end sub

sub testAProfileIsOnlyEverAnsweredWithItsOwnKeptAnswers()
    ctx = cacheFixture()
    cacheList(ctx)
    g = GetGlobalAA()
    g.slot = "2 http://tv.local:8477"
    cacheServes("/api/v2/items", "", -28, "")
    assertEqual(cacheList(cacheFresh()), -28, "the kid is not answered with the adult's")
    cacheServes("/api/v2/items", cacheMovies(30))
    cacheList(cacheFresh())
    cacheServes("/api/v2/items", "", -28, "")
    assertEqual(cacheList(cacheFresh()), [30], "the kid's own last answer")

    g.slot = ""
    assertEqual(cacheList(cacheFresh()), -28, "Who's watching is answered from nothing kept")
end sub

sub testAnAnswerArrivingAfterTheProfileLeftIsNotKept()
    ctx = cacheFixture()
    GetGlobalAA().onAsk = ""
    cacheList(ctx)
    assertEqual(ListDir("tmp:/").Count(), 0, "signed out while the server answered")
end sub

sub testClearingKeepsNothingAndLeavesOtherFiles()
    ctx = cacheFixture()
    cacheList(ctx)
    WriteAsciiFile("tmp:/rabbit-ears-812.bif", "x")
    cacheClear("tmp:/")
    assertEqual(ListDir("tmp:/").Count(), 1)
    cacheServes("/api/v2/items", "", -28, "")
    assertEqual(cacheList(cacheFresh()), -28, "nothing kept")
end sub

sub testKeysThatShareAFileNameAreNotTakenForEachOther()
    assertTrue(cacheName("1 a/items?q=x") <> cacheName("1 a/items?q=y"))
    ctx = cacheFixture()
    cacheList(ctx)
    name = cacheName("1 http://tv.local:8477/api/v2/items")
    WriteAsciiFile("tmp:/" + name, "1 0 1 http://tv.local:8477/api/v2/other" + Chr(10) + cacheMovies(99))
    assertEqual(cacheList(cacheFresh()), [20], "another key's answer is not read")
    assertEqual(cacheTimesAsked(), 2)
end sub
