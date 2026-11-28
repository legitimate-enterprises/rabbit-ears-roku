sub testPlaylistCaptionCountsItsKind()
    assertEqual(playlistCaption({ kind: "music", itemCount: 48 }), "48 songs")
    assertEqual(playlistCaption({ kind: "movies", itemCount: 1 }), "1 movie")
    assertEqual(playlistCaption({ kind: "tv", itemCount: 12 }), "12 episodes")
    assertEqual(playlistCaption({ kind: "tv", itemCount: 12, access: "read", ownerName: "Ana" }), "12 episodes · Shared by Ana")
    assertEqual(playlistCaption({ kind: "tv", itemCount: 1, access: "owner", ownerName: "Me" }), "1 episode")
end sub

sub testEntryTitleByKind()
    assertEqual(playlistEntryTitle({ kind: "movie", item: { parsedTitle: "dune part two", metadata: { title: "Dune: Part Two" } } }), "Dune: Part Two")
    assertEqual(playlistEntryTitle({ kind: "show", item: { parsedTitle: "Harbor Lights" } }), "Harbor Lights")
    assertEqual(playlistEntryTitle({ kind: "artist", artist: { name: "Velvet Anchor" } }), "Velvet Anchor")
    assertEqual(playlistEntryTitle({ kind: "album", album: { title: "Low Tide" } }), "Low Tide")
    assertEqual(playlistEntryTitle({ kind: "song", song: { title: "Reckoner" } }), "Reckoner")
end sub

sub testEntryCaptionNamesWhatAContainerStandsFor()
    assertEqual(playlistEntryCaption({ kind: "show", itemCount: 12, durationMs: 520 * 60000 }), "12 episodes · 8h 40m")
    assertEqual(playlistEntryCaption({ kind: "season", itemCount: 1, durationMs: 50 * 60000 }), "1 episode · 50m")
    assertEqual(playlistEntryCaption({ kind: "artist", itemCount: 9, durationMs: 0 }), "9 songs")
    assertEqual(playlistEntryCaption({ kind: "album", itemCount: 10, durationMs: 41 * 60000 }), "10 songs · 41m")
end sub

sub testEntryCaptionOfAPlayableThing()
    movie = { kind: "movie", itemCount: 1, durationMs: 166 * 60000, item: { metadata: { releaseDate: "2024-03-01" } } }
    assertEqual(playlistEntryCaption(movie), "2024 · 2h 46m")
    episode = { kind: "episode", itemCount: 1, durationMs: 50 * 60000, item: { seasonNumber: 2, episodeNumber: 4 }, show: { parsedTitle: "Harbor Lights" } }
    assertEqual(playlistEntryCaption(episode), "Harbor Lights · S2 E4 · 50m")
    song = { kind: "song", itemCount: 1, durationMs: 215000, song: { artistName: "Velvet Anchor" } }
    assertEqual(playlistEntryCaption(song), "Velvet Anchor · 3:35")
end sub

sub testEntryArtIsTheItemsExceptASongsAlbum()
    assertEqual(playlistEntryArtId({ itemId: uid(7), kind: "show" }), uid(7))
    assertEqual(playlistEntryArtId({ itemId: uid(8), kind: "song", song: { albumId: uid(3) } }), uid(3))
end sub

sub testEntryArtIsWhatItsKindNamesCarries()
    assertEqual(playlistEntryArtPath({ itemId: uid(7), kind: "season", item: { id: uid(7), posterUrl: "/api/v2/artwork/w500/s.jpg" }, show: { id: uid(6), posterUrl: "/api/v2/artwork/w500/x.jpg" } }), "/api/v2/artwork/w500/s.jpg")
    assertEqual(playlistEntryArtPath({ itemId: uid(8), kind: "song", song: { albumId: uid(3), posterUrl: "/api/v2/artwork/caa/a.jpg" } }), "/api/v2/artwork/caa/a.jpg")
    assertEqual(playlistEntryArtPath({ itemId: uid(9), kind: "artist", artist: { id: uid(9), posterUrl: "/api/v2/artwork/music/r.jpg" } }), "/api/v2/artwork/music/r.jpg")
    assertEqual(playlistEntryArtPath({ collectionId: uid(12), kind: "collection", collection: { id: uid(12), posterUrl: "/api/v2/artwork/w500/c.jpg" } }), "/api/v2/artwork/w500/c.jpg")
end sub

