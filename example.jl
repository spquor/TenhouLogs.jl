using TenhouLogs
const Mj = TenhouLogs

function Mj.analyzer(::Val{Mj.matchend}, pst::Mj.PlayState)
    @show pst.scores
end

Mj.analyseDatabase("dataset\\scraw2019s4p.db";
        offset = 170000, limit = 0)
