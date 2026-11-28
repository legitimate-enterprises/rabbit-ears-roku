' The server's REST API as the app calls it: request building and response
' handling, free of roUrlTransfer so they run under the test interpreter.

' Every operation the app calls, as [method, path]. tests/spec.test.mjs fails
' when one is missing from openapi.yaml.
function apiOperations() as object
    return {
        getHealth: ["GET", "/health"]
        signIn: ["POST", "/auth/sign-in"]
        signOut: ["POST", "/auth/sign-out"]
        getMe: ["GET", "/me"]
        moveDevice: ["PUT", "/me/household"]
        getUpNext: ["GET", "/profiles/{profileId}/up-next/{itemId}"]
        setProfilePreferences: ["PUT", "/profiles/{profileId}/preferences"]
        createDeviceLink: ["POST", "/device-links"]
        pollDeviceLink: ["GET", "/device-links/{linkId}"]
        getDeviceLinkQr: ["GET", "/device-links/{linkId}/qr"]
        unlockProfile: ["POST", "/profiles/{profileId}/unlock"]
        lockDevice: ["POST", "/me/lock"]
        listWatchStates: ["GET", "/profiles/{profileId}/watch-state"]
        listShowProgress: ["GET", "/profiles/{profileId}/show-progress"]
        getWatchState: ["GET", "/profiles/{profileId}/watch-state/{itemId}"]
        putWatchState: ["PUT", "/profiles/{profileId}/watch-state/{itemId}"]
        putWatchStates: ["PUT", "/profiles/{profileId}/watch-state/batch"]
        search: ["GET", "/search"]
        listItems: ["GET", "/items"]
        getItem: ["GET", "/items/{itemId}"]
        listActiveOccasions: ["GET", "/profiles/{profileId}/occasions"]
        listGenres: ["GET", "/genres"]
        getItemArtwork: ["GET", "/items/{itemId}/artwork/{kind}"]
        getItemCredits: ["GET", "/items/{itemId}/credits"]
        getPersonArtwork: ["GET", "/people/{personId}/artwork"]
        getItemRelated: ["GET", "/items/{itemId}/related"]
        checkPlayability: ["POST", "/items/{itemId}/playability"]
        listMediaFiles: ["GET", "/media-files"]
        startPlayback: ["POST", "/playback/sessions"]
        endPlayback: ["DELETE", "/playback/sessions/{sessionId}"]
        updatePlaybackDisplay: ["PUT", "/playback/sessions/{sessionId}/display"]
        updatePlaybackAudioRoute: ["PUT", "/playback/sessions/{sessionId}/audio-route"]
        updatePlaybackNetwork: ["PUT", "/playback/sessions/{sessionId}/network"]
        reportPlaybackThroughput: ["PUT", "/playback/sessions/{sessionId}/throughput"]
        selectPlaybackTracks: ["PUT", "/playback/sessions/{sessionId}/tracks"]
        reportPlaybackEvent: ["POST", "/playback/sessions/{sessionId}/events"]
        reportPlaybackPosition: ["PUT", "/playback/sessions/{sessionId}/position"]
        listPlaybackSessions: ["GET", "/playback/sessions"]
        getPlaybackSession: ["GET", "/playback/sessions/{sessionId}"]
        movePlaybackSession: ["POST", "/playback/sessions/{sessionId}/move"]
        startLocalCheck: ["POST", "/local-checks"]
        confirmLocalCheck: ["POST", "/local-checks/{checkId}/confirmation"]
        listEvents: ["GET", "/events"]
        listLibraries: ["GET", "/libraries"]
        listMusicArtists: ["GET", "/music/artists"]
        getMusicArtist: ["GET", "/music/artists/{artistId}"]
        listMusicAlbums: ["GET", "/music/albums"]
        getMusicAlbum: ["GET", "/music/albums/{albumId}"]
        listMusicSongs: ["GET", "/music/songs"]
        listPlaylists: ["GET", "/profiles/{profileId}/playlists"]
        listPlaylistEntries: ["GET", "/profiles/{profileId}/playlists/{playlistId}/entries"]
        listPlaylistPlayOrder: ["GET", "/profiles/{profileId}/playlists/{playlistId}/play-order"]
        listCollections: ["GET", "/collections"]
        listCollectionMovies: ["GET", "/collections/{collectionId}/movies"]
        getCollectionArtwork: ["GET", "/collections/{collectionId}/artwork/{kind}"]
        listYouTubeChannels: ["GET", "/youtube/channels"]
        getYouTubeChannel: ["GET", "/youtube/channels/{channelId}"]
        listYouTubeVideos: ["GET", "/youtube/videos"]
        getYouTubeVideo: ["GET", "/youtube/videos/{videoId}"]
        putYouTubeChannelWatchState: ["PUT", "/profiles/{profileId}/youtube/channels/{channelId}/watch-state"]
        openWatchTogether: ["POST", "/watch-together"]
        listWatchTogethers: ["GET", "/watch-together"]
        getWatchTogether: ["GET", "/watch-together/{watchTogetherId}"]
        leaveWatchTogether: ["DELETE", "/watch-together/{watchTogetherId}"]
        joinWatchTogether: ["POST", "/watch-together/{watchTogetherId}/join"]
        setWatchTogetherState: ["PUT", "/watch-together/{watchTogetherId}/state"]
        listStations: ["GET", "/stations"]
        getStation: ["GET", "/stations/{stationId}"]
        startStationPlayback: ["POST", "/stations/{stationId}/playback"]
    }