sub testEntryArtWithoutTheFieldIsTheIdAddress()
    assertEqual(playlistEntryArtPath({ itemId: uid(7), kind: "show", item: { id: uid(7) } }), "/api/v2/items/" + uid(7) + "/artwork/poster")
    assertEqual(playlistEntryArtPath({ itemId: uid(8), kind: "song", song: { albumId: uid(3) } }), "/api/v2/items/" + uid(3) + "/artwork/poster", "a song's album")
    assertEqual(playlistEntryArtPath({ collectionId: uid(12), kind: "collection", collection: { id: uid(12) } }), "/api/v2/collections/" + uid(12) + "/artwork/poster")
end sub

sub testPlayOrderStartsAtAnEntrysFirstRow()
    rows = [
        { entryId: 1, itemId: 11, kind: "episode", item: { id: 11 } }
        { entryId: 1, itemId: 12, kind: "episode", item: { id: 12 } }
        { entryId: 2, itemId: 41, kind: "movie", item: { id: 41 } }
        { entryId: 3, itemId: 11, kind: "episode", item: { id: 11 } }
    ]
    r = playOrderFrom(rows, 2)
    assertEqual(r.index, 2)
    assertEqual(r.playables.Count(), 4, "nothing is deduplicated")
    assertEqual(r.playables[2].id, 41)
    assertEqual(playOrderFrom(rows, invalid).index, 0)
    assertEqual(playOrderFrom(rows, 99).index, 0, "an unknown entry plays from the top")
end sub

sub testPlayOrderOfSongsIsTheirSongObjects()
    rows = [{ entryId: 5, itemId: 11, kind: "song", song: { id: 11, title: "Nude" } }, { entryId: 6, itemId: 12, kind: "song" }, { entryId: 7, itemId: 13, kind: "song", song: { id: 13, title: "Reckoner" } }]
    r = playOrderFrom(rows, 7)
    assertEqual(r.playables.Count(), 2, "a row without its song is left out")
    assertEqual(r.index, 1, "the index counts only what plays")
    assertEqual(r.playables[1].title, "Reckoner")
end sub

sub testCollectionCaptionCountsMovies()
    assertEqual(collectionCaption({ movieCount: 3 }), "3 movies")
    assertEqual(collectionCaption({ movieCount: 1 }), "1 movie")
end sub

sub testCollectionOrderedOnlyWhenHandOrdered()
    assertTrue(collectionOrdered({ customOrder: true }), "a hand-ordered collection")
    assertTrue(not collectionOrdered({ customOrder: false }), "a release-ordered one")
    assertTrue(not collectionOrdered({}), "one with no flag")
end sub

sub testCollectionMovieCaptionLeadsWithRuntime()
    assertEqual(collectionMovieCaption({ metadata: { runtimeMinutes: 166, releaseDate: "2024-03-01" } }), "2h 46m · 2024")
    assertEqual(collectionMovieCaption({ parsedYear: 1999 }), "1999")
    assertEqual(collectionMovieCaption({}), "")
end sub

sub testCollectionEntryHasNoItem()
    e = { id: 6, kind: "collection", collectionId: uid(12), itemCount: 3, durationMs: 330 * 60000, collection: { id: uid(12), name: "Harbor Lights Saga", movieCount: 3 } }
    assertEqual(playlistEntryTitle(e), "Harbor Lights Saga")
    assertEqual(playlistEntryCaption(e), "3 movies · 5h 30m")
    assertEqual(playlistEntryArtId(e), uid(12))
end sub

sub testPlayOrderStartsAtACollectionsFirstMovie()
    rows = [
        { entryId: 1, itemId: 31, kind: "movie", item: { id: 31 } }
        { entryId: 2, itemId: 41, kind: "movie", item: { id: 41 } }
        { entryId: 2, itemId: 42, kind: "movie", item: { id: 42 } }
        { entryId: 2, itemId: 43, kind: "movie", item: { id: 43 } }
    ]
    r = playOrderFrom(rows, 2)
    assertEqual(r.index, 1)
    assertEqual(r.playables[r.index].id, 41)
end sub

sub testEntryTitleNamesTheEditionWhenTheTitleHasSeveral()
    movie = { kind: "movie", editionId: 32, item: { parsedTitle: "Glass Orchard" } }
    assertEqual(playlistEntryTitle(movie), "Glass Orchard", "one edition: no name")
    movie.editionName = "Extended"
    assertEqual(playlistEntryTitle(movie), "Glass Orchard · Extended")
end sub

sub testPlayOrderRowsCarryTheirEdition()
    rows = [{ entryId: 2, itemId: 41, kind: "movie", editionId: 32, editionName: "Extended", item: { id: 41 } }, { entryId: 3, itemId: 11, kind: "episode", item: { id: 11 } }]
    r = playOrderFrom(rows, invalid)
    assertEqual(r.playables[0].editionId, 32, "the row's edition plays")
    assertEqual(r.playables[1].editionId, invalid, "none named: the server's default")
end sub
