' Focus within a view: m.controls maps ids to nodes, m.rings to the rings
' of controls that do not draw their own, and m.layout is the focusMove
' layout. The view's current control is m.current.
sub uiFocus(id as string)
    if m.current <> invalid and m.rings[m.current] <> invalid then m.rings[m.current].visible = false
    m.current = id
    m.controls[id].setFocus(true)
    if m.rings[id] <> invalid then m.rings[id].visible = true
end sub

function uiArrow(key as string) as boolean
    if m.current = invalid then return false
    target = focusMove(m.layout, m.current, key)
    if target = "" then return false
    uiFocus(target)
    return true
end function

' A view handed focus by the router gives it to its current control.
sub uiRestore()
    uiBlur()
    if m.top.hasFocus() and m.current <> invalid then uiFocus(m.current)
end sub

' Focus gone from the view, as to the bar above it, takes the current
' control's ring with it; uiFocus shows it again on return.
sub uiBlur()
    if m.top.isInFocusChain() or m.current = invalid then return
    if m.rings[m.current] <> invalid then m.rings[m.current].visible = false
end sub

' A focusable panel: a raised shape with its own ring.
function uiPanel(parent as object, id as string, radius as integer, x as integer, y as integer, w as integer, h as integer, color = "raised" as string) as object
    g = parent.CreateChild("Group")
    g.translation = [x, y]
    g.focusable = true
    uiShape(g, radius, 0, 0, w, h, uiColor(color))
    m.controls[id] = g
    m.rings[id] = uiRing(g, 0, 0, w, h)
    return g
end function

function uiKeyboard(title as string, text as string, secure as boolean, handler as string) as object
    d = CreateObject("roSGNode", "StandardKeyboardDialog")
    d.title = title
    d.text = text
    d.buttons = ["OK", "Cancel"]
    d.textEditBox.secureMode = secure
    d.observeFieldScoped("buttonSelected", handler)
    m.top.getScene().dialog = d
    return d
end function
