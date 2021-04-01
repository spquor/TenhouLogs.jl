
function analyseDatabase(dbpath::String, cbacks::Dict{MatchEvent,Function};
        readsize::Int = 2000, offset::Int = 0, total::Int = 0)

    # initialize main data structures
    if !isfile(dbpath) error("Database not found") end
    db = SQLite.DB(dbpath)
    playstates = [PlayState(undef) for i=1:Threads.nthreads()]

    # check database reading boundaties
    iszero(total) && (total = DataFrame(
            DBInterface.execute(db, "SELECT COUNT(id) FROM records"))[1,1])

    # read and parse chunks of records
    while offset < total

        # construct temporary index and select subtable
        table = DataFrame(
            DBInterface.execute(db, "SELECT * FROM records WHERE id IN
            (SELECT id FROM records LIMIT $readsize OFFSET $offset)")
        )

        # parsing problems are fast when done in parallel
        Threads.@threads for i = 1:min(nrow(table), readsize)

            # decompress tenhou log contents into immutable string
            str = String(transcode(LZ4FrameDecompressor, table.content[i]))

            status = 1
            strlen = sizeof(str)

            # read tags sequentially
            while status < strlen

                brk(c) = ('0' <= c <= '9' || c == ' ' || c == '/')

                tagbeg::Int = findnext('<', str, status)
                tagend::Int = findnext(brk, str, tagbeg)
                status::Int = findnext('>', str, tagend)

                tag = str[tagbeg+1:tagend-1]
                data = str[tagend:status-2]

                try
                    # parse using function dictionary
                    ParserDict[tag](data, playstates[Threads.threadid()])
                        # and callback on any user event
                catch ex
                    println(offset + i, "\t|\t", "http://tenhou.net/0/?log=",
                            table.id[i])
                    rethrow(ex)
                end

            end
        end

        # shift subtable offset
        offset = offset + readsize
    end

    return nothing
end

function analyseLog(dbpath::String, cbacks::Dict{MatchEvent,Function}, i::Int)

    analyseDatabase(dbpath, cbacks; readsize=1, offset=i-1, total=i)

    return nothing
end
