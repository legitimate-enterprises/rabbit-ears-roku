function labels(rows as object) as object
    out = []
    for each r in rows
        out.Push(r.label)
    end for
    return out
end function

sub testAdultMenuIsSwitchPreferencesSignOut()
    assertEqual(profileMenu(true), ["Switch profile", "Preferences", "Sign out"])
end sub

sub testKidMenuHasNoPreferences()
    assertEqual(profileMenu(false), ["Switch profile", "Sign out"])
end sub

sub testPreferencesHoldHideRememberAndSkipPin()
    rows = profilePreferences(true, { remember: true, skipPin: false })
    assertEqual(labels(rows), ["Hide kids' content", "Remember profile", "Skip PIN"])
    assertEqual([rows[0].checked, rows[1].checked, rows[2].checked], [true, true, false])
end sub

sub testSkipPinOnlyWhileRemembered()
    rows = profilePreferences(false, { remember: false, skipPin: true })
    assertEqual(labels(rows), ["Hide kids' content", "Remember profile"])
    assertEqual([rows[0].checked, rows[1].checked], [false, false])
end sub
