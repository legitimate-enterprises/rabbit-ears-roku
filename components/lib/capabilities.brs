' The capability snapshot from roDeviceInfo. Every function takes the device
' as an argument, so tests pass a stand-in that answers from a table.

' Probes per codec: ffprobe's codec name, roDeviceInfo's, the profiles as
' [ffprobe name, Roku name, bit depth], and the levels from highest as
' [Roku level, ffprobe level, max height, max frame rate].
function capabilityVideoProbes() as object
    return [
        {
            codec: "h264", roku: "mpeg4 avc"
            profiles: [["Constrained Baseline", "baseline", 8], ["Main", "main", 8], ["High", "high", 8]]
            ' Roku decodes H.264 to 1080p at any level.
            levels: [["5.1", 51, 1080, 60], ["4.2", 42, 1080, 60], ["4.1", 41, 1080, 30], ["4.0", 40, 1080, 30]]
        }
        {
            codec: "hevc", roku: "hevc"
            profiles: [["Main", "main", 8], ["Main 10", "main 10", 10]]
            levels: [["5.1", 153, 2160, 60], ["5.0", 150, 2160, 30], ["4.1", 123, 1080, 60], ["4.0", 120, 1080, 30]]
        }
        { codec: "vp9", roku: "vp9", profiles: [["Profile 0", "profile 0", 8], ["Profile 2", "profile 2", 10]], levels: [] }
        { codec: "av1", roku: "av1", profiles: [["Main", "main", 10]], levels: [] }
    ]
end function

' Group A. The server muxes MPEG-TS segments for Roku, which does not play
' fragmented MP4 HLS with audio muxed in.
function capabilityDecoder(di as object) as object
    videoCodecs = []
    ' shortcut: roDeviceInfo takes no level for VP9 and AV1, so they borrow HEVC's ceiling; probe them by size if a device ever disagrees.
    ceiling = { height: 1080, fps: 60 }
    for each probe in capabilityVideoProbes()
        profiles = []
        level = invalid
        height = 0
        fps = 0
        depth = 8
        for each p in probe.profiles
            levels = probe.levels
            if levels.Count() = 0 then levels = [[invalid, invalid, ceiling.height, ceiling.fps]]
            for each l in levels
                query = { Codec: probe.roku, Profile: p[1] }
                if l[0] <> invalid then query.Level = l[0]
                if di.CanDecodeVideo(query).result
                    profiles.Push(p[0])
                    if l[1] <> invalid and (level = invalid or l[1] > level) then level = l[1]
                    if l[2] > height then height = l[2]
                    if l[3] > fps then fps = l[3]
                    if p[2] > depth then depth = p[2]
                    exit for
                end if
            end for
        end for
        if profiles.Count() > 0
            ' HDR needs a 10-bit decode; which formats is the display's answer.
            hdr = []
            if depth >= 10 then hdr = capabilityHdr(di)
            ' Literal keys keep their case in the JSON body; dot assignment would lowercase them.
            d = { codec: probe.codec, profiles: profiles, hardware: true, maxWidth: Int(height * 16 / 9), maxHeight: height, maxFrameRate: fps, maxBitDepth: depth, hdrFormats: hdr }
            if level <> invalid then d.AddReplace("maxLevel", level)
            if probe.codec = "hevc" then ceiling = { height: height, fps: fps }
            videoCodecs.Push(d)
        end if
    end for
    containers = []
    for each c in ["mp4", "mkv", "mov"]
        if di.CanDecodeVideo({ Codec: "mpeg4 avc", Container: c }).result then containers.Push(c)
    end for
    audioCodecs = []
    for each c in ["aac", "ac3", "eac3", "mp3", "flac", "opus", "alac", "dts", "truehd"]
        if di.CanDecodeAudio({ Codec: c }).result
            audioCodecs.Push(c)
            ' A FLAC or MP3 file is its codec's own framing, so the Audio node plays the file as it is.
            if c = "flac" or c = "mp3" then containers.Push(c)
        end if
    end for
    return {
        protocols: ["http", "hls"]
        containers: containers
        videoCodecs: videoCodecs
        audioCodecs: audioCodecs
        ' Bitmap subtitles are converted or burned in by the server.
        subtitleFormats: ["webvtt"]
        segmentFormats: ["ts"]
    }
