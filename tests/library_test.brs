function episodes() as object
    return [{ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }]
end function

sub testNextEpisodeResumesTheOneInProgress()
    states = { "2": { watched: true, positionMs: 0, lastPlayedAt: "2025-02-01T00:00:00Z" }, "3": { watched: false, positionMs: 5000, lastPlayedAt: "2025-02-02T00:00:00Z" } }
    assertEqual(libraryNextEpisode(episodes(), states), 2)
end sub

sub testNextEpisodeAfterTheLatestWatched()
    states = { "1": { watched: true, positionMs: 0, lastPlayedAt: "2025-02-03T00:00:00Z" }, "3": { watched: true, positionMs: 0, lastPlayedAt: "2025-02-01T00:00:00Z" } }
    assertEqual(libraryNextEpisode(episodes(), states), 1)
end sub

sub testNextEpisodeStartsAtTheTop()
    assertEqual(libraryNextEpisode(episodes(), {}), 0)
    all = {}
    for each e in episodes()
        all[e.id.ToStr()] = { watched: true, positionMs: 0, lastPlayedAt: "2025-02-01T00:00:00Z" }
    end for
    assertEqual(libraryNextEpisode(episodes(), all), -1, "all watched")
end sub

sub testEpisodeAfterIsTheNextInItsSeason()
    assertEqual(libraryEpisodeAfter(episodes(), 2).id, 3, "mid-season")
    assertEqual(libraryEpisodeAfter(episodes(), 4), invalid, "season finale")
end sub

sub testNextSeasonSkipsSpecials()
    seasons = [{ id: 31, seasonNumber: 1 }, { id: 30, seasonNumber: 0 }, { id: 32, seasonNumber: 2 }]
    assertEqual(libraryNextSeason(seasons, 1).id, 32, "after a season finale")
    assertEqual(libraryNextSeason(seasons, 2), invalid, "after the series finale")
    assertEqual(libraryNextSeason(seasons, 0).id, 31, "after the specials, never the specials")
end sub

sub testHomeHeroIsTheLatestInProgress()
    states = [{ itemId: 9, watched: false, positionMs: 60000, lastPlayedAt: "2025-03-03T00:00:00Z" }, { itemId: 8, watched: true, positionMs: 0, lastPlayedAt: "2025-03-02T00:00:00Z" }, { itemId: 7, watched: false, positionMs: 1000, lastPlayedAt: "2025-03-01T00:00:00Z" }]
    items = { "9": { id: 9, kind: "episode" }, "7": { id: 7, kind: "movie" } }
    h = libraryHome(states, items, [], {})
    assertEqual(h.hero.item.id, 9)
    assertEqual(h.hero.state.positionMs, 60000)
    assertEqual(h.nextUp.Count(), 0, "an item in progress is Also in progress, not Next up")
    assertEqual(h.also.Count(), 1)
    assertEqual(h.also[0].item.id, 7)
end sub

sub testHomeHasNoHeroWithNothingInProgress()
    states = [{ itemId: 8, watched: true, positionMs: 0, lastPlayedAt: "2025-03-02T00:00:00Z" }]
    h = libraryHome(states, { "8": { id: 8, kind: "movie" } }, [{ id: 1, parsedTitle: "a", addedAt: "2025-01-01T00:00:00Z" }], {})
    assertEqual(h.hero, invalid)
    assertEqual(h.also.Count(), 0)
    assertEqual(h.recent.Count(), 1, "Recently added stays a row")
end sub

sub testAWatchedItemWithAPositionIsInProgress()
    assertTrue(libraryInProgress({ watched: true, positionMs: 5000 }), "played again partway")
    assertTrue(not libraryInProgress({ watched: true, positionMs: 0 }))
    states = [{ itemId: 9, watched: true, positionMs: 60000, lastPlayedAt: "2025-03-03T00:00:00Z" }]
    h = libraryHome(states, { "9": { id: 9, kind: "movie" } }, [], {})
    assertEqual(h.hero.item.id, 9)
end sub

