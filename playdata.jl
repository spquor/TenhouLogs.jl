
@enum Lobby 一般 上級 特上 鳳凰
@enum Dan   新人 級9 級8 級7 級6 級5 級4 級3 級2 級1 初段 二段 三段 四段 五段 六段 七段 八段 九段 十段 天鳳位

@enum Suit 萬子 筒子 索子 字牌
@enum Numeral 一 二 三 四 五 六 七 八 九
@enum Glyph 東 南 西 北 白 發 中

@enum Call リーチ ツモ ロン チー ポン カン


struct Tile{Rank}
    rank::      Rank
    suit::      Suit
end

if !( @isdefined Hand )
    const Hand = Vector{Tile}
end

if !( @isdefined Pond )
    const Pond = Vector{Tile}
end

if !( @isdefined Points )
    const Points = Int32
end

if !( @isdefined Meld )
    const Meld = Int32
end

# struct Call
#     type::      Call
#     from::      Glyph
#     tile::      Tile
#     with::      Vector{Tile}
# end

# struct Play
#     tile::      Tile
#     tsumogiri:: Bool
#     call::      Call
# end

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

struct Round
    number::    Int8
    repeat::    Int8
    riichi::    Int8
    dice01::    Int8
    dice02::    Int8
    doraid::    Tile
    dealer::    Glyph

    scores::    Vector{Points}
    haipai::    Vector{Hand}
end
