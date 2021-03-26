
@enum Lobby 一般 上級 特上 鳳凰
@enum Dan 新人 九級 八級 七級 六級 五級 四級 三級 二級 一級 初段 二段 三段 四段 五段 六段 七段 八段 九段 十段 天鳳位

@enum Round 東一 東二 東三 東四 南一 南二 南三 南四 西一 西二 西三 西四
@enum Dice ⚀ ⚁ ⚂ ⚃ ⚄ ⚅
@enum Seat 東家 南家 西家 北家

@enum Suit::Int8 萬子 筒子 索子 字牌
@enum Rank::Int8 赤 一 二 三 四 五 六 七 八 九 東 南 西 北 白 發 中

@enum Yaku mentsumo riichi ippatsu chankan rinshan haitei houtei pinfu tanyao ipeiko tonpai nanpai xiapai peipai tonhai nanhai xiahai peihai haku hatsu chun daburii chiitoitsu chanta ittsu sandoujun sandoukou sankantsu toitoi sanankou shousangen honroutou ryanpeikou junchan honitsu chinitsu renhou tenhou chihou daisangen suuankou suuankoutanki tsuuiisou ryuuiisou chinroutou chuurenpouto junseichuurenpouto kokushi kokushijuusan daisuushi shousuushi suukantsu dora uradora akadora
@enum Limit nolimit mangan haneman baiman sanbaiman yakuman
@enum Ryuukyoku tsuujou yao9 reach4 ron3 kan4 kaze4 nagashi

@enum State OPENED CLOSED RIICHI
@enum Play チー ポン 大明槓 小明槓 暗槓 キタ


struct Tile
    rank::      Rank
    suit::      Suit
end

if !( @isdefined Tiles )
    const Tiles = Vector{Union{Tile,Missing}}
end

struct Meld
    play::      Play
    from::      Seat
    tile::      Tile
    with::      Vector{Tile}
end

if !( @isdefined Melds )
    const Melds = Vector{Union{Meld,Missing}}
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
    namaes::    Vector{String}
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
    dced::      Vector{Seat}
    turn::      Int8
    cycle::     Round
    rolls::     Tuple{Dice,Dice}
    dealer::    Seat
    honba::     Int8
    riichi::    Int8
    doraid::    Tiles
    scores::    Vector{Int32}
    hands::     Vector{Tiles}
    melds::     Vector{Melds}
    discard::   Vector{Tiles}
    tedashi::   Vector{Tiles}
    flipped::   Vector{Tiles}
    status::    Vector{State}
    result::    Result
end

@eval function tileget(c::Int)
    return Tile(
        (c == 16 || c == 52 || c == 88) ? (赤) :
            c < 108 ? Rank(c % 36 ÷ 4 + 1) :
                Rank(c % 36 ÷ 4 + 10),
                    Suit(c ÷ 36)
    )
end

@inline function tileget(s::Int, b::Int, t::Int)
    return tileget(36s + 4b + t)
end

if !( @isdefined Wall )
    const Wall = Dict("$c" => tileget(c) for c = 0:135)
end

@inline function draw(str::AbstractString, pst::PlayState, i::Int)

    pst.turn = pst.turn + 1
    pst.hands[i][end] = Wall[str]
end

@inline function drop(str::AbstractString, pst::PlayState, i::Int)

    droppedtile = Wall[str]

    dropindex = findfirst(isequal(missing), pst.discard[i])
    pst.discard[i][dropindex] = droppedtile

    if !isequal(pst.hands[i][end], droppedtile)

        dropindex = findfirst(isequal(missing), pst.tedashi[i])
        pst.tedashi[i][dropindex] = droppedtile

        tileindex = findfirst(isequal(droppedtile), pst.hands[i])
        pst.hands[i][tileindex] = pst.hands[i][end]
    end

    pst.hands[i][end] = missing
end

@inline function chi(code::Int, who::Int, from::Int)

    base, call = divrem(code >> 10, 3)
    suit, base = divrem(base, 7)

    tile = tileget(suit, base + call, code >> (3 + 2*call) & 0x3)
    tiles = Tile[]; for i = 0:2
        shift = (code >> (3 + 2*i) & 0x3)
        (i != call) && push!(tiles, tileget(suit, base + i, shift))
    end

    Meld(チー, Seat(from-1), tile, tiles)
end

@inline function pon(code::Int, who::Int, from::Int)

    base, call = divrem(code >> 9, 3)
    suit, base = divrem(base, 9)

    except = code >> 5 & 0x3
    if (call == except)
        call = call + 1
    end

    tile = tileget(suit, base, call)
    tiles = Tile[]; for i = 0:3
        if (i != call) && (i != except)
            push!(tiles, tileget(suit, base, i))
        end
    end

    Meld(ポン, Seat(from-1), tile, tiles)
end

@inline function pei(code::Int, who::Int, from::Int)

    Meld(キタ, Seat(from-1), Tile(北, 字牌), Tile[])
end

@inline function kkn(code::Int, who::Int, from::Int)

    base, call = div(code >> 9, 3), 3
    suit, base = divrem(base, 9)

    tile = tileget(suit, base, code >> 5 & 0x3)

    Meld(小明槓, Seat(from-1), tile, Tile[])
end

@inline function kan(code::Int, who::Int, from::Int)

    base, call = divrem(code >> 8, 4)
    suit, base = divrem(base, 9)

    tile = tileget(suit, base, call)
    tiles = Tile[]; for i = 0:3
        (i != call) && push!(tiles, tileget(suit, base, i))
    end

    Meld((who == from) ? 暗槓 : 大明槓,
        Seat(from-1), tile, tiles)
end