sub testHomeMergesVideosInProgressByWhenPlayed()
    states = [{ itemId: 9, watched: false, positionMs: 1000, lastPlayedAt: "2025-03-02T00:00:00Z" }, { itemId: 50, watched: false, positionMs: 1000, lastPlayedAt: "2025-03-03T00:00:00Z" }]
    videos = [{ id: 50, title: "v", positionMs: 1000, lastPlayedAt: "2025-03-03T00:00:00Z" }, { id: 51, title: "w", positionMs: 2000, watched: true, lastPlayedAt: "2025-03-01T00:00:00Z" }]
    q = libraryHomeQueue(states, {}, videos)
    assertEqual([q[0].itemId, q[1].itemId, q[2].itemId], [50, 9, 51], "a video's own state is not a second entry")
    items = { "9": { id: 9, kind: "movie" }, "50": videos[0], "51": videos[1] }
    h = libraryHome(states, items, [], {}, videos)
    assertEqual([h.hero.item.id, h.also[0].item.id, h.also[1].item.id], [50, 9, 51])
    assertEqual([h.hero.video, h.also[0].video, h.also[1].video], [true, false, true])
end sub

sub testHomeRecentlyAddedNewestFirst()
    titles = [{ id: 1, parsedTitle: "a", addedAt: "2025-01-01T00:00:00Z" }, { id: 2, parsedTitle: "b", addedAt: "2025-03-01T00:00:00Z" }, { id: 3, parsedTitle: "c", addedAt: "2025-02-01T00:00:00Z" }]
    h = libraryHome([], {}, titles, {})
    assertEqual(h.hero, invalid)
    assertEqual([h.recent[0].id, h.recent[1].id, h.recent[2].id], [2, 3, 1])
end sub

sub testHomeIsEmptyOnlyWithNothingToShow()
    none = { hero: invalid, onNow: [], also: [], nextUp: [], occasions: [], recent: [], videos: [] }
    assertEqual(libraryHomeEmpty(none), true)
    for each k in ["onNow", "also", "nextUp", "occasions", "recent", "videos"]
        h = {}
        h.Append(none)
        h[k] = [{ id: 1 }]
        assertEqual(libraryHomeEmpty(h), false, k)
    end for
    h = {}
    h.Append(none)
    h.hero = { item: { id: 1 } }
    assertEqual(libraryHomeEmpty(h), false, "a hero")
end sub

sub testNextUpHoldsAShowsNextEpisodeByWhenItWasPlayed()
    states = [{ itemId: 2, watched: true, positionMs: 0, lastPlayedAt: "2025-03-02T00:00:00Z" }, { itemId: 7, watched: false, positionMs: 5000, lastPlayedAt: "2025-03-01T00:00:00Z" }, { itemId: 9, watched: false, positionMs: 5000, lastPlayedAt: "2025-02-01T00:00:00Z" }]
    progress = { "100": { showId: 100, nextEpisodeId: 3, lastPlayedAt: "2025-03-02T00:00:00Z" } }
    q = libraryHomeQueue(states, progress)
    assertEqual([q[0].itemId, q[1].itemId, q[2].itemId], [3, 7, 9])
    assertEqual(q[0].showId, 100)
    assertEqual(q[0].state, invalid, "never played")
    items = { "3": { id: 3, kind: "episode" }, "7": { id: 7, kind: "movie" }, "9": { id: 9, kind: "movie" } }
    h = libraryHome(states, items, [], progress)
    assertEqual(h.hero.item.id, 7)
    assertEqual([h.nextUp[0].item.id, h.also[0].item.id], [3, 9])
    assertEqual(h.nextUp[0].showId, 100)
end sub

sub testNextUpSkipsAShowAtAnEpisodeInProgressOrFinished()
    states = [{ itemId: 2, watched: false, positionMs: 900, lastPlayedAt: "2025-03-03T00:00:00Z" }, { itemId: 21, watched: true, positionMs: 0, lastPlayedAt: "2025-03-02T00:00:00Z" }]
    progress = { "100": { showId: 100, nextEpisodeId: 2, lastPlayedAt: "2025-03-03T00:00:00Z" }, "200": { showId: 200, lastPlayedAt: "2025-03-02T00:00:00Z" }, "300": { showId: 300, nextEpisodeId: 31 } }
    q = libraryHomeQueue(states, progress)
    assertEqual(q.Count(), 1, "show 100 resumes in the hero, 200 is done, 300 never played")
    assertEqual(q[0].itemId, 2)
    assertEqual(q[0].showId, 100, "an episode in progress takes its show from the show it is next in")
