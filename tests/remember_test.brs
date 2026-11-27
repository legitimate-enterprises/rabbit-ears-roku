function rememberMe(locked as boolean, activeId as integer) as object
    return {
        activeProfileId: activeId
        locked: locked
        profiles: [
            { id: 1, kind: "adult", name: "Ada", hasPin: true, pending: false }
            { id: 2, kind: "kid", name: "Jason", hasPin: false, pending: false }
            { id: 3, kind: "adult", name: "Bea", hasPin: false, pending: true }
            { id: 4, kind: "adult", name: "Cy", hasPin: false, pending: false, revokedAt: "2026-11-01T00:00:00Z" }
        ]
    }
end function

sub testOffShowsWhoIsWatching()
    assertEqual(rememberLaunch({ remember: false, skipPin: true }, rememberMe(false, 2)), { go: "who" })
    assertEqual(rememberLaunch({ remember: false, skipPin: false }, rememberMe(true, 1)), { go: "who" })
end sub

sub testRemembersAProfileWithoutPin()
    s = { remember: true, skipPin: false }
    assertEqual(rememberLaunch(s, rememberMe(false, 2)).go, "home", "already unlocked")
    r = rememberLaunch(s, rememberMe(true, 2))
    assertEqual(r.go, "unlock", "locked on the server")
    assertEqual(r.profile.id, 2)
end sub

sub testAsksForTheRememberedPinUnlessSkipped()
    r = rememberLaunch({ remember: true, skipPin: false }, rememberMe(false, 1))
    assertEqual(r.go, "pin")
    assertEqual(r.profile.id, 1)
    assertEqual(rememberLaunch({ remember: true, skipPin: true }, rememberMe(false, 1)).go, "home")
end sub

sub testLockedPinProfileStillNeedsItsPin()
    assertEqual(rememberLaunch({ remember: true, skipPin: true }, rememberMe(true, 1)).go, "pin")
end sub

sub testGoneProfileFallsBackToWhoIsWatching()
    s = { remember: true, skipPin: true }
    assertEqual(rememberLaunch(s, rememberMe(false, 9)), { go: "who" }, "removed")
    assertEqual(rememberLaunch(s, rememberMe(false, 3)), { go: "who" }, "pending")
    assertEqual(rememberLaunch(s, rememberMe(false, 4)), { go: "who" }, "revoked")
end sub
