using MjStats

function MjStats.analyzer(::Val{MjStats.matchend}, pst::MjStats.PlayState)
    @show pst.scores
end

# MjStats.analyseDatabase("scraw2019s4p.db")
MjStats.analyseDatabase("scraw2019s4p.db";
    offset = 170000, total = 0)