end sub

sub testNextUpHoldsADozen()
    states = []
    items = {}
    for id = 1 to 14
        states.Push({ itemId: id, watched: false, positionMs: 1000, lastPlayedAt: "2025-03-01T00:00:00Z" })
        items[id.ToStr()] = { id: id, kind: "movie" }
    end for
    h = libraryHome(states, items, [], {})
    assertEqual(h.hero.item.id, 1)
    assertEqual(h.also.Count(), 12)
end sub

sub testSortByTitle()
    list = librarySort([{ parsedTitle: "b" }, { parsedTitle: "A", metadata: { title: "c" } }, { parsedTitle: "a" }], "title")
    assertEqual([itemTitle(list[0]), itemTitle(list[1]), itemTitle(list[2])], ["a", "b", "c"])
end sub

sub testSortByYearNewestFirst()
    list = librarySort([{ id: 1, parsedTitle: "a", parsedYear: 1995 }, { id: 2, parsedTitle: "b" }, { id: 3, parsedTitle: "c", parsedYear: 2024 }], "year")
    assertEqual(ids(list), [3, 1, 2])
end sub

sub testSortByLastWatchedReadsAShowsProgress()
    states = { "1": { watched: true, positionMs: 0, lastPlayedAt: "2025-01-01T00:00:00Z" } }
    progress = { "2": { showId: 2, seasons: 1, episodes: 2, unwatched: 1, inProgress: false, lastPlayedAt: "2025-03-01T00:00:00Z" } }
    items = [{ id: 1, kind: "movie", parsedTitle: "a" }, { id: 3, kind: "movie", parsedTitle: "c" }, { id: 2, kind: "show", parsedTitle: "b" }]
    assertEqual(ids(librarySort(items, "watched", states, progress)), [2, 1, 3])
end sub

sub testStoredSortIsOneOfTheGridsOrRecentlyAdded()
    assertEqual(librarySorts(), ["added", "title", "watched", "year"])
    assertEqual(libraryStoredSort("year"), "year")
    assertEqual(libraryStoredSort(""), "added", "none stored yet")
    assertEqual(libraryStoredSort("rating"), "added", "a sort the grid no longer offers")
end sub

function ids(items as object) as object
    out = []
    for each i in items
        out.Push(i.id)
    end for
    return out
end function

sub testUnwatchedCountsEpisodesWithoutAWatchedState()
    states = { "11": { watched: true, positionMs: 0 }, "12": { watched: false, positionMs: 900 } }
    assertEqual(libraryUnwatched([11, 12, 13], states), 2)
    assertEqual(libraryUnwatched([], states), 0)
end sub

sub testFilterMoviesByTheirOwnState()
    states = { "1": { watched: true, positionMs: 0 }, "2": { watched: false, positionMs: 5000 } }
    movies = [{ id: 1, kind: "movie" }, { id: 2, kind: "movie" }, { id: 3, kind: "movie" }]
    assertEqual(ids(libraryFilter(movies, "all", states, {})), [1, 2, 3])
    assertEqual(ids(libraryFilter(movies, "unwatched", states, {})), [2, 3])
    assertEqual(ids(libraryFilter(movies, "progress", states, {})), [2])
end sub

sub testFilterShowsByTheirProgress()
    progress = { "1": { showId: 1, seasons: 1, episodes: 2, unwatched: 1, inProgress: true }, "2": { showId: 2, seasons: 1, episodes: 1, unwatched: 0, inProgress: false } }
    shows = [{ id: 1, kind: "show" }, { id: 2, kind: "show" }, { id: 3, kind: "show" }]
    assertEqual(ids(libraryFilter(shows, "unwatched", {}, progress)), [1], "a show without progress counts for nothing")
    assertEqual(ids(libraryFilter(shows, "progress", {}, progress)), [1])
