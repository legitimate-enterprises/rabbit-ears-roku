' Roku deep links: contentId is an item id; movie and episode play, series
' and season open details.

' { itemId, play } from launch or roInput arguments, or invalid when the
' link is not one of ours.
function deepLinkRoute(args as object) as dynamic
    if args = invalid or args.contentId = invalid or args.mediaType = invalid then return invalid
    id = apiText(args.contentId)
    for i = 1 to Len(id)
        if Instr(1, "0123456789", Mid(id, i, 1)) = 0 then return invalid
    end for
    if id = "" or Val(id) < 1 then return invalid
    play = { movie: true, episode: true, series: false, season: false }[LCase(apiText(args.mediaType))]
    if play = invalid then return invalid
    return { itemId: Val(id), play: play }
end function

' The item decides: a link that says play but names a show opens details.
function deepLinkView(link as object, item as object) as string
    if link.play and (item.kind = "movie" or item.kind = "episode") then return "player"
    return "details"
end function
