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
            return noevents
        end

        ranks = splitkey((s)->Dan(parse(Int,s)), "dan", str)
        rates = splitkey((s)->parse(Float32,s), "rate", str)
        sexes = splitkey((s)->(s[1]), "sx", str)

        pst.table = Table(names, ranks, rates, sexes)

        return matchset
    end,

    "INIT" => (str::AbstractString, pst::PlayState) -> begin

        roundseed::Vector{SubString{String}} =
                splitkey((s)->(s), "seed", str)
        number, repeat, riichi, dice01, dice02 =
                map((s)-> s[1] - '0', roundseed)
        doraid = Wall[roundseed[end]]

        dealer = parsekey((s)->Seat(parse(Int,s)), "oya", str)
        scores = splitkey((s)->parse(Points,s), "ten", str)

        haipai = Hand[]
        for haikey in ["hai0", "hai1", "hai2", "hai3"]
            hai = splitkey(haikey, str) do s Wall[s] end
            if !isnothing(hai)
                push!(haipai, hai)
            end
        end

        RoundInit(Round(number), (Dice(dice01), Dice(dice02)),
                dealer, doraid, repeat, riichi, scores, haipai)

        pst.round = Round(number)
        pst.scores = scores
        pst.hands = haipai

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

        RoundWin(pt, (han, fu), Limit(lh), yaku, dora, ura, w, f)

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

        RoundTie(tierule, reveal)

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

        return tiledrop
    end,

    "E" => (str::AbstractString, pst::PlayState) -> begin

        return tiledrop
    end,

    "F" => (str::AbstractString, pst::PlayState) -> begin

        return tiledrop
    end,

    "G" => (str::AbstractString, pst::PlayState) -> begin

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

        return playerdc
    end
)
#end

# tileindex = findfirst(isequal(Wall[str]), pst.hands[1])
# popat!(pst.hands[1], tileindex)

function GameResults(owari::AbstractString)

    result = split(match(r"owari=\"(?<str>[^\"]+)\""s, owari)[:str], ",")

    scores = Points[]
    okauma = Float32[]

    for index in range(1, length(result); step = 2)
        push!(scores, parse(Points, result[index]))
        push!(okauma, parse(Float32, result[index+1]))
    end
end