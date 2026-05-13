' FetchTask - downloads a URL on a background thread and returns the body.
sub init()
    m.top.functionName = "fetch"
    m.top.done = false
    m.top.result = ""
    m.top.error = ""
end sub

sub fetch()
    url = m.top.url
    if url = "" then
        m.top.error = "Empty URL"
        m.top.result = ""
        m.top.done = true
        return
    end if

    port = CreateObject("roMessagePort")
    ut = CreateObject("roUrlTransfer")
    ut.SetMessagePort(port)
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.InitClientCertificates()
    ut.RetainBodyOnError(true)
    ut.EnableEncodings(true)
    ut.AddHeader("User-Agent", "RokuWebSlideshow/1.0")

    if not ut.AsyncGetToString() then
        m.top.error = "Could not start request"
        m.top.result = ""
        m.top.done = true
        return
    end if

    msg = wait(20000, port)
    if type(msg) <> "roUrlEvent" then
        ut.AsyncCancel()
        m.top.error = "Request timed out"
        m.top.result = ""
        m.top.done = true
        return
    end if

    code = msg.GetResponseCode()
    body = msg.GetString()

    if code >= 200 and code < 400 then
        m.top.error = ""
        m.top.result = body
    else
        m.top.error = "HTTP " + code.toStr()
        m.top.result = body
    end if
    m.top.done = true
end sub
