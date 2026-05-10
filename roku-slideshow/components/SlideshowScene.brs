' SlideshowScene - main scene logic
'
' Behavior:
'   1. On launch, look up baseUrl in the registry. If missing, prompt the user
'      to enter one with a StandardKeyboardDialog.
'   2. Fetch <baseUrl>/manifest.json. If that fails, fall back to parsing the
'      directory listing HTML at <baseUrl>/.
'   3. Display images in order with a 1.2s crossfade between slides.
'   4. Queue audio files into the Audio node and loop when finished.
'   5. * (Star) clears the saved URL and re-prompts.

sub init()
    m.bg          = m.top.findNode("bg")
    m.slidePoster = m.top.findNode("slidePoster")
    m.nextPoster  = m.top.findNode("nextPoster")
    m.musicPlayer = m.top.findNode("musicPlayer")
    m.statusBg    = m.top.findNode("statusBg")
    m.titleLabel  = m.top.findNode("titleLabel")
    m.statusLabel = m.top.findNode("statusLabel")
    m.hintLabel   = m.top.findNode("hintLabel")
    m.fadeAnim    = m.top.findNode("fadeAnim")
    m.slideTimer  = m.top.findNode("slideTimer")

    m.images        = []
    m.audio         = []
    m.currentIndex  = 0
    m.nextIndex     = 0
    m.slideDuration = 6
    m.baseUrl       = ""
    m.playing       = false

    m.slideTimer.observeField("fire", "onSlideTimer")
    m.nextPoster.observeField("loadStatus", "onNextPosterLoaded")
    m.fadeAnim.observeField("state", "onFadeState")
    m.musicPlayer.observeField("state", "onMusicState")

    m.top.setFocus(true)
    loadConfig()
end sub

' ----- configuration --------------------------------------------------------

sub loadConfig()
    sec = CreateObject("roRegistrySection", "slideshow")
    if sec.Exists("baseUrl") then
        m.baseUrl = sec.Read("baseUrl")
        showStatus("Loading from: " + m.baseUrl)
        startSlideshow()
    else
        promptForUrl()
    end if
end sub

sub promptForUrl()
    m.playing = false
    showStatus("Enter the URL of your slides folder.")

    dlg = CreateObject("roSGNode", "StandardKeyboardDialog")
    dlg.title = "Slideshow Source URL"
    dlg.message = "Type the full URL of the folder on your website that holds your images and music. Example: https://example.com/slides/"
    dlg.text = m.baseUrl
    dlg.buttons = ["Save", "Cancel"]
    dlg.observeField("buttonSelected", "onUrlDialogButton")
    dlg.observeField("wasClosed", "onUrlDialogClosed")
    m.urlDialog = dlg
    m.top.dialog = dlg
end sub

sub onUrlDialogButton()
    dlg = m.urlDialog
    if dlg = invalid then return

    if dlg.buttonSelected = 0 then
        url = dlg.text
        if url <> "" then
            sec = CreateObject("roRegistrySection", "slideshow")
            sec.Write("baseUrl", url)
            sec.Flush()
            m.baseUrl = url
            dlg.close = true
            showStatus("Loading from: " + url)
            startSlideshow()
            return
        end if
    end if
    dlg.close = true
end sub

sub onUrlDialogClosed()
    m.urlDialog = invalid
    m.top.dialog = invalid
    if m.baseUrl = "" then
        showStatus("No URL set. Press * to enter a URL.")
    end if
end sub

' ----- network --------------------------------------------------------------

sub startSlideshow()
    m.images = []
    m.audio = []
    m.currentIndex = 0
    m.playing = false

    m.fetchTask = CreateObject("roSGNode", "FetchTask")
    m.fetchTask.url = ensureSlash(m.baseUrl) + "manifest.json"
    m.fetchTask.observeField("done", "onManifestDone")
    m.fetchTask.control = "RUN"
end sub

sub onManifestDone()
    task = m.fetchTask
    if task = invalid then return
    if task.done <> true then return

    body = task.result
    handled = false

    if task.error = "" and body <> "" then
        json = ParseJson(body)
        if json <> invalid and json.images <> invalid then
            m.images = []
            for each img in json.images
                m.images.push(resolveUrl(img))
            end for
            if json.audio <> invalid then
                m.audio = []
                for each a in json.audio
                    m.audio.push(resolveUrl(a))
                end for
            end if
            if json.duration <> invalid and json.duration > 0 then
                m.slideDuration = json.duration
            end if
            handled = true
        end if
    end if

    if handled and m.images.count() > 0 then
        beginPlayback()
    else
        ' Fall back to parsing a directory listing.
        m.dirTask = CreateObject("roSGNode", "FetchTask")
        m.dirTask.url = ensureSlash(m.baseUrl)
        m.dirTask.observeField("done", "onDirListingDone")
        m.dirTask.control = "RUN"
    end if
end sub

sub onDirListingDone()
    task = m.dirTask
    if task = invalid then return
    if task.done <> true then return

    if task.error <> "" then
        showStatus("Could not reach " + m.baseUrl + chr(10) + task.error + chr(10) + chr(10) + "Press * to change URL.")
        return
    end if

    html = task.result
    if html = invalid then html = ""

    m.images = []
    m.audio = []

    rx = CreateObject("roRegex", "href\s*=\s*[" + chr(34) + "']([^" + chr(34) + "'#?]+)[" + chr(34) + "']", "i")
    matches = rx.MatchAll(html)
    for each match in matches
        href = match[1]
        if href <> "" and href <> "../" and href <> "./" then
            lower = LCase(href)
            if isImageName(lower) then
                m.images.push(resolveUrl(href))
            else if isAudioName(lower) then
                m.audio.push(resolveUrl(href))
            end if
        end if
    end for

    if m.images.count() = 0 then
        showStatus("No images found at " + m.baseUrl + chr(10) + chr(10) + "Add a manifest.json or enable directory listing on your server." + chr(10) + chr(10) + "Press * to change URL.")
        return
    end if

    beginPlayback()
