sub testProbeDatagram()
    assertEqual(discoveryProbe(), "RABBIT-EARS DISCOVER 1")
end sub

sub testReplyNamesTheServerAndPort()
    r = discoveryReply("RABBIT-EARS SERVER 1 8477 Rabbit Ears", "192.168.1.20")
    assertEqual(r, { name: "Rabbit Ears", address: "192.168.1.20:8477" })
end sub

sub testReplyWithoutName()
    assertEqual(discoveryReply("RABBIT-EARS SERVER 1 9000", "10.0.0.2"), { name: "Rabbit Ears", address: "10.0.0.2:9000" })
end sub

sub testIgnoresOtherDatagrams()
    assertEqual(discoveryReply("RABBIT-EARS DISCOVER 1", "10.0.0.2"), invalid, "an echo of the probe")
    assertEqual(discoveryReply("RABBIT-EARS SERVER 2 8477 x", "10.0.0.2"), invalid, "another version")
    assertEqual(discoveryReply("RABBIT-EARS SERVER 1 99999 x", "10.0.0.2"), invalid, "bad port")
    assertEqual(discoveryReply("hello", "10.0.0.2"), invalid)
end sub

sub testFoundWhenAReplyNamesTheSavedServer()
    servers = [{ name: "Den", address: "192.168.1.9:8477" }, discoveryReply("RABBIT-EARS SERVER 1 9000 Rabbit Ears", "192.168.1.20")]
    assertTrue(discoveryFound(apiServerBase("192.168.1.20:9000"), servers), "the saved base of the address a reply gives")
    assertTrue(not discoveryFound("http://192.168.1.20:8477", servers), "another port")
    assertTrue(not discoveryFound("https://rabbit.example.com", servers), "a server away from home")
    assertTrue(not discoveryFound("http://192.168.1.20:9000", []), "no reply")
end sub