end function

' What the viewer typed or discovery found, as a URL base. A bare host gets
' plain HTTP on the server's default port.
function apiServerBase(text as string) as string
    base = text.Trim()
    if base = "" then return ""
    if Instr(1, base, "://") = 0
        base = "http://" + base
        if Instr(Len("http://") + 1, base, ":") = 0 then base = base + ":8477"
    end if
    while Mid(base, Len(base)) = "/"
        base = Left(base, Len(base) - 1)
    end while
    return base
end function

' Whether a password, link code or token may go to base: over https, or
' over plain HTTP only to a host a local network alone reaches.
function apiSecure(base as string) as boolean
    if LCase(Left(base, 8)) = "https://" then return true
    return LCase(Left(base, 7)) = "http://" and apiLocal(base)
end function

' Whether base names a host a local network alone reaches: localhost, mDNS
' .local, RFC 1918, link-local, IPv6 loopback, unique and link-local.
function apiLocal(base as string) as boolean
    scheme = Instr(1, base, "://")
    if scheme = 0 then return false
    host = LCase(base.Mid(scheme + 2))
    for each c in ["/", "?", "#"]
        i = Instr(1, host, c)
        if i > 0 then host = Left(host, i - 1)
    end for
    parts = host.Split("@")
    host = parts[parts.Count() - 1]
    if Left(host, 1) = "["
        bracket = Instr(1, host, "]")
        if bracket = 0 then return false
        host = host.Mid(1, bracket - 2)
        return host = "::1" or Left(host, 2) = "fc" or Left(host, 2) = "fd" or Left(host, 4) = "fe80"
    end if
    host = host.Split(":")[0]
    if host = "localhost" or Right(host, 6) = ".local" then return true
    labels = host.Split(".")
    if labels.Count() <> 4 then return false
    for each label in labels
        n = label.ToInt()
        if n.ToStr() <> label or n < 0 or n > 255 then return false
    end for
    a = labels[0].ToInt()
    b = labels[1].ToInt()
    return a = 10 or a = 127 or (a = 192 and b = 168) or (a = 169 and b = 254) or (a = 172 and b >= 16 and b <= 31)
end function