end sub

' ----- playback -------------------------------------------------------------

sub beginPlayback()
    hideStatus()
    m.playing = true
    m.currentIndex = 0
    m.slidePoster.opacity = 1.0
    m.nextPoster.opacity = 0.0
    m.slidePoster.uri = m.images[0]

    if m.audio.count() > 0 then
        contentRoot = CreateObject("roSGNode", "ContentNode")
        for each url in m.audio
            song = CreateObject("roSGNode", "ContentNode")
            song.url = url
            song.streamFormat = audioFormatForUrl(url)
            contentRoot.appendChild(song)
        end for
        m.musicPlayer.contentList = contentRoot
        m.musicPlayer.control = "play"
    end if

    m.slideTimer.duration = m.slideDuration
    m.slideTimer.control = "start"
end sub

sub onSlideTimer()
    if not m.playing then return
    if m.images.count() < 2 then
        m.slideTimer.control = "start"
        return
    end if

    next = m.currentIndex + 1
    if next >= m.images.count() then next = 0
    m.nextIndex = next

    m.nextPoster.opacity = 0.0
    m.nextPoster.uri = m.images[next]
end sub

sub onNextPosterLoaded()
    if m.nextPoster.loadStatus = "ready" then
        m.fadeAnim.control = "start"
    else if m.nextPoster.loadStatus = "failed" then
        ' Skip this slide and advance.
        m.currentIndex = m.nextIndex
        m.slideTimer.control = "start"
    end if
end sub

sub onFadeState()
    if m.fadeAnim.state = "stopped" then
        m.slidePoster.uri = m.nextPoster.uri
        m.slidePoster.opacity = 1.0
        m.nextPoster.opacity = 0.0
        m.currentIndex = m.nextIndex
        m.slideTimer.control = "start"
    end if
end sub

sub onMusicState()
    state = m.musicPlayer.state
    if state = "finished" then
        m.musicPlayer.control = "play"
    end if
end sub

' ----- input ---------------------------------------------------------------

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false

    if key = "back" then
        return false ' let the system close the channel
    end if

    if key = "options" or key = "*" then
        sec = CreateObject("roRegistrySection", "slideshow")
        sec.Delete("baseUrl")
        sec.Flush()
        m.playing = false
        m.slideTimer.control = "stop"
        m.musicPlayer.control = "stop"
        m.baseUrl = ""
        promptForUrl()
        return true
    end if

    if key = "play" or key = "OK" then
        if m.playing then
            ' Skip to next slide immediately.
            onSlideTimer()
        else if m.baseUrl <> "" then
            startSlideshow()
        end if
        return true
    end if

    if key = "rewind" or key = "left" then
        if m.images.count() > 0 then
            prev = m.currentIndex - 1
            if prev < 0 then prev = m.images.count() - 1
            m.nextIndex = prev
            m.nextPoster.opacity = 0.0
            m.nextPoster.uri = m.images[prev]
        end if
        return true
    end if

    if key = "fastforward" or key = "right" then
        if m.images.count() > 0 then onSlideTimer()
        return true
    end if

    return false
end function

' ----- helpers --------------------------------------------------------------

sub showStatus(text as string)
    m.statusBg.visible    = true
    m.titleLabel.visible  = true
    m.statusLabel.visible = true
    m.hintLabel.visible   = true
    m.statusLabel.text    = text
end sub

sub hideStatus()
    m.statusBg.visible    = false
    m.titleLabel.visible  = false
    m.statusLabel.visible = false
    m.hintLabel.visible   = false
end sub

function ensureSlash(url as string) as string
    if url = "" then return url
    if Right(url, 1) = "/" then return url
    return url + "/"
end function

function resolveUrl(href as string) as string
    if href = "" then return href
    if Instr(1, href, "://") > 0 then return href

    if Left(href, 1) = "/" then
        rx = CreateObject("roRegex", "^([a-z]+://[^/]+)", "i")
        match = rx.Match(m.baseUrl)
        if match.count() >= 2 then return match[1] + href
        return href
    end if

    return ensureSlash(m.baseUrl) + href
end function

function isImageName(lower as string) as boolean
    return endsWith(lower, ".jpg") or endsWith(lower, ".jpeg") or endsWith(lower, ".png") or endsWith(lower, ".bmp") or endsWith(lower, ".gif") or endsWith(lower, ".webp")
end function

function isAudioName(lower as string) as boolean
    return endsWith(lower, ".mp3") or endsWith(lower, ".m4a") or endsWith(lower, ".aac") or endsWith(lower, ".wav") or endsWith(lower, ".flac")
end function

function audioFormatForUrl(url as string) as string
    lower = LCase(url)
    if endsWith(lower, ".mp3")  then return "mp3"
    if endsWith(lower, ".m4a")  then return "m4a"
    if endsWith(lower, ".aac")  then return "aac"
    if endsWith(lower, ".wav")  then return "wav"
    if endsWith(lower, ".flac") then return "flac"
    return "mp3"
end function

function endsWith(s as string, suffix as string) as boolean
    n = Len(s)
    k = Len(suffix)
    if k > n then return false
    return Right(s, k) = suffix
end function
