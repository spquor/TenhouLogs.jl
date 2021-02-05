
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

if !( @isdefined Hand )
    const Hand = Vector{Tile}
end

struct PlayedTile
    tile::      Tile
    play::      Play
    from::      Seat
    tsumogiri:: Bool
end

if !( @isdefined Pond )
    const Pond = Vector{PlayedTile}
end

struct Meld
    called::    PlayedTile
    play::      Play
    from::      Seat
    with::      Vector{Tile}
end

if !( @isdefined Melds )
    const Melds = Vector{Meld}
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

if !( @isdefined Points )
    const Points = Int32
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
    names::     Vector{String}
    ranks::     Vector{Dan}
    rates::     Vector{Float32}
    sexes::     Vector{Char}
end

struct RoundInit
    round::     Round
    rolls::     Tuple{Dice,Dice}
    dealer::    Seat
    doraid::    Tile
    repeat::    Int8
    riichi::    Int8
    scores::    Vector{Points}
    haipai::    Vector{Hand}
end

struct RoundWin
    value::     Points
    hanfu::     Tuple{Int8,Int8}
    limit::     Limit
    yaku::      Vector{Tuple{Yaku,Int8}}
    dora::      Vector{Tile}
    ura::       Vector{Tile}
    caller::    Seat
    provider::  Seat
end

struct RoundTie
    tierule::   Ryuukyoku
    reveal::    Vector{Seat}
end

struct GameResults
    scores::    Vector{Points}
    okauma::    Vector{Float32}
end
