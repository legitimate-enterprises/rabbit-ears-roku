function detailsLayout() as object
    return [["play", "watched"], ["audio"], ["cast"]]
end function

sub testLeftAndRightStayInTheRow()
    assertEqual(focusMove(detailsLayout(), "play", "right"), "watched")
    assertEqual(focusMove(detailsLayout(), "watched", "right"), "")
    assertEqual(focusMove(detailsLayout(), "play", "left"), "")
end sub

sub testUpAndDownKeepTheColumnWhereTheyCan()
    layout = [["seek"], ["pill", "subtitles", "next"]]
    assertEqual(focusMove(layout, "seek", "down"), "pill")
    assertEqual(focusMove(detailsLayout(), "watched", "down"), "audio")
    keypad = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["delete", "0", "done"]]
    assertEqual(focusMove(keypad, "5", "down"), "8")
    assertEqual(focusMove(keypad, "8", "down"), "0")
    assertEqual(focusMove(keypad, "3", "up"), "")
end sub

sub testEmptyRowsAreSkipped()
    layout = [["play"], [], ["cast"]]
    assertEqual(focusMove(layout, "play", "down"), "cast")
    assertEqual(focusMove(layout, "cast", "up"), "play")
end sub

sub testUnknownCurrentOrKey()
    assertEqual(focusMove(detailsLayout(), "nope", "down"), "")
    assertEqual(focusMove(detailsLayout(), "play", "OK"), "")
end sub
