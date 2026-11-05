extends GutTest
## Checks the generated art against the Art-Style and Design pages.
## Run the art build first; a missing or stale PNG fails here.

const Palette := preload("res://tools/art/palette.gd")
const Sheets := preload("res://tools/art/sheets.gd")
const SPRITE_DIR := "res://assets/sprites"
const FONT_PNG := "res://assets/fonts/pixel.png"
const FLOOR := "tiles_floor"

## WCAG's minimum for graphics: actors and pickups against the floor.
const MIN_ACTOR_CONTRAST := 3.0
## Props sit between the floor and the actors.
const MIN_PROP_CONTRAST := 1.2
## The floor stays quiet: spread of luminance inside the floor tiles.
const MAX_FLOOR_SPREAD := 0.1
## Accent colours stay apart under each colour-blindness simulation (sRGB distance).
const MIN_ACCENT_DISTANCE := 0.15

## Machado et al. 2009, severity 1.0, applied to linear RGB. Rows are r, g, b.
const CVD := {
	"protanopia": [
		Vector3(0.152286, 1.052583, -0.204868),
		Vector3(0.114503, 0.786281, 0.099216),
		Vector3(-0.003882, -0.048116, 1.051998),
	],
	"deuteranopia": [
		Vector3(0.367322, 0.860646, -0.227968),
		Vector3(0.280085, 0.672501, 0.047413),
		Vector3(-0.011820, 0.042940, 0.968881),
	],
	"tritanopia": [
		Vector3(1.255528, -0.076749, -0.178779),
		Vector3(-0.078411, 0.930809, 0.147602),
		Vector3(0.004733, 0.691367, 0.303900),
	],
}
## The accents that carry gameplay meaning (white is only a flash).
const SIGNAL_ACCENTS := { "enemy": 2, "player": 4, "healing": 6, "xp": 11 }

var _sheets: Array = []


func before_all() -> void:
	var parsed := Sheets.load_all()
	assert_eq(parsed.errors.size(), 0, "\n".join(parsed.errors))
	_sheets = parsed.sheets


func _image(sheet_name: String) -> Image:
	return Image.load_from_file(
		ProjectSettings.globalize_path(SPRITE_DIR.path_join(sheet_name + ".png"))
	)


