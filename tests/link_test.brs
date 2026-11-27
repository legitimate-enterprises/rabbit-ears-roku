function poll(status as integer, body as object) as object
    return apiResult(status, FormatJson(body))
end function

sub testPendingAndUnreachedWait()
    assertEqual(linkOutcome(5, 5, poll(200, { status: "pending", expiresAt: "2025-01-01T00:10:00Z" })), "wait")
    assertEqual(linkOutcome(5, 5, apiResult(0, "")), "wait", "no answer")
    assertEqual(linkOutcome(5, 5, poll(500, { code: "internal", message: "boom" })), "wait", "server failure")
end sub

sub testTheTokenSignsInEvenForAnOlderLink()
    r = poll(200, { status: "approved", expiresAt: "2025-01-01T00:10:00Z", signIn: { token: "t", me: {} } })
    assertEqual(linkOutcome(5, 5, r), "signIn")
    assertEqual(linkOutcome(6, 5, r), "signIn", "handed over once, so never dropped")
end sub

sub testDeniedAndGone()
    assertEqual(linkOutcome(5, 5, poll(200, { status: "denied", expiresAt: "2025-01-01T00:10:00Z" })), "denied")
    assertEqual(linkOutcome(5, 5, poll(200, { status: "expired", expiresAt: "2025-01-01T00:10:00Z" })), "expired")
    assertEqual(linkOutcome(5, 5, poll(404, { code: "not_found", message: "gone" })), "expired")
end sub

sub testAnAnswerForAnotherLinkChangesNothing()
    assertEqual(linkOutcome(6, 5, poll(404, { code: "not_found", message: "gone" })), "stale", "a new code is on screen")
    assertEqual(linkOutcome(invalid, 5, poll(200, { status: "denied", expiresAt: "2025-01-01T00:10:00Z" })), "stale", "asking for a new code")
end sub
