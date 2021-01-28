using SQLite
using DataFrames
using CodecLz4

include("parsers.jl")

Base.show(io::IO, t::Tile) = print(io, t.rank, t.suit)

mutable struct PlayState
    scores:: Vector{Points}
    hands:: Vector{Hand}
    ponds:: Vector{Pond}
    melds:: Vector{Melds}
end

function analyseLog(log::AbstractString)

    it = rxiterator(r"<(?<tag>[A-Z]+)(?<str>.+?)\/>"s, log)

    rules = Rules(it(r"GO")[:str])
    numplayers::Int8 = rules.sanma ? 3 : 4
    table = Table(it(r"UN")[:str], numplayers)

    init() = begin
        round = Round(it(r"INIT")[:str], numplayers)
        playstate = PlayState(
            round.scores, round.haipai,
            [PlayedTile[] for i=1:4],
            [Meld[] for i=1:4]
        )
    end

    init()

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
            #win
            if occursin("owari", play.match)
                break
            else init() end
        elseif play[:tag] == "RYUUKYOKU"
            #tie
            if occursin("owari", play.match)
                break
            else init() end
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
        DBInterface.execute(db, "SELECT id, content FROM records LIMIT 100;")
    )

    println(table.id[logidx])

    # decompress tenhou log contents and return processed table
    return String(transcode(LZ4FrameDecompressor, table.content[logidx]))
end

analyseLog(queryLog("scraw2009s4p.db", 43))
