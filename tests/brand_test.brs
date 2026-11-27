sub testProductNameBeforeAServerIsKnown()
    assertEqual(brandName("", "", "Den"), "Rabbit Ears")
    assertEqual(brandName("", "", ""), "Rabbit Ears")
end sub

sub testServerNameOnceKnown()
    assertEqual(brandName("http://10.0.0.2:8477", "http://10.0.0.2:8477", "Den"), "Den")
end sub

sub testNeverAnEmptyName()
    assertEqual(brandName("http://10.0.0.2:8477", "http://10.0.0.2:8477", ""), "Rabbit Ears")
    assertEqual(brandName("http://10.0.0.2:8477", "http://10.0.0.2:8477", "  "), "Rabbit Ears")
end sub

sub testAnotherServersNameIsNotShown()
    assertEqual(brandName("http://10.0.0.3:8477", "http://10.0.0.2:8477", "Den"), "Rabbit Ears", "a server not yet talked to")
end sub
