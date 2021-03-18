using FunctionWrappers

include("playdata.jl")
include("utility.jl")

@enum MatchEvent noevents matchset roundinit roundwin roundtie matchend tiledraw tiledrop opencall riichicall doraflip playerdc playerin

if !( @isdefined ParserDict )

    const Parser = FunctionWrappers.FunctionWrapper{
        MatchEvent, Tuple{String,PlayState}
    }

    function draw(str::AbstractString, pst::PlayState, i::Int)

        pst.turn = pst.turn + 1
        pst.hands[i][end] = Wall[str]
    end

    function drop(str::AbstractString, pst::PlayState, i::Int)

        droppedtile = Wall[str]

        dropindex = findfirst(isequal(missing), pst.discard[i])
        pst.discard[i][dropindex] = droppedtile

        if !isequal(pst.hands[i][end], droppedtile)

            dropindex = findfirst(isequal(missing), pst.tedashi[i])
            pst.tedashi[i][dropindex] = droppedtile

            tileindex = findfirst(isequal(droppedtile), pst.hands[i])
            pst.hands[i][tileindex] = pst.hands[i][end]
        end

        pst.hands[i][end] = missing
    end

    const ParserDict = Dict{String,Parser}(

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

        namaes = String[]
        for namekey in ("n0", "n1", "n2", "n3")
            name = parsekey((s)->decodeuri(s), namekey, str)
            if !isnothing(name)
                push!(namaes, name)
            end
        end

        if length(namaes) == 1
            nameindex = findfirst(isequal(namaes[1]), pst.table.namaes) - 1
            seatindex = findfirst(isequal(Seat(nameindex)), pst.dced) + 0
            deleteat!(pst.dced, seatindex)
            return playerin
        end

        playercount = length(namaes)
        vecranks = Vector{Dan}(undef, playercount)
        vecrates = Vector{Float32}(undef, playercount)
        vecsexes = Vector{Char}(undef, playercount)

        pst.table = Table(namaes,
            splitkey((s)->Dan(parse(Int,s)), "dan", str, vecranks),
            splitkey((s)->parse(Float32,s), "rate", str, vecrates),
            splitkey((s)->(s[1]), "sx", str, vecsexes))
        pst.dced = Seat[]

        pst.hands = [Tiles(undef, 14) for i in 1:playercount]
        pst.melds = [Melds(undef, 8) for i in 1:playercount]
        pst.discard = [Tiles(undef, 32) for i in 1:playercount]
        pst.tedashi = [Tiles(undef, 32) for i in 1:playercount]
        pst.flipped = [Tiles(undef, 1) for i in 1:playercount]

        pst.doraid = Tiles(undef, 5)
        pst.scores = Vector{Int32}(undef, playercount)
        pst.status = Vector{State}(undef, playercount)

        return matchset
    end,

    "INIT" => (str::AbstractString, pst::PlayState) -> begin

        roundseed = splitkey((s)->(s), "seed", str,
                Vector{String}(undef, 6))
        number, pst.honba, pst.riichi, dice01, dice02 =
                map((s)-> s[1] - '0', roundseed)

        pst.turn = 0
        pst.cycle = Round(number)
        pst.rolls = Dice(dice01), Dice(dice02)

        fill!(pst.doraid, missing)
        pst.doraid[1] = Wall[roundseed[end]]

        pst.dealer = parsekey((s)->Seat(parse(Int,s)), "oya", str)
        splitkey((s)->parse(Int32,s), "ten", str, pst.scores)

        playercount = length(pst.table.namaes)
        haikey = ("hai0", "hai1", "hai2", "hai3")

        for i in 1:playercount
            fill!(pst.hands[i], missing)
            fill!(pst.melds[i], missing)
            fill!(pst.discard[i], missing)
            fill!(pst.tedashi[i], missing)
            fill!(pst.flipped[i], missing)
            splitkey(
                (s)->Wall[s], haikey[i],
                    str, pst.hands[i]
            )
        end

        fill!(pst.status, closed)
        pst.result = nothing

        return roundinit
    end,

    "AGARI" => (str::AbstractString, pst::PlayState) -> begin

        fu, pt, lh = splitkey((s)->parse(Int,s), "ten", str,
                Vector{Int}(undef, 3))

        yaku = Tuple{Yaku,Int8}[]

        if occursin("yakuman", str)
            ykm::Vector{Int} = splitkey((s)->parse(Int,s), "yakuman", str)
            for index in range(1, length(ykm); step = 1)
                push!(yaku, (Yaku(ykm[index]), 13))
            end
        else
            yku::Vector{Int} = splitkey((s)->parse(Int,s), "yaku", str)
            for index in range(1, length(yku); step = 2)
                push!(yaku, (Yaku(yku[index]), yku[index + 1]))
            end
        end

        han = mapreduce(x->x[2], +, yaku)

        dora = Tile[]; splitkey((s)->Wall[s], "doraHai", str, dora)
        ura = Tile[]; splitkey((s)->Wall[s], "doraHaiUra", str, ura)

        pst.result = RoundWin(pt, (han, fu), Limit(lh), yaku, dora, ura,
            parsekey((s)->Seat(parse(Int,s)), "who", str),
            parsekey((s)->Seat(parse(Int,s)), "fromWho", str)
        )

        sc = splitkey((s)->parse(Int,s), "sc", str, Vector{Int}(undef, 8))
        for i in range(1, Int(length(sc) / 2); step = 1)
            pst.scores[i] = pst.scores[i] + sc[2*i]
        end

        return roundwin
    end,

    "RYUUKYOKU" => (str::AbstractString, pst::PlayState) -> begin

        tierule::Ryuukyoku = tsuujou
        reveal = Seat[]

        if occursin("type", str)
            gettierule(s) = Ryuukyoku(findfirst(isequal(s),
                ("yao9", "reach4", "ron3", "kan4", "kaze4", "nm")
            ))
            tierule = parsekey(gettierule, "type", str)
        end

        occursin("hai0", str) && push!(reveal, Seat(0))
        occursin("hai1", str) && push!(reveal, Seat(1))
        occursin("hai2", str) && push!(reveal, Seat(2))
        occursin("hai3", str) && push!(reveal, Seat(3))

        pst.result = RoundTie(tierule, reveal)

        sc = splitkey((s)->parse(Int,s), "sc", str, Vector{Int}(undef, 8))
        for i in range(1, Int(length(sc) / 2); step = 1)
            pst.scores[i] = pst.scores[i] + sc[2*i]
        end

        return roundtie
    end,

    "T" => (str::AbstractString, pst::PlayState) -> begin
        draw(str, pst, 1)
        return tiledraw
    end,

    "U" => (str::AbstractString, pst::PlayState) -> begin
        draw(str, pst, 2)
        return tiledraw
    end,

    "V" => (str::AbstractString, pst::PlayState) -> begin
        draw(str, pst, 3)
        return tiledraw
    end,

    "W" => (str::AbstractString, pst::PlayState) -> begin
        draw(str, pst, 4)
        return tiledraw
    end,

    "D" => (str::AbstractString, pst::PlayState) -> begin
        drop(str, pst, 1)
        return tiledrop
    end,

    "E" => (str::AbstractString, pst::PlayState) -> begin
        drop(str, pst, 2)
        return tiledrop
    end,

    "F" => (str::AbstractString, pst::PlayState) -> begin
        drop(str, pst, 3)
        return tiledrop
    end,

    "G" => (str::AbstractString, pst::PlayState) -> begin
        drop(str, pst, 4)
        return tiledrop
    end,

    "N" => (str::AbstractString, pst::PlayState) -> begin

        who = parsekey((s)->parse(Int,s), "who", str) + 1
        code = parsekey((s)->parse(Int,s), "m", str) + 0
        from = mod(who + code & 0x3, 1:4)

        tls = Tiles(missing, 4)
        play = チー

        if (code & 0x4 != 0) # chii

            base, call = divrem(code >> 10, 3)
            suit, base = divrem(base, 7)

            tls = [
                Tile(Rank(base + 0), Suit(suit)),
                Tile(Rank(base + 1), Suit(suit)),
                Tile(Rank(base + 2), Suit(suit))
            ]

        elseif (code & 0x8 != 0) # pon

            base, call = divrem(code >> 9, 3)
            suit, base = divrem(base, 9)
            (suit == 3) && (base = base + 9)

            tile = Tile(Rank(base), Suit(suit))
            tls = [ tile, tile, tile ]

            play = ポン

        elseif (code & 0x10 != 0) # chakan

            base, call = divrem(code >> 9, 3)
            suit, base = divrem(base, 9)
            (suit == 3) && (base = base + 9)

            tile = Tile(Rank(base), Suit(suit))
            tls = [ tile, tile, tile, tile ]

            play = 大明槓

        elseif (code & 0x20 != 0) # peinuk

            call = 0
            tls = [Tile(北, 字牌)]
            play = キタ

        else # ankan

            base, call = divrem(code >> 8, 4)
            suit, base = divrem(base, 9)
            (suit == 3) && (base = base + 9)

            tile = Tile(Rank(base), Suit(suit))
            tls = [ tile, tile, tile, tile ]

            play = from == who ? 暗槓 : 小明槓
        end

        meld = Meld(play, Seat(from-1), tls[call+1], tls)

        if (meld.play != 大明槓)

            for i in eachindex(tls)
                if i != (call+1)
                    tileindex = findfirst(isequal(tls[i]), pst.hands[who])
                    (pst.hands[who][tileindex] = missing)
                end
            end

            meldindex = findfirst(isequal(missing), pst.melds[who])
            pst.melds[who][meldindex] = meld
        else

            meldindex = findfirst((x)->(x.tile == meld.tile), pst.melds[who])
            pst.melds[who][meldindex] = meld
        end

        if !ismissing(pst.hands[who][end])
            tileindex = findfirst(isequal(tls[call+1]), pst.hands[who])
            pst.hands[who][tileindex] = pst.hands[who][end]
            pst.hands[who][end] = missing
        end

        if (meld.play != 暗槓)
            pst.status[who] = opened
        end

        return opencall
    end,

    "REACH" => (str::AbstractString, pst::PlayState) -> begin

        who = parsekey((s)->parse(Int,s), "who", str) + 1

        if parsekey((s)->parse(Int,s), "step", str) == 1
            pst.status[who] = fixed
        else
            pst.scores[who] -= 10
            pst.flipped[who][begin] = pst.discard[who][end]
        end

        return riichicall
    end,

    "DORA" => (str::AbstractString, pst::PlayState) -> begin
        push!(pst.doraid, parsekey((s)->Wall[s], "hai", str))
        return doraflip
    end,

    "BYE" => (str::AbstractString, pst::PlayState) -> begin
        push!(pst.dced, parsekey((s)->Seat(parse(Int,s)), "who", str))
        return playerdc
    end,

    "SHUFFLE" => (str::AbstractString, pst::PlayState) -> begin
        return noevents
    end,

    "TAIKYOKU" => (str::AbstractString, pst::PlayState) -> begin
        return noevents
    end,

    "mjloggm" => (str::AbstractString, pst::PlayState) -> begin
        return noevents
    end,

    "" => (str::AbstractString, pst::PlayState) -> begin
        return matchend
    end
)
end
