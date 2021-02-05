include("playdata.jl")

function decodeuri(str::AbstractString)

    out = IOBuffer()
    io = IOBuffer(str)

    while !eof(io)
        c = read(io, Char)
        if c == '%'
            cn = read(io, Char)
            c = read(io, Char)
            write(out, parse(UInt8, string(cn, c); base=16))
        else
            write(out, c)
        end
    end

    return String(take!(out))
end

function rxiterator(rx::Regex, str::AbstractString)

    matches = eachmatch(rx, str)
    local state = Ref((0, false))

    (rx::Regex = r"") -> begin

        if !iszero(state[][1])
            m, state[] = iterate(matches, state[])
        else
            m, state[] = iterate(matches)
        end

        while !occursin(rx, m[1])
            m, state[] = iterate(matches, state[])
        end

        return m
    end
end

function Rules(go::AbstractString)

    code = parse(Int, match(r"\"(?<str>[^\"]+)\""s, go)[:str])

    bits = map(Bool, digits(code, base = 2, pad = 8))
    (   !bits[8] && !bits[6]    ) && ( lobby = 一般 )
    (    bits[8] && !bits[6]    ) && ( lobby = 上級 )
    (   !bits[8] &&  bits[6]    ) && ( lobby = 特上 )
    (    bits[8] &&  bits[6]    ) && ( lobby = 鳳凰 )

    Rules(!bits[1], !bits[2], !bits[3], bits[4], bits[5], bits[7], lobby)
end

function Table(un::AbstractString, np::Int8)

    it = rxiterator(r"\s(?<tag>[^=]+)=\"(?<str>[^\"]+)\""s, un)

    names = [decodeuri(it()[:str]) for s = 1:np]
    ranks = map(Dan, [parse(Int8, s) for s in split(it()[:str], ",")])
    rates = [parse(Float32, s) for s in split(it()[:str], ",")]
    sexes = map((s)-> s[1], split(it()[:str], ","))

    Table(names, ranks, rates, sexes)
end

function RoundInit(init::AbstractString, np::Int8)

    it = rxiterator(r"\s(?<tag>[^=]+)=\"(?<str>[^\"]+)\""s, init)

    roundseed = split(it()[:str], ",")
    number, repeat, riichi, dice01, dice02, =
            map((s)-> s[1] - '0', roundseed)
    doraid = Wall[roundseed[end]]

    scores = [parse(Int, s) for s in split(it()[:str], ",")]
    dealer = Seat(it()[:str][1] - '0')
    haipai = [map(split(it()[:str], ",")) do x Wall[x] end for s = 1:np]

    RoundInit(Round(number), (Dice(dice01), Dice(dice02)),
            dealer, doraid, repeat, riichi, scores, haipai)
end

function RoundWin(agari::AbstractString)

    it = rxiterator(r"\s(?<tag>[^=]+)=\"(?<str>[^\"]+)\""s, agari)

    fu, pt, lh = [parse(Int, s) for s in split(it(r"ten")[:str], ",")]

    combo = split(it()[:str], ",")

    yaku = [
        (Yaku(parse(Int, combo[index])), parse(Int8, combo[index + 1]))
        for index in range(1, length(combo); step = 2)
    ]

    han = mapreduce(x->x[2], +, yaku)

    dora = map(split(it()[:str], ",")) do x Wall[x] end
    ura = occursin("Ura", agari) ?
        map(split(it()[:str], ",")) do x Wall[x] end : Tile[]

    caller = Seat(parse(Int, it()[:str]))
    provider = Seat(parse(Int, it()[:str]))

    RoundWin(pt, (han, fu), Limit(lh), yaku, dora, ura, caller, provider)
end

function RoundTie(ryuukyoku::AbstractString)

    tierule = notile
    reveal = Seat[]

    if (occursin("type", ryuukyoku))
        tierule = Ryuukyoku(
            findfirst(isequal(match(r"\"(?<str>[^\"]+)\""s, ryuukyoku)[:str]),
                ["yao9", "reach4", "ron3", "kan4", "kaze4", "nm"]
        ))
    end

    occursin("hai0", ryuukyoku) && push!(reveal, Seat(0))
    occursin("hai1", ryuukyoku) && push!(reveal, Seat(1))
    occursin("hai2", ryuukyoku) && push!(reveal, Seat(2))
    occursin("hai3", ryuukyoku) && push!(reveal, Seat(3))

    RoundTie(tierule, reveal)
end

function GameResults(owari::AbstractString)

    result = split(match(r"owari=\"(?<str>[^\"]+)\""s, owari)[:str], ",")

    scores = Points[]
    okauma = Float32[]

    for index in range(1, length(result); step = 2)
        push!(scores, parse(Points, result[index]))
        push!(okauma, parse(Float32, result[index+1]))
    end

    GameResults(scores, okauma)
end