end sub

sub testStandingOfAMovieAndAShow()
    states = { "1": { watched: false, positionMs: 900, lastPlayedAt: "2025-01-01T00:00:00Z" } }
    progress = { "2": { showId: 2, seasons: 3, episodes: 24, unwatched: 5, inProgress: false, lastPlayedAt: "2025-02-01T00:00:00Z" } }
    m1 = libraryStanding({ id: 1, kind: "movie" }, states, progress)
    assertEqual([m1.unwatched, m1.inProgress, m1.lastPlayedAt], [1, true, "2025-01-01T00:00:00Z"])
    m3 = libraryStanding({ id: 3, kind: "movie" }, states, progress)
    assertEqual([m3.unwatched, m3.inProgress, m3.lastPlayedAt], [1, false, ""])
    s2 = libraryStanding({ id: 2, kind: "show" }, states, progress)
    assertEqual([s2.unwatched, s2.inProgress, s2.lastPlayedAt], [5, false, "2025-02-01T00:00:00Z"])
    s4 = libraryStanding({ id: 4, kind: "show" }, states, progress)
    assertEqual([s4.unwatched, s4.inProgress, s4.lastPlayedAt], [0, false, ""])
end sub

sub testFilterKidsByTheServersKidsContent()
    items = [{ id: 1, kind: "movie", kidsContent: true, metadata: { contentRating: "PG" } }, { id: 2, kind: "movie", kidsContent: false, metadata: { contentRating: "G" } }, { id: 3, kind: "movie" }, { id: 4, kind: "show", kidsContent: true, metadata: { contentRating: "TV-14" } }, { id: 5, kind: "show", kidsContent: false, metadata: { contentRating: "TV-Y" } }]
    assertEqual(ids(libraryFilter(items, "kids", {}, {})), [1, 4], "an override or a rating, as the server decided")
end sub

sub testKidsChipAsksTheServerOnlyWhileKidsContentIsHidden()
    assertEqual(libraryKidsOnly("kids", true), true, "hide on, chip picked")
    assertEqual(libraryKidsOnly("kids", false), false, "hide off filters the loaded list")
    assertEqual(libraryKidsOnly("all", true), false, "hide on without the chip")
    assertEqual(libraryKidsOnly("unwatched", true), false)
end sub

sub testAProfileHidesKidsContentOnlyWhenItsOwnFlagIsOn()
    profiles = [{ id: 1, kind: "adult", hideKidsContent: true }, { id: 2, kind: "adult" }, { id: 3, kind: "kid" }]
    assertEqual(libraryHides(profiles, 1), true)
    assertEqual(libraryHides(profiles, 2), false, "no flag")
    assertEqual(libraryHides(profiles, 3), false, "a kid")
    assertEqual(libraryHides(profiles, 9), false, "unknown")
end sub

sub testEveryTabShowsUntilTheServerHasAnswered()
    assertEqual(libraryTabs(invalid), ["Home", "TV", "Movies", "Music", "YouTube", "Search"])
end sub

sub testTabsFollowTheKindsOfLibraryTheServerHas()
    assertEqual(libraryTabs(["music", "movies", "movies"]), ["Home", "Movies", "Music", "Search"])
    assertEqual(libraryTabs([]), ["Home", "Search"], "no library")
end sub

sub testMusicBarHasPlaylistsForAKid()
    assertEqual(ids(libraryBar("music", false, "songs").views), ["albums", "artists", "songs", "playlists", "stations"], "a kid's shared playlists")
end sub

sub testSearchSectionsHoldTheNonEmptyLists()
    r = { movies: [{ id: 1 }], shows: [], episodes: [{ id: 2 }], people: [{ id: 5 }], artists: [{ id: 6 }], albums: [{ id: 7 }], songs: [{ id: 3 }], channels: [{ id: 8 }], videos: [{ id: 4 }] }
    s = searchSections(r)
    titles = []
    for each x in s
        titles.Push(x.title)
    end for
    assertEqual(titles, ["Movies", "TV", "Songs", "Albums", "Artists", "Videos", "Channels", "People"])
    assertEqual(s[7].kind, "people")
    assertEqual(s[1].items.Count(), 1)
    assertEqual(searchSections({ movies: [], shows: [], episodes: [], people: [], artists: [], albums: [], songs: [], channels: [], videos: [] }).Count(), 0)
