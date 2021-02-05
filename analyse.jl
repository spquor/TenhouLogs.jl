using SQLite
using DataFrames
using CodecLz4

include("parsers.jl")

Base.show(io::IO, t::Tile) = print(io, t.rank, t.suit)

mutable struct PlayState
    round::     Round
    dealer::    Seat
    repeat::    Int8
    riichi::    Int8
    doraid::    Vector{Tile}
    scores::    Vector{Points}
    hands::     Vector{Hand}
    ponds::     Vector{Pond}
    melds::     Vector{Melds}
    turn::      Int8
end

function analyseLog(log::AbstractString)

    it = rxiterator(r"<(?<tag>[A-Z]+)(?<str>.+?)\/>"s, log)

    rules = Rules(it(r"GO")[:str])
    numplayers::Int8 = rules.sanma ? 3 : 4
    table = Table(it(r"UN")[:str], numplayers)

    roundinit() = begin
        r = RoundInit(it(r"INIT")[:str], numplayers)
        playstate = PlayState(
            r.round, r.dealer, r.repeat, r.riichi,
            [r.doraid], copy(r.scores), copy(r.haipai),
            [PlayedTile[] for i=1:4], [Meld[] for i=1:4], 0
        )
    end

    roundinit()

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

            @show RoundWin(play[:str])

            if occursin("owari", play.match)
                @show GameResults(play[:str])
                break
            else roundinit() end

        elseif play[:tag] == "RYUUKYOKU"

            @show RoundTie(play[:str])

            if occursin("owari", play.match)
                @show GameResults(play[:str])
                break
            else roundinit() end

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