end function

' The Video node's streamFormat: HLS, or a file by the container name the
' server gives it (mp4, mov or mkv, as probed above).
function capabilityStreamFormat(streamKind as string, container as dynamic) as string
    if streamKind = "hls" then return "hls"
    if container = "mkv" then return "mkv"
    return "mp4"
end function

function capabilityHdr(di as object) as object
    props = di.GetDisplayProperties()
    formats = []
    for each f in [["Hdr10", "hdr10"], ["Hdr10Plus", "hdr10plus"], ["DolbyVision", "dolby_vision"], ["HLG", "hlg"]]
        if props[f[0]] = true then formats.Push(f[1])
    end for
    return formats
end function

' Group B. GetVideoMode names the output, such as 1080p, 720p50 or
' 2160p60b10; no rate means 60.
function capabilityDisplay(di as object) as object
    mode = di.GetVideoMode()
    height = Val(mode)
    rate = 60
    for i = 1 to Len(mode)
        c = Mid(mode, i, 1)
        if c = "p" or c = "i"
            tail = Val(Mid(mode, i + 1))
            if tail > 0 then rate = tail
            exit for
        end if
    end for
    width = { "2160": 3840, "1080": 1920, "720": 1280, "576": 720, "480": 720 }[height.ToStr()]
    if width = invalid then width = Int(height * 16 / 9)
    return { width: width, height: height, refreshRate: rate, hdrFormats: capabilityHdr(di) }
end function

' Group C.
function capabilityAudioRoute(di as object) as object
    route = LCase(di.GetAudioOutputChannel())
    channels = 2
    if Instr(1, route, "5.1") > 0 then channels = 6
    if Instr(1, route, "7.1") > 0 then channels = 8
    passthrough = []
    for each c in ["ac3", "eac3", "dts", "truehd"]
        if di.CanDecodeAudio({ Codec: c, PassThru: 1 }).result then passthrough.Push(c)
    end for
    return { channels: channels, passthroughCodecs: passthrough }
end function

' Group D. Roku reports neither a metered path nor a low-data mode, and a
' VPN is invisible to an app. quality is {}, { auto: true } or
' { maxBitrate: n }.
function capabilityNetwork(discovered as boolean, quality as object) as object
    ' auto is always sent: the server treats a snapshot without it as a v1 client.
    n = { discoveredLocally: discovered, metered: false, lowData: false, vpn: false, auto: false }
    n.Append(quality)
    return n
end function

' decoder is capabilityDecoder's answer, which the caller probes once and keeps.
function capabilitySnapshot(di as object, decoder as object, discovered as boolean, quality as object) as object
    return {
        decoder: decoder
        display: capabilityDisplay(di)
        audioRoute: capabilityAudioRoute(di)
        network: capabilityNetwork(discovered, quality)
    }
end function

' What a mid-playback change is measured against. The connection type
' stands in for the path: a new one can mean a new source address.
function capabilityReading(di as object) as object
    return { display: capabilityDisplay(di), audioRoute: capabilityAudioRoute(di), connection: di.GetConnectionType() }
end function

' The groups to re-send: display and audioRoute carry their new value;
' network is true, since its value depends on the viewer's quality pick.
function capabilityChanged(before as object, now as object) as object
    changed = {}
    for each group in ["display", "audioRoute"]
        if FormatJson(before[group]) <> FormatJson(now[group]) then changed[group] = now[group]
    end for
    if before.connection <> now.connection then changed.network = true
    return changed
end function
