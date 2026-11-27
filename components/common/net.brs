' Starts work on an ApiTask from the render thread, which may not block on
' the network. The handler, a sub of the calling component, receives the
' task's response; a new call for the same handler drops the one before.

sub netCall(op as string, params as object, query as object, body as dynamic, handler as string)
    netRun({ op: op, params: params, query: query, body: body }, handler)
end sub

' A composite load that ApiTask runs as one sequence: home, grid, details,
' play and so on.
sub netLoad(name as string, args as object, handler as string)
    netRun({ load: name, args: args }, handler)
end sub

sub netRun(request as object, handler as string)
    netDrop(handler)
    task = CreateObject("roSGNode", "ApiTask")
    task.request = request
    task.observeFieldScoped("response", handler)
    task.control = "run"
    m.netTasks[handler] = task
end sub

' The handler no longer receives the response of a call in flight, and a
' read load in flight is stopped.
sub netDrop(handler as string)
    if m.netTasks = invalid then m.netTasks = {}
    old = m.netTasks[handler]
    if old = invalid then return
    old.unobserveFieldScoped("response")
    ' A superseded read stops, or the loads pile up on a low-memory device.
    name = old.request.load
    if name <> invalid and apiLoadReads(name) then old.control = "stop"
end sub
