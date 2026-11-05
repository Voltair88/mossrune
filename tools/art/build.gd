extends SceneTree
## Builds every PNG in assets/ from tools/art. Exit 1 with file:line on a bad grid.
## godot_console --headless --path . -s res://tools/art/build.gd, then --import.

const Palette := preload("res://tools/art/palette.gd")
const Sheets := preload("res://tools/art/sheets.gd")

const SPRITE_DIR := "res://assets/sprites"
const FONT_SOURCE := "res://tools/art/font.txt"
const FONT_PNG := "res://assets/fonts/pixel.png"
## 5x7 glyphs in 6x8 cells, so letters get 1px of spacing. Characters 32-95.
const GLYPH_W := 5
const GLYPH_H := 7
const CELL_W := 6
const CELL_H := 8
const FONT_FIRST := 32
const FONT_LAST := 95
const FONT_COLUMNS := 16
## White, so a Label's modulate or font colour can tint it.
const FONT_INK := "c"

## The swing arc is drawn by code: a band between two radii, swept over 3 frames.
const SWING_SIZE := 32
const SWING_INNER := 9.0
const SWING_OUTER := 14.0
const SWING_RIM := 1.5
## Start and end angle (degrees, 0 = right) covered by each frame.
const SWING_FRAMES: Array[Vector2] = [Vector2(-60, -20), Vector2(-60, 30), Vector2(0, 60)]
const SWING_BODY := "d"
const SWING_EDGE := "4"


func _init() -> void:
	var parsed := Sheets.load_all()
	var errors: PackedStringArray = parsed.errors
	var font := _font_image(errors)
	if not errors.is_empty():
		printerr("art build failed:\n  " + "\n  ".join(errors))
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(SPRITE_DIR)
	DirAccess.make_dir_recursive_absolute(FONT_PNG.get_base_dir())
	var count := 0
	for sheet: Sheets.Sheet in parsed.sheets:
		_save(_sheet_image(sheet), SPRITE_DIR.path_join(sheet.name + ".png"))
		count += 1
	_save(_swing_image(), SPRITE_DIR.path_join("fx_swing.png"))
	_save(font, FONT_PNG)
	print("art build: %d sheets, fx_swing, font" % count)
	quit(0)


func _save(image: Image, path: String) -> void:
	var err := image.save_png(path)
	assert(err == OK, "could not write " + path)


func _sheet_image(sheet: Sheets.Sheet) -> Image:
	var image := Image.create_empty(
		sheet.width * sheet.frames.size(),
		sheet.height,
		false,
		Image.FORMAT_RGBA8,
	)
	for f in sheet.frames.size():
		var rows := sheet.frames[f]
		for y in sheet.height:
			for x in sheet.width:
				var key := rows[y][x]
				if key != Palette.TRANSPARENT:
					image.set_pixel(f * sheet.width + x, y, Palette.color_of(key))
		if sheet.kind in Sheets.OUTLINED:
			_outline(image, f * sheet.width, sheet.width, sheet.height)
	return image


## Paints every transparent pixel that touches an opaque one (4 directions)
## with the outline colour, within one frame.
func _outline(image: Image, x0: int, w: int, h: int) -> void:
	var edge: Array[Vector2i] = []
	for y in h:
		for x in range(x0, x0 + w):
			if image.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var p := Vector2i(x, y) + d
				if (
					p.x >= x0 and p.x < x0 + w and p.y >= 0
					and p.y < h and image.get_pixelv(p).a > 0.0
				):
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		image.set_pixelv(p, Palette.COLORS[Palette.OUTLINE])


func _swing_image() -> Image:
	var image := Image.create_empty(
		SWING_SIZE * SWING_FRAMES.size(),
		SWING_SIZE,
		false,
		Image.FORMAT_RGBA8,
	)
	var center := Vector2(SWING_SIZE, SWING_SIZE) / 2.0
	for f in SWING_FRAMES.size():
		var span := SWING_FRAMES[f]
		for y in SWING_SIZE:
			for x in SWING_SIZE:
				var v := Vector2(x + 0.5, y + 0.5) - center
				var r := v.length()
				var angle := rad_to_deg(v.angle())
				if r < SWING_INNER or r > SWING_OUTER or angle < span.x or angle > span.y:
					continue
				var key := SWING_EDGE if r > SWING_OUTER - SWING_RIM else SWING_BODY
				image.set_pixel(f * SWING_SIZE + x, y, Palette.color_of(key))
	return image


## font.txt: '@ <char>' then 7 rows of 5 characters, '#' for ink and '.' for empty.
func _font_image(errors: PackedStringArray) -> Image:
	var count := FONT_LAST - FONT_FIRST + 1
	var rows_n := ceili(float(count) / FONT_COLUMNS)
	var image := Image.create_empty(
		FONT_COLUMNS * CELL_W,
		rows_n * CELL_H,
		false,
		Image.FORMAT_RGBA8,
	)
	var lines := FileAccess.get_file_as_string(FONT_SOURCE).split("\n")
	var n := 0
	while n < lines.size():
		var line := lines[n].strip_edges(false, true)
		n += 1
		if not line.begins_with("@ "):
			if not line.is_empty() and not line.begins_with("#"):
				errors.append("%s:%d: expected '@ <char>'" % [FONT_SOURCE, n])
			continue
		var ch := line.substr(2)
		if ch == "space":
			ch = " "
		var code := ch.unicode_at(0) if ch.length() == 1 else -1
		if code < FONT_FIRST or code > FONT_LAST:
			errors.append(
				"%s:%d: glyph '%s' is not one character in %d-%d"
				% [FONT_SOURCE, n, ch, FONT_FIRST, FONT_LAST]
			)
			continue
		var cell := code - FONT_FIRST
		var ox := (cell % FONT_COLUMNS) * CELL_W
		var oy := floori(float(cell) / FONT_COLUMNS) * CELL_H
		for gy in GLYPH_H:
			var row := lines[n + gy].strip_edges(false, true) if n + gy < lines.size() else ""
			if row.length() != GLYPH_W or row.replace("#", "").replace(".", "") != "":
				errors.append(
					"%s:%d: glyph rows are %d characters of '#' and '.'"
					% [FONT_SOURCE, n + gy + 1, GLYPH_W]
				)
				break
			for gx in GLYPH_W:
				if row[gx] == "#":
					image.set_pixel(ox + gx, oy + gy, Palette.color_of(FONT_INK))
		n += GLYPH_H
	return image
