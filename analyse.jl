using SQLite
using DataFrames
using CodecLz4

include("parsers.jl")
include("parsers_n.jl")

function analyseLog(str::AbstractString)

    playstate = PlayState(undef)

    brk(c) = ('0' <= c <= '9' || c == ' ' || c == '/')

    status = 1

    while status < length(str)

        tagbeg::Int = findnext('<', str, status)
        tagend::Int = findnext(brk, str, tagbeg)
        status::Int = findnext('>', str, tagend)

        parser = get(ParserDict, str[(tagbeg+1):(tagend-1)], nothing)

        if !isnothing(parser)
            parser(str[tagend:status-2], playstate)
        end

    end

end

function analyseLogOld(log::AbstractString)

    it = rxiterator(r"<(?<tag>[A-Z]+)(?<str>.+?)\/>"s, log)

    rules = Rules(it(r"GO")[:str])
    numplayers::Int8 = rules.sanma ? 3 : 4
    table = Table(it(r"UN")[:str], numplayers)

    round = RoundInit(it(r"INIT")[:str], numplayers)
    playstate = PlayStateOld(round)

    while true  play = it()

        if play[:tag] in ["T", "U", "V", "W", "D", "E", "F", "G"]
            draw = Wall[play[:str]]

        elseif play[:tag] == "N"
            #call meld
        elseif play[:tag] == "REACH"
            #coll riichi
        elseif play[:tag] == "DORA"
            #flip dora
        elseif play[:tag] == "AGARI"

            RoundWin(play[:str])
            if occursin("owari", play.match)
                GameResults(play[:str])
                break
            end

        elseif play[:tag] == "RYUUKYOKU"

            RoundTie(play[:str])
            if occursin("owari", play.match)
                GameResults(play[:str])
                break
            end

        elseif play[:tag] == "INIT"

            round = RoundInit(play[:str], numplayers)
            playstate = PlayStateOld(round)

        elseif play[:tag] == "BYE"
            #player dc'd
        elseif play[:tag] == "UN"
            #player rc'd
        else error("Invalid tag") end

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
# analyseLogOld(queryLog("scraw2019s4p.db", 25))
# queryLog("scraw2009s4p.db", 105)
queryLogs("scraw2009s4p.db")
