' Roku's launch timer: AppLaunchComplete once home first shows, and every
' view before it (sign-in, Link a TV, Who's watching, a retry) inside one
' AppDialogInitiate and AppDialogComplete pair, so the viewer's time there
' is not counted as launch.

' The beacons that showing view fires, in order. state is { launched,
' inDialog } and is updated in place.
function launchBeacons(state as object, view as string) as object
    if state.launched then return []
    if view <> "TabsView"
        if state.inDialog then return []
        state.inDialog = true
        return ["AppDialogInitiate"]
    end if
    state.launched = true
    if not state.inDialog then return ["AppLaunchComplete"]
    state.inDialog = false
    return ["AppDialogComplete", "AppLaunchComplete"]
end function
