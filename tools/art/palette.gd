extends RefCounted
## Sweetie 16 by GrafxKid. In the sprite grids, each colour is written as its
## index in hex (0-9, a-f), and '.' is transparent.

const KEYS := "0123456789abcdef"
const TRANSPARENT := "."
const COLORS: PackedColorArray = [
	Color("1a1c2c"), # 0 near black: outlines
	Color("5d275d"), # 1 dark purple
	Color("b13e53"), # 2 red
	Color("ef7d57"), # 3 orange
	Color("ffcd75"), # 4 yellow
	Color("a7f070"), # 5 light green
	Color("38b764"), # 6 green: healing
	Color("257179"), # 7 teal: moss
	Color("29366f"), # 8 dark blue
	Color("3b5dc9"), # 9 blue
	Color("41a6f6"), # a light blue
	Color("73eff7"), # b cyan
	Color("f4f4f4"), # c white
	Color("94b0c2"), # d light grey
	Color("566c86"), # e grey
	Color("333c57"), # f dark grey
]

## Colour roles from the Design page. Accents are kept for gameplay and never
## appear in tiles or props.
const ENEMY := [2, 3] # red family: enemies and telegraphs
const XP := [11] # cyan
## Light green alone matches yellow under deuteranopia, so healing is mid green.
const HEALING := [6, 5] # green, light green highlight
const PLAYER := [4] # yellow: player and pickups
const FLASH := [12] # white: hit flashes only
const ACCENTS := [2, 3, 4, 5, 6, 11, 12]
const OUTLINE := 0


static func color_of(key: String) -> Color:
	return COLORS[KEYS.find(key)]


static func is_key(c: String) -> bool:
	return c == TRANSPARENT or (c.length() == 1 and KEYS.contains(c))


## Palette index of a pixel colour, -1 if it isn't in the palette.
static func index_of(color: Color) -> int:
	for i in COLORS.size():
		if COLORS[i].to_rgba32() == color.to_rgba32():
			return i
	return -1
