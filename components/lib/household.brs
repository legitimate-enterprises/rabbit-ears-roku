' Which household is this Roku in: asked once, after a password sign-in.

' The rows a sign-in result offers, { id, name, label }, the adult's own
' household first; none when they are in only one.
function householdChoices(result as object) as object
    out = []
    offered = result.households
    if offered = invalid or offered.Count() < 2 then return out
    for each h in offered
        label = "Visiting"
        if out.Count() = 0 then label = "Yours"
        out.Push({ id: h.id, name: h.name, label: label })
    end for
    return out
end function
