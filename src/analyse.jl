
# specialize this function with required MatchEvent values
function analyzer(::Val{MatchEvent}, pst::PlayState) where {MatchEvent}
    nothing
end

function tablesize(stmt::SQLite.Stmt)::Int
    return Tables.rowtable(DBInterface.execute(stmt))[1][1]
end

function tabledata(stmt::SQLite.Stmt, args::Tuple{Int,Int,Int,Int})::Array{
        NamedTuple{(:id, :timestamp, :content),
        Tuple{String,Int64,Array{UInt8,1}}},1}
    return Tables.rowtable(DBInterface.execute(stmt, args))
end

function analyseDatabase(dbpath::String;
        readsize::Int = 1000, offset::Int = 0, limit::Int = 0,
        mindt::DateTime = DateTime(2000), maxdt::DateTime = now(UTC))

    # open database and compile sql statement
    if !isfile(dbpath) error("Database not found") end
    db = SQLite.DB(dbpath)
    selectsize = DBInterface.prepare(db, "SELECT COUNT(id) FROM records")
    selectdata = DBInterface.prepare(db, "SELECT * FROM records WHERE id IN
    (SELECT id FROM records LIMIT ? OFFSET ?) AND timestamp BETWEEN ? AND ?")
    mindate = Dates.datetime2epochms(mindt)
    maxdate = Dates.datetime2epochms(maxdt)

    # initialize main data structures
    if iszero(limit) limit = tablesize(selectsize) end
    playstates = [PlayState(undef) for i=1:Threads.nthreads()]

    # read and parse chunks of records
    while offset < limit

        # select required subtable
        table = tabledata(selectdata, (readsize, offset, mindate, maxdate))

        # parsing problems are fast when done in parallel
        Threads.@threads for i = 1:min(length(table), readsize)

            # get playstate and register log id
            st = playstates[Threads.threadid()]
            st.logid = table[i].id

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

                try
                    # parse using function dictionary
                    if isempty(tag)             ev = END(data, st)
                    elseif tag == "GO"          ev = GO(data, st)
                    elseif tag == "UN"          ev = UN(data, st)
                    elseif tag == "INIT"        ev = INIT(data, st)
                    elseif tag == "AGARI"       ev = AGA(data, st)
                    elseif tag == "RYUUKYOKU"   ev = RYU(data, st)
                    elseif tag == "T"           ev = DRAW(data, st, 1)
                    elseif tag == "U"           ev = DRAW(data, st, 2)
                    elseif tag == "V"           ev = DRAW(data, st, 3)
                    elseif tag == "W"           ev = DRAW(data, st, 4)
                    elseif tag == "D"           ev = DROP(data, st, 1)
                    elseif tag == "E"           ev = DROP(data, st, 2)
                    elseif tag == "F"           ev = DROP(data, st, 3)
                    elseif tag == "G"           ev = DROP(data, st, 4)
                    elseif tag == "N"           ev = MELD(data, st)
                    elseif tag == "REACH"       ev = RCH(data, st)
                    elseif tag == "DORA"        ev = DORA(data, st)
                    elseif tag == "BYE"         ev = BYE(data, st)
                    else                        ev = SKIP(data, st)
                    end

                    # and callback on any user event
                    if     ev == noevents       analyzer(Val(noevents), st)
                    elseif ev == matchset       analyzer(Val(matchset), st)
                    elseif ev == roundinit      analyzer(Val(roundinit), st)
                    elseif ev == roundwin       analyzer(Val(roundwin), st)
                    elseif ev == roundtie       analyzer(Val(roundtie), st)
                    elseif ev == matchend       analyzer(Val(matchend), st)
                    elseif ev == tiledraw       analyzer(Val(tiledraw), st)
                    elseif ev == tiledrop       analyzer(Val(tiledrop), st)
                    elseif ev == meldcall       analyzer(Val(meldcall), st)
                    elseif ev == riichicall     analyzer(Val(riichicall), st)
                    elseif ev == doraflip       analyzer(Val(doraflip), st)
                    elseif ev == playerdc       analyzer(Val(playerdc), st)
                    elseif ev == playerin       analyzer(Val(playerin), st)
                    else                        error("Unknown MatchEvent")
                    end

                catch ex
                    println("Error while parsing log: \t",
                            "http://tenhou.net/0/?log=", st.logid, "\t|\t",
                            " Round:", st.cycle, " Turn:", st.turn)
                    rethrow(ex)
                end

            end
        end

        # shift subtable offset
        offset = offset + readsize
    end

    return nothing
end

function analyseLog(dbpath::String, i::Int)

    # log indexing starts from 1 for consistency
    analyseDatabase(dbpath; readsize=1, offset=i-1, limit=i)

    return nothing
end