end sub

sub testSearchSectionsJoinEpisodesThenShows()
    r = { movies: [], shows: [{ id: 1 }], episodes: [{ id: 2 }, { id: 3 }], people: [], artists: [], albums: [], songs: [], channels: [], videos: [] }
    s = searchSections(r)
    assertEqual(s.Count(), 1)
    assertEqual([s[0].items[0].id, s[0].items[2].id], [2, 1])
end sub

function texts(items as object) as object
    out = []
    for each i in items
        out.Push(i.text)
    end for
    return out
end function

sub testBarSplitsViewTabsFromFilterChips()
    movies = libraryBar("movie", true, "unwatched")
    assertEqual(texts(movies.views), ["Movies", "Collections", "Playlists", "Stations"])
    assertEqual(ids(movies.views), ["library", "collections", "playlists", "stations"])
    assertEqual([movies.view, texts(movies.chips)], ["library", ["All", "Unwatched", "In progress", "Kids"]], "a filter is the library's view")
    assertEqual(ids(movies.chips), ["all", "unwatched", "progress", "kids"])
    kid = libraryBar("movie", false, "all")
    assertEqual([texts(kid.views), ids(kid.chips)], [["Movies", "Collections", "Playlists", "Stations"], ["all", "unwatched", "progress"]], "shared playlists but no Kids for a kid")
    shows = libraryBar("show", true, "stations")
    assertEqual([texts(shows.views), shows.view], [["Shows", "Playlists", "Stations"], "stations"])
    assertEqual(ids(shows.chips), ["all", "unwatched", "progress", "kids"], "stations keeps the grid's filters")
    assertEqual(libraryBar("movie", true, "collections").chips, [], "nothing filters collections")
    assertEqual(libraryBar("show", true, "playlists").chips, [], "nothing filters playlists")
end sub

sub testMusicAndYouTubeBarsKeepTheirListings()
    music = libraryBar("music", true, "songs")
    assertEqual([texts(music.views), music.view, music.chips], [["Albums", "Artists", "Songs", "Playlists", "Stations"], "songs", []])
    assertEqual(ids(music.views), ["albums", "artists", "songs", "playlists", "stations"])
    unwatched = libraryBar("youtube", true, "unwatched")
    assertEqual([ids(unwatched.views), texts(unwatched.views), unwatched.view], [["videos", "channels"], ["Videos", "Channels"], "videos"], "Unwatched filters videos")
    assertEqual(ids(libraryBar("youtube", true, "videos").chips), ["unwatched"])
    assertEqual(libraryBar("youtube", true, "channels").chips, [], "nothing filters channels")
end sub

function cuts() as object
    return [
        { id: 31, name: "Standard", isDefault: true, runtimeMs: 7920000, copies: [{ mediaFileId: 301, quality: "1080p" }] }
        { id: 32, name: "Extended", isDefault: false, runtimeMs: 13680000, copies: [{ mediaFileId: 302, quality: "4K" }, { mediaFileId: 303, quality: "1080p" }] }
    ]
end function

sub testPreselectedEditionHoldsTheSavedPositionElseTheDefault()
    assertEqual(libraryPreselectedEdition(cuts(), { watched: false, positionMs: 60000, editionId: 32 }).id, 32, "the position's edition")
    assertEqual(libraryPreselectedEdition(cuts(), invalid).id, 31, "never played")
    assertEqual(libraryPreselectedEdition(cuts(), { watched: true, positionMs: 0, editionId: 32 }).id, 31, "watched holds no position")
    assertEqual(libraryPreselectedEdition(cuts(), { watched: false, positionMs: 60000 }).id, 31, "a position without an edition is the default's")
    assertEqual(libraryPreselectedEdition(cuts(), { watched: false, positionMs: 60000, editionId: 99 }).id, 31, "an edition gone from the title")
    assertEqual(libraryPreselectedEdition(invalid, invalid), invalid, "no editions")
