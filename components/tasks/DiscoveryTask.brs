sub init()
    m.top.functionName = "work"
end sub

' Broadcasts the probe to the server's default HTTP port, on the global
' broadcast address and each interface's /24 one, and collects replies for
' two seconds.
sub work()
    port = CreateObject("roMessagePort")
    socket = CreateObject("roDatagramSocket")
    socket.SetMessagePort(port)
    socket.SetBroadcast(true)
    socket.NotifyReadable(true)
    targets = ["255.255.255.255"]
    ips = CreateObject("roDeviceInfo").GetIPAddrs()
    for each name in ips
        parts = ips[name].Split(".")
        if parts.Count() = 4 then targets.Push(parts[0] + "." + parts[1] + "." + parts[2] + ".255")
    end for
    for each host in targets
        target = CreateObject("roSocketAddress")
        target.SetAddress(host + ":8477")
        socket.SetSendToAddress(target)
        socket.SendStr(discoveryProbe())
    end for
    found = []
    seen = {}
    deadline = CreateObject("roTimespan")
    while deadline.TotalMilliseconds() < 2000
        msg = Wait(2000 - deadline.TotalMilliseconds(), port)
        if Type(msg) = "roSocketEvent" and socket.IsReadable()
            reply = discoveryReply(socket.ReceiveStr(512), socket.GetReceivedFromAddress().GetHostName())
            if reply <> invalid and seen[reply.address] = invalid
                seen[reply.address] = true
                found.Push(reply)
            end if
        end if
    end while
    socket.Close()
    m.top.servers = found
end sub
