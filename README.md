# MjStats

*Julia log analysis tools for [Tenhou.net](https://tenhou.net/) mahjong server.*

## Creating log database

```
Command line usage: julia dbcreate.jl [command]
    Available commands:
      index [years] -- Download Tenhou.net scraw indexes for the list of
                       [years]. Indexes will be used later when creating
                       log file database.
      s4p [indexes] -- Create database for all 4p south games in [indexes]
      e4p [indexes] -- Create database for all 4p east games in [indexes]
      s3p [indexes] -- Create database for all 3p south games in [indexes]
      e3p [indexes] -- Create database for all 3p east games in [indexes]
```
