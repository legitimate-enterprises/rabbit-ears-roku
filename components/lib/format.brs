' Labels as the boards print them.

' Runtime leads with hours: 2h 46m, 2h, 50m.
function formatRuntime(minutes as dynamic) as string
    if minutes = invalid or minutes <= 0 then return ""
    h = minutes \ 60
    rest = minutes mod 60
    if h = 0 then return rest.ToStr() + "m"
    if rest = 0 then return h.ToStr() + "h"
    return h.ToStr() + "h " + rest.ToStr() + "m"
end function

' A length in milliseconds as a runtime, to the nearest minute.
function formatDuration(ms as dynamic) as string
    if ms = invalid then return ""
    return formatRuntime(Int(ms / 60000 + 0.5))
end function

function formatLeft(runtimeMinutes as dynamic, positionMs as dynamic) as string
    if runtimeMinutes = invalid then return ""
    left = runtimeMinutes - Int(positionMs / 60000)
    if left <= 0 then return ""
    return formatRuntime(left) + " left"
end function

function formatClock(seconds as dynamic) as string
    s = Int(seconds)
    if s < 0 then s = 0
    h = s \ 3600
    mm = (s mod 3600) \ 60
    ss = s mod 60
    if h > 0 then return h.ToStr() + ":" + formatTwo(mm) + ":" + formatTwo(ss)
    return mm.ToStr() + ":" + formatTwo(ss)
end function

function formatTwo(n as integer) as string
    if n < 10 then return "0" + n.ToStr()
    return n.ToStr()
end function

' Whole megabits when the tenth is zero: 38 Mb/s, 1.5 Mb/s.
function formatMbps(bps as dynamic) as string
    tenths = Int(bps / 100000 + 0.5)
    text = (tenths \ 10).ToStr()
    if tenths mod 10 <> 0 then text = text + "." + (tenths mod 10).ToStr()
    return text + " Mb/s"
end function

function formatResolution(width as integer, height as integer) as string
    if width >= 3200 or height >= 2000 then return "4K"
    if height >= 1000 or width >= 1800 then return "1080p"
    if height >= 700 then return "720p"
    if height >= 460 then return "480p"
    return height.ToStr() + "p"
end function

function itemTitle(item as object) as string
    if item.metadata <> invalid and item.metadata.title <> invalid and item.metadata.title <> "" then return item.metadata.title
    return item.parsedTitle
end function

function formatEpisodeCode(item as object) as string
    s = 0
    e = 0
    if item.seasonNumber <> invalid then s = item.seasonNumber
    if item.episodeNumber <> invalid then e = item.episodeNumber
    return "S" + s.ToStr() + " E" + e.ToStr()
end function

function formatYear(item as object) as string
    if item.metadata <> invalid and item.metadata.releaseDate <> invalid then return Left(item.metadata.releaseDate, 4)
    if item.parsedYear <> invalid then return item.parsedYear.ToStr()
    return ""
end function

function formatDate(iso as dynamic) as string
    if iso = invalid or Len(iso) < 10 then return ""
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    month = Val(Mid(iso, 6, 2))
    if month < 1 or month > 12 then return ""
    return months[month - 1] + " " + Val(Mid(iso, 9, 2)).ToStr() + ", " + Left(iso, 4)
end function

' ISO 639-2 codes as ffprobe reports them, B and T forms both.
function formatLanguage(code as dynamic) as string
    if code = invalid or code = "" or code = "und" then return "Unknown"
    names = { eng: "English", spa: "Spanish", fre: "French", fra: "French", ger: "German", deu: "German", ita: "Italian", por: "Portuguese", jpn: "Japanese", kor: "Korean", chi: "Chinese", zho: "Chinese", dut: "Dutch", nld: "Dutch", swe: "Swedish", nor: "Norwegian", dan: "Danish", fin: "Finnish", pol: "Polish", rus: "Russian", hin: "Hindi", ara: "Arabic" }
    name = names[LCase(code)]
    if name = invalid then return UCase(code)
    return name
end function

function formatCodec(codec as dynamic) as string
    if codec = invalid then return ""
    name = { h264: "H.264", hevc: "HEVC", av1: "AV1", vp9: "VP9", aac: "AAC", ac3: "Dolby Digital", eac3: "Dolby Digital Plus", truehd: "Dolby TrueHD", dts: "DTS", flac: "FLAC", opus: "Opus", mp3: "MP3" }[codec]
    if name = invalid then return UCase(codec)
    return name
end function

' English · Dolby Atmos 7.1: the track's title when it has one, else its
' codec and channels.
function formatAudio(track as object) as string
    detail = track.title
    if detail = invalid or detail = ""
        channels = { "1": "Mono", "2": "Stereo", "6": "5.1", "8": "7.1" }[apiText(track.channels)]
        detail = formatCodec(track.codec)
        if channels <> invalid then detail = detail + " " + channels
    end if
    return formatLanguage(track.language) + " · " + detail
end function

function formatSubtitle(track as object) as string
    name = formatLanguage(track.language)
    if track.title <> invalid and Instr(1, UCase(track.title), "SDH") > 0 then name = name + " SDH"
    return name
end function

