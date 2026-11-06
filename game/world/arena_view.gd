class_name ArenaView
extends RefCounted
## Draws an ArenaData: floor and wall tiles on a TileMapLayer, props as y-sorted
## sprites standing on their blocks.

const TILE_SIZE := Vector2i(16, 16)
const FLOOR_PNG := "res://assets/sprites/tiles_floor.png"
const WALL_PNG := "res://assets/sprites/tiles_wall.png"
const PROP_DIR := "res://assets/sprites/"
## Floor variants: 0 and 2 are cracked, 1 is plain. Most tiles are plain.
const FLOOR_VARIANTS := 3
const CRACK_EVERY := 5
const HASH_X := 7
const HASH_Y := 13


static func build(arena: ArenaData, layer: TileMapLayer, props_parent: Node2D) -> void:
	var tiles := TileSet.new()
	tiles.tile_size = TILE_SIZE
	var floor_id := tiles.add_source(_atlas(FLOOR_PNG, FLOOR_VARIANTS))
	var wall_id := tiles.add_source(_atlas(WALL_PNG, 1))
	layer.tile_set = tiles
	var size := arena.size_tiles
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1:
				layer.set_cell(cell, wall_id, Vector2i.ZERO)
			else:
				layer.set_cell(cell, floor_id, Vector2i(_floor_variant(x, y), 0))
	for i in arena.blocks.size():
		if i >= arena.block_props.size() or arena.block_props[i] == "":
			continue
		var block := arena.blocks[i]
		var prop := Sprite2D.new()
		prop.texture = load(PROP_DIR + arena.block_props[i] + ".png") as Texture2D
		prop.centered = false
		prop.offset = Vector2(0, -prop.texture.get_height())
		prop.position = Vector2(block.position.x, block.end.y) * ArenaData.TILE
		props_parent.add_child(prop)


static func _floor_variant(x: int, y: int) -> int:
	var h := (x * HASH_X + y * HASH_Y) % CRACK_EVERY
	if h == 0:
		return 0
	if h == 1:
		return 2
	return 1


static func _atlas(path: String, count: int) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.texture = load(path) as Texture2D
	src.texture_region_size = TILE_SIZE
	for i in count:
		src.create_tile(Vector2i(i, 0))
	return src
