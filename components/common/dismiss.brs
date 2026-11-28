' Dismiss on the details views: it ends a title's progress without
' marking it unwatched. The view's onMarked reads the state again.

' The Dismiss button, in an array to join to a button row: empty unless the
' title is in progress.
function dismissButtons(state as dynamic) as object
    if not libraryInProgress(state) then return []
    m.controls.dismiss = uiButton(m.top, "dismiss", "Dismiss", "s", 0, 0)
    return [m.controls.dismiss]
end function

sub dismiss(item as object)
    netCall("dismissWatchState", { profileId: m.global.profileId, itemId: item.id }, {}, invalid, "onMarked")
end sub
