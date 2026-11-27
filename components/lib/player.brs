' The player's rules that need no Video node.

' Paused as the viewer left it: the Video node is paused, or a re-decided
' stream is held to pause once it plays.
function playerPaused(state as string, hold as boolean) as boolean
    return state = "paused" or hold
end function

' Whether the Video node's position is the loaded stream's own: it reads 0,
' or the stream before, until this one plays.
function playerStarted(state as string, seconds as double) as boolean
    return (state = "playing" or state = "paused") and seconds > 0
end function

' Where the viewer is, in ms: startMs, the stream's positionMs, until
' playerStarted, when the caller passes invalid.
function playerPositionMs(startMs as dynamic, seconds as double) as integer
    if startMs <> invalid then return startMs
    return Int(seconds * 1000)
end function

' What the router plays from a getUpNext answer: { item, editionId, queue,
' index }. From a playlist, queue holds the rows after the one at index, so
' the answered row is taken from it with the rows after; otherwise it is the
' answered item, or the video, whose channelId plays it as one.
function playerUpNext(answer as object, queue as object, index as dynamic) as object
    n = { item: answer.item, editionId: answer.editionId, queue: [], index: invalid }
    if answer.video <> invalid then n.item = answer.video
    if n.item = invalid then n.item = { id: answer.itemId }
    if answer.index = invalid or index = invalid then return n
    skip = answer.index - index
    if skip < 1 or skip > queue.Count() then return n
    n.item = queue[skip - 1]
    for i = skip to queue.Count() - 1
        n.queue.Push(queue[i])
    end for
    n.index = answer.index
    return n
end function
