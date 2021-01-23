using SQLite
using DataFrames
using CodecLz4

include("parsers.jl")

mutable struct PlayState
    scores:: Vector{Points}
    hands:: Vector{Hand}
    ponds:: Vector{Pond}
    melds:: Vector{Meld}
end

function analyseLog(log::String)

    rx = r"<(?<tag>[A-Z]+)(?<str>.+?)\/>"s
    command = eachmatch(rx, log)
    cmd, state = iterate(command)

    while(cmd[:tag] != "GO")
        cmd, state = iterate(command, state)
    end
    rules = Rules(cmd[:str])

    while(cmd[:tag] != "UN")
        cmd, state = iterate(command, state)
    end
    table = Table(cmd[:str])

    while(cmd[:tag] != "INIT")
        cmd, state = iterate(command, state)
    end

    nextnode = (cmd, state)
    playstate = PlayState(
        Vector{Points}(undef, 4),
        Vector{Hand}(undef, 4),
        Vector{Pond}(undef, 4),
        Vector{Meld}(undef, 4)
    )

    while (nextnode != nothing)

        cmd, state = nextnode
        round = Round(cmd[:str])
        @show round

        playstate.scores = round.scores
        playstate.hands = round.haipai

        cmd, state = iterate(command, state)

        while true

            if cmd[:tag] in ["T", "U", "V", "W", "D", "E", "F", "G"]
                draw = Tile(cmd[:str])
                
            elseif cmd[:tag] == "N"
                #call meld
            elseif cmd[:tag] == "REACH"
                #coll riichi
            elseif cmd[:tag] == "DORA"
                #flip dora
            elseif cmd[:tag] == "AGARI"
                #win
                nextnode = iterate(command, state)
                break
            elseif cmd[:tag] == "RYUUKYOKU"
                #tie
                nextnode = iterate(command, state)
                break
            else continue end

            cmd, state = iterate(command, state)
        end

    end

end

function queryLog(dbpath::String, num::Int)

    if !isfile(dbpath)
        error("Database not found!")
    end

    # establish connection and select table
    db = SQLite.DB(dbpath)
    table = DataFrame(
        DBInterface.execute(db, "SELECT id, content FROM records LIMIT 100;")
    )

    println(table.id[num])

    # decompress tenhou log contents and return processed table
    return transcode(LZ4FrameDecompressor, table.content[num])
end

analyseLog(String(queryLog("scraw2009s4p.db", 43)))
