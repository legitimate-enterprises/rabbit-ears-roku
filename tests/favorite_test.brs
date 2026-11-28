sub testFavoriteToggleCallsAndState()
    on = favoriteCall("episode", uid(1), uid(2), true)
    r = apiRequest(on.op, on.params)
    assertEqual([r.method, r.path, r.body], ["PUT", "/api/v2/profiles/" + uid(1) + "/favorites/" + uid(2), ""])
    off = favoriteCall("video", uid(1), uid(2), false)
    r = apiRequest(off.op, off.params)
    assertEqual([r.method, r.path], ["DELETE", "/api/v2/profiles/" + uid(1) + "/favorites/" + uid(2)])
    assertEqual(favoriteButton(true), { text: "Favorite", kind: "p", icon: "star-fill" }, "on, as Shuffle and Repeat show it")
    assertEqual(favoriteButton(false), { text: "Favorite", kind: "s", icon: "star" })
end sub

sub testOnlyTheEightKindsCanBeStarred()
    for each k in ["movie", "show", "season", "episode", "artist", "album", "song", "video"]
        assertTrue(favoriteCall(k, uid(1), uid(2), true) <> invalid, k)
    end for
    for each k in ["channel", "collection", "playlist", "person", "station"]
        assertEqual(favoriteCall(k, uid(1), uid(2), true), invalid, k)
    end for
end sub
