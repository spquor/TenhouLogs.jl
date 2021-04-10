
function analyseDatabase(dbpath::String, cbacks::Dict{MatchEvent,Function};
        readsize::Int = 1000, offset::Int = 0, total::Int = 0)

    # open database and compile sql statement
    if !isfile(dbpath) error("Database not found") end
    db = SQLite.DB(dbpath)
    iszero(total) && (total = Tables.rowtable(
            DBInterface.execute(db, "SELECT COUNT(id) FROM records"))[1][1])
    tableselect = DBInterface.prepare(db, "SELECT * FROM records WHERE id IN
            (SELECT id FROM records LIMIT ? OFFSET ?)")

    # initialize main data structures
    playstates = [PlayState(undef) for i=1:Threads.nthreads()]

    # read and parse chunks of records
    while offset < total

        # select required subtable
        table = Tables.rowtable(
            DBInterface.execute(tableselect, (readsize, offset))
        )

        # parsing problems are fast when done in parallel
        Threads.@threads for i = 1:min(length(table), readsize)

            # decompress tenhou log contents into immutable string
            str = String(transcode(LZ4FrameDecompressor, table[i].content))

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
                st = playstates[Threads.threadid()]

                try
                    # parse using function dictionary

                    if isempty(tag)             END(data, st)
                    elseif tag == "GO"          GO(data, st)
                    elseif tag == "UN"          UN(data, st)
                    elseif tag == "INIT"        INIT(data, st)
                    elseif tag == "AGARI"       AGA(data, st)
                    elseif tag == "RYUUKYOKU"   RYU(data, st)
                    elseif tag == "T"           DRAW(data, st, 1)
                    elseif tag == "U"           DRAW(data, st, 2)
                    elseif tag == "V"           DRAW(data, st, 3)
                    elseif tag == "W"           DRAW(data, st, 4)
                    elseif tag == "D"           DROP(data, st, 1)
                    elseif tag == "E"           DROP(data, st, 2)
                    elseif tag == "F"           DROP(data, st, 3)
                    elseif tag == "G"           DROP(data, st, 4)
                    elseif tag == "N"           MELD(data, st)
                    elseif tag == "REACH"       RCH(data, st)
                    elseif tag == "DORA"        DORA(data, st)
                    elseif tag == "BYE"         BYE(data, st)
                    else                        SKIP(data, st)
                    end

                        # and callback on any user event
                catch ex
                    println("Error in log #", offset + i, "\t|\t",
                            "http://tenhou.net/0/?log=", table[i].id, "\t|\t",
                            "Round:", st.cycle, " / ", st.turn, "\t|\t")
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
