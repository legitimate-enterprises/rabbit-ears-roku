sub testPlayableMediaTypes()
    assertEqual(deepLinkRoute({ contentId: uid(41), mediaType: "movie" }), { itemId: uid(41), play: true })
    assertEqual(deepLinkRoute({ contentId: uid(7), mediaType: "episode" }), { itemId: uid(7), play: true })
end sub

sub testDetailMediaTypes()
    assertEqual(deepLinkRoute({ contentId: uid(3), mediaType: "series" }), { itemId: uid(3), play: false })
    assertEqual(deepLinkRoute({ contentId: uid(4), mediaType: "Season" }), { itemId: uid(4), play: false })
end sub

sub testAnIdInCapitalsIsTheSameId()
    assertEqual(deepLinkRoute({ contentId: UCase(uid(41)), mediaType: "movie" }), { itemId: uid(41), play: true })
end sub

sub testRejectsMalformedLinks()
    assertEqual(deepLinkRoute({}), invalid, "no args")
    assertEqual(deepLinkRoute({ contentId: uid(41) }), invalid, "no mediaType")
    assertEqual(deepLinkRoute({ contentId: "abc", mediaType: "movie" }), invalid, "not an id")
    assertEqual(deepLinkRoute({ contentId: "41", mediaType: "movie" }), invalid, "an integer id no server gives now")
    assertEqual(deepLinkRoute({ contentId: 41, mediaType: "movie" }), invalid, "an integer")
    assertEqual(deepLinkRoute({ contentId: uid(41) + "0", mediaType: "movie" }), invalid, "too long")
    assertEqual(deepLinkRoute({ contentId: uid(41), mediaType: "shortFormVideo" }), invalid, "unsupported type")
end sub

sub testViewFollowsTheItemKind()
    assertEqual(deepLinkView({ itemId: uid(41), play: true }, { id: uid(41), kind: "movie" }), "player")
    assertEqual(deepLinkView({ itemId: uid(7), play: true }, { id: uid(7), kind: "episode" }), "player")
    assertEqual(deepLinkView({ itemId: uid(3), play: false }, { id: uid(3), kind: "show" }), "details")
    assertEqual(deepLinkView({ itemId: uid(3), play: true }, { id: uid(3), kind: "show" }), "details", "a show never plays")
end sub
