extends SceneTree
## Lays every generated PNG out on the floor tile, scaled up, plus a font sample.
## Writes captures/contact.png and captures/contact_grey.png for review.
## godot_console --headless --path . -s res://tools/art/contact_sheet.gd

const SPRITE_DIR := "res://assets/sprites"
const FONT_PNG := "res://assets/fonts/pixel.png"
const OUT_DIR := "res://captures"
const SCALE := 4
const PAD := 8
const ROW_WIDTH := 320
const SAMPLE := "MOSSRUNE 0123456789 LEVEL UP! 10:00 HP 100%"
const CELL := Vector2i(6, 8)
const FONT_COLUMNS := 16
const FONT_FIRST := 32


func _init() -> void:
	var images: Array[Image] = []
	for file in DirAccess.get_files_at(SPRITE_DIR):
		if file.ends_with(".png"):
			images.append(_load(SPRITE_DIR.path_join(file)))
	images.append(_text(SAMPLE))

	# Shelf layout at 1x, then scaled.
	var placed: Array[Vector2i] = []
	var x := PAD
	var y := PAD
	var shelf := 0
	for img in images:
		if x + img.get_width() > ROW_WIDTH:
			x = PAD
			y += shelf + PAD
			shelf = 0
		placed.append(Vector2i(x, y))
		x += img.get_width() + PAD
		shelf = maxi(shelf, img.get_height())
	var size := Vector2i(ROW_WIDTH + PAD, y + shelf + PAD)

	var sheet := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var floor_tile := _load(SPRITE_DIR.path_join("tiles_floor.png")).get_region(
		Rect2i(0, 0, 16, 16)
	)
	for ty in range(0, size.y, 16):
		for tx in range(0, size.x, 16):
			sheet.blit_rect(
				floor_tile,
				Rect2i(Vector2i.ZERO, floor_tile.get_size()),
				Vector2i(tx, ty),
			)
	for i in images.size():
		sheet.blend_rect(images[i], Rect2i(Vector2i.ZERO, images[i].get_size()), placed[i])
	sheet.resize(size.x * SCALE, size.y * SCALE, Image.INTERPOLATE_NEAREST)

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	sheet.save_png(OUT_DIR.path_join("contact.png"))
	for py in sheet.get_height():
		for px in sheet.get_width():
			var c := sheet.get_pixel(px, py)
			var l := c.get_luminance()
			sheet.set_pixel(px, py, Color(l, l, l))
	sheet.save_png(OUT_DIR.path_join("contact_grey.png"))
	print("contact sheet: %d images" % images.size())
	quit(0)


func _load(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _text(s: String) -> Image:
	var font := _load(FONT_PNG)
	var img := Image.create_empty(s.length() * CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
	for i in s.length():
		var cell := s.unicode_at(i) - FONT_FIRST
		var src := Rect2i(
			Vector2i(cell % FONT_COLUMNS, floori(float(cell) / FONT_COLUMNS)) * CELL,
			CELL,
		)
		img.blit_rect(font, src, Vector2i(i * CELL.x, 0))
	return img
