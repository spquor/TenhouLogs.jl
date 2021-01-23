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

    () -> begin

        if @isdefined state
            nextmatch = iterate(matches, state)
        else
            nextmatch = iterate(matches)
        end

        m, state = nextmatch

        return SubString{String}[cap for cap in m.captures if !isnothing(cap)]
    end
end

function Tile(wallid::AbstractString)

    id = parse(Int, wallid)
    suit = Suit(id ÷ 36)
    rank =  id % 36 ÷ 4

    suit == 字牌 ? Tile(Glyph(rank), suit) : Tile(Numeral(rank), suit)
end

Base.show(io::IO, z::Tile) = print(io, z.rank, z.suit)

function Rules(go::AbstractString)

    rx = r"\"(?<str>[^\"]+)\""s
    m = match(rx, go)
    code = parse(Int, m[:str])

    bits = map(Bool, digits(code, base = 2, pad = 8))
    (   !bits[8] && !bits[6]    ) && ( lobby = 一般 )
    (    bits[8] && !bits[6]    ) && ( lobby = 上級 )
    (   !bits[8] &&  bits[6]    ) && ( lobby = 特上 )
    (    bits[8] &&  bits[6]    ) && ( lobby = 鳳凰 )

    Rules(!bits[1], !bits[2], !bits[3], bits[4], bits[5], bits[7], lobby)
end

function Table(un::AbstractString)

    rx = r"\s(?<tag>[^=]+)=\"(?<str>[^\"]+)\""s
    matches = eachmatch(rx, un)
    m, state = iterate(matches)

    names = String[]
    while (m[:tag] != "dan")
        push!(names, decodeuri(m[:str]))
        m, state = iterate(matches, state)
    end

    ranks = map(Dan, [parse(Int8, s) for s in split(m[:str], ",")])
    m, state = iterate(matches, state)

    rates = [parse(Float32, s) for s in split(m[:str], ",")]
    m, state = iterate(matches, state)

    sexes = map((s)-> s[1], split(m[:str], ","))
    Table(names, ranks, rates, sexes)
end

function Round(init::AbstractString)

    rx = r"\s(?<tag>[^=]+)=\"(?<str>[^\"]+)\""s
    matches = eachmatch(rx, init)
    m, state = iterate(matches)

    roundseed = split(m[:str], ",")
    number, repeat, riichi, dice01, dice02, =
            map((s)-> s[1] - '0', roundseed)
    doraid = Tile(roundseed[end])
    m, state = iterate(matches, state)

    scores = [parse(Int, s) for s in split(m[:str], ",")]
    m, state = iterate(matches, state)

    dealer = Glyph(m[:str][1] - '0')
    m, state = iterate(matches, state)

    haipai = Vector{Tile}[]
    while startswith(m[:tag], "hai")
        push!(haipai, map(Tile, split(m[:str], ",")))
        nextnode = iterate(matches, state)
        if (nextnode == nothing) break end
        m, state = nextnode
    end

    Round(number, repeat, riichi, dice01, dice02,
            doraid, dealer, scores, haipai)
end