' The method, server-relative path with query, and JSON body of one
' operation; invalid for an unknown operation or a missing path parameter.
function apiRequest(name as string, params = {} as object, query = {} as object, body = invalid as dynamic) as dynamic
    op = apiOperations()[name]
    if op = invalid then return invalid
    path = op[1]
    for each key in params
        path = path.Replace("{" + apiName(key) + "}", apiText(params[key]))
    end for
    if Instr(1, path, "{") > 0 then return invalid
    pairs = []
    for each key in query.Keys()
        ' An array is a repeated parameter, as the spec gives listEvents' kinds.
        values = query[key]
        if Type(values) <> "roArray" then values = [values]
        for each v in values
            pairs.Push(apiName(key) + "=" + apiText(v).EncodeUriComponent())
        end for
    end for
    if pairs.Count() > 0 then path = path + "?" + pairs.Join("&")
    text = ""
    if body <> invalid then text = FormatJson(apiSpelled(body))
    return { method: op[0], path: "/api/v2" + path, body: text }
end function

' The server-relative address of an image that obj's key names, as an
' item's posterUrl. Without the key, as in a reply from a server before
' 0.24.0 or one kept from before the upgrade, it is the id address op and
' params name, which misses, leaving the placeholder, when there is no image.
function apiArtPath(obj as dynamic, key as string, op as string, params as object) as string
    if obj <> invalid and obj[key] <> invalid then return obj[key]
    return apiRequest(op, params).path
end function

' Every camelCase name the spec gives a property or parameter, keyed in lower
' case. A Roku stores a literal's unquoted keys and dot-assigned keys in lower
' case, so whatever the app sends is spelled from here; tests/spec.test.mjs
' fails when the spec has a name this lacks.
function apiNames() as object
    if m.apiNames <> invalid then return m.apiNames
    m.apiNames = {}
    names = [
        "accountId", "activeProfileId", "activeTranscodes", "addedAt", "adultId", "albumArtistId"
        "albumCount", "albumId", "albumTitle", "artItemId", "artistId", "artistName", "audioAction"
        "audioCodec", "audioCodecs", "audioRoute", "audioTrackId", "avatarUrl", "backdropPath", "backdropUrl"
        "badReason", "bifUrl", "bitDepth", "bufferGoalSeconds", "bufferMs", "channelId", "channelLayout", "channelPosterUrl", "channelTitle"
        "checkId", "clientId", "clientSecret", "clientSecretSet", "collectionId", "colorPrimaries"
        "colorTransfer", "contentRating", "conversionId", "cpuModel", "cpuPercent", "createdAt", "currentEntry"
        "currentPassword", "currentRung", "dataDir", "databasePath", "decidedAt", "deviceId", "deviceName"
        "discNumber", "discoveredLocally", "dismissedAt", "diskFreeBytes", "diskTotalBytes", "downloadId", "durationMs"
        "editionId", "editionName", "effectiveAtMs", "effectivePositionMs", "endMs", "endedAt", "endsAt", "entryId", "episodeNumber"
        "expiresAt", "expiresInDays", "externalId", "fetchedAt", "ffmpegCommand", "filterMode"
        "finishedAt", "floorMs", "folderId", "forKids", "frameRate", "frameUrl", "fromName", "fromProfileId", "fromSessionId", "genreId", "hasPin"
        "hdrFormat", "hdrFormats", "headshotUrl", "hideKidsContent", "householdId", "householdIds", "householdName", "identityId", "identityReviewId", "imageUrl", "inProgress"
        "intervalMs", "intervalSeconds", "inviteExpiresAt", "invitedBy", "isAdmin", "isDefault"
        "isForced", "itemCount", "itemId", "itemIds", "itemKind", "joinBy", "joinCode", "joinCodeId", "joinMsLeft"
        "joinedAt", "kidNames", "kidsContent", "kidsContentOverride", "lastPlayedAt", "lastRun", "lastScannedAt"
        "lastSeenAt", "lastVideoOn", "libraryId", "linkId", "linksByEmail", "lowData", "maxBitDepth"
        "maxBitrate", "maxFrameRate", "maxHeight", "maxItems", "maxLength", "maxLevel", "maxSampleRate"
        "maxTranscodes", "maxWidth", "measuredBitrate", "mediaFileId", "memoryBytes", "memoryTotalBytes"
        "memoryUsedBytes", "metadataMode", "metadataSource", "minItems", "missingAt", "modifiedAt", "movedToDeviceName", "movieCeiling", "movieCount"
        "musicBrainzId", "newOwnerName", "newPassword", "nextEpisodeId", "nextOffset", "nextRunAt", "offerId", "onAir"
        "openedAt", "operationId", "otherAccountId", "ownerId", "ownerName", "parentId", "parsedTitle", "parsedYear", "passthroughCodecs"
        "pausedById", "pausedByName", "personId", "pinLocked", "pixelFormat", "playCount"
        "playedAt", "playlistId", "pollToken", "positionMs", "posterPath", "posterUrl", "probedAt", "probeError", "probeFailedAt", "profileId", "profileKind", "profileName"
        "profileIds", "profilePath", "providerId", "publishedOn", "raisedAt", "readAheadSeconds", "refreshRate", "releaseDate"
        "requestBody", "requiredGroup", "resumesAt", "returnTo", "revokedAt", "rttMs", "runId", "runRequestedAt"
        "rungBitrate", "rungHeight", "runtimeMinutes", "runtimeMs", "sampleRate", "scanHour"
        "seasonNumber", "securitySchemes", "seekPreviewId", "segmentFormats", "serverName"
        "serverTime", "serverTimeMs", "serverWide", "sessionId", "setupRequired", "shareProfileId", "showId", "signIn", "sizeBytes"
        "songCount", "songId", "sortName", "sortTitle", "sourceUrl", "stallCount", "startMs", "startedAt"
        "startsAt", "stationId", "storageTotalBytes", "storageUsedBytes", "streamIndex", "streamKind"
        "streamUrl", "subtitleAction", "subtitleFormats", "subtitleIsText", "subtitleTrackId"
        "taskId", "tasksPaused", "thisDevice", "tmdbConfigured", "tmdbId", "tmdbKey", "toName", "toProfileId", "trackId", "trackNumber"
        "transcodeCacheBytes", "transcodeCacheCapBytes", "transcodeReason", "tvCeiling", "uniqueItems"
        "unwatchedCount", "upNext", "usedAt", "videoAction", "videoCodecs", "videoCount"
        "videoId", "videoToolbox", "watchFiles", "watchTogetherId"
        "anchorDate", "customOrder", "daysAfter", "daysBefore", "firstDate", "keywordIds", "lastDate"
        "occasionId", "sampleRateHz", "actingProfileId", "apiMax", "apiMin", "apiVersion", "changedAt", "createdBy"
        "fileModifiedAt", "modifiedBy", "ownPlaylistId", "schemaMax", "schemaMin"
    ]
    for each name in names
        m.apiNames[LCase(name)] = name
    end for
    return m.apiNames
