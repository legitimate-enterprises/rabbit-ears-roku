' The browse boards' rows under the tabs: the view tabs, then a row of
' filter chips and the count, with selects such as Sort and Genre at the
' right, and the menu a select opens. A view defines barTabs(), its
' libraryBar, and barSelects() as [{ id, text }], keeps m.chip, m.note,
' m.items and m.bar, and may put rows above the view tabs in m.above.

' The chip row's top in m.bar: 32 under the view tabs, when there are
' views to switch between.
function barRowY() as integer
    if barTabs().views.Count() > 1 then return 90
    return 0
end function

' A 56-tall control of the row, as wide as its text.
function barControl(id as string, radius as integer, text as string, on as boolean) as object
    g = uiPanel(m.bar, id, radius, 0, 0, 0, 56, "glass")
    l = uiLabel(g, text, 26, on, uiPick(on, "ground", "text"), 24, 0)
    l.height = 56
    l.vertAlign = "center"
    resize(id, l.boundingRect().width + 48)
    return g
end function

sub resize(id as string, w as integer)
    m.controls[id].GetChild(0).width = w
    m.rings[id].width = w + 20
end sub

' Rebuilt whole, so focus goes back to its control.
sub drawBar()
    focused = m.top.isInFocusChain() and m.menu = invalid
    uiClear(m.bar)
    bar = barTabs()
    y = barRowY()
    m.layout = []
    if m.above <> invalid then m.layout.Append(m.above)
    if y > 0
        texts = []
        ids = []
        current = 0
        for each v in bar.views
            if v.id = bar.view then current = ids.Count()
            texts.Push(v.text)
            ids.Push(v.id)
        end for
        ' Each tab pads its label by 6 a side, and tabs are 40 apart.
        tabs = uiTabs(m.bar, texts, current, m.x + 6, 8, 52)
        for i = 0 to ids.Count() - 1
            m.controls[ids[i]] = tabs[i].node
            m.rings[ids[i]] = tabs[i].ring
        end for
        m.layout.Push(ids)
    end if
    row = []
    x = m.x
    for each c in bar.chips
        on = (c.id = m.chip)
        g = barControl(c.id, 28, c.text, on)
        shape = g.GetChild(0)
        if on
            shape.blendColor = uiColor("accent")
        else
            shape.uri = "pkg:/images/outline28.9.png"
            shape.blendColor = "0xFFFFFF33"
        end if
        g.translation = [x, y]
        x = x + shape.width + 16
        row.Push(c.id)
    end for
    count = uiLabel(m.bar, m.note, 26, false, "dim", x + 16, y)
    count.height = 56
    count.vertAlign = "center"
    selects = barSelects()
    right = 1920 - 96
    for i = selects.Count() - 1 to 0 step -1
        s = selects[i]
        g = barControl(s.id, 12, s.text, false)
        w = g.GetChild(0).width
        uiImage(g, "chevron.png", w - 12, 17, 22, 22, uiColor("text"))
        resize(s.id, w + 30)
        right = right - w - 30
        g.translation = [right, y]
        right = right - 16
    end for
    for each s in selects
        row.Push(s.id)
    end for
    m.layout.Push(row)
    if m.items.Count() > 0 then m.layout.Push(["grid"])
    ' An empty grid draws no ring, so focus stays on the row above it.
    if m.items.Count() = 0 and m.current = "grid" then m.current = m.chip
    if focused then uiFocus(m.current)
end sub

' m.options under the focused select, inside the right margin.
sub openMenu(handler as string)
    at = m.controls[m.current].translation
    x = at[0]
    if x > 1920 - 96 - 480 then x = 1920 - 96 - 480
    m.menu = m.top.CreateChild("OptionMenu")
    m.menu.menuWidth = 480
    m.menu.maxHeight = 780 - at[1]
    m.menu.options = m.options
    m.menu.translation = [x, 240 + at[1]]
    m.menu.observeFieldScoped("chosen", handler)
    m.menu.observeFieldScoped("cancelled", "closeMenu")
    m.menu.setFocus(true)
end sub

sub closeMenu()
    if m.menu = invalid then return
    m.top.removeChild(m.menu)
    m.menu = invalid
    uiFocus(m.current)
end sub
