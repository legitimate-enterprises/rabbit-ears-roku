' The profile menu on the browse bar and its Preferences.

' The profile menu's entries; Preferences is an adult's only.
function profileMenu(adult as boolean) as object
    if adult then return ["Switch profile", "Preferences", "Sign out"]
    return ["Switch profile", "Sign out"]
end function

' Preferences as OptionMenu rows: the profile's Hide kids' content, and this
' device's Remember profile with Skip PIN under it while it is on.
function profilePreferences(hides as boolean, remember as object) as object
    rows = [
        { label: "Hide kids' content", detail: "Leave kids' titles out of what you browse", checked: hides, disabled: false }
        { label: "Remember profile", detail: "Start as the last profile, not Who's watching", checked: remember.remember, disabled: false }
    ]
    if remember.remember then rows.Push({ label: "Skip PIN", detail: "Start without asking for its PIN", checked: remember.skipPin, disabled: false })
    return rows
end function
