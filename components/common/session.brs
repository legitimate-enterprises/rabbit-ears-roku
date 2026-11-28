' The server, its name and the device token, kept in this app's registry
' section. The token is a secret: it is never printed or logged. That the server
' answered discovery is kept with them: a later launch may play before its
' search ends, or lose the reply.

function sessionRead() as object
    r = CreateObject("roRegistrySection", "RabbitEars")
    return { server: r.Read("server"), serverName: r.Read("serverName"), token: r.Read("token"), discovered: r.Read("discovered") = "1" }
end function

sub sessionSave(server as string, token as string)
    sessionUse(server, token)
    r = CreateObject("roRegistrySection", "RabbitEars")
    r.Write("server", server)
    r.Write("serverName", m.global.serverName)
    r.Write("token", token)
    if m.global.discovered then r.Write("discovered", "1") else r.Delete("discovered")
    r.Flush()
end sub

sub sessionClear()
    r = CreateObject("roRegistrySection", "RabbitEars")
    r.Delete("token")
    r.Flush()
    sessionUse(m.global.server, "")
    cacheClear("cachefs:/")
end sub

' The signOut call's answer, in a view: whatever it was, this device signs in
' anew.
sub onSignedOut()
    sessionClear()
    m.global.me = {}
    m.global.locked = false
    m.top.navigate = { to: "SignInView" }
end sub

' Posters and the Video node share the scene's HTTP agent, so artwork
' requests carry the token. Another server has yet to answer discovery
' or say its name.
sub sessionUse(server as string, token as string)
    if server <> m.global.server
        m.global.discovered = false
        m.global.serverName = ""
        m.global.home = { url: "", at: 0 }
    end if
    m.global.server = server
    m.global.token = token
    agent = m.top.getScene().getHttpAgent()
    agent.SetCertificatesFile("common:/certs/ca-bundle.crt")
    headers = {}
    if token <> "" then headers["Authorization"] = "Bearer " + token
    agent.SetHeaders(headers)
end sub

' The kinds of library this server last said it has, or invalid before it has
' said; kept so a launch does not show tabs it then removes.
function sectionsRead() as dynamic
    r = CreateObject("roRegistrySection", "RabbitEars")
    key = "sections." + m.global.server
    if not r.Exists(key) then return invalid
    kinds = []
    for each k in r.Read(key).Split(",")
        if k <> "" then kinds.Push(k)
    end for
    return kinds
end function

sub sectionsSave(kinds as object)
    r = CreateObject("roRegistrySection", "RabbitEars")
    joined = ""
    for each k in kinds
        if joined <> "" then joined = joined + ","
        joined = joined + k
    end for
    r.Write("sections." + m.global.server, joined)
    r.Flush()
end sub

' Remember profile and Skip PIN for the adult signed in on this device, off
' until set.
function rememberRead(me as object) as object
    r = CreateObject("roRegistrySection", "RabbitEars")
    id = me.account.id.ToStr()
    return { remember: r.Read("remember." + id) = "1", skipPin: r.Read("skipPin." + id) = "1" }
end function

sub rememberSave(me as object, settings as object)
    r = CreateObject("roRegistrySection", "RabbitEars")
    id = me.account.id.ToStr()
    for each k in ["remember", "skipPin"]
        if settings[k] then r.Write(k + "." + id, "1") else r.Delete(k + "." + id)
    end for
    r.Flush()
end sub
