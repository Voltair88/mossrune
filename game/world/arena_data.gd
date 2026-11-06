class_name ArenaData
extends Resource
## An arena: its size, the wall ring around it and the solid blocks inside
## (pillars, the shrine). Collision, spawning and the tile map all read this,
## so there is one source of truth for what is solid. Files live in data/arenas/.

const TILE := 16.0

## Size in tiles, the outer wall ring included.
@export var size_tiles: Vector2i = Vector2i(64, 40)
## Solid rectangles in tiles. Props are drawn on these.
@export var blocks: Array[Rect2i] = []
## Prop sheet drawn on each block, same order as blocks ("" draws nothing).
@export var block_props: PackedStringArray = []
@export var player_start_tile: Vector2i = Vector2i(32, 24)

var _block_rects: Array[Rect2] = []


## Everything inside the walls, in pixels.
func inner_rect() -> Rect2:
	return Rect2(Vector2.ONE * TILE, Vector2(size_tiles - Vector2i.ONE * 2) * TILE)


func outer_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size_tiles) * TILE)


func player_start() -> Vector2:
	return (Vector2(player_start_tile) + Vector2.ONE / 2) * TILE


## True if a circle at pos fits inside the walls without touching a block.
func is_free(pos: Vector2, radius: float) -> bool:
	if not inner_rect().grow(-radius).has_point(pos):
		return false
	for rect in _rects():
		if _circle_overlap(pos, radius, rect) != Vector2.ZERO:
			return false
	return true


## Pushes a circle out of the walls and blocks. Moving along a wall slides.
func resolve(pos: Vector2, radius: float) -> Vector2:
	var inner := inner_rect().grow(-radius)
	var out := pos.clamp(inner.position, inner.end)
	for rect in _rects():
		# Cheap reject first: most circles are nowhere near a block.
		if rect.grow(radius).has_point(out):
			out += _circle_overlap(out, radius, rect)
	return out


## The push that moves the circle out of rect, zero if they don't overlap.
static func _circle_overlap(pos: Vector2, radius: float, rect: Rect2) -> Vector2:
	var closest := pos.clamp(rect.position, rect.end)
	var away := pos - closest
	var d2 := away.length_squared()
	if d2 >= radius * radius:
		return Vector2.ZERO
	if d2 > 0.0:
		return away / sqrt(d2) * (radius - sqrt(d2))
	# Centre inside the rect: leave by the nearest side.
	var left := pos.x - rect.position.x
	var right := rect.end.x - pos.x
	var up := pos.y - rect.position.y
	var down := rect.end.y - pos.y
	var least := minf(minf(left, right), minf(up, down))
	if least == left:
		return Vector2(-(left + radius), 0.0)
	if least == right:
		return Vector2(right + radius, 0.0)
	if least == up:
		return Vector2(0.0, -(up + radius))
	return Vector2(0.0, down + radius)


func _rects() -> Array[Rect2]:
	if _block_rects.size() != blocks.size():
		_block_rects.clear()
		for b in blocks:
			_block_rects.append(Rect2(Vector2(b.position) * TILE, Vector2(b.size) * TILE))
	return _block_rects
