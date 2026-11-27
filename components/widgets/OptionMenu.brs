sub init()
    m.top.focusable = true
    m.top.observeField("focusedChild", "uiRestore")
end sub

sub draw()
    uiClear(m.top)
    m.controls = {}
    m.rings = {}
    m.layout = []
    m.current = invalid
    w = m.top.menuWidth
    panel = uiShape(m.top, 16, 0, 0, w, 0, uiColor("raised"))
    clip = m.top.CreateChild("Group")
    m.rows = clip.CreateChild("Group")
    y = 12
    if m.top.heading <> ""
        uiLabel(m.rows, m.top.heading, 24, false, "dim", 30, y + 8)
        y = y + 52
    end if
    options = m.top.options
    for i = 0 to options.Count() - 1
        o = options[i]
        row = uiPanel(m.rows, i.ToStr(), 12, 12, y, w - 24, 76, "raised")
        ' Rows sit closer than a ring reaches, so a row drawn later would
        ' cover the ring of the one above: only the checked row has a fill,
        ' and that one translucent.
        row.GetChild(0).visible = o.checked
        if o.checked
            row.GetChild(0).blendColor = "0xFFFFFF14"
            uiImage(row, "check.png", 18, 25, 26, 26, uiColor("accent"))
        end if
        if o.detail = invalid or o.detail = ""
            uiLabel(row, o.label, 26, true, "text", 62, 22)
        else
            uiLabel(row, o.label, 26, true, "text", 62, 8)
            uiLabel(row, o.detail, 24, false, "sub", 62, 40)
        end if
        if o.verdict <> invalid
            v = uiLabel(row, o.verdict, 24, true, o.tone, 0, 0, 0)
            v.width = w - 24 - 18
            v.height = 76
            v.horizAlign = "right"
            v.vertAlign = "center"
        end if
        if o.disabled
            row.opacity = 0.45
        else
            m.layout.Push([i.ToStr()])
            if m.current = invalid or o.checked then m.current = i.ToStr()
        end if
        y = y + 80
        ' Auto stands apart from the rungs.
        if o.label = "Auto"
            uiRect(m.rows, 22, y + 2, w - 44, 1, "0xFFFFFF1A")
            y = y + 8
        end if
    end for
    m.height = y + 8
    if m.top.maxHeight > 0 and m.height > m.top.maxHeight
        m.height = m.top.maxHeight
        clip.clippingRect = [0, 0, w, m.height]
    end if
    panel.height = m.height
    reveal()
end sub

' Scrolls the rows so the focused one, with its ring, is inside the panel.
sub reveal()
    if m.current = invalid then return
    y = m.controls[m.current].translation[1]
    top = -m.rows.translation[1]
    if y - 12 < top then top = y - 12
    if y + 88 > top + m.height then top = y + 88 - m.height
    m.rows.translation = [0, -top]
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "OK" and m.current <> invalid
        m.top.chosen = m.current.ToInt()
    else if key = "back"
        m.top.cancelled = true
    else if key <> "options"
        uiArrow(key)
        reveal()
    end if
    ' The menu is modal: no key but options reaches the player beneath it.
    return key <> "options"
end function