end sub

sub testResumeIsOfferedOnlyOnTheEditionHoldingThePosition()
    standard = cuts()[0]
    extended = cuts()[1]
    onExtended = { watched: false, positionMs: 60000, editionId: 32 }
    assertTrue(libraryResumes(onExtended, extended), "its own edition")
    assertTrue(not libraryResumes(onExtended, standard), "another edition starts from the beginning")
    assertTrue(libraryResumes({ watched: false, positionMs: 60000 }, standard), "no edition named is the default's")
    assertTrue(not libraryResumes({ watched: false, positionMs: 60000 }, extended))
    assertTrue(libraryResumes(onExtended, invalid), "one edition: as before")
    assertTrue(not libraryResumes({ watched: true, positionMs: 0, editionId: 32 }, extended), "nothing to resume")
    assertTrue(not libraryResumes(invalid, extended))
end sub

sub testEditionLabelReadsNameRuntimeAndCopies()
    assertEqual(libraryEditionLabel(cuts()[1]), "Extended · 3h 48m · 4K, 1080p")
    assertEqual(libraryEditionLabel(cuts()[0]), "Standard · 2h 12m · 1080p")
    assertEqual(libraryEditionLabel({ name: "Director's Cut", copies: [{ mediaFileId: 1 }, { mediaFileId: 2, quality: "1080p" }, { mediaFileId: 3, quality: "1080p" }] }), "Director's Cut · 1080p", "no runtime, a copy without video, a quality named once")
    assertEqual(libraryEditionLabel({ name: "Theatrical", copies: [] }), "Theatrical")
end sub

sub testEditionFileIsItsFirstCopyElseTheItemsFirst()
    files = [{ id: 301 }, { id: 303 }, { id: 302 }]
    assertEqual(libraryEditionFile(files, cuts()[1]).id, 302, "the tallest copy of the chosen cut")
    assertEqual(libraryEditionFile(files, invalid).id, 301, "no edition chosen: as before")
    assertEqual(libraryEditionFile(files, { id: 33, copies: [] }).id, 301, "a cut without files")
    assertEqual(libraryEditionFile([], cuts()[0]), invalid)
end sub

sub testThePlayersFileIsTheOneTheStreamNames()
    files = [{ id: 301 }, { id: 303 }, { id: 302 }]
    assertEqual(libraryEditionFile(files, cuts()[1], 303).id, 303, "the copy the server plays, not the cut's first")
    assertEqual(libraryEditionFile(files, invalid, 303).id, 303, "the default cut's copy, not the item's first file")
    assertEqual(libraryEditionFile(files, cuts()[1], invalid).id, 302, "a stream that names no file")
    assertEqual(libraryEditionFile(files, cuts()[1], 999).id, 302, "a file the listing lacks")
end sub

sub testProgressLineOfAVideoWithoutADuration()
    video = { video: true, item: { title: "V", channelTitle: "Chan" }, state: { positionMs: 540000 } }
    assertEqual(libraryProgressLine(video), "Chan", "no duration: the channel alone")
    video.item.durationMs = 1080000
    assertEqual(libraryProgressLine(video), "Chan · 9m left")
    assertEqual(libraryRuntimeOf(video), 18)
end sub

' An ItemRelated as the server sends it: two collections of other films
' and a franchise neighbor on each side.
function relatedAnswer() as object
    text = "{""collections"":[{""collection"":{""id"":1,""name"":""The Lord of the Rings""},""items"":[{""id"":11,""kind"":""movie"",""parsedTitle"":""a"",""metadata"":{""title"":""The Fellowship of the Ring""}},{""id"":13,""kind"":""movie"",""parsedTitle"":""c"",""metadata"":{""title"":""The Return of the King""}}]},{""collection"":{""id"":2,""name"":""Favorites""},""items"":[{""id"":21,""kind"":""movie"",""parsedTitle"":""The Hobbit""}]}],"
    text = text + """similar"":[],"
    text = text + """previous"":{""id"":11,""kind"":""movie"",""parsedTitle"":""a"",""metadata"":{""title"":""The Fellowship of the Ring""}},""next"":{""id"":13,""kind"":""movie"",""parsedTitle"":""c"",""metadata"":{""title"":""The Return of the King""}}}"
    return apiResult(200, text).data
