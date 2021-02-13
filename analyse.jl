using SQLite
using DataFrames
using CodecLz4

include("parserdict.jl")

function analyseLog(str::AbstractString)

    playstate = PlayState(undef)

    brk(c) = ('0' <= c <= '9' || c == ' ' || c == '/')

    status = 1
    strlen = length(str)

    while status < strlen

        tagbeg::Int = findnext('<', str, status)
        tagend::Int = findnext(brk, str, tagbeg)
        status::Int = findnext('>', str, tagend)

        parser = get(ParserDict, str[(tagbeg+1):(tagend-1)], nothing)

        if !isnothing(parser)
            parser(str[tagend:status-2], playstate)
        end

    end

end

function queryLog(dbpath::String, logidx::Int)

    if !isfile(dbpath)
        error("Database not found!")
    end

    # establish connection and select table
    db = SQLite.DB(dbpath)
    table = DataFrame(
        DBInterface.execute(db, "SELECT id, content FROM records LIMIT 1000;")
    )

    # decompress tenhou log contents and return processed table
    return String(
        transcode(LZ4FrameDecompressor, table.content[logidx])
    )
end

function queryLogs(dbpath::String)

    if !isfile(dbpath)
        error("Database not found!")
    end

    # establish connection and select table
    db = SQLite.DB(dbpath)
    table = DataFrame(
        DBInterface.execute(db, "SELECT id, content FROM records LIMIT 1000;")
    )

    # decompress tenhou log contents and return processed table
    for i = 1:1000
        analyseLog(String(
            transcode(LZ4FrameDecompressor, table.content[i])
        ))
    end
end

# analyseLog(queryLog("scraw2009s4p.db", 25))
queryLogs("scraw2009s4p.db")
