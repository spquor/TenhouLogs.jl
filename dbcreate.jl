using SQLite
using DataFrames
using Dates
using Downloads
using ZipFile
using CodecZlib
using CodecLz4

function openLogDatabase(dbpath)

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

function getLogData(m::RegexMatch)

    datetime = DateTime(m[:id][1:10] * m[:min], "yyyymmddHHMM")

    buffer = IOBuffer()
    retry(Downloads.download, delays = [0.2, 0.5, 1, 2, 3])(
            "http://tenhou.net/0/log/?" * m[:id], buffer
        )

    content = transcode(LZ4FrameCompressor, take!(buffer))

    return m[:id], Dates.datetime2epochms(datetime), content
end

function createDBFromIndex(indexpath, dbpath, gametype)

    # open database and compile sql statements
    insertind, insertrec, selectind, selectrec, beginsql, endsql =
            openLogDatabase(dbpath)
    println("* Database connected")
    processed = DataFrame(DBInterface.execute(selectind))

    # create regular expression for specified gametype
    rx = Regex(":(?<min>\\d\\d)[\\W\\d]+?$gametype[^?]+\\?log=(?<id>[^\"]+)")

    # iterate over all unique html subindexes in index archive
    global zipfile = ZipFile.Reader(indexpath)
    for file in zipfile.files
        notprocessed = isempty(processed) || !(file.name in processed.id)
        if (occursin("scc", file.name) && notprocessed)

            # read subindex into memory (unzip if necessary)
            subindex = read(file, String)
            if occursin("gz", file.name)
                subindex = String(transcode(GzipDecompressor, subindex))
            end

            # iterate over each record that matches regex
            data = Vector{Tuple}()
            @sync for match in eachmatch(rx, subindex)
                @async push!(data, getLogData(match))
            end

            # create current index information tuple
            info = (
                file.name,
                Dates.datetime2epochms(now(UTC)),
                size(data, 1)
            )

            # commit available data into database
            if !(isempty(data) || isempty(info))
                DBInterface.execute(beginsql)
                for record in data
                    DBInterface.execute(insertrec, record)
                end
                DBInterface.execute(insertind, info)
                DBInterface.execute(endsql)
                println(info[1], ": ", info[3], " logs inserted")
            end
        end
    end

    # confirm all work is done
    println("* Database complete")
end

for arg in ARGS[2:length(ARGS)]
    # get game type from first arg
    if (ARGS[1] == "s4p")
        gametype = "四.南";
    elseif (ARGS[1] == "s3p")
        gametype = "三.南";
    elseif (ARGS[1] == "e4p")
        gametype = "四.東";
    elseif (ARGS[1] == "e3p")
        gametype = "三.東";
    else exit() end
    # create database for any index archive in consequent args
    if occursin("zip", arg)
        createDBFromIndex(arg, split(arg, ".")[1] * ARGS[1] * ".db", gametype)
    end
end
