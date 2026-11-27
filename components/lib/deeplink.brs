' Roku deep links: contentId is an item id; movie and episode play, series
' and season open details.

' { itemId, play } from launch or roInput arguments, or invalid when the
' link is not one of ours.
function deepLinkRoute(args as object) as dynamic
    if args = invalid or args.contentId = invalid or args.mediaType = invalid then return invalid
    id = LCase(apiText(args.contentId))
    if not apiId(id) then return invalid
    play = { movie: true, episode: true, series: false, season: false }[LCase(apiText(args.mediaType))]
    if play = invalid then return invalid
    return { itemId: id, play: play }
end function

' The item decides: a link that says play but names a show opens details.
function deepLinkView(link as object, item as object) as string
    if link.play and (item.kind = "movie" or item.kind = "episode") then return "player"
    return "details"
end function
