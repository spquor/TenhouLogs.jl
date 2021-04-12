
__precompile__(true)

module MjStats

include("playdata.jl")
include("parseutils.jl")
include("parserdict.jl")

using SQLite
using Tables
using Dates
using Downloads
using ZipFile
using CodecZlib
using CodecLz4

include("dbcreate.jl")
include("analyse.jl")

end
