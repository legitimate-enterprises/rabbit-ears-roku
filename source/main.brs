' Shows the scene and hands it deep links: the one the app launched with,
' and any roInput delivers while it runs.
sub Main(args as dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene("MainScene")
    screen.Show()
    scene.observeField("exit", port)
    input = CreateObject("roInput")
    input.SetMessagePort(port)
    ' What the app keeps is in cachefs:, which the system frees outside the
    ' app's memory, so a warning has nothing to free; the console log says
    ' where memory stood.
    memory = CreateObject("roAppMemoryMonitor")
    memory.SetMessagePort(port)
    memory.EnableMemoryWarningEvent(true)
    device = CreateObject("roDeviceInfo")
    device.SetMessagePort(port)
    device.EnableLowGeneralMemoryEvent(true)
    if args <> invalid then scene.launchArgs = args
    while true
        msg = Wait(0, port)
        t = Type(msg)
        if t = "roSGScreenEvent" and msg.IsScreenClosed() then return
        if t = "roSGNodeEvent" and msg.GetField() = "exit" then return
        if t = "roInputEvent" and msg.IsInput() then scene.deepLink = msg.GetInfo()
        if t = "roAppMemoryNotificationEvent" or t = "roDeviceInfoEvent"
            ' bs:disable-next-line: LINT3012
            print "memory "; FormatJson(msg.GetInfo()); " used "; memory.GetMemoryLimitPercent(); "%, free "; memory.GetChannelAvailableMemory(); " KB, limit "; FormatJson(memory.GetChannelMemoryLimit())
        end if
    end while
end sub
