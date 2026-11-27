function ladder() as object
    return [
        { width: 3840, height: 2160, bitrate: 38000000 }
        { width: 1920, height: 1080, bitrate: 8000000 }
        { width: 1280, height: 720, bitrate: 4000000 }
        { width: 854, height: 480, bitrate: 1500000 }
    ]
end function

sub testRungFromTheSegmentBitrate()
    r = telemetryRung({ segBitrateBps: 4128000, segUrl: "/api/v1/streams/k/0/2/7.ts" }, ladder())
    assertEqual(r, { currentRung: 2, rungHeight: 720, rungBitrate: 4128000 })
end sub

sub testNoRungBeforeTheFirstSegment()
    assertEqual(telemetryRung(invalid, ladder()), {})
    assertEqual(telemetryRung({ segBitrateBps: 0 }, ladder()), {})
end sub

sub testRungWithoutALadder()
    assertEqual(telemetryRung({ segBitrateBps: 8000000 }, []), { rungBitrate: 8000000 })
end sub

sub testSample()
    s = telemetrySample(5123456, 12000, 2, { currentRung: 1, rungHeight: 1080, rungBitrate: 8000000 }, 61000)
    assertEqual(s, { measuredBitrate: 5123456, bufferMs: 12000, stallCount: 2, currentRung: 1, rungHeight: 1080, rungBitrate: 8000000, positionMs: 61000 })
    assertEqual(telemetrySample(1500.6, 0, 0, {}, 0).measuredBitrate, 1500)
    assertEqual(telemetrySample(-1, -5, 0, {}, -1), { measuredBitrate: 0, bufferMs: 0, stallCount: 0, positionMs: 0 })
end sub

sub testSampleJsonKeepsSchemaKeyCase()
    json = FormatJson(telemetrySample(1, 2, 3, telemetryRung({ segBitrateBps: 8000000 }, ladder()), 4))
    for each key in ["measuredBitrate", "bufferMs", "stallCount", "currentRung", "rungHeight", "rungBitrate", "positionMs"]
        assertTrue(Instr(1, json, Chr(34) + key + Chr(34)) > 0, key)
    end for
end sub
