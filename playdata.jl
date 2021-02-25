
@enum Lobby 一般 上級 特上 鳳凰
@enum Dan 新人 九級 八級 七級 六級 五級 四級 三級 二級 一級 初段 二段 三段 四段 五段 六段 七段 八段 九段 十段 天鳳位

@enum Suit 萬子 筒子 索子 字牌
@enum Rank 一 二 三 四 五 六 七 八 九 東 南 西 北 白 發 中

@enum Yaku mentsumo riichi ippatsu chankan rinshan haitei houtei pinfu tanyao ipeiko tonpai nanpai xiapai peipai tonhai nanhai xiahai peihai haku hatsu chun daburii chiitoitsu chanta ittsu sandoujun sandoukou sankantsu toitoi sanankou shousangen honroutou ryanpeikou junchan honitsu chinitsu renhou tenhou chihou daisangen suuankou suuankoutanki tsuuiisou ryuuiisou chinroutou chuurenpouto junseichuurenpouto kokushi kokushijuusan daisuushi shousuushi suukantsu dora uradora akadora

@enum Ryuukyoku tsuujou yao9 reach4 ron3 kan4 kaze4 nagashi

@enum Limit nolimit mangan haneman baiman sanbaiman yakuman

@enum Round 東一 東二 東三 東四 南一 南二 南三 南四 西一 西二 西三 西四
@enum Dice ⚀ ⚁ ⚂ ⚃ ⚄ ⚅

@enum Seat 東家 南家 西家 北家
@enum Play リーチ ツモ ロン チー ポン カン


struct Tile
    rank::      Rank
    suit::      Suit
end

if !( @isdefined Tiles )
    const Tiles = Vector{Tile}
end

struct Meld
    called::    Tile
    play::      Play
    from::      Seat
    with::      Vector{Tile}
end

if !( @isdefined Melds )
    const Melds = Vector{Meld}
end

struct Rules
    offine::    Bool
    akadora::   Bool
    kuitan::    Bool
    hanchan::   Bool
    sanma::     Bool
    blitz::     Bool
    lobby::     Lobby
end

struct Table
    names::     Vector{AbstractString}
    ranks::     Vector{Dan}
    rates::     Vector{Float32}
    sexes::     Vector{Char}
end

struct RoundWin
    value::     Int32
    hanfu::     Tuple{Int8,Int8}
    limit::     Limit
    yaku::      Vector{Tuple{Yaku,Int8}}
    dora::      Tiles
    ura::       Tiles
    caller::    Seat
    provider::  Seat
end

struct RoundTie
    tierule::   Ryuukyoku
    reveal::    Vector{Seat}
end

if !( @isdefined Result )
    const Result = Union{RoundWin,RoundTie,Nothing}
end

mutable struct PlayState
    PlayState(
        ::UndefInitializer
    ) = new()

    rules::     Rules
    table::     Table
    round::     Round
    rolls::     Tuple{Dice,Dice}
    turn::      Int8
    dealer::    Seat
    repeat::    Int8
    riichi::    Int8
    doraid::    Tiles
    scores::    Vector{Int32}
    hands::     Vector{Tiles}
    melds::     Vector{Melds}
    ponds::     Vector{Tiles}
    dropped::   Vector{Seat}
    result::    Result
end

if !( @isdefined Wall )
    const Wall = Dict(
        "$c" => Tile(
            c < 108 ? Rank(c % 36 ÷ 4) :
                Rank(c % 36 ÷ 4 + 9),
                    Suit(c ÷ 36)
        ) for c = 0:135
    )
end
