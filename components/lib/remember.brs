' Remember profile: this device's choice, per signed-in adult, to start as
' the profile last active here instead of at Who's watching.

' Where launch goes from me, the getMe reply, as { go, profile }: "who" for
' Who's watching; "pin" for the remembered profile's PIN pad; "unlock" to
' unlock it without one before home; "home" to carry on as it. The server
' unlocks a profile with a PIN only with that PIN, so a locked device asks
' for it even with skipPin.
function rememberLaunch(settings as object, me as object) as object
    if not settings.remember then return { go: "who" }
    p = invalid
    for each candidate in me.profiles
        if candidate.id = me.activeProfileId and not candidate.pending and candidate.revokedAt = invalid then p = candidate
    end for
    if p = invalid then return { go: "who" }
    locked = me.locked = true
    if p.hasPin and (locked or not settings.skipPin) then return { go: "pin", profile: p }
    if locked then return { go: "unlock", profile: p }
    return { go: "home", profile: p }
end function

' The registry keys of Remember profile and Skip PIN kept under an account
' id that is no id the server gives, which no adult signs in as again.
function rememberStale(keys as object) as object
    stale = []
    for each key in keys
        for each prefix in ["remember.", "skipPin."]
            if Left(key, Len(prefix)) = prefix and not apiId(key.Mid(Len(prefix))) then stale.Push(key)
        end for
    end for
    return stale
end function
