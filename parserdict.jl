include("playdata.jl")
include("utility.jl")

@enum MatchEvent noevents matchset roundinit roundwin roundtie matchend tiledraw tiledrop tilecall playerdc

#if !( @isdefined ParserDict ) const
ParserDict = Dict(

    "GO" => (str::AbstractString, pst::PlayState) -> begin

        function getbits(code)
            digits(parse(Int, code); base = 2, pad = 8)
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
            seatindex = findfirst(isequal(Seat(nameindex)), pst.dced)
            deleteat!(pst.dced, seatindex)
            return noevents
        end

        ranks = splitkey((s)->Dan(parse(Int,s)), "dan", str)
        rates = splitkey((s)->parse(Float32,s), "rate", str)
        sexes = splitkey((s)->(s[1]), "sx", str)

        pst.table = Table(names, ranks, rates, sexes)
        pst.dced = Seat[]

        return matchset
    end,

    "INIT" => (str::AbstractString, pst::PlayState) -> begin

        roundseed::Vector{SubString{String}} =
                splitkey((s)->(s), "seed", str)
        number, pst.repeat, pst.riichi, dice01, dice02 =
                map((s)-> s[1] - '0', roundseed)
        pst.doraid = [Wall[roundseed[end]]]

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
        pst.discard = [Tiles[] for i in 1:4]
        pst.tedashi = [Tiles[] for i in 1:4]
        pst.flipped = [Tiles[] for i in 1:4]
        pst.status = [closed for i in 1:4]
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
        deleteat!(pst.hands[1], tileindex)
        push!(pst.discard[1], Wall[str])
        (tileindex != 14) && push!(pst.tedashi[1], Wall[str])
        return tiledrop
    end,

    "E" => (str::AbstractString, pst::PlayState) -> begin
        tileindex = findfirst(isequal(Wall[str]), pst.hands[2])
        deleteat!(pst.hands[2], tileindex)
        push!(pst.discard[2], Wall[str])
        (tileindex != 14) && push!(pst.tedashi[2], Wall[str])
        return tiledrop
    end,

    "F" => (str::AbstractString, pst::PlayState) -> begin
        tileindex = findfirst(isequal(Wall[str]), pst.hands[3])
        deleteat!(pst.hands[3], tileindex)
        push!(pst.discard[3], Wall[str])
        (tileindex != 14) && push!(pst.tedashi[3], Wall[str])
        return tiledrop
    end,

    "G" => (str::AbstractString, pst::PlayState) -> begin
        tileindex = findfirst(isequal(Wall[str]), pst.hands[4])
        deleteat!(pst.hands[4], tileindex)
        push!(pst.discard[4], Wall[str])
        (tileindex != 14) && push!(pst.tedashi[4], Wall[str])
        return tiledrop
    end,

    "N" => (str::AbstractString, pst::PlayState) -> begin

        code = parsekey((s)->parse(Int, s), "m", str)

        if (code & 0x4 != 0) # chii

            base, call = divrem(code >> 10, 3)
            suit, base = divrem(base, 7)

            tls = [
                Tile(Rank(base + 0), Suit(suit)),
                Tile(Rank(base + 1), Suit(suit)),
                Tile(Rank(base + 2), Suit(suit))
            ]

            meld = Meld(チー, tls)

        elseif (code & 0x8 != 0) # pon

            base, call = divrem(code >> 9, 3)
            suit, base = divrem(base, 9)

            tile = Tile(Rank(base), Suit(suit))
            tls = [ tile, tile, tile ]

            meld = Meld(ポン, tls)

        elseif (code & 0x10 != 0) # chakan

            base, call = divrem(code >> 9, 3)
            suit, base = divrem(base, 9)

            tile = Tile(Rank(base), Suit(suit))
            tls = [ tile, tile, tile, tile ]

            meld = Meld(大明槓, tls)

        elseif (code & 0x20 != 0) # peinuk

            meld = Meld(キタ, [])

        else # ankan

            base, call = divrem(code >> 8, 4)
            suit, base = divrem(base, 9)

            tile = Tile(Rank(base), Suit(suit))
            tls = [ tile, tile, tile, tile ]

            meld = Meld(小明槓, tls)

        end

        push!(pst.melds[code & 0x3 + 1], meld)

        return tilecall
    end,

    "REACH" => (str::AbstractString, pst::PlayState) -> begin

        who = parsekey((s)->parse(Int,s), "who", str) + 1

        if parsekey((s)->(parse(Int,s) == 1), "step", str)
            pst.status[who] = fixed
        else
            pst.scores[who] -= 1000
            push!(pst.flipped[who], pst.discard[who][end])
        end

        return tilecall
    end,

    "DORA" => (str::AbstractString, pst::PlayState) -> begin
        push!(pst.doraid, parsekey((s)->Wall[s], "hai", str))
        return noevents
    end,

    "BYE" => (str::AbstractString, pst::PlayState) -> begin
        push!(pst.dced, parsekey((s)->Seat(parse(Int,s)), "who", str))
        return playerdc
    end
)
#end
