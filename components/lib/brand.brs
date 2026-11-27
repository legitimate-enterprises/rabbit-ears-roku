' The name the interface gives the place the viewer is in: the server's
' own, set by its admin, once the app talks to that server, and the
' product's before then. The mark beside it never changes.

' shown is the server the screen is about and server the one the app talks
' to, whose name is name; a name is never shown for another server.
function brandName(shown as string, server as string, name as string) as string
    if shown = "" or shown <> server or name.Trim() = "" then return "Rabbit Ears"
    return name
end function

' The brand label beside the logo, cut short with an ellipsis past
' maxWidth. shown is as for brandName.
function brandLabel(parent as object, shown as string, x as integer, y as integer, maxWidth as integer) as object
    m.brandShown = shown
    m.brand = uiLabel(parent, "", 30, true, "text", x, y)
    m.brandMax = maxWidth
    brandUpdate()
    return m.brand
end function

' A view whose layout does not follow the brand's width observes
' serverName with this.
sub brandUpdate()
    if m.brand = invalid then return
    m.brand.width = 0
    m.brand.text = brandName(m.brandShown, m.global.server, m.global.serverName)
    if m.brand.boundingRect().width > m.brandMax then m.brand.width = m.brandMax
end sub

' Asks the server for its name; sessionSave keeps it with the server.
sub brandRefresh()
    m.brandAsked = m.global.server
    netCall("getHealth", {}, {}, invalid, "onBrandHealth")
end sub

sub onBrandHealth(event as object)
    r = event.getData()
    ' An answer from a server since left behind names nothing.
    if m.brandAsked <> m.global.server or not r.ok or Type(r.data) <> "roAssociativeArray" then return
    name = r.data.serverName
    if Type(name) <> "roString" and Type(name) <> "String" then return
    if name.Trim() = "" then return
    m.global.serverName = name
    reg = CreateObject("roRegistrySection", "RabbitEars")
    if reg.Read("server") <> m.global.server then return
    reg.Write("serverName", name)
    reg.Flush()
end sub
