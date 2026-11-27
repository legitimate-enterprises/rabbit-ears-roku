' Group E, sent every 10 seconds and on every stall.

' The rung in use from the Video node's streamingSegment: its declared
' bitrate, matched to the nearest rung for the height and index, since a
' variant's declared bitrate carries audio on top of the rung's.
function telemetryRung(segment as dynamic, rungs as object) as object
    if segment = invalid or segment.segBitrateBps = invalid or segment.segBitrateBps <= 0 then return {}
    bps = segment.segBitrateBps
    r = { rungBitrate: bps }
    best = -1
    for i = 0 to rungs.Count() - 1
        if best < 0 or Abs(rungs[i].bitrate - bps) < Abs(rungs[best].bitrate - bps) then best = i
    end for
    ' AddReplace keeps the key's case in the JSON body; dot assignment would lowercase it.
    if best >= 0
        r.AddReplace("currentRung", best)
        r.AddReplace("rungHeight", rungs[best].height)
    end if
    return r
end function

function telemetrySample(measuredBps as dynamic, bufferMs as integer, stalls as integer, rung as object, positionMs as integer) as object
    measured = Int(measuredBps)
    if measured < 0 then measured = 0
    if bufferMs < 0 then bufferMs = 0
    if positionMs < 0 then positionMs = 0
    s = { measuredBitrate: measured, bufferMs: bufferMs, stallCount: stalls, positionMs: positionMs }
    s.Append(rung)
    return s
end function
