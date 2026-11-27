sub init()
    m.top.functionName = "work"
end sub

' HDMI hot plug, link and codec events wake the loop at once; the audio
' route has no event, so the loop also reads every five seconds.
sub work()
    port = CreateObject("roMessagePort")
    di = CreateObject("roDeviceInfo")
    di.SetMessagePort(port)
    di.EnableLinkStatusEvent(true)
    di.EnableCodecCapChangedEvent(true)
    hdmi = CreateObject("roHdmiStatus")
    hdmi.SetMessagePort(port)
    last = capabilityReading(di)
    while m.top.active
        Wait(5000, port)
        now = capabilityReading(di)
        changed = capabilityChanged(last, now)
        last = now
        if changed.Count() > 0 and m.top.active then m.top.changed = changed
    end while
end sub
