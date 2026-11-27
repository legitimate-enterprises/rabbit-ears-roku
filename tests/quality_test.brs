function homeStream() as object
    return {
        away: false
        negotiated: { verdict: "direct_play", width: 3840, height: 2160, hdrFormat: "hdr10", bitrate: 38000000 }
        rungs: [
            { width: 3840, height: 2160, bitrate: 38000000, verdict: "direct_play" }
            { width: 1920, height: 1080, bitrate: 8000000, verdict: "video_transcode" }
            { width: 1280, height: 720, bitrate: 4000000, verdict: "video_transcode" }
        ]
    }
end function

sub testHomeMenuHasNoAuto()
    options = qualityOptions(homeStream(), { auto: true }, { codec: "hevc", hdrFormat: "hdr10" })
    assertEqual(options.Count(), 3)
    assertEqual(options[0].label, "Original")
    assertEqual(options[0].detail, "4K HDR10 · HEVC · 38 Mb/s")
    assertEqual(options[0].verdict, "Direct play")
    assertEqual(options[0].tone, "ok")
    assertTrue(options[0].checked, "Auto at home plays as Original")
    assertEqual(options[1].label, "1080p")
    assertEqual(options[1].detail, "H.264 · 8 Mb/s")
    assertEqual(options[1].verdict, "Transcode")
    assertEqual(options[1].tone, "accent", "a uiColor name")
    assertEqual(options[1].network, { maxBitrate: 8000000 })
    assertEqual(options[0].network, {})
end sub

sub testFixedPickIsChecked()
    options = qualityOptions(homeStream(), { maxBitrate: 4000000 }, {})
    assertTrue(not options[0].checked)
    assertTrue(options[2].checked)
    assertEqual(options[0].detail, "4K · 38 Mb/s", "no source facts")
end sub

sub testAwayMenuOffersAutoFirstAndBlocksRungs()
    s = homeStream()
    s.away = true
    s.auto = true
    s.rungs[0].verdict = "remux"
    s.rungs[1].blocked = true
    options = qualityOptions(s, { auto: true }, {}, { height: 720, bitrate: 4000000 })
    assertEqual(options.Count(), 4)
    assertEqual(options[0].label, "Auto")
    assertEqual(options[0].detail, "Now 720p · adjusts to your connection")
    assertEqual(options[0].network, { auto: true })
    assertTrue(options[0].checked)
    assertEqual(options[1].verdict, "Remux")
    assertTrue(options[2].disabled)
    assertEqual(options[2].verdict, "Wi-Fi only")
    assertTrue(not options[3].disabled)
end sub

sub testAutoDetailBeforeARungIsKnown()
    s = homeStream()
    s.away = true
    options = qualityOptions(s, { auto: true }, {})
    assertEqual(options[0].detail, "Adjusts to your connection")
end sub

sub testPillReadsTheNegotiatedStream()
    assertEqual(qualityPill(homeStream(), invalid), { tags: ["4K", "HDR"], text: "Direct play", rate: "38 Mb/s" })
end sub

sub testPillInAutoReadsTheRungInUse()
    s = homeStream()
    s.auto = true
    s.negotiated.verdict = "video_transcode"
    assertEqual(qualityPill(s, { height: 1080, bitrate: 8000000 }), { tags: ["1080p"], text: "Auto", rate: "8 Mb/s" })
end sub
