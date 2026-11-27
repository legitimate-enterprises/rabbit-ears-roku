' The server's answers to this device's reads, kept as files by active
' profile, server and request. A read is answered at once from what is
' kept, of any age, and the server is asked behind it; an answer the
' server changed or refused is taken, and views are told to read again. A
' write the server answered has the next read of each kept answer wait on
' the server first. What is kept stands in while the server cannot be
' reached or is failing.

' What one ApiTask run reads through: dir, the folder answers are kept in;
' slot, the function naming the profile and server active now, or "" for
' none, as while locked, when nothing is kept or answered; fetch, the
' function asking the server for { method, path } and answering
' { code, text, type, retryAfter }; and expired, the second at or before
' which a kept answer is asked for first.
function cacheContext(dir as string, slot as function, fetch as function, expired as integer) as object
    return { dir: dir, slot: slot, at: slot(), fetch: fetch, expired: expired, behind: [], files: invalid }
end function

' Reads never kept: what something waits on to change or what changes with
' the time, Me, which names the active profile, a link's token, and
' whether the server is up.
function cacheAsked() as object
    return { getme: true, listevents: true, getwatchstate: true, getupnext: true, listplaybacksessions: true, getplaybacksession: true, listwatchtogethers: true, getwatchtogether: true, liststations: true, getstation: true, polldevicelink: true, gethealth: true }
end function

' Whether a write's answer of code has the next read of everything kept ask
' first: any the server sent, except to the player's periodic reports,
' whose effect on watch state comes as a live event, and to the questions
' asked by POST.
function cacheMarks(op as string, code as integer) as boolean
    if code <= 0 then return false
    return not { reportplaybackposition: true, reportplaybackevent: true, reportplaybackthroughput: true, updateplaybacknetwork: true, updateplaybackdisplay: true, updateplaybackaudioroute: true, checkplayability: true, startlocalcheck: true }.DoesExist(LCase(op))
end function

' The reply to the GET req of op: the kept answer when there is one the
' last write did not expire, with the server asked by cacheRefresh;
' otherwise the server's, kept when it is a successful read, or the kept
' one when the server is down.
function cacheGet(ctx as object, op as string, req as object) as object
    fetch = ctx.fetch
    if ctx.at = "" or cacheAsked().DoesExist(LCase(op)) then return fetch(req)
    key = ctx.at + req.path
    kept = cacheRead(ctx, key)
    if kept <> invalid and kept.at > ctx.expired
        if kept.fresh then cacheWrite(ctx, key, kept.at, false, kept.text) else ctx.behind.Push({ req: req, key: key, kept: kept })
        return cacheReply(kept)
    end if
    at = CreateObject("roDateTime").AsSeconds()
    reply = fetch(req)
    if cacheKeeps(reply)
        cacheWrite(ctx, key, at, false, reply.text)
    else if kept <> invalid and cacheDown(reply.code)
        return cacheReply(kept)
    end if
    return reply
end function

' Asks the server for each answer read from what is kept, taking a changed
' one and dropping one it refused; true when any of either happened, for
' views to read again. A changed answer is read once more without asking.
function cacheRefresh(ctx as object) as boolean
    fetch = ctx.fetch
    changed = false
    behind = ctx.behind
    ctx.behind = []
    for each b in behind
        at = CreateObject("roDateTime").AsSeconds()
        reply = fetch(b.req)
        if cacheKeeps(reply)
            if reply.text <> b.kept.text and cacheWrite(ctx, b.key, at, true, reply.text) then changed = true
        else if not cacheDown(reply.code) and cacheDrop(ctx, b.key)
            changed = true
        end if
    end for
    return changed
end function

' Signed out: nothing kept stays.
sub cacheClear(dir as string)
    for each f in ListDir(dir)
        if Left(f, 2) = "r-" then DeleteFile(dir + f)
    end for
end sub

' A key's file name, two hashes of it; a file says which key it holds, so
' keys that share a name only miss each other. Each hash stays below 2^24,
' which a float holds exactly, as the test interpreter's Int() takes one.
function cacheName(key as string) as string
    a = 0#
    b = 0#
    for i = 1 to Len(key)
        c = Asc(Mid(key, i, 1))
        a = a * 31 + c
        a = a - Int(a / 16777213#) * 16777213#
        b = b * 131 + c
        b = b - Int(b / 16777213#) * 16777213#
    end for
    return "r-" + Int(a).ToStr() + "-" + Int(b).ToStr()
end function

' A kept answer as { at, fresh, text }, or invalid. Only files the folder
' listed are read, as reading a missing one stops the test interpreter.
' The system may evict a file meanwhile, which then reads as empty.
function cacheRead(ctx as object, key as string) as dynamic
    if ctx.files = invalid
        ctx.files = {}
        for each f in ListDir(ctx.dir)
            ctx.files[f] = true
        end for
    end if
    name = cacheName(key)
    if not ctx.files.DoesExist(name) then return invalid
    s = ReadAsciiFile(ctx.dir + name)
    nl = Instr(1, s, Chr(10))
    if nl = 0 then return invalid
    head = Left(s, nl - 1).Split(" ")
    if head.Count() < 3 or Mid(s, Len(head[0]) + Len(head[1]) + 3, nl - Len(head[0]) - Len(head[1]) - 3) <> key then return invalid
    return { at: head[0].ToInt(), fresh: head[1] = "1", text: Mid(s, nl + 1) }
end function

' Keeps text for key while the profile asking is still active, so an
' answer arriving after a switch or a sign-out is dropped; true when kept.
function cacheWrite(ctx as object, key as string, at as integer, fresh as boolean, text as string) as boolean
    slot = ctx.slot
    if slot() <> ctx.at then return false
    name = cacheName(key)
    flag = "0"
    if fresh then flag = "1"
    if not WriteAsciiFile(ctx.dir + name, at.ToStr() + " " + flag + " " + key + Chr(10) + text) then return false
    if ctx.files <> invalid then ctx.files[name] = true
    return true
end function

' True when the profile asking is still active, so its views read again.
function cacheDrop(ctx as object, key as string) as boolean
    slot = ctx.slot
    if slot() <> ctx.at then return false
    name = cacheName(key)
    DeleteFile(ctx.dir + name)
    if ctx.files <> invalid then ctx.files.Delete(name)
    return true
end function

function cacheReply(kept as object) as object
    return { code: 200, text: kept.text, type: "application/json", retryAfter: "" }
end function

function cacheKeeps(reply as object) as boolean
    return reply.code = 200 and Left(reply.type, 16) = "application/json"
end function

' Unreachable, or answering only that it is failing, as behind a proxy.
function cacheDown(code as integer) as boolean
    return code <= 0 or code >= 500
end function
