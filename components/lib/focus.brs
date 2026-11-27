' Focus order of screens built from buttons: rows of control ids, top to
' bottom. Up and down keep the column where the next row is long enough.

' The id that takes focus, or "" when the key leaves the layout so the
' parent can handle it.
function focusMove(rows as object, current as string, key as string) as string
    for r = 0 to rows.Count() - 1
        for c = 0 to rows[r].Count() - 1
            if rows[r][c] = current then return focusFrom(rows, r, c, key)
        end for
    end for
    return ""
end function

function focusFrom(rows as object, r as integer, c as integer, key as string) as string
    if key = "left" and c > 0 then return rows[r][c - 1]
    if key = "right" and c < rows[r].Count() - 1 then return rows[r][c + 1]
    stepBy = { up: -1, down: 1 }[key]
    if stepBy = invalid then return ""
    i = r + stepBy
    while i >= 0 and i < rows.Count()
        n = rows[i].Count()
        if n > 0
            if c < n then return rows[i][c]
            return rows[i][n - 1]
        end if
        i = i + stepBy
    end while
    return ""
end function
