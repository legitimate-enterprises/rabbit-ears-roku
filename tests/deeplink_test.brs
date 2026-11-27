sub testPlayableMediaTypes()
    assertEqual(deepLinkRoute({ contentId: "41", mediaType: "movie" }), { itemId: 41, play: true })
    assertEqual(deepLinkRoute({ contentId: "7", mediaType: "episode" }), { itemId: 7, play: true })
end sub

sub testDetailMediaTypes()
    assertEqual(deepLinkRoute({ contentId: "3", mediaType: "series" }), { itemId: 3, play: false })
    assertEqual(deepLinkRoute({ contentId: "4", mediaType: "Season" }), { itemId: 4, play: false })
end sub

sub testRejectsMalformedLinks()
    assertEqual(deepLinkRoute({}), invalid, "no args")
    assertEqual(deepLinkRoute({ contentId: "41" }), invalid, "no mediaType")
    assertEqual(deepLinkRoute({ contentId: "abc", mediaType: "movie" }), invalid, "not an id")
    assertEqual(deepLinkRoute({ contentId: "0", mediaType: "movie" }), invalid, "zero")
    assertEqual(deepLinkRoute({ contentId: "41", mediaType: "shortFormVideo" }), invalid, "unsupported type")
end sub

sub testViewFollowsTheItemKind()
    assertEqual(deepLinkView({ itemId: 41, play: true }, { id: 41, kind: "movie" }), "player")
    assertEqual(deepLinkView({ itemId: 7, play: true }, { id: 7, kind: "episode" }), "player")
    assertEqual(deepLinkView({ itemId: 3, play: false }, { id: 3, kind: "show" }), "details")
    assertEqual(deepLinkView({ itemId: 3, play: true }, { id: 3, kind: "show" }), "details", "a show never plays")
end sub