end function

function apiName(key as string) as string
    name = apiNames()[LCase(key)]
    if name = invalid then return key
    return name
end function

' value with every object key, at any depth, spelled as the spec spells it.
function apiSpelled(value as dynamic) as dynamic
    t = type(value)
    if t = "roAssociativeArray"
        out = {}
        for each key in value
            out.AddReplace(apiName(key), apiSpelled(value[key]))
        end for
        return out
    else if t = "roArray"
        out = []
        for each v in value
            out.Push(apiSpelled(v))
        end for
        return out
    end if
    return value
end function

' startPlayback's body. A choice left out is the server's: no editionId
' plays the default edition, no positionMs resumes from the watch state.
function apiPlaybackBody(a as object, snapshot as object) as object
    body = { profileId: a.profileId, itemId: a.itemId, snapshot: snapshot }
    for each key in ["editionId", "positionMs", "audioTrackId", "playlistId"]
        if a[key] <> invalid then body.AddReplace(key, a[key])
    end for
    return body
end function

' startStationPlayback's body: the server picks the program and the live
' position, so only the snapshot and tracks the viewer chose go.
function apiStationBody(a as object, snapshot as object) as object
    body = { snapshot: snapshot }
    for each key in ["audioTrackId", "subtitleTrackId"]
        if a[key] <> invalid then body.AddReplace(key, a[key])
    end for
    return body
end function

