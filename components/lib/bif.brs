' Roku BIF: an 8-byte magic, version, frame count and frame separation in
' milliseconds at offsets 8, 12 and 16, then from offset 64 one
' (timestamp, offset) pair per frame and a closing pair whose offset is the
' end of the last frame. Words are little-endian.

function bifWord(b as object, i as integer) as longinteger
    return b[i] + b[i + 1] * 256& + b[i + 2] * 65536& + b[i + 3] * 16777216&
end function

' Where a playback session's BIF is fetched to. A download still running
' for an earlier stream, a dropped player's too, writes only its own file,
' and its reply names a file that is not the current stream's.
function bifFile(sessionId as dynamic) as string
    return "tmp:/rabbit-ears-" + sessionId.ToStr() + ".bif"
end function

' Frame n of a session's BIF, cut to its own file for a Poster to show.
function bifFrameFile(sessionId as dynamic, n as integer) as string
    return "tmp:/rabbit-ears-" + sessionId.ToStr() + "-" + n.ToStr() + ".jpg"
end function

' The roFileSystem.Match patterns for a session's BIF and frames in tmp:.
function bifPatterns(sessionId as dynamic) as object
    id = sessionId.ToStr()
    return ["rabbit-ears-" + id + ".bif", "rabbit-ears-" + id + "-*"]
end function

' Bytes from the start of the file through the closing index pair.
function bifHeaderBytes(b as object) as longinteger
    return 64 + (bifWord(b, 12) + 1) * 8
end function

' { intervalMs, frames: [{ offset, length }] } or invalid when b is not a
' BIF. b needs only the header and index.
function bifIndex(b as object) as dynamic
    magic = [&h89, &h42, &h49, &h46, &h0d, &h0a, &h1a, &h0a]
    if b.Count() < 64 then return invalid
    for i = 0 to 7
        if b[i] <> magic[i] then return invalid
    end for
    count = bifWord(b, 12)
    if b.Count() < bifHeaderBytes(b) then return invalid
    interval = bifWord(b, 16)
    if interval = 0 then interval = 1000
    frames = []
    for n = 0 to count - 1
        at = 64 + n * 8
        offset = bifWord(b, at + 4)
        frames.Push({ offset: offset, length: bifWord(b, at + 12) - offset })
    end for
    return { intervalMs: interval, frames: frames }
end function

function bifFrameAt(index as object, seconds as float) as integer
    n = Int(seconds * 1000 / index.intervalMs)
    if n < 0 then n = 0
    if n > index.frames.Count() - 1 then n = index.frames.Count() - 1
    return n
end function
