using SQLite
using DataFrames
using CodecLz4

include("parserdict.jl")

function analyseLog(str::AbstractString)

    playstate = PlayState(undef)

    brk(c) = ('0' <= c <= '9' || c == ' ' || c == '/')

    status = 1
    strlen = sizeof(str)

    while status < strlen

        tagbeg::Int = findnext('<', str, status)
        tagend::Int = findnext(brk, str, tagbeg)
        status::Int = findnext('>', str, tagend)

        tag = str[tagbeg+1:tagend-1]
        data = str[tagend:status-2]

        ParserDict[tag](data, playstate)
    end

end

function queryLog(dbpath::String, logidx::Int)

    # establish connection and select table
    db = SQLite.DB(dbpath)
    table = DataFrame(
        DBInterface.execute(db, "SELECT id, content FROM records LIMIT 1000;")
    )

    # decompress tenhou log contents and return processed table
    # println("http://tenhou.net/0/?log=", table.id[logidx])
    return String(
        transcode(LZ4FrameDecompressor, table.content[logidx])
    )
end

function queryLogs(dbpath::String)

    # establish connection and select table
    db = SQLite.DB(dbpath)
    table = DataFrame(
        DBInterface.execute(db, "SELECT id, content FROM records LIMIT 1000;")
    )

    # decompress tenhou log contents and return processed table
    for i = 1:1000
        # println(i, "\t|\t", "http://tenhou.net/0/?log=", table.id[i])
        stringbuffer = transcode(LZ4FrameDecompressor, table.content[i])
        analyseLog(String(stringbuffer))
    end
end

# analyseLog(queryLog("scraw2009s4p.db", 25))
queryLogs("scraw2009s4p.db")
