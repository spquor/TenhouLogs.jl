include("playdata.jl")
include("utility.jl")

@enum MatchEvent noevents matchset roundinit roundwin roundtie matchend tiledraw tiledrop tilecall playerdc

#if !( @isdefined ParserDict ) const
ParserDict = Dict(

    "GO" => (str::AbstractString, pst::PlayState) -> begin

        function getbits(code)
            digits(parse(Int, code), base = 2, pad = 8)
        end

        bits = map(Bool, parsekey(getbits, "type", str))

        (   !bits[8] && !bits[6]    ) && ( lobby = 一般 )
        (    bits[8] && !bits[6]    ) && ( lobby = 上級 )
        (   !bits[8] &&  bits[6]    ) && ( lobby = 特上 )
        (    bits[8] &&  bits[6]    ) && ( lobby = 鳳凰 )

        pst.rules = Rules(!bits[1], !bits[2], !bits[3],
                bits[4], bits[5], bits[7], lobby)

        return noevents
    end,

    "UN" => (str::AbstractString, pst::PlayState) -> begin

        names = AbstractString[]
        for namekey in ["n0", "n1", "n2", "n3"]
            name = parsekey((s)->decodeuri(s), namekey, str)
            if !isnothing(name)
                push!(names, name)
            end
        end

        if length(names) == 1
            nameindex = findfirst(isequal(names[1]), pst.table.names) - 1
            seatindex = findfirst(isequal(Seat(nameindex)), pst.dropped)
            popat!(pst.dropped, seatindex)
            return noevents
        end

        ranks = splitkey((s)->Dan(parse(Int,s)), "dan", str)
        rates = splitkey((s)->parse(Float32,s), "rate", str)
        sexes = splitkey((s)->(s[1]), "sx", str)

        pst.table = Table(names, ranks, rates, sexes)
        pst.dropped = Seat[]

        return matchset
    end,

    "INIT" => (str::AbstractString, pst::PlayState) -> begin

        roundseed::Vector{SubString{String}} =
                splitkey((s)->(s), "seed", str)
        number, pst.repeat, pst.riichi, dice01, dice02 =
                map((s)-> s[1] - '0', roundseed)
        doraid = [Wall[roundseed[end]]]

        pst.round = Round(number)
        pst.rolls = Dice(dice01), Dice(dice02)
        pst.turn = 0

        pst.dealer = parsekey((s)->Seat(parse(Int,s)), "oya", str)
        pst.scores = splitkey((s)->parse(Int32,s), "ten", str)

        haipai = Tiles[]
        for haikey in ["hai0", "hai1", "hai2", "hai3"]
            hai = splitkey(haikey, str) do s Wall[s] end
            if !isnothing(hai)
                push!(haipai, hai)
            end
        end

        pst.hands = haipai
        pst.melds = [Melds[] for i in 1:4]
        pst.ponds = [Tiles[] for i in 1:4]
        pst.result = nothing

        return roundinit
    end,

    "AGARI" => (str::AbstractString, pst::PlayState) -> begin

        fu, pt, lh = splitkey((s)->parse(Int, s), "ten", str)

        if occursin("yakuman", str)
            combo = splitkey((s)->parse(Int, s), "yakuman", str)
            yaku = [
                ( Yaku(combo[1]), 13 )
            ]
        else
            combo = splitkey((s)->parse(Int, s), "yaku", str)
            yaku = [
                (   Yaku(combo[index]), combo[index + 1]    )
                for index in range(1,length(combo); step = 2)
            ]
        end

        han = mapreduce(x->x[2], +, yaku)

        dora = splitkey("doraHai", str) do x Wall[x] end
        ura = splitkey("doraHaiUra", str) do x Wall[x] end

        if isnothing(ura)
            ura = Tile[]
        end

        w = parsekey((s)->Seat(parse(Int,s)), "who", str)
        f = parsekey((s)->Seat(parse(Int,s)), "fromWho", str)

        pst.scores = splitkey((s)->parse(Int32,s), "sc", str)
        pst.result = RoundWin(pt, (han, fu), Limit(lh), yaku, dora, ura, w, f)

        return roundwin
    end,

    "RYUUKYOKU" => (str::AbstractString, pst::PlayState) -> begin

        tierule = tsuujou
        reveal = Seat[]

        if occursin("type", str)
            gettierule(s) = Ryuukyoku(findfirst(isequal(s),
                ["yao9", "reach4", "ron3", "kan4", "kaze4", "nm"]
            ))
            tierule = parsekey(gettierule, "type", str)
        end

        occursin("hai0", str) && push!(reveal, Seat(0))
        occursin("hai1", str) && push!(reveal, Seat(1))
        occursin("hai2", str) && push!(reveal, Seat(2))
        occursin("hai3", str) && push!(reveal, Seat(3))

        pst.scores = splitkey((s)->parse(Int32,s), "sc", str)
        pst.result = RoundTie(tierule, reveal)

        return roundtie
    end,

    "T" => (str::AbstractString, pst::PlayState) -> begin
        push!(pst.hands[1], Wall[str])
        return tiledraw
    end,

    "U" => (str::AbstractString, pst::PlayState) -> begin
        push!(pst.hands[2], Wall[str])
        return tiledraw
    end,

    "V" => (str::AbstractString, pst::PlayState) -> begin
        push!(pst.hands[3], Wall[str])
        return tiledraw
    end,

    "W" => (str::AbstractString, pst::PlayState) -> begin
        push!(pst.hands[4], Wall[str])
        return tiledraw
    end,

    "D" => (str::AbstractString, pst::PlayState) -> begin
        tileindex = findfirst(isequal(Wall[str]), pst.hands[1])
        push!(pst.ponds[1], popat!(pst.hands[1], tileindex))
        return tiledrop
    end,

    "E" => (str::AbstractString, pst::PlayState) -> begin
        tileindex = findfirst(isequal(Wall[str]), pst.hands[2])
        push!(pst.ponds[2], popat!(pst.hands[2], tileindex))
        return tiledrop
    end,

    "F" => (str::AbstractString, pst::PlayState) -> begin
        tileindex = findfirst(isequal(Wall[str]), pst.hands[3])
        push!(pst.ponds[3], popat!(pst.hands[3], tileindex))
        return tiledrop
    end,

    "G" => (str::AbstractString, pst::PlayState) -> begin
        tileindex = findfirst(isequal(Wall[str]), pst.hands[4])
        push!(pst.ponds[4], popat!(pst.hands[4], tileindex))
        return tiledrop
    end,

    "N" => (str::AbstractString, pst::PlayState) -> begin

        return tilecall
    end,

    "REACH" => (str::AbstractString, pst::PlayState) -> begin

        return tilecall
    end,

    "DORA" => (str::AbstractString, pst::PlayState) -> begin

        return noevents
    end,

    "BYE" => (str::AbstractString, pst::PlayState) -> begin
        push!(pst.dropped, parsekey((s)->Seat(parse(Int,s)), "who", str))
        return playerdc
    end
)
#end