static func _lum(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


static func _contrast(a: float, b: float) -> float:
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


## Mean luminance of opaque pixels, outline excluded.
static func _mean_lum(img: Image) -> float:
	var total := 0.0
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and Palette.index_of(c) != Palette.OUTLINE:
				total += _lum(c)
				n += 1
	return total / n if n > 0 else 0.0


func _kind(kind: String) -> Array:
	return _sheets.filter(
		func(s: Sheets.Sheet) -> bool:
			return s.kind == kind,
	)


func test_every_sheet_is_built_and_up_to_date() -> void:
	for s: Sheets.Sheet in _sheets:
		var img := _image(s.name)
		assert_not_null(img, s.name + ".png exists (run the art build)")
		if img == null or img.get_size() != Vector2i(s.width * s.frames.size(), s.height):
			fail_test(s.name + " missing or wrong size")
			continue
		# A PNG older than its grid shows up as a mismatched pixel.
		var stale := 0
		for f in s.frames.size():
			for y in s.height:
				for x in s.width:
					var key: String = s.frames[f][y][x]
					if (
						key != Palette.TRANSPARENT
						and img.get_pixel(f * s.width + x, y) != Palette.color_of(key)
					):
						stale += 1
		assert_eq(stale, 0, s.name + " matches its grid (rebuild the art)")


func test_every_pixel_is_in_the_palette() -> void:
	var files := Array(DirAccess.get_files_at(SPRITE_DIR)).filter(
		func(f: String) -> bool:
			return f.ends_with(".png"),
	)
	var paths := files.map(
		func(f: String) -> String:
			return SPRITE_DIR.path_join(f),
	)
	paths.append(FONT_PNG)
	for path: String in paths:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		var bad := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a != 0.0 and (c.a != 1.0 or Palette.index_of(c) < 0):
					bad += 1
		assert_eq(bad, 0, path.get_file() + " off-palette pixels")


func test_tiles_and_props_use_no_accent_colours() -> void:
	for s: Sheets.Sheet in _kind("tile") + _kind("prop"):
		for frame: PackedStringArray in s.frames:
			for row in frame:
				for key in row:
					if key != Palette.TRANSPARENT:
						assert_false(
							Palette.KEYS.find(key) in Palette.ACCENTS,
							"%s uses accent %s" % [s.name, key],
						)


func test_outlined_sprites_keep_the_frame_edge_clear() -> void:
	for s: Sheets.Sheet in _kind("actor") + _kind("item"):
		var img := _image(s.name)
		for y in img.get_height():
			for x in img.get_width():
				var on_edge := (
					y == 0 or y == s.height - 1 or x % s.width == 0 or x % s.width == s.width - 1
				)
				var c := img.get_pixel(x, y)
				if on_edge and c.a > 0.0:
					assert_eq(
						Palette.index_of(c),
						Palette.OUTLINE,
						"%s (%d, %d) body pixel on the edge" % [s.name, x, y],
					)


func test_feet_row_is_the_same_in_every_frame_of_an_actor() -> void:
	var feet := { }
	for s: Sheets.Sheet in _kind("actor"):
		var entity := s.name.get_slice("_", 0)
		var img := _image(s.name)
		for f in s.frames.size():
			var used := img.get_region(Rect2i(f * s.width, 0, s.width, s.height)).get_used_rect()
			var bottom := used.end.y
			if not feet.has(entity):
				feet[entity] = bottom
			assert_eq(bottom, feet[entity], "%s frame %d feet row" % [s.name, f + 1])


func test_actors_and_pickups_stand_out_from_the_floor() -> void:
	var floor_lum := _mean_lum(_image(FLOOR))
	for s: Sheets.Sheet in _kind("actor") + _kind("item"):
		var c := _contrast(_mean_lum(_image(s.name)), floor_lum)
		assert_gt(c, MIN_ACTOR_CONTRAST, s.name + " contrast against the floor")


func test_props_sit_between_floor_and_actors() -> void:
	var floor_lum := _mean_lum(_image(FLOOR))
	var weakest_actor := INF
	for s: Sheets.Sheet in _kind("actor"):
		weakest_actor = minf(weakest_actor, _contrast(_mean_lum(_image(s.name)), floor_lum))
	for s: Sheets.Sheet in _kind("prop"):
		var c := _contrast(_mean_lum(_image(s.name)), floor_lum)
		assert_between(c, MIN_PROP_CONTRAST, weakest_actor, s.name)


func test_floor_is_low_contrast() -> void:
	var img := _image(FLOOR)
	var lo := INF
	var hi := -INF
	for y in img.get_height():
		for x in img.get_width():
			var l := _lum(img.get_pixel(x, y))
			lo = minf(lo, l)
			hi = maxf(hi, l)
	assert_lt(hi - lo, MAX_FLOOR_SPREAD)


func test_accents_stay_distinct_under_colour_blindness() -> void:
	var names := SIGNAL_ACCENTS.keys()
	for kind: String in CVD:
		var m: Array = CVD[kind]
		for i in names.size():
			for j in range(i + 1, names.size()):
				var a := _simulate(Palette.COLORS[SIGNAL_ACCENTS[names[i]]], m)
				var b := _simulate(Palette.COLORS[SIGNAL_ACCENTS[names[j]]], m)
				assert_gt(
					a.distance_to(b),
					MIN_ACCENT_DISTANCE,
					"%s: %s vs %s" % [kind, names[i], names[j]],
				)


static func _simulate(c: Color, m: Array) -> Vector3:
	var l := c.srgb_to_linear()
	var v := Vector3(l.r, l.g, l.b)
	var out := Color(
		clampf(m[0].dot(v), 0, 1),
		clampf(m[1].dot(v), 0, 1),
		clampf(m[2].dot(v), 0, 1),
	).linear_to_srgb()
	return Vector3(out.r, out.g, out.b)


func test_effects_live_in_their_own_sheets() -> void:
	for s: Sheets.Sheet in _sheets:
		assert_eq(s.kind == "fx", s.name.begins_with("fx_"), s.name)
	assert_true(FileAccess.file_exists(SPRITE_DIR.path_join("fx_swing.png")), "fx_swing built")


func test_font_imports_with_every_glyph() -> void:
	var font := load(FONT_PNG) as FontFile
	assert_not_null(font, "pixel.png imports as a FontFile")
	if font:
		for ch in "MOSSRUNE 0123456789 :!?%":
			assert_true(font.has_char(ch.unicode_at(0)), "glyph '%s'" % ch)


func test_hit_flash_shader_loads() -> void:
	var shader := load("res://game/combat/hit_flash.gdshader") as Shader
	assert_not_null(shader)
	assert_string_contains(shader.code, "uniform float flash")
