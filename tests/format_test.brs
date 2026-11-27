sub testRuntimeLeadsWithHours()
    assertEqual(formatRuntime(166), "2h 46m")
    assertEqual(formatRuntime(120), "2h")
    assertEqual(formatRuntime(50), "50m")
    assertEqual(formatRuntime(invalid), "")
end sub

sub testDurationToTheNearestMinute()
    assertEqual(formatDuration(166 * 60000 + 20000), "2h 46m")
    assertEqual(formatDuration(49 * 60000 + 30000), "50m")
    assertEqual(formatDuration(0), "")
    assertEqual(formatDuration(invalid), "")
end sub

sub testPartsSkipTheEmptyOnes()
    assertEqual(formatParts(["2024", "", "2h 46m"]), "2024 · 2h 46m")
    assertEqual(formatParts(["", ""]), "")
    assertEqual(formatParts([]), "")
end sub

sub testTimeLeft()
    assertEqual(formatLeft(50, 27 * 60000), "23m left")
    assertEqual(formatLeft(166, 60000), "2h 45m left")
    assertEqual(formatLeft(invalid, 1000), "")
end sub

sub testClock()
    assertEqual(formatClock(1504), "25:04")
    assertEqual(formatClock(3723), "1:02:03")
    assertEqual(formatClock(-5), "0:00")
end sub

sub testMbpsDropsTrailingZero()
    assertEqual(formatMbps(38000000), "38 Mb/s")
    assertEqual(formatMbps(8000000), "8 Mb/s")
    assertEqual(formatMbps(1500000), "1.5 Mb/s")
    assertEqual(formatMbps(800000), "0.8 Mb/s")
end sub

sub testResolutionLabel()
    assertEqual(formatResolution(3840, 2160), "4K")
    assertEqual(formatResolution(1920, 800), "1080p")
    assertEqual(formatResolution(1280, 720), "720p")
    assertEqual(formatResolution(854, 480), "480p")
    assertEqual(formatResolution(640, 360), "360p")
end sub

sub testItemTitleAndEpisodeCode()
    e = { kind: "episode", parsedTitle: "woes.hollow", seasonNumber: 2, episodeNumber: 4, metadata: { title: "Woe's Hollow" } }
    assertEqual(itemTitle(e), "Woe's Hollow")
    assertEqual(itemTitle({ parsedTitle: "Flow" }), "Flow")
    assertEqual(formatEpisodeCode(e), "S2 E4")
end sub

sub testYear()
    assertEqual(formatYear({ metadata: { releaseDate: "2024-03-01" } }), "2024")
    assertEqual(formatYear({ parsedYear: 1995 }), "1995")
    assertEqual(formatYear({}), "")
end sub


sub testDate()
    assertEqual(formatDate("2025-02-07"), "Feb 7, 2025")
    assertEqual(formatDate("2024-12-25T00:00:00Z"), "Dec 25, 2024")
    assertEqual(formatDate(invalid), "")
    assertEqual(formatDate("2024-00-10"), "", "a month outside 01-12")
    assertEqual(formatDate("2024-13-10"), "", "a month outside 01-12")
end sub

sub testLanguage()
    assertEqual(formatLanguage("eng"), "English")
    assertEqual(formatLanguage("spa"), "Spanish")
    assertEqual(formatLanguage("xho"), "XHO")
    assertEqual(formatLanguage(invalid), "Unknown")
end sub

sub testAudioTrack()
    assertEqual(formatAudio({ language: "eng", title: "Dolby Atmos 7.1", codec: "truehd", channels: 8 }), "English · Dolby Atmos 7.1")
    assertEqual(formatAudio({ language: "eng", codec: "eac3", channels: 6 }), "English · Dolby Digital Plus 5.1")
    assertEqual(formatAudio({ language: "fre", codec: "aac", channels: 2 }), "French · AAC Stereo")
end sub

sub testSubtitleTrack()
    assertEqual(formatSubtitle({ language: "eng", title: "English SDH" }), "English SDH")
    assertEqual(formatSubtitle({ language: "spa" }), "Spanish")
end sub

function subs(specs as object) as object
    tracks = [{ kind: "audio", language: "fre" }]
    for each s in specs
        parts = s.Split("/")
        t = { kind: "subtitle", language: parts[0] }
        if parts.Count() > 1 then t.title = parts[1]
        tracks.Push(t)
    end for
    return tracks
end function