end function

sub testRelatedIsOneShelfPerCollectionInOrder()
    shelves = []
    for each s in libraryRelated(relatedAnswer())
        ids = []
        for each item in s.items
            ids.Push(item.id)
        end for
        shelves.Push([s.collection.name, ids])
    end for
    assertEqual(shelves, [["The Lord of the Rings", [11, 13]], ["Favorites", [21]]])
end sub

sub testRelatedIsEmptyUntilAnAnswerAndWhenItIsEmpty()
    assertEqual(libraryRelated(invalid), [], "loading or failed")
    assertEqual(libraryRelated(apiResult(200, "{""collections"":[],""similar"":[]}").data), [], "empty")
end sub

sub testNeighborsNameTheFilmTheyOpenInPlace()
    n = libraryNeighbors(relatedAnswer())
    assertEqual(n.Count(), 2)
    assertEqual(n[0].id, "previous")
    assertEqual(n[0].text, "Previous: The Fellowship of the Ring")
    assertEqual(n[0].navigate.item.id, 11)
    assertEqual(n[1].id, "next")
    assertEqual(n[1].text, "Next: The Return of the King")
    assertEqual(n[1].navigate.to, "details")
    assertTrue(n[0].navigate.replace and n[1].navigate.replace, "replace the page rather than stack one")
end sub

sub testNeighborsOfAnEpisodeNameItsCode()
    text = "{""collections"":[],""similar"":[],""next"":{""id"":40,""kind"":""episode"",""parsedTitle"":""Pilot"",""seasonNumber"":2,""episodeNumber"":1}}"
    n = libraryNeighbors(apiResult(200, text).data)
    assertEqual(n.Count(), 1, "no previous at the first episode")
    assertEqual(n[0].id, "next")
    assertEqual(n[0].text, "Next: S2 E1")
end sub

sub testNoNeighborsWithoutThem()
    assertEqual(libraryNeighbors(invalid), [], "loading or failed")
    assertEqual(libraryNeighbors(apiResult(200, "{""collections"":[],""similar"":[]}").data), [], "neither")
end sub

sub testOccasionRowsKeepTheServersOrderAndSkipAnEmptyOne()
    active = [{ id: 8, name: "Halloween" }, { id: 7, name: "Christmas" }, { id: 6, name: "Easter" }]
    rows = libraryHomeOccasions(active, [[{ id: 1 }], [{ id: 2 }, { id: 3 }], []])
    assertEqual([rows[0].name, rows[1].name], ["Halloween", "Christmas"])
    assertEqual(rows.Count(), 2)
    assertEqual(rows[1].items.Count(), 2)
    assertEqual(libraryHomeOccasions([], []).Count(), 0)
end sub

sub testAnOccasionsRowIsTitledByItsHeadlineElseItsName()
    active = [{ id: 7, name: "Christmas", headline: "Ho, Ho, Ho!" }, { id: 8, name: "Halloween" }, { id: 9, name: "Easter", headline: "  " }]
    rows = libraryHomeOccasions(active, [[{ id: 1 }], [{ id: 2 }], [{ id: 3 }]])
    assertEqual([rows[0].title, rows[1].title, rows[2].title], ["Ho, Ho, Ho!", "Halloween", "Easter"])
    assertEqual([rows[0].name, rows[1].name, rows[2].name], ["Christmas", "Halloween", "Easter"])
    assertEqual(rows[0].occasion.id, 7)
end sub

