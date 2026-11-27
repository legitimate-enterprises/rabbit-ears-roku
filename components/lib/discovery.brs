' Discovery without Bonjour: a broadcast probe on the server's HTTP port,
' answered by a unicast datagram "RABBIT-EARS SERVER 1 <port> [<name>]".

function discoveryProbe() as string
    return "RABBIT-EARS DISCOVER 1"
end function

' { name, address } from a reply, or invalid for anything else on the port.
function discoveryReply(text as string, fromHost as string) as dynamic
    words = text.Trim().Split(" ")
    if words.Count() < 4 or words[0] <> "RABBIT-EARS" or words[1] <> "SERVER" or words[2] <> "1" then return invalid
    port = Val(words[3])
    if port < 1 or port > 65535 then return invalid
    name = "Rabbit Ears"
    if words.Count() > 4
        rest = []
        for i = 4 to words.Count() - 1
            rest.Push(words[i])
        end for
        name = rest.Join(" ")
    end if
    return { name: name, address: fromHost + ":" + port.ToStr() }
end function

' Whether a reply names the server saved as base, in apiServerBase's form.
' A server saved by host name is never found: a reply carries an address.
function discoveryFound(base as string, servers as object) as boolean
    for each s in servers
        if apiServerBase(s.address) = base then return true
    end for
    return false
end function
