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

function Round(init::AbstractString, np::Int8)

    it = rxiterator(r"\s(?<tag>[^=]+)=\"(?<str>[^\"]+)\""s, init)

    roundseed = split(it()[:str], ",")
    number, repeat, riichi, dice01, dice02, =
            map((s)-> s[1] - '0', roundseed)
    doraid = Wall[roundseed[end]]

    scores = [parse(Int, s) for s in split(it()[:str], ",")]
    dealer = Seat(it()[:str][1] - '0')
    haipai = [map(split(it()[:str], ",")) do x Wall[x] end for s = 1:np]

    Round(number, repeat, riichi, dice01, dice02,
            doraid, dealer, scores, haipai)
end
