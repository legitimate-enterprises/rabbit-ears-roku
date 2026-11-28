' Starring an item: the call that toggles it and the button that shows it.

' The call that makes itemId, an item of kind, a favorite of profileId or
' no longer one, as { op, params }; invalid for a kind that is no
' FavoriteKind, as a channel. Neither sends at: the call goes now.
function favoriteCall(kind as string, profileId as string, itemId as string, on as boolean) as dynamic
    if not { movie: true, show: true, season: true, episode: true, artist: true, album: true, song: true, video: true }.DoesExist(kind) then return invalid
    op = "deleteFavorite"
    if on then op = "putFavorite"
    return { op: op, params: { profileId: profileId, itemId: itemId } }
end function

' The Favorite toggle as a details button draws it, lit while on as
' Shuffle and Repeat are.
function favoriteButton(on as boolean) as object
    if on then return { text: "Favorite", kind: "p", icon: "star-fill" }
    return { text: "Favorite", kind: "s", icon: "star" }
end function
