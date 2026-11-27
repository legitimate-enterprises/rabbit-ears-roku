' A stand-in roDeviceInfo: answers come from the tables below, and every
' CanDecodeVideo query is recorded so its shape can be checked.
function fakeDevice() as object
    return {
        queries: []
        video: { "mpeg4 avc|baseline|4.2": true, "mpeg4 avc|main|4.2": true, "mpeg4 avc|high|4.2": true, "hevc|main|5.1": true, "hevc|main 10|5.1": true, "mpeg4 avc|mp4": true, "mpeg4 avc|mkv": true }
        audio: { aac: true, ac3: true, eac3: true, mp3: true, flac: true }
        passthrough: { ac3: true, eac3: true, dts: true }
        mode: "2160p60b10"
        display: { Hdr10: true, Hdr10Plus: false, HLG: true, DolbyVision: false }
        channel: "5.1 surround"
        connection: "WiFiConnection"
        CanDecodeVideo: function(f as object) as object
            m.queries.Push(f)
            key = f.Codec + "|"
            if f.Container <> invalid
                key = key + f.Container
            else
                key = key + f.Profile + "|"
                if f.Level <> invalid then key = key + f.Level
            end if
            return { result: m.video[key] = true }
        end function
        CanDecodeAudio: function(f as object) as object
            if f.PassThru = 1 then return { result: m.passthrough[f.Codec] = true }
            return { result: m.audio[f.Codec] = true }
        end function
        GetVideoMode: function() as string
            return m.mode
        end function
        GetDisplayProperties: function() as object
            return m.display
        end function
        GetAudioOutputChannel: function() as string
            return m.channel
        end function
        GetConnectionType: function() as string
            return m.connection
        end function
    }
end function

sub testDecoderReportsHlsWithTsSegmentsAndFileContainers()
    d = capabilityDecoder(fakeDevice())
    assertEqual(d.protocols, ["http", "hls"])
    assertEqual(d.segmentFormats, ["ts"])
    assertEqual(d.containers, ["mp4", "mkv", "mp3", "flac"])
    assertEqual(d.subtitleFormats, ["webvtt"])
end sub

sub testDecoderReportsAnAudioFileOnlyWhenItsCodecDecodes()
    device = fakeDevice()
    device.audio = { aac: true, mp3: true }
    assertEqual(capabilityDecoder(device).containers, ["mp4", "mkv", "mp3"])
end sub

sub testDecoderVideoProfilesAndLevels()
    d = capabilityDecoder(fakeDevice())
    assertEqual(d.videoCodecs.Count(), 2, "only h264 and hevc decode")
    h264 = d.videoCodecs[0]
    assertEqual(h264.codec, "h264")
    assertEqual(h264.profiles, ["Constrained Baseline", "Main", "High"])
    assertEqual(h264.maxLevel, 42)
    assertEqual([h264.maxWidth, h264.maxHeight, h264.maxFrameRate, h264.maxBitDepth], [1920, 1080, 60, 8])
    assertTrue(h264.hardware)
    hevc = d.videoCodecs[1]
    assertEqual(hevc.profiles, ["Main", "Main 10"])
    assertEqual(hevc.maxLevel, 153)
    assertEqual([hevc.maxWidth, hevc.maxHeight, hevc.maxBitDepth], [3840, 2160, 10])
    assertEqual(hevc.hdrFormats, ["hdr10", "hlg"])
end sub

sub testDecoderTakesTheHighestLevelThatDecodes()
    device = fakeDevice()
    device.video = { "hevc|main|5.0": true, "hevc|main|4.1": true }
    d = capabilityDecoder(device)
    hevc = d.videoCodecs[0]
    assertEqual(hevc.maxLevel, 150)
    assertEqual([hevc.maxHeight, hevc.maxFrameRate, hevc.maxBitDepth], [2160, 30, 8])
    assertEqual(hevc.hdrFormats, [], "8-bit decode carries no HDR")
end sub

