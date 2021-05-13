# TenhouLogs.jl

*Julia log analysis tools for [Tenhou.net](https://tenhou.net/) mahjong server.*


## Installation

This package is not registered, but cloning is very simple.
```
pkg> add https://github.com/spquor/TenhouLogs.jl
```


## Creating log database

First we need to download an annual log index. There are indexes for each year since 2009.
```
TenhouLogs.downloadLogIndex("2012")
```

Now we can build log databases like this:
```
TenhouLogs.buildLogDatabase("scraw2012.zip", "scraw2012s4p.db", MjStats.S4P_GAME)

# Function requres 3 arguments.
# 1st agrument is a path to index archive.
# 2nd argument is a path to resulting database.
# 3rd argument represents one of 4 gametypes:
# - S4P_GAME (4 player south);
# - S3P_GAME (3 player south);
# - E4P_GAME (4 player east only);
# - E3P_GAME (3 player east only).
```

The database uses SQLite engine and logs are compressed with Lz4 algorithm.


## Analysing datasets

To actually process parsed results we need to define some methods. The following one would print final scores for all processed logs. The function is always called "analyzer". Multiple analyzers can be defined.
```
function TenhouLogs.analyzer(::Val{TenhouLogs.matchend}, pst::TenhouLogs.PlayState)
    @show pst.scores
end

# Analyzer requires 2 arguments. This is a callback function.
# 1st argument is a value type of the specific match event we need to analyze. Event list can be found in MatchEvents enumeration.
# 2nd argument is a structure that fully describes current state of a match.
```

After all analyzers are defined, start the parser with the following function.
```
TenhouLogs.analyseDatabase("scraw2012s4p.db")
```

Actually this can take very long time (depends on db size). Following call will process logs from 100000th to 110000th.
```
TenhouLogs.analyseDatabase("scraw2012s4p.db"; offset = 100000, limit = 110000)
```

You can also filter logs by timestamps using Julia Dates module. Following call will process logs from May 13th 2012 to June 22nd 2012.
```
TenhouLogs.analyseDatabase("scraw2012s4p.db"; mindt = DateTime(2012,5,13), maxdt = DateTime(2012,6,22,23,59))
```

Parser is processing 2500 logs per second on my 10 years old i5 with only 2 cores in use (Julia is pretty fast!). This could be exploited to do some fancy math. Also parser uses threading without any synchronization so be careful with shared data access inside analyzers.
