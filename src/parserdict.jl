
@enum MatchEvent noevents matchset roundinit roundwin roundtie matchend tiledraw tiledrop meldcall riichicall doraflip playerdc playerin

    function GO(str::AbstractString, pst::PlayState)

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
    end

    function UN(str::AbstractString, pst::PlayState)

        namaes = String[]
        for namekey in ("n0", "n1", "n2", "n3")
            name = parsekey((s)->decodeuri(s), namekey, str)
            if !isnothing(name)
                push!(namaes, name)
            end
        end

        if length(namaes) == 1
            nameindex = findfirst(isequal(namaes[1]), pst.table.namaes) - 1
            seatindex = findfirst(isequal(Seat(nameindex)), pst.dced)
            if !isnothing(seatindex) deleteat!(pst.dced, seatindex)
            else push!(pst.dced, Seat(nameindex)) end
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
        pst.melds = [Melds(undef, 12) for i in 1:playercount]
        pst.discard = [Tiles(undef, 32) for i in 1:playercount]
        pst.tedashi = [Tiles(undef, 32) for i in 1:playercount]
        pst.rchtile = [Tiles(undef, 1) for i in 1:playercount]

        pst.scores = Vector{Int32}(undef, playercount)
        pst.status = Vector{State}(undef, playercount)

        return matchset
    end

    function INIT(str::AbstractString, pst::PlayState)

        roundseed = splitkey((s)->(s), "seed", str,
                Vector{String}(undef, 6))
        number, pst.honba, pst.rbets, dice01, dice02 =
                map((s)-> s[1] - '0', roundseed)
        pst.doraid = [Wall[roundseed[end]]]

        pst.turn = 0
        pst.cycle = Round(number)
        pst.rolls = Dice(dice01), Dice(dice02)

        pst.dealer = Seat(parsekey((s)->parse(Int,s), "oya", str))
        pst.player = pst.dealer
        splitkey((s)->parse(Int32,s), "ten", str, pst.scores)

        playercount = length(pst.table.namaes)
        haikey = ("hai0", "hai1", "hai2", "hai3")

        for i in 1:playercount
            fill!(pst.hands[i], missing)
            fill!(pst.melds[i], missing)
            fill!(pst.discard[i], missing)
            fill!(pst.tedashi[i], missing)
            fill!(pst.rchtile[i], missing)
            splitkey(
                (s)->Wall[s], haikey[i],
                    str, pst.hands[i]
            )
        end

        fill!(pst.status, CLOSED)
        pst.result = nothing

        return roundinit
    end

    function AGA(str::AbstractString, pst::PlayState)

        fu, pt, lh = splitkey((s)->parse(Int,s), "ten", str,
                Vector{Int}(undef, 3))

        yaku = Tuple{Yaku,Int}[]

        if occursin("yakuman", str)
            ykm::Vector{Int} = splitkey((s)->parse(Int,s), "yakuman", str)
            for index in range(1, length(ykm); step = 1)
                push!(yaku, (Yaku(ykm[index]), 1))
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
            Seat(parsekey((s)->parse(Int,s), "who", str)),
            Seat(parsekey((s)->parse(Int,s), "fromWho", str))
        )

        sc = splitkey((s)->parse(Int,s), "sc", str, Vector{Int}(undef, 8))
        for i in range(1, Int(length(sc) / 2); step = 1)
            pst.scores[i] = pst.scores[i] + sc[2*i]
        end

        return roundwin
    end

    function RYU(str::AbstractString, pst::PlayState)

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
    end

    function DRAW(str::AbstractString, pst::PlayState, who::Int)

        pst.turn = pst.turn + 1
        pst.player = Seat(who - 1)
        pst.hands[who][end] = Wall[str]

        return tiledraw
    end

    function DROP(str::AbstractString, pst::PlayState, who::Int)

        droppedtile = Wall[str]

        dropindex = findfirst(isequal(missing), pst.discard[who])
        pst.discard[who][dropindex] = droppedtile

        if !isequal(pst.hands[who][end], droppedtile)

            dropindex = findfirst(isequal(missing), pst.tedashi[who])
            pst.tedashi[who][dropindex] = droppedtile

            tileindex = findfirst(isequal(droppedtile), pst.hands[who])
            pst.hands[who][tileindex] = pst.hands[who][end]
        end

        pst.hands[who][end] = missing

        return tiledrop
    end

    function MELD(str::AbstractString, pst::PlayState)

        who = parsekey((s)->parse(Int,s), "who", str) + 1
        code = parsekey((s)->parse(Int,s), "m", str)
        from = mod(who + code & 0x3, 1:4)

        if      (code & 0x04 != 0)  meld = chi(code, who, from)
        elseif  (code & 0x08 != 0)  meld = pon(code, who, from)
        elseif  (code & 0x10 != 0)  meld = kkn(code, who, from)
        elseif  (code & 0x20 != 0)  meld = pei(code, who, from)
        else    #= code unknown =#  meld = kan(code, who, from)
        end

        meldindex = findfirst(isequal(missing), pst.melds[who])
        pst.player = Seat(who - 1)
        pst.melds[who][meldindex] = meld

        for tile in meld.with
            tileindex = findfirst(isequal(tile), pst.hands[who])
            pst.hands[who][tileindex] = missing
        end

        if !ismissing(pst.hands[who][end])
            tileindex = findfirst(isequal(meld.tile), pst.hands[who])
            pst.hands[who][tileindex] = pst.hands[who][end]
            pst.hands[who][end] = missing
        end

        if (meld.play != 暗槓)
            pst.status[who] = OPENED
        end

        return meldcall
    end

    function RCH(str::AbstractString, pst::PlayState)

        who = parsekey((s)->parse(Int,s), "who", str) + 1

        if parsekey((s)->parse(Int,s), "step", str) == 1
            pst.status[who] = RIICHI
        else
            pst.scores[who] -= 10
            tileindex = findfirst(isequal(missing), pst.discard[who])
            pst.rchtile[who][begin] = pst.discard[who][tileindex-1]
        end

        return riichicall
    end

    function DORA(str::AbstractString, pst::PlayState)

        push!(pst.doraid, parsekey((s)->Wall[s], "hai", str))

        return doraflip
    end

    function BYE(str::AbstractString, pst::PlayState)

        seat = Seat(parsekey((s)->parse(Int,s), "who", str))
        dcedindex = findfirst(isequal(seat), pst.dced)
        if isnothing(dcedindex) push!(pst.dced, seat)
        else deleteat!(pst.dced, dcedindex) end

        return playerdc
    end

    function SKIP(str::AbstractString, pst::PlayState)

        return noevents
    end

    function END(str::AbstractString, pst::PlayState)

        return matchend
    end
