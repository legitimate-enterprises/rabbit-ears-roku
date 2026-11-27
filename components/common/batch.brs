' A list whose rows arrive in batches. rest, a reply's apiNextBatch, loads
' the next batch once focus nears the last loaded row of list, a MarkupList
' or MarkupGrid with one content child per row. The view defines
' batchRows(rows), which adds the rows to its model and to the end of the
' list's content, leaving the rows there and the focus where they are.
sub batchStart(list as object, rest as dynamic)
    batchStop()
    m.batch = { list: list, rest: rest, loading: false }
    ' One observer however often the same list starts again.
    list.unobserveFieldScoped("itemFocused")
    list.observeFieldScoped("itemFocused", "batchOnFocused")
end sub

' Discards the continuation and the batch in flight.
sub batchStop()
    m.batch = invalid
    netDrop("batchOnRows")
end sub

' Whether rows remain to load.
function batchMore() as boolean
    return m.batch <> invalid and m.batch.rest <> invalid
end function

sub batchOnFocused()
    b = m.batch
    if b = invalid or b.list.content = invalid then return
    if not apiBatchDue(b.list.itemFocused, b.list.content.getChildCount(), b.rest, b.loading) then return
    b.loading = true
    netLoad("list", b.rest, "batchOnRows")
end sub

' A failed batch is asked for again at the next focus move.
sub batchOnRows(event as object)
    r = event.getData()
    b = m.batch
    b.loading = false
    if not r.ok then return
    b.rest = r.rest
    batchRows(r.data)
end sub
