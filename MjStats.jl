module MjStats

# __precompile__(false)

include("playdata.jl")
include("playutils.jl")

include("parseutils.jl")
include("parserdict.jl")

export PlayState
export MatchEvent

using SQLite
using DataFrames
using CodecLz4

include("analyse.jl")

end
