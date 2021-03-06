 ' This code is adapted from the Roku SDK web_server example app.
 ' Original notices from that example are copied below.

 ' Roku Streaming Player Web Server
 ' This code was heavily influenced by darkhttpd/1.7
 ' The darkhttpd copyright notice is included below.

 '
 ' darkhttpd
 ' copyright (c) 2003-2008 Emil Mikulic.
 '
 ' Permission to use, copy, modify, and distribute this software for any
 ' purpose with or without fee is hereby granted, provided that the
 ' above copyright notice and this permission notice appear in all
 ' copies.
 ' 
 ' THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
 ' WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
 ' WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
 ' AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
 ' DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR
 ' PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 ' TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 ' PERFORMANCE OF THIS SOFTWARE.
 ' 

 ' Adapted from C to Brightscript with mods by Roku, Inc.

function ClassRequest()
    this = m.ClassRequest
    if this=invalid
        this = CreateObject("roAssociativeArray")
        ' constants
        this.class   = "Request"
        this.unix2NL = UnixNL() + UnixNL()
        this.win2NL  = WinNL() + WinNL()
        ' members
        this.method   = invalid
        this.uri      = invalid
        this.path     = invalid
        this.query    = invalid
        this.protocol = invalid
        this.buf      = invalid
        this.fields   = invalid
        this.id       = 0
        this.conn     = invalid
        this.remote_addr = invalid
        this.remote_port = invalid
        ' copied members
        this.range_begin       = 0
        this.range_end         = 0
        this.range_begin_given = false
        this.range_end_given   = false
        this.ok                = true
        ' functions
        this.add        = request_add
        this.isComplete = request_is_complete
        this.parse      = request_parse
        this.parseRange = request_parse_range
        this.parseConn  = request_parse_connection
        this.process    = request_process
        ' singleton
        m.ClassRequest = this
    end if
    this.id = this.id + 1
    return this
end function

function InitRequest() as Dynamic
    this = CreateObject("roAssociativeArray")
    this.append(ClassRequest())
    this.fields = CreateObject("roAssociativeArray")
    return this
end function

function request_add(incoming as String)
    if isstr(m.buf) then m.buf = m.buf + incoming else m.buf = incoming
end function

function request_is_complete() as Boolean
    buf = m.buf
    complete = isstr(buf) and (right(buf,2)=m.unix2NL) or (right(buf,4)=m.win2NL)
    'if complete then info(m,"header:"+UnixNL()+buf)
    return complete
end function

function request_parse(conn as Object) as Boolean
    m.conn = conn
    lines = m.buf.tokenize(WinNL())
    operation = lines.RemoveHead()
    if operation<>invalid 
        parts = operation.tokenize(" ")
        if parts.count()=3
            m.method   = Ucase(parts.RemoveHead())
            m.uri      = parts.RemoveHead()
            m.protocol = Ucase(parts.RemoveHead())
            info(m,m.method + " '" + m.uri + "'")
            for each line in lines
                sep = instr(1, line, ":")
                if sep > 1 then
                    name = left(line, sep-1)
                    value = mid(line, sep+1).Trim()
                    m.fields[name] = value
                end if
            end for
            ' interpret some fields if present
            m.parseRange()
            m.parseConn(conn)

            ' parse query string if present
            m.query = CreateObject("roAssociativeArray")
' @mikeh: URI parsing fix for remote playback control
            querypos = m.uri.instr("?")
            if (querypos > 0) then
                m.path = m.uri.left(querypos)
                args = m.uri.mid(querypos+1).tokenize("&")
                for each arg in args
                    av = arg.tokenize("=")
                    if av.count()=2 then m.query[UrlUnescape(av.GetHead())] = UrlUnescape(av.GetTail())
                end for
            else
                m.path = m.uri
            end if

            ' note the remote address information
            parts = conn.client.tokenize(":")
            if parts.count() = 2
                m.remote_addr = parts.GetHead()
                m.remote_port = parts.GetTail()
            end if
        else
            err(m,"invalid request: "+operation)
            m.ok = false
        end if
    else
        err(m,"empty request")
        m.ok = false
    end if
    return m.ok
end function

function request_parse_range()
    range = m.fields.range
    if range<>invalid
        endpoints = lcase(range).tokenize("=")
        if endpoints.count()=2 and endpoints.GetHead()="bytes"
            range = endpoints.GetTail().Trim()
            hyphen = range.instr("-")
            if hyphen>0
                m.range_begin = strtoi(range.left(hyphen))
                m.range_begin_given = true
            end if
            last = range.len()-1
            if hyphen<last
                m.range_end = strtoi(range.right(last-hyphen))
                m.range_end_given = true
            end if
        end if
        info(m,"range request begin" + Stri(m.range_begin) + " end" + Stri(m.range_end))
    end if
end function

function request_parse_connection(conn as object) as Boolean
    connection = m.fields.connection
    if connection<>invalid then conn.close = (lcase(connection.trim())= "close")
end function

 ' ---------------------------------------------------------------------------
 ' Process a request
 '
function request_process(conn as Object) as Boolean
    return m.parse(conn)
end function

