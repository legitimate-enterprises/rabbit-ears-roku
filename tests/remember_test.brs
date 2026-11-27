function rememberMe(locked as boolean, activeId as string) as object
    return {
        activeProfileId: activeId
        locked: locked
        profiles: [
            { id: uid(1), kind: "adult", name: "Ada", hasPin: true, pending: false }
            { id: uid(2), kind: "kid", name: "Jason", hasPin: false, pending: false }
            { id: uid(3), kind: "adult", name: "Bea", hasPin: false, pending: true }
            { id: uid(4), kind: "adult", name: "Cy", hasPin: false, pending: false, revokedAt: "2026-11-01T00:00:00Z" }
        ]
    }
end function

sub testOffShowsWhoIsWatching()
    assertEqual(rememberLaunch({ remember: false, skipPin: true }, rememberMe(false, uid(2))), { go: "who" })
    assertEqual(rememberLaunch({ remember: false, skipPin: false }, rememberMe(true, uid(1))), { go: "who" })
end sub

sub testRemembersAProfileWithoutPin()
    s = { remember: true, skipPin: false }
    assertEqual(rememberLaunch(s, rememberMe(false, uid(2))).go, "home", "already unlocked")
    r = rememberLaunch(s, rememberMe(true, uid(2)))
    assertEqual(r.go, "unlock", "locked on the server")
    assertEqual(r.profile.id, uid(2))
end sub

sub testAsksForTheRememberedPinUnlessSkipped()
    r = rememberLaunch({ remember: true, skipPin: false }, rememberMe(false, uid(1)))
    assertEqual(r.go, "pin")
    assertEqual(r.profile.id, uid(1))
    assertEqual(rememberLaunch({ remember: true, skipPin: true }, rememberMe(false, uid(1))).go, "home")
end sub

sub testLockedPinProfileStillNeedsItsPin()
    assertEqual(rememberLaunch({ remember: true, skipPin: true }, rememberMe(true, uid(1))).go, "pin")
end sub

sub testGoneProfileFallsBackToWhoIsWatching()
    s = { remember: true, skipPin: true }
    assertEqual(rememberLaunch(s, rememberMe(false, uid(9))), { go: "who" }, "removed")
    assertEqual(rememberLaunch(s, rememberMe(false, uid(3))), { go: "who" }, "pending")
    assertEqual(rememberLaunch(s, rememberMe(false, uid(4))), { go: "who" }, "revoked")
end sub

sub testChoicesKeptUnderAnIdNoServerGivesAreStale()
    keys = ["server", "token", "remember." + uid(1), "skipPin." + uid(1), "remember.7", "skipPin.7", "sections.http://tv.local:8477", "grid.movie.sort"]
    assertEqual(rememberStale(keys), ["remember.7", "skipPin.7"])
    assertEqual(rememberStale([]), [])
end sub
