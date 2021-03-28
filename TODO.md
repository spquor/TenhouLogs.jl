
# TODO STRING PERFORMANCE IMPROVEMENTS
# 1. searching string inside string is slow
# 2. immutable strings could be changed to cstrings
# 3. hash function for dicts could be improved
#

using StringViews

macro sview(sss, n1, n2)
    return quote
        StringView(@view $(esc(sss)).data[$(esc(n1)):$(esc(n2))])
    end
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


# 1. Anonymous functions could be causing slowdowns
# 2. Function caching and globaling can improve performance
# 3. FunctionWrappers could be useful for ccalling
#

using FunctionWrappers

const Parser = FunctionWrappers.FunctionWrapper{
    MatchEvent, Tuple{String,PlayState}
}
