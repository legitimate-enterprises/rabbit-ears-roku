sub testDetailsOfALosslessDirectPlay()
    groups = musicDetails({
        source: { codec: "flac", lossless: true, bitrate: 2115600, sampleRateHz: 96000, bitDepth: 24, channels: 2, sizeBytes: 67400000 }
        delivered: { verdict: "direct_play", codec: "flac", bitrate: 2115600, lossless: true }
    })
    assertEqual(groups, [
        {
            title: "Source", rows: [
                { label: "Format", value: "FLAC", tone: "text", tag: "Lossless" }
                { label: "Bitrate", value: "2,116 kb/s", tone: "text", tag: "" }
                { label: "Sample rate", value: "96 kHz", tone: "text", tag: "" }
                { label: "Bit depth", value: "24-bit", tone: "text", tag: "" }
                { label: "Channels", value: "Stereo", tone: "text", tag: "" }
                { label: "Size", value: "67.4 MB", tone: "text", tag: "" }
            ]
        }
        {
            title: "Delivered", rows: [
                { label: "Playback", value: "Direct play", tone: "ok", tag: "" }
                { label: "Codec", value: "FLAC", tone: "text", tag: "" }
                { label: "Bitrate", value: "2,116 kb/s", tone: "text", tag: "" }
            ]
        }
    ])
end sub

sub testDetailsOfAConvertedSongLeaveOutWhatIsAbsent()
    groups = musicDetails({
        source: { codec: "opus", lossless: false, sampleRateHz: 44100, channels: 6 }
        delivered: { verdict: "audio_transcode", codec: "aac", bitrate: 256000, lossless: false }
    })
    assertEqual(groups[0].rows, [
        { label: "Format", value: "Opus", tone: "text", tag: "" }
        { label: "Sample rate", value: "44.1 kHz", tone: "text", tag: "" }
        { label: "Channels", value: "6 channels", tone: "text", tag: "" }
    ])
    assertEqual(groups[1].rows, [
        { label: "Playback", value: "Audio transcode", tone: "accent", tag: "" }
        { label: "Codec", value: "AAC", tone: "text", tag: "" }
        { label: "Bitrate", value: "256 kb/s", tone: "text", tag: "" }
    ])
end sub

sub testDetailsNameMonoAndRemux()
    groups = musicDetails({ source: { channels: 1, sampleRateHz: 22050 }, delivered: { verdict: "remux", codec: "mp3", bitrate: 1005000 } })
    assertEqual(groups[0].rows, [
        { label: "Sample rate", value: "22.05 kHz", tone: "text", tag: "" }
        { label: "Channels", value: "Mono", tone: "text", tag: "" }
    ])
    assertEqual(groups[1].rows[0], { label: "Playback", value: "Remux", tone: "ok", tag: "" })
    assertEqual(groups[1].rows[2], { label: "Bitrate", value: "1,005 kb/s", tone: "text", tag: "" })
end sub

sub testDetailsOfNoAudioIsNothing()
    assertEqual(musicDetails(invalid), [])
end sub

sub testStreamFormatFollowsWhatIsDelivered()
    assertEqual(musicStreamFormat({ streamKind: "hls", negotiated: { audioCodec: "aac" } }), "hls")
    assertEqual(musicStreamFormat({ streamKind: "file", negotiated: { audioCodec: "flac" } }), "flac")
    assertEqual(musicStreamFormat({ streamKind: "file", negotiated: { audioCodec: "mp3" } }), "mp3")
    assertEqual(musicStreamFormat({ streamKind: "file", negotiated: { audioCodec: "alac" } }), "mp4")
    assertEqual(musicStreamFormat({ streamKind: "file", negotiated: {} }), "mp4")
end sub

sub testAdvanceStopsAtTheEndUnlessRepeating()
    assertEqual(musicAdvance(0, 3, false, 1), 1)
    assertEqual(musicAdvance(2, 3, false, 1), -1)
    assertEqual(musicAdvance(2, 3, true, 1), 0)
    assertEqual(musicAdvance(1, 3, false, -1), 0)
    assertEqual(musicAdvance(0, 3, false, -1), 0, "previous on the first restarts it")
    assertEqual(musicAdvance(0, 3, true, -1), 2)
    assertEqual(musicAdvance(0, 0, true, 1), -1, "an empty queue")
