' The quality menu and the pill under the seek bar.

function qualityVerdict(verdict as string) as string
    return { direct_play: "Direct play", remux: "Remux", audio_transcode: "Audio transcode", video_transcode: "Transcode" }[verdict]
end function

' Menu rows, top to bottom: { label, detail, verdict, tone, checked,
' disabled, network }, where tone is a uiColor name and network is what
' picking the row sends. Away from home Auto comes first; at home there is
' none, and Auto plays as Original. source is the file's { codec,
' hdrFormat } when known, inUse the rung the player is on.
function qualityOptions(stream as object, choice as object, source as object, inUse = invalid as dynamic) as object
    options = []
    away = stream.away = true
    if away
        detail = "Adjusts to your connection"
        if inUse <> invalid and inUse.height <> invalid then detail = "Now " + formatResolution(Int(inUse.height * 16 / 9), inUse.height) + " · adjusts to your connection"
        options.Push({ label: "Auto", detail: detail, verdict: "Transcode", tone: "accent", checked: choice.auto = true, disabled: false, network: { auto: true } })
    end if
    for i = 0 to stream.rungs.Count() - 1
        rung = stream.rungs[i]
        res = formatResolution(rung.width, rung.height)
        o = { label: res, verdict: qualityVerdict(rung.verdict), tone: "accent", disabled: rung.blocked = true }
        if i = 0
            o.label = "Original"
            o.network = {}
            o.detail = res
            if source.hdrFormat <> invalid then o.detail = o.detail + " " + formatHdr(source.hdrFormat)
            if source.codec <> invalid then o.detail = o.detail + " · " + formatCodec(source.codec)
            o.detail = o.detail + " · " + formatMbps(rung.bitrate)
            o.checked = choice.maxBitrate = invalid and (choice.auto <> true or not away)
        else
            o.network = { maxBitrate: rung.bitrate }
            o.detail = formatMbps(rung.bitrate)
            if rung.verdict = "video_transcode" then o.detail = "H.264 · " + o.detail
            o.checked = choice.maxBitrate = rung.bitrate
        end if
        if rung.verdict = "direct_play" then o.tone = "ok"
        if o.disabled
            o.verdict = "Wi-Fi only"
            o.tone = "dim"
        end if
        options.Push(o)
    end for
    return options
end function

' { tags, text, rate }: 4K HDR Direct play 38 Mb/s, or in Auto the rung in
' use, as 1080p Auto 8 Mb/s.
function qualityPill(stream as object, inUse as dynamic) as object
    n = stream.negotiated
    if stream.auto = true
        h = n.height
        bps = n.bitrate
        if inUse <> invalid and inUse.height <> invalid then h = inUse.height
        if inUse <> invalid and inUse.bitrate <> invalid then bps = inUse.bitrate
        return { tags: [formatResolution(Int(h * 16 / 9), h)], text: "Auto", rate: formatMbps(bps) }
    end if
    tags = [formatResolution(n.width, n.height)]
    if n.hdrFormat <> invalid then tags.Push("HDR")
    return { tags: tags, text: qualityVerdict(n.verdict), rate: formatMbps(n.bitrate) }
end function