sub testSubtitlesLineListsAFewAndSummarizesMany()
    assertEqual(formatSubtitles(subs(["eng"])), "English")
    assertEqual(formatSubtitles(subs(["eng", "eng/SDH", "spa"])), "English, English SDH, Spanish")
    assertEqual(formatSubtitles(subs(["eng", "eng/SDH", "spa", "fre", "ger"])), "English, English SDH, +3 other languages")
    assertEqual(formatSubtitles(subs(["eng", "spa", "spa/SDH", "spa"])), "English, +1 other language")
    assertEqual(formatSubtitles(subs(["eng", "eng", "eng", "eng"])), "English")
    assertEqual(formatSubtitles(subs(["spa", "fre", "ger", "ita"])), "4 languages")
    assertEqual(formatSubtitles(subs(["spa", "spa/SDH", "spa", "spa"])), "Spanish, Spanish SDH")
    assertEqual(formatSubtitles(subs(["EN-us", "en", "spa", "fre"])), "EN-US, EN, +2 other languages", "en and a region count as English")
    assertEqual(formatSubtitles(subs(["eng", "und", "", "spa"])), "English, +2 other languages", "missing and und are one language")
    assertEqual(formatSubtitles(subs([])), "")
end sub

sub testVideoLine()
    file = { bitrate: 38000000, tracks: [{ kind: "video", codec: "hevc", width: 3840, height: 2160, hdrFormat: "hdr10" }] }
    assertEqual(formatVideo(file), "4K HDR10 · HEVC · 38 Mb/s")
    file.tracks[0].hdrFormat = "dolby_vision"
    assertEqual(formatVideo(file), "4K Dolby Vision · HEVC · 38 Mb/s")
    assertEqual(formatVideo({ tracks: [{ kind: "video", codec: "h264", width: 1920, height: 1080 }] }), "1080p · H.264")
    assertEqual(formatVideo(invalid), "")
end sub

sub testCountsGroupThousands()
    assertEqual(formatCount(1210), "1,210")
    assertEqual(formatCount(14), "14")
    assertEqual(formatCount(1000000), "1,000,000")
    assertEqual(formatCountOf(1, "song"), "1 song")
    assertEqual(formatCountOf(1140, "movie"), "1,140 movies")
    assertEqual(formatCountOf(0, "video"), "0 videos")
    assertEqual(formatCountOf(2000, "song", true), "2,000+ songs", "rows remain to load")
end sub

sub testAPagedListCountsFromTheServersTotal()
    assertEqual(formatCountOfTotal(3150, 2000, "song", true), "3,150 songs", "rows remain to load")
    assertEqual(formatCountOfTotal(1, 1, "album", false), "1 album")
    assertEqual(formatCountOfTotal(0, 0, "station", false), "0 stations")
    assertEqual(formatCountOfTotal(invalid, 2000, "video", true), "2,000+ videos", "no total to go by")
    assertEqual(formatCountOfTotal(invalid, 7, "video", false), "7 videos")
end sub

sub testDaysAgoAsTheBoardsWordThem()
    today = "2026-11-14"
    assertEqual(formatAgo("2026-11-14", today), "today")
    assertEqual(formatAgo("2026-11-13", today), "yesterday")
    assertEqual(formatAgo("2026-11-11", today), "3 days ago")
    assertEqual(formatAgo("2026-11-05", today), "last week")
    assertEqual(formatAgo("2026-10-31", today), "2 weeks ago")
    assertEqual(formatAgo("2026-10-10", today), "last month")
    assertEqual(formatAgo("2026-09-01", today), "2 months ago")
    assertEqual(formatAgo("2025-10-01", today), "last year")
    assertEqual(formatAgo("2023-02-28", today), "3 years ago")
    assertEqual(formatAgo("2024-03-01", "2024-02-28"), "today", "a date after today reads today")
    assertEqual(formatAgo("2024-03-01", "2024-03-02"), "yesterday", "across a leap day")
    assertEqual(formatAgo(invalid, today), "")
end sub

sub testVideoCaptionLeadsWithTheChannel()
    v = { channelTitle: "Workbench Weekly", durationMs: 42 * 60000 + 20000, publishedOn: "2026-11-14" }
    assertEqual(formatVideoCaption(v, "2026-11-14", true), "Workbench Weekly · 42m · today")
    assertEqual(formatVideoCaption(v, "2026-11-28", false), "42m · 2 weeks ago")
    assertEqual(formatVideoCaption({ channelTitle: "Pocket Atlas" }, "2026-11-14", true), "Pocket Atlas")
    v.durationMs = 42 * 60000 + 59000
    assertEqual(formatVideoCaption(v, "2026-11-14", false), "43m · today", "a length rounds to the nearest minute")
end sub

sub testProfileColorIsTheServers()
    assertEqual(formatProfileColor("#3C4170"), "0x3C4170FF")
    assertEqual(formatProfileColor(invalid), "0x3C4170FF", "a missing color reads as the first")
end sub

sub testPersonColorIsTheIdsLastByteOfTheEight()
    assertEqual(formatPersonColor(uid(1)), formatPersonColor(uid(9)))
    assertEqual(formatPersonColor(uid(0)), "0x3C4170FF")
    assertEqual(formatPersonColor(uid(7)), "0x4A6B2EFF")
    assertEqual(formatPersonColor("019ac3e0-5b2a-7c3d-8e4f-0000000000ff"), "0x4A6B2EFF", "0xff is 255")
end sub
