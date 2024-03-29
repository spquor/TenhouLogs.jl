
@enum Lobby 一般 上級 特上 鳳凰
@enum Dan 新人 九級 八級 七級 六級 五級 四級 三級 二級 一級 初段 二段 三段 四段 五段 六段 七段 八段 九段 十段 天鳳位

@enum Round 東一 東二 東三 東四 南一 南二 南三 南四 西一 西二 西三 西四
@enum Dice ⚀ ⚁ ⚂ ⚃ ⚄ ⚅
@enum Seat 東家 南家 西家 北家

@enum Suit::UInt8 萬子 筒子 索子 字牌
@enum Rank::UInt8 赤 一 二 三 四 五 六 七 八 九 東 南 西 北 白 發 中

@enum Yaku mentsumo riichi ippatsu chankan rinshan haitei houtei pinfu tanyao ipeiko tonpai nanpai xiapai peipai tonhai nanhai xiahai peihai haku hatsu chun daburii chiitoitsu chanta ittsu sandoujun sandoukou sankantsu toitoi sanankou shousangen honroutou ryanpeikou junchan honitsu chinitsu renhou tenhou chihou daisangen suuankou suuankoutanki tsuuiisou ryuuiisou chinroutou chuurenpouto junseichuurenpouto kokushi kokushijuusan daisuushi shousuushi suukantsu dora uradora akadora
@enum Limit nolimit mangan haneman baiman sanbaiman yakuman
@enum Ryuukyoku tsuujou yao9 reach4 ron3 kan4 kaze4 nagashi

@enum State CLOSED OPENED RIICHI
@enum Play ポン チー 大明槓 小明槓 暗槓 キタ

@enum MatchEvent noevents matchset roundinit roundwin roundtie matchend tiledraw tiledrop meldcall riichicall doraflip playerdc playerin


struct Tile
    rank::      Rank
    suit::      Suit
end

const Tiles =
    Vector{Union{Tile,Missing}}

struct Meld
    play::      Play
    from::      Seat
    tile::      Tile
    with::      Vector{Tile}
end

const Melds =
    Vector{Union{Meld,Missing}}

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
    namaes::    Vector{String}
    ranks::     Vector{Dan}
    rates::     Vector{Float32}
    sexes::     Vector{Char}
end

struct RoundWin
    value::     Int32
    hanfu::     Tuple{UInt8,UInt8}
    limit::     Limit
    yaku::      Vector{Tuple{Yaku,Int}}
    dora::      Tiles
    ura::       Tiles
    caller::    Seat
    provider::  Seat
end

struct RoundTie
    tierule::   Ryuukyoku
    reveal::    Vector{Seat}
end

const Result =
    Union{RoundWin,RoundTie,Nothing}

mutable struct PlayState
    PlayState(
        ::UndefInitializer
    ) = new()

    logid::     String
    rules::     Rules
    table::     Table
    dced::      Vector{Seat}
    turn::      Int8
    cycle::     Round
    rolls::     Tuple{Dice,Dice}
    dealer::    Seat
    player::    Seat
    honba::     Int8
    rbets::     Int8
    doraid::    Vector{Tile}
    scores::    Vector{Int32}
    hands::     Vector{Tiles}
    melds::     Vector{Melds}
    discard::   Vector{Tiles}
    tedashi::   Vector{Tiles}
    rchtile::   Vector{Tiles}
    status::    Vector{State}
    result::    Result
end
