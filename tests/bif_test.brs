' Little-endian 32-bit words as bytes.
function le(n as longinteger) as object
    out = []
    for i = 0 to 3
        out.Push(n mod 256)
        n = n \ 256
    end for
    return out
end function

' A BIF of three frames, 10 seconds apart, at offsets 96, 196 and 346.
function sampleBif() as object
    b = [&h89, &h42, &h49, &h46, &h0d, &h0a, &h1a, &h0a]
    b.Append(le(0))
    b.Append(le(3))
    b.Append(le(10000))
    while b.Count() < 64
        b.Push(0)
    end while
    for each entry in [[0, 96], [1, 196], [2, 346], [4294967295&, 500]]
        b.Append(le(entry[0]))
        b.Append(le(entry[1]))
    end for
    return b
end function

sub testIndexListsEveryFrame()
    index = bifIndex(sampleBif())
    assertEqual(index.intervalMs, 10000)
    assertEqual(index.frames, [{ offset: 96, length: 100 }, { offset: 196, length: 150 }, { offset: 346, length: 154 }])
end sub

sub testIndexNeedsTheMagic()
    b = sampleBif()
    b[1] = 0
    assertEqual(bifIndex(b), invalid)
    assertEqual(bifIndex([]), invalid)
end sub

sub testZeroSeparationMeansOneSecond()
    b = sampleBif()
    for i = 16 to 19
        b[i] = 0
    end for
    assertEqual(bifIndex(b).intervalMs, 1000)
end sub

sub testHeaderSize()
    assertEqual(bifHeaderBytes(sampleBif()), 64 + 4 * 8)
end sub

sub testEachStreamFetchesItsOwnBif()
    assertEqual(bifFile(812), "tmp:/rabbit-ears-812.bif")
    assertTrue(bifFile(812) <> bifFile(813), "a late download for another stream writes another file")
end sub

sub testEachStreamCutsItsFramesUnderItsOwnName()
    assertEqual(bifFrameFile(812, 3), "tmp:/rabbit-ears-812-3.jpg")
    assertEqual(bifPatterns(812), ["rabbit-ears-812.bif", "rabbit-ears-812-*"], "never another stream's, as 8120's")
end sub

sub testFrameAtAPosition()
    index = bifIndex(sampleBif())
    assertEqual(bifFrameAt(index, 0), 0)
    assertEqual(bifFrameAt(index, 14.9), 1)
    assertEqual(bifFrameAt(index, 3600), 2, "clamped to the last frame")
end sub
