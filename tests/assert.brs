' Each failed check prints one FAIL line, which tests/brs.test.mjs reports.
sub assertEqual(actual as dynamic, expected as dynamic, label = "" as string)
    a = FormatJson({ v: actual })
    e = FormatJson({ v: expected })
    if a <> e then print "FAIL " + GetGlobalAA().test + " " + label + ": got " + a + ", want " + e
end sub

sub assertTrue(actual as boolean, label = "" as string)
    if not actual then print "FAIL " + GetGlobalAA().test + " " + label
end sub