sub testAWashColorIsRRGGBBFFAndNeedsThreeValidOnes()
    assertEqual(libraryWashColors(["#C8102E", "#00843d", "#FFD100"]), ["0xC8102EFF", "0x00843DFF", "0xFFD100FF"])
    assertEqual(libraryWashColors(["#C8102E", "#00843D"]).Count(), 0, "two")
    assertEqual(libraryWashColors([]).Count(), 0, "none")
    assertEqual(libraryWashColors(invalid).Count(), 0, "absent")
    assertEqual(libraryWashColors(["#C8102E", "#00843D", "nope"]).Count(), 0, "one bad")
    assertEqual(libraryWashColors(["C8102E", "#00843D", "#FFD100"]).Count(), 0, "no hash")
    assertEqual(libraryWashColors(["#C8102E0", "#00843D", "#FFD100"]).Count(), 0, "long")
    assertEqual(libraryWashColors(["#C8102G", "#00843D", "#FFD100"]).Count(), 0, "not hex")
end sub

sub testADetailsRowHoldsTheOtherMembersOfEachOccasionAndSkipsAnEmptyOne()
    active = [{ id: 7, name: "Christmas" }, { id: 8, name: "Halloween" }]
    rows = libraryOccasionRelated(active, [[{ id: 31 }, { id: 32 }], [{ id: 31 }]], 31)
    assertEqual(rows.Count(), 1)
    assertEqual(rows[0].collection.name, "Christmas")
    assertEqual(rows[0].items.Count(), 1)
    assertEqual(rows[0].items[0].id, 32)
end sub

sub testActiveOccasionsForATitleAskForItsId()
    r = apiRequest("listActiveOccasions", { profileId: 3 }, { date: "2026-12-05", itemId: 31 })
    assertEqual(r.path, "/api/v1/profiles/3/occasions?date=2026-12-05&itemId=31")
end sub

sub testActiveOccasionsAskForTheDeviceDateAndEachOneItsTitles()
    r = apiRequest("listActiveOccasions", { profileId: 3 }, { date: "2026-12-05" })
    assertEqual(r.path, "/api/v1/profiles/3/occasions?date=2026-12-05")
    assertEqual(apiRequest("listItems", {}, { occasionId: 8, limit: 20 }).path, "/api/v1/items?limit=20&occasionId=8")
end sub

sub testCrewLinesGroupEachJobInCreditOrder()
    crew = [{ name: "Michael Bay", job: "Director" }, { name: "David Weisberg", job: "Writer" }, { name: "Mark Rosner", job: "Writer" }, { name: "Jonathan Hensleigh", job: "Screenplay" }, { name: "X" }]
    assertEqual(libraryCrewLines(crew, [], false), [["Director", "Michael Bay"], ["Writer", "David Weisberg, Mark Rosner"], ["Screenplay", "Jonathan Hensleigh"], ["Crew", "X"]])
end sub

sub testEpisodeCrewLinesReadAsTheBoardsDoAndNameGuestStars()
    crew = [{ name: "A", job: "Director" }, { name: "B", job: "Writer" }]
    cast = [{ name: "C" }, { name: "D" }, { name: "E" }, { name: "F" }]
    assertEqual(libraryCrewLines(crew, cast, true), [["Directed by", "A"], ["Written by", "B"], ["Guest stars", "C, D, E"]])
    assertEqual(libraryCrewLines([], [], true), [])
end sub

sub testSeasonCountLeavesOutSpecials()
    assertEqual(libraryRegularSeasons([{ seasonNumber: 0 }, { seasonNumber: 1 }, { seasonNumber: 2 }]), 2)
end sub

sub testSelectingANextUpEpisodePlaysItResumingItsEdition()
    never = { item: { id: 3, kind: "episode" }, state: invalid, video: false }
    assertEqual(libraryNextUpRoute(never), { to: "player", item: never.item, editionId: invalid })
    kept = { item: { id: 4, kind: "episode" }, state: { itemId: 4, editionId: 9, positionMs: 100 }, video: false }
    assertEqual(libraryNextUpRoute(kept), { to: "player", item: kept.item, editionId: 9 })
    clip = { item: { id: 5, title: "Clip" }, state: invalid, video: true }
    assertEqual(libraryNextUpRoute(clip), { to: "details", view: "VideoView", video: clip.item }, "a video keeps its details")
end sub