sub testDecoderQueriesUseRokuCodecNames()
    device = fakeDevice()
    capabilityDecoder(device)
    first = device.queries[0]
    assertEqual(first.Codec, "mpeg4 avc")
    assertEqual(first.Profile, "baseline")
    assertEqual(first.Level, "5.1")
end sub

sub testDecoderAudioDecodeOnly()
    d = capabilityDecoder(fakeDevice())
    assertEqual(d.audioCodecs, ["aac", "ac3", "eac3", "mp3", "flac"], "DTS passes through but does not decode")
end sub

sub testDisplayFromVideoModeAndHdr()
    device = fakeDevice()
    assertEqual(capabilityDisplay(device), { width: 3840, height: 2160, refreshRate: 60, hdrFormats: ["hdr10", "hlg"] })
    device.mode = "1080p"
    device.display = {}
    assertEqual(capabilityDisplay(device), { width: 1920, height: 1080, refreshRate: 60, hdrFormats: [] })
    device.mode = "720p50"
    assertEqual(capabilityDisplay(device).refreshRate, 50)
    assertEqual(capabilityDisplay(device).width, 1280)
    device.mode = "480i"
    assertEqual(capabilityDisplay(device).width, 720)
end sub

sub testAudioRouteChannelsAndPassthrough()
    device = fakeDevice()
    assertEqual(capabilityAudioRoute(device), { channels: 6, passthroughCodecs: ["ac3", "eac3", "dts"] })
    device.channel = "Stereo"
    device.passthrough = {}
    assertEqual(capabilityAudioRoute(device), { channels: 2, passthroughCodecs: [] })
end sub

sub testNetworkHasNoMeteredOrLowData()
    assertEqual(capabilityNetwork(true, { auto: true }), { discoveredLocally: true, metered: false, lowData: false, vpn: false, auto: true })
    assertEqual(capabilityNetwork(false, { maxBitrate: 4000000 }), { discoveredLocally: false, metered: false, lowData: false, vpn: false, auto: false, maxBitrate: 4000000 })
    assertEqual(capabilityNetwork(false, {}), { discoveredLocally: false, metered: false, lowData: false, vpn: false, auto: false })
end sub

sub testSnapshotHasEveryGroup()
    s = capabilitySnapshot(fakeDevice(), { protocols: ["hls"] }, true, { auto: true })
    assertEqual(s.Keys(), ["audioRoute", "decoder", "display", "network"])
    assertEqual(s.decoder, { protocols: ["hls"] }, "the decoder group as probed once")
end sub

sub testChangedGroupsNamesOnlyWhatMoved()
    device = fakeDevice()
    before = capabilityReading(device)
    assertEqual(capabilityChanged(before, capabilityReading(device)), {})
    device.channel = "Stereo"
    assertEqual(capabilityChanged(before, capabilityReading(device)).Keys(), ["audioRoute"])
    device.mode = "1080p"
    device.connection = "WiredConnection"
    assertEqual(capabilityChanged(before, capabilityReading(device)).Keys(), ["audioRoute", "display", "network"])
end sub

sub testSnapshotJsonKeepsSchemaKeyCase()
    json = FormatJson(capabilitySnapshot(fakeDevice(), capabilityDecoder(fakeDevice()), true, { auto: true }))
    for each key in ["maxLevel", "maxWidth", "hdrFormats", "segmentFormats", "passthroughCodecs", "discoveredLocally", "refreshRate", "audioRoute"]
        assertTrue(Instr(1, json, Chr(34) + key + Chr(34)) > 0, key)
    end for
end sub

sub testStreamFormatFollowsTheServersContainerNames()
    assertEqual(capabilityStreamFormat("hls", "mkv"), "hls")
    assertEqual(capabilityStreamFormat("file", "mkv"), "mkv")
    assertEqual(capabilityStreamFormat("file", "mp4"), "mp4")
    assertEqual(capabilityStreamFormat("file", "mov"), "mp4")
    assertEqual(capabilityStreamFormat("file", invalid), "mp4")
end sub