' The Subtitles line of a file's tracks, each label once in track order:
' all of three tracks or fewer; past three, the English labels and
' +N other languages, or N languages when none is English.
function formatSubtitles(tracks as object) as string
    labels = []
    english = []
    seen = {}
    others = {}
    count = 0
    for each t in tracks
        if t.kind = "subtitle"
            count = count + 1
            label = formatSubtitle(t)
            key = formatLanguageKey(t.language)
            isEnglish = key = "eng" or key = "en"
            if not isEnglish then others.AddReplace(key, true)
            if not seen.DoesExist(label)
                seen.AddReplace(label, true)
                labels.Push(label)
                if isEnglish then english.Push(label)
            end if
        end if
    end for
    n = others.Count()
    if count <= 3 or (english.Count() = 0 and n = 1) then return labels.Join(", ")
    if english.Count() = 0 then return n.ToStr() + " languages"
    if n = 1 then english.Push("+1 other language")
    if n > 1 then english.Push("+" + n.ToStr() + " other languages")
    return english.Join(", ")
end function

' A language code without case or region; a missing one is und.
function formatLanguageKey(code as dynamic) as string
    if code = invalid or code = "" then return "und"
    return LCase(code).Split("-")[0].Split("_")[0]
end function

' 4K HDR10 · HEVC · 38 Mb/s, from the file's first video track.
function formatVideo(file as dynamic) as string
    if file = invalid then return ""
    for each t in file.tracks
        if t.kind = "video"
            res = formatResolution(t.width, t.height)
            if t.hdrFormat <> invalid then res = res + " " + formatHdr(t.hdrFormat)
            parts = [res, formatCodec(t.codec)]
            if file.bitrate <> invalid then parts.Push(formatMbps(file.bitrate))
            return parts.Join(" · ")
        end if
    end for
    return ""
end function

function formatHdr(format as string) as string
    return { hdr10: "HDR10", hdr10plus: "HDR10+", dolby_vision: "Dolby Vision", hlg: "HLG" }[format]
end function

' A caption's facts in order, the empty ones left out: 2024 · 2h 46m.
function formatParts(parts as object) as string
    out = []
    for each p in parts
        if p <> "" then out.Push(p)
    end for
    return out.Join(" · ")
end function

' Thousands grouped with commas: 1,210.
function formatCount(n as integer) as string
    text = n.ToStr()
    out = ""
    while Len(text) > 3
        out = "," + Right(text, 3) + out
        text = Left(text, Len(text) - 3)
    end while
    return text + out
end function

' 1 song, 1,210 albums: the noun takes an s unless there is exactly one.
' A list with rows still to load counts as more than its n.
function formatCountOf(n as integer, noun as string, partial = false as boolean) as string
    if partial then return formatCount(n) + "+ " + noun + "s"
    if n = 1 then return "1 " + noun
    return formatCount(n) + " " + noun + "s"
end function

' A paged list's count: the server's total once a page has told it, else
' what loaded so far.
function formatCountOfTotal(total as dynamic, shown as integer, noun as string, partial as boolean) as string
    if total <> invalid then return formatCountOf(total, noun)
    return formatCountOf(shown, noun, partial)
end function

' Days since 1970-01-01 of an ISO date's day, by the proleptic Gregorian
' calendar, so date math needs no roDateTime.
function formatDayNumber(iso as string) as integer
    y = Val(Left(iso, 4))
    mo = Val(Mid(iso, 6, 2))
    d = Val(Mid(iso, 9, 2))
    if mo <= 2 then y = y - 1
    era = y \ 400
    yoe = y - era * 400
    mp = (mo + 9) mod 12
    doy = (153 * mp + 2) \ 5 + d - 1
    doe = yoe * 365 + yoe \ 4 - yoe \ 100 + doy
    return era * 146097 + doe - 719468
end function

' How long before today a day was, as the YouTube boards word it: today,
' yesterday, 3 days ago, last week, 2 weeks ago, last month, 2 months ago.
function formatAgo(iso as dynamic, today as string) as string
    if iso = invalid or Len(iso) < 10 then return ""
    days = formatDayNumber(today) - formatDayNumber(iso)
    if days <= 0 then return "today"
    if days = 1 then return "yesterday"
    if days < 7 then return days.ToStr() + " days ago"
    if days < 14 then return "last week"
    if days < 30 then return (days \ 7).ToStr() + " weeks ago"
    if days < 60 then return "last month"
    if days < 365 then return (days \ 30).ToStr() + " months ago"
    if days < 730 then return "last year"
    return (days \ 365).ToStr() + " years ago"
end function

' A video tile's caption: Workbench Weekly · 42m · today.
function formatVideoCaption(video as object, today as string, withChannel as boolean) as string
    parts = []
    if withChannel then parts.Push(video.channelTitle)
    if video.durationMs <> invalid then parts.Push(formatDuration(video.durationMs))
    ago = formatAgo(video.publishedOn, today)
    if ago <> "" then parts.Push(ago)
    return parts.Join(" · ")
end function

' Today on this device's clock, as an ISO date for formatAgo.
function formatToday() as string
    d = CreateObject("roDateTime")
    d.ToLocalTime()
    return Left(d.ToISOString(), 10)
end function

' A profile's color as the server states it, #RRGGBB, for a node's color.
function formatProfileColor(hex as dynamic) as string
    if hex = invalid then return "0x3C4170FF"
    return "0x" + Mid(hex, 2) + "FF"
end function

' A cast member's placeholder disc, one of the server's eight colors.
function formatPersonColor(id as string) as string
    colors = ["0x3C4170FF", "0x2E6B5BFF", "0x6B3A2EFF", "0x5B4A8AFF", "0x8A5A2BFF", "0x2E5B8AFF", "0x6B2E5AFF", "0x4A6B2EFF"]
    return colors[apiIdPick(id, 8)]
end function
