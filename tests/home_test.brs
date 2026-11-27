' The local check for a server signed in to at a public address.

sub testAHomeCheckRunsOnlyAwayFromTheServersOwnAddressAndStandsTenMinutes()
    none = { url: "", at: 0 }
    assertTrue(homeDue("https://media.example.com", none, 1000), "never checked")
    assertTrue(not homeDue("http://192.168.1.20:8477", none, 1000), "signed in at home")
    assertTrue(not homeDue("https://media.example.com", { url: "", at: 1000 }, 1599), "a check that found nothing stands")
    assertTrue(not homeDue("https://media.example.com", { url: "http://192.168.1.20:8477", at: 1000 }, 1599), "one that found an address")
    assertTrue(homeDue("https://media.example.com", { url: "http://192.168.1.20:8477", at: 1000 }, 1600), "ten minutes on")
end sub

sub testStreamsPlayFromTheAddressTheCheckConfirmed()
    assertEqual(homeStreamBase("https://media.example.com", { url: "http://192.168.1.20:8477", at: 1000 }), "http://192.168.1.20:8477")
    assertEqual(homeStreamBase("https://media.example.com", { url: "", at: 1000 }), "https://media.example.com")
end sub

sub testTheCheckIsInTheApi()
    assertEqual(apiRequest("startLocalCheck"), { body: "", method: "POST", path: "/api/v1/local-checks" })
    assertEqual(apiRequest("confirmLocalCheck", { checkId: "c1" }, {}, { nonce: "n", proof: "p" }).path, "/api/v1/local-checks/c1/confirmation")
end sub