end sub

sub testShuffleKeepsTheCurrentSongFirst()
    songs = [{ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }, { id: 5 }]
    out = musicShuffle(songs, 2)
    assertEqual(out.Count(), 5)
    assertEqual(out[0].id, 3)
    seen = {}
    for each s in out
        seen[s.id.ToStr()] = true
    end for
    assertEqual(seen.Count(), 5, "every song once")
end sub

sub testTheQueueGrowsWhenPlaybackNearsItsEnd()
    more = { op: "listMusicSongs", params: {}, query: {}, offset: 2000 }
    assertTrue(musicMoreDue(1980, 2000, more, false), "near the end")
    assertTrue(musicMoreDue(1999, 2000, more, false), "on the last song")
    assertTrue(not musicMoreDue(0, 2000, more, false), "far from the end")
    assertTrue(not musicMoreDue(1999, 2000, more, true), "a batch in flight")
    assertTrue(not musicMoreDue(1999, 2000, invalid, false), "the list is exhausted")
end sub

sub testAGrownQueueKeepsItsOrderWithoutShuffle()
    q = [{ id: 1 }, { id: 2 }]
    musicGrow(q, q, false, [{ id: 3 }, { id: 4 }])
    assertEqual(q.Count(), 4)
    assertEqual(q[3].id, 4)
end sub

sub testAGrownShuffledQueueDealsTheBatchAfterWhatIsQueued()
    ordered = [{ id: 1 }, { id: 2 }, { id: 3 }]
    queue = [{ id: 2 }, { id: 3 }, { id: 1 }]
    batch = []
    for i = 4 to 40
        batch.Push({ id: i })
    end for
    musicGrow(queue, ordered, true, batch)
    assertEqual(ordered.Count(), 40)
    assertEqual(ordered[39].id, 40, "the original order is kept for shuffle off")
    assertEqual(queue.Count(), 40)
    assertEqual([queue[0].id, queue[1].id, queue[2].id], [2, 3, 1], "what is queued does not move")
    seen = {}
    moved = false
    for i = 3 to 39
        seen[queue[i].id.ToStr()] = true
        if queue[i].id <> i + 1 then moved = true
    end for
    assertEqual(seen.Count(), 37, "every new song once")
    assertTrue(moved, "the batch is dealt at random")
end sub

sub testAlbumFactsAsTheBoardPrintsThem()
    album = { year: 2007, songCount: 10, durationMs: 42 * 60000 + 29000, lossless: true }
    assertEqual(musicAlbumFacts(album), ["2007", "10 songs", "42m"])
    assertEqual(musicAlbumFacts({ songCount: 1, durationMs: 75 * 60000 }), ["1 song", "1h 15m"])
end sub

sub testArtistFactsNameTheFirstGenre()
    artist = { albumCount: 9, songCount: 112, genres: [{ id: 1, name: "Alternative rock" }, { id: 2, name: "Art rock" }] }
    assertEqual(musicArtistFacts(artist), ["9 albums", "112 songs", "Alternative rock"])
    assertEqual(musicArtistFacts({ albumCount: 1, songCount: 1, genres: [] }), ["1 album", "1 song"])
end sub

sub testAFailureWithTheServerOutOfReachStopsOnTheSongWithoutSkipping()
    unreachable = apiResult(-28, "")
    assertEqual(musicAfterFailure(unreachable, 1, 1), "hold", "out of reach")
    refused = apiResult(409, "{""code"": ""no_playable_entry"", ""message"": ""no""}")
    assertEqual(musicAfterFailure(refused, 1, 1), "skip", "the server refused the song")
    assertEqual(musicAfterFailure(refused, 3, 1), "stop", "three in a row")
    assertEqual(musicAfterFailure(refused, 1, -1), "stop", "the last song")
end sub

sub testSongNumbersAreTrackNumbersOrPositions()
    assertEqual(musicSongNumber({ trackNumber: 4 }, 0), "4")
    assertEqual(musicSongNumber({}, 2), "3")
end sub
