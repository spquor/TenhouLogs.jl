using SQLite
using DataFrames
using Dates
using Downloads
using ZipFile
using CodecZlib
using CodecLz4

function createLogDatabase(dbpath::String)

    db = SQLite.DB(dbpath)

    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS indexes(
            id TEXT PRIMARY KEY,
            timestamp INTEGER,
            numrecords INTEGER
        )""")

    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS records(
            id TEXT PRIMARY KEY,
            timestamp INTEGER,
            content BLOB NOT NULL
        )""")

    return (
        DBInterface.prepare(db, "INSERT INTO indexes VALUES(?,?,?);"),
        DBInterface.prepare(db, "INSERT INTO records VALUES(?,?,?);"),
        DBInterface.prepare(db, "SELECT id FROM indexes;"),
        DBInterface.prepare(db, "SELECT id FROM records;"),
        DBInterface.prepare(db, "BEGIN TRANSACTION;"),
        DBInterface.prepare(db, "COMMIT;")
    )
end

function getLogContent(m::RegexMatch)

    logid::AbstractString = m[:id]

    datetime = Dates.datetime2epochms(DateTime(
            parse(Int, logid[1:4]),
            parse(Int, logid[5:6]),
            parse(Int, logid[7:8]),
            parse(Int, logid[9:10]),
            parse(Int, m[:min])
        ))

    buffer = IOBuffer()
    retry(Downloads.download; delays = [0.2, 0.5, 1, 2, 3])(
            "http://tenhou.net/0/log/?" * logid, buffer
        )

    content = transcode(LZ4FrameCompressor, take!(buffer))

    return logid, datetime, content
end

function buildLogDatabase(indexpath::String, dbpath::String, gametype::String)

    # open database and compile sql statements
    insertind, insertrec, selectind, selectrec, beginsql, endsql =
            createLogDatabase(dbpath)
    println("* Database connected - ", dbpath)

    # get list of subindexes already appended to database
    indexinfo = DataFrame(DBInterface.execute(selectind))
    appended = isempty(indexinfo) ? String[] : indexinfo.id::Vector{String}

    # create regular expression for specified gametype
    rx = Regex(":(?<min>\\d\\d)[\\W\\d]+?$gametype[^?]+\\?log=(?<id>[^\"]+)")

    # iterate over all unique html subindexes in index archive
    zipfile = ZipFile.Dir(indexpath)
    for file in zipfile.files
        if (occursin("scc", file.name) && !(file.name in appended))

            # read subindex (unzip if necessary)
            subindex = read(file, String)
            if occursin("gz", file.name)
                subindex = String(transcode(GzipDecompressor, subindex))
            end

            # download and append log content to database
            matches = collect(eachmatch(rx, subindex))
            DBInterface.execute(beginsql)
            @sync for match in matches
                @async DBInterface.execute(insertrec, getLogContent(match))
            end

            # append subindex information
            DBInterface.execute(insertind, (
                file.name,
                Dates.datetime2epochms(now(UTC)),
                length(matches)
            ))

            # write available data into database
            DBInterface.execute(endsql)
            println(file.name, ": ", length(matches), " logs inserted")
        end
    end

    # after all work is done
    close(zipfile)
    println("* Database complete - ", dbpath)
end

function downloadProgress()

    local lastprinted = Ref(0)
    (total, current) -> begin

        if (current > lastprinted[] + 200000)   # print every 200kb
            lastprinted[] = current
            write(stdout, "\e[1G" * "< Downloading: $current/$total\t")
        end

        return nothing
    end
end

function downloadLogIndex(year::String)

    result = Downloads.download("http://tenhou.net/sc/raw/scraw$year.zip",
            "scraw$year.zip", progress = downloadProgress(), verbose = true)
    write(stdout, "* Download complete: scraw$year.zip\n\n")

    return result
end

if !isinteractive() # running as a script

    usage = """Command line usage: julia dbcreate.jl [command]
      Available commands:
        index [years] -- Download Tenhou.net scraw indexes for the list of
                         [years]. Indexes will be used later when creating
                         log file database.
        s4p [indexes] -- Create database for all 4p south games in [indexes]
        e4p [indexes] -- Create database for all 4p east games in [indexes]
        s3p [indexes] -- Create database for all 3p south games in [indexes]
        e3p [indexes] -- Create database for all 3p east games in [indexes]
    """

    function helpfulExit()
        println(usage)
        exit()
    end

    if length(ARGS) < 2
        helpfulExit()
    end

    for arg in ARGS[2:length(ARGS)]

        if (ARGS[1] == "index")

            # download index archives for specified years
            @assert 2009 <= parse(Int, arg) <= Dates.year(now(UTC))
            downloadLogIndex(arg)
        else

            # get game type from the first arg
            if (ARGS[1] == "s4p")
                gametype = "四.南";
            elseif (ARGS[1] == "s3p")
                gametype = "三.南";
            elseif (ARGS[1] == "e4p")
                gametype = "四.東";
            elseif (ARGS[1] == "e3p")
                gametype = "三.東";
            else helpfulExit() end

            # create database for selected index archives
            @assert occursin("scraw", arg) && occursin("zip", arg)
            databasename = split(arg, ".")[1] * ARGS[1] * ".db"
            buildLogDatabase(arg, databasename, gametype)
        end
    end

end
