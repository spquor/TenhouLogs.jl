
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

    @assert startswith(indexpath, "scraw") && endswith(indexpath, "zip")

    # open database and compile sql statements
    insertind, insertrec, selectind, selectrec, beginsql, endsql =
            createLogDatabase(dbpath)
    println("* Database connected - ", dbpath)

    # get list of subindexes already appended to database
    appended::Vector{String} = Tables.columntable(DBInterface.execute(selectind)).id

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

    @assert 2009 <= parse(Int, year) <= Dates.year(now(UTC))

    result = Downloads.download("http://tenhou.net/sc/raw/scraw$year.zip",
            "scraw$year.zip", progress = downloadProgress(), verbose = true)
    write(stdout, "* Download complete: scraw$year.zip\n\n")

    return result
end

const S4P_GAME = "四.南"
const S3P_GAME = "三.南"
const E4P_GAME = "四.東"
const E3P_GAME = "三.東"
