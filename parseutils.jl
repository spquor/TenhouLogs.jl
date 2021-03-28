
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