' selectPlaybackTracks's body. The selection replaces the session's, so it
' repeats the audio track the viewer chose; subtitle is a track id, or off
' or forced, which name none.
function apiTrackBody(audioTrackId as dynamic, subtitle as string) as object
    body = {}
    if audioTrackId <> invalid then body.AddReplace("audioTrackId", audioTrackId)
    if subtitle <> "off" and subtitle <> "forced" then body.AddReplace("subtitleTrackId", subtitle)
    return body
end function

' Whether text is an id as the spec's Id pattern writes one, a UUIDv7 in
' lowercase; the server answers 400 to any other.
function apiId(text as string) as boolean
    return CreateObject("roRegex", "^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", "").IsMatch(text)
end function

' The index into a palette of count that id picks: its last byte, random in
' a UUIDv7, as the server picks a profile's color.
function apiIdPick(id as string, count as integer) as integer
    return Val(Right(id, 2), 16) mod count
end function

' A response as { ok, status, data, code, message }. A status of zero or
' below is roUrlTransfer's own failure: the server was never reached. A
' 429's message reads its Retry-After seconds, in whole minutes. A success
' whose body is not JSON is a failure: something else answered.
function apiResult(status as integer, text as string, retryAfter = "" as string) as object
    data = invalid
    if text <> "" then data = ParseJson(text)
    if status >= 200 and status < 300
        if text = "" or data <> invalid then return { ok: true, status: status, data: data, code: "", message: "" }
        return { ok: false, status: status, data: invalid, code: "http", message: "The server's answer could not be read." }
    end if
    if status <= 0 then return { ok: false, status: status, data: invalid, code: "network", message: "Can't reach the server." }
    r = { ok: false, status: status, data: invalid, code: "http", message: "The server answered " + status.ToStr() + "." }
    if Type(data) = "roAssociativeArray" and data.code <> invalid then r = { ok: false, status: status, data: data, code: data.code, message: data.message }
    if status = 429
        later = "a few minutes"
        minutes = (Int(Val(retryAfter)) + 59) \ 60
        if minutes = 1 then later = "1 minute"
        if minutes > 1 then later = minutes.ToStr() + " minutes"
        r.message = "Too many attempts. Try again in " + later + "."
    end if
    return r
end function

' How long a call to op with query waits on the server before it counts as
' out of reach. The server holds a poll up to 25 seconds; the check for the
' title playing on another device gives up within 3, so it plays unasked.
function apiWaitMs(op as string, query as object) as integer
    if query.DoesExist("after") then return 35000
    if op = "listPlaybackSessions" then return 3000
    return 20000
end function

' Whether a reply found the device locked at Who's watching, which then
' answers nothing but the picker's own calls until a profile is picked.
function apiLocked(r as object) as boolean
    return r.code = "device_locked"
end function

' Whether a reply says the server no longer knows the device. Only its own
' code says so; a proxy's 401 does not.
function apiSignedOut(r as object) as boolean
    return r.code = "unauthorized"
end function

' A long listing loads in batches. The args of the "list" load for the
' batch after one that stopped at offset: the same op, params and query, so
' the sort and filter stay the ones the list was loaded with; invalid when
' no rows remain.
function apiNextBatch(op as string, params as object, query as object, offset as dynamic) as dynamic
    if offset = invalid then return invalid
    return { op: op, params: params, query: query, offset: offset }
end function

' Whether the batch rest names loads now: one remains, none is in flight,
' and focus has come within a server page of the last loaded row.
function apiBatchDue(focused as integer, loaded as integer, rest as dynamic, loading as boolean) as boolean
    return rest <> invalid and not loading and focused >= loaded - 200
end function

' Whether the composite load name only reads, so a task running it may be
' stopped when a newer call supersedes it; the others write, or start a
' session, and run to their end.
function apiLoadReads(name as string) as boolean
    return not { markall: true, update: true, play: true, song: true, station: true, bif: true }.DoesExist(name)
end function

function apiText(value as dynamic) as string
    if Type(value) = "String" or Type(value) = "roString" then return value
    return value.ToStr()
end function
