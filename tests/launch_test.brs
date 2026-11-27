sub testHomeFirstOnlyCompletesLaunch()
    s = { launched: false, inDialog: false }
    assertEqual(launchBeacons(s, "TabsView"), ["AppLaunchComplete"])
    assertEqual(launchBeacons(s, "details"), [], "after launch")
end sub

sub testViewsBeforeHomeAreOneDialog()
    s = { launched: false, inDialog: false }
    assertEqual(launchBeacons(s, "SignInView"), ["AppDialogInitiate"])
    assertEqual(launchBeacons(s, "LinkView"), [], "still in the dialog")
    assertEqual(launchBeacons(s, "WhoView"), [], "still in the dialog")
    assertEqual(launchBeacons(s, "TabsView"), ["AppDialogComplete", "AppLaunchComplete"])
end sub

sub testWhoIsWatchingAfterLaunchFiresNothing()
    s = { launched: false, inDialog: false }
    launchBeacons(s, "TabsView")
    assertEqual(launchBeacons(s, "WhoView"), [])
    assertEqual(launchBeacons(s, "TabsView"), [])
end sub
