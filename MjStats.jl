
__precompile__(true)

module MjStats

include("playdata.jl")
include("playutils.jl")

include("parseutils.jl")
include("parserdict.jl")

export PlayState
export MatchEvent

using SQLite
using Tables
using CodecLz4

include("analyse.jl")

end
