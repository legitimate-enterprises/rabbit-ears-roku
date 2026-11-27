sub init()
    m.top.focusable = true
    m.top.observeField("focusedChild", "onFocus")
end sub

sub draw()
    uiClear(m.top)
    h = 76
    size = 30
    pad = 38
    if m.top.small
        h = 64
        size = 26
        pad = 28
    end if
    fill = uiShape(m.top, 14, 0, 0, 0, h, uiColor("glass"))
    color = "text"
    if m.top.kind = "p"
        fill.blendColor = uiColor("accent")
        color = "ground"
    else if m.top.kind = "o"
        fill.uri = "pkg:/images/outline14.9.png"
        fill.blendColor = uiColor("accent")
        color = "accent"
    end if
    x = pad
    if m.top.icon <> ""
        uiImage(m.top, m.top.icon + ".png", x, (h - 26) \ 2, 26, 26, uiColor(color))
        x = x + 40
    end if
    label = uiLabel(m.top, m.top.text, size, true, color, x, 0)
    label.height = h
    label.vertAlign = "center"
    if m.top.maxWidth > 0 and x + label.boundingRect().width + pad > m.top.maxWidth then label.width = m.top.maxWidth - x - pad
    w = x + label.boundingRect().width + pad
    fill.width = w
    m.ring = uiRing(m.top, 0, 0, w, h)
    onFocus()
end sub

sub onFocus()
    if m.ring <> invalid then m.ring.visible = m.top.hasFocus()
end sub
