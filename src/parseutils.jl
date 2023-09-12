
function decodeuri(str::AbstractString)

    out = IOBuffer()

    status = 1
    strlen = sizeof(str)

    while status < strlen
        c = str[status]
        if c == '%'
            cn = str[status+1]
            cv = str[status+2]
            write(out, parse(UInt8, string(cn, cv); base=16))
            status = status+3
        else
            write(out, c)
            status = status+1
        end
    end

    return String(take!(out))
end

function parsekey(parser::Function, key::AbstractString, str::AbstractString)

    keyrange = findfirst(key, str)
    if keyrange === nothing
        return nothing
    end

    state::Int = keyrange[end] + 2
    endq::Int = findnext(isequal('\"'), str, state + 1)

    return parser(str[state+1:endq-1])
end

function splitkey(parser::Function, key::AbstractString, str::AbstractString,
        result::AbstractVector = [], pushindex::Integer = 1)

    keyrange = findfirst(key, str)
    if keyrange === nothing
        return nothing
    end

    brk(c) = (c == ',' || c == '\"')
    state::Int = keyrange[end] + 2
    endq::Int = findnext(isequal('\"'), str, state + 1)

    if endq - state == 1
        return result
    end

    if (length(result) == 0)
        while state != endq
            nextbrk::Int = findnext(brk, str, state + 1)
            push!(result, parser(str[state+1:nextbrk-1]))
            state = nextbrk
        end
    else
        while state != endq
            nextbrk::Int = findnext(brk, str, state + 1)
            result[pushindex] = parser(str[state+1:nextbrk-1])
            pushindex = pushindex + 1
            state = nextbrk
        end
    end

    return result
end


@inline function tileget(c::Int)
    return Tile(
        (c == 16 || c == 52 || c == 88) ? (赤) :
            c < 108 ? Rank(c % 36 ÷ 4 + 1) :
                Rank(c % 36 ÷ 4 + 10),
                    Suit(c ÷ 36)
    )
end

@inline function tileget(s::Int, b::Int, t::Int)
    return tileget(36s + 4b + t)
end

const Wall = Dict("$c" => tileget(c) for c = 0:135)


@inline function chi(code::Int, who::Int, from::Int)

    base, call = divrem(code >> 10, 3)
    suit, base = divrem(base, 7)

    tile = tileget(suit, base + call, code >> (3 + 2*call) & 0x3)
    tiles = Tile[]; for i = 0:2
        shift = (code >> (3 + 2*i) & 0x3)
        (i != call) && push!(tiles, tileget(suit, base + i, shift))
    end

    Meld(チー, Seat(from-1), tile, tiles)
end

@inline function pon(code::Int, who::Int, from::Int)

    base, call = divrem(code >> 9, 3)
    suit, base = divrem(base, 9)

    except = code >> 5 & 0x3
    if (call == except)
        call = call + 1
    end

    tile = tileget(suit, base, call)
    tiles = Tile[]; for i = 0:3
        if (i != call) && (i != except)
            push!(tiles, tileget(suit, base, i))
        end
    end

    Meld(ポン, Seat(from-1), tile, tiles)
end

@inline function pei(code::Int, who::Int, from::Int)

    Meld(キタ, Seat(from-1), Tile(北, 字牌), Tile[])
end

@inline function kkn(code::Int, who::Int, from::Int)

    base, call = div(code >> 9, 3), 3
    suit, base = divrem(base, 9)

    tile = tileget(suit, base, code >> 5 & 0x3)

    Meld(小明槓, Seat(from-1), tile, Tile[])
end

@inline function kan(code::Int, who::Int, from::Int)

    base, call = divrem(code >> 8, 4)
    suit, base = divrem(base, 9)

    tile = tileget(suit, base, call)
    tiles = Tile[]; for i = 0:3
        (i != call) && push!(tiles, tileget(suit, base, i))
    end

    Meld((who == from) ? 暗槓 : 大明槓,
        Seat(from-1), tile, tiles)
end
