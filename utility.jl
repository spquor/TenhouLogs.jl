
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

function parsekey(parser::Function, key::AbstractString, str::AbstractString)

    keyrange = findfirst(key, str)
    if keyrange == nothing
        return nothing
    end

    state::Int = keyrange[end] + 2
    endq::Int = findnext(isequal('\"'), str, state + 1)

    return parser(str[state+1:endq-1])
end

function splitkey(parser::Function, key::AbstractString, str::AbstractString,
        result::AbstractVector = [], pushindex::Integer = 1)

    keyrange = findfirst(key, str)
    if keyrange == nothing
        return nothing
    end

    brk(c) = (c == ',' || c == '\"')
    state::Int = keyrange[end] + 2
    endq::Int = findnext(isequal('\"'), str, state + 1)

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
