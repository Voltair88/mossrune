extends RefCounted
## Parses the sprite grids in tools/art/sprites/*.txt. Shared by build.gd and
## test/test_art.gd so both read the same source.
##
## File format:
##   # comment
##   ! kind actor|item|tile|prop|fx     (once, before the first sheet)
##   @ <anim> [WxH]                     (starts a sheet, default 16x16)
##   <H rows of W palette keys>         (one frame; a blank line ends it)
## A sheet is saved as assets/sprites/<file>_<anim>.png, frames side by side.

const Palette := preload("res://tools/art/palette.gd")
const SOURCE_DIR := "res://tools/art/sprites"
const DEFAULT_SIZE := 16
const KINDS: PackedStringArray = ["actor", "item", "tile", "prop", "fx"]
## Kinds that get the 1px outline, which needs a 1px margin inside the frame.
const OUTLINED: PackedStringArray = ["actor", "item"]


class Sheet:
	extends RefCounted
	var name: String
	var kind: String
	var width: int
	var height: int
	## Each frame is an Array of row strings.
	var frames: Array[PackedStringArray] = []


## Parses every source file. Returns {"sheets": Array[Sheet], "errors": PackedStringArray}.
static func load_all() -> Dictionary:
	var sheets: Array[Sheet] = []
	var errors: PackedStringArray = []
	for file in DirAccess.get_files_at(SOURCE_DIR):
		if file.ends_with(".txt"):
			parse_file(SOURCE_DIR.path_join(file), sheets, errors)
	return { "sheets": sheets, "errors": errors }


static func parse_file(path: String, sheets: Array[Sheet], errors: PackedStringArray) -> void:
	var text := FileAccess.get_file_as_string(path)
	var base := path.get_file().get_basename()
	var kind := ""
	var sheet: Sheet = null
	var rows: PackedStringArray = []
	var frame_line := 0
	var lines := text.split("\n")
	# One extra blank line at the end closes the last frame.
	lines.append("")
	for n in lines.size():
		var line := lines[n].strip_edges(false, true)
		var where := "%s:%d" % [path, n + 1]
		if line.begins_with("#"):
			continue
		if line.is_empty() or line.begins_with("@"):
			if not rows.is_empty():
				_close_frame(sheet, rows, kind, "%s:%d" % [path, frame_line], errors)
				rows = []
		if line.is_empty():
			continue
		if line.begins_with("!"):
			var parts := line.substr(1).strip_edges().split(" ", false)
			if parts.size() != 2 or parts[0] != "kind" or not parts[1] in KINDS:
				errors.append(where + ": expected '! kind <%s>'" % "|".join(KINDS))
			else:
				kind = parts[1]
			continue
		if line.begins_with("@"):
			sheet = _open_sheet(line, base, kind, where, errors)
			if sheet != null:
				sheets.append(sheet)
			continue
		if sheet == null:
			errors.append(where + ": pixel row before any '@ <anim>' line")
			continue
		if rows.is_empty():
			frame_line = n + 1
		for i in line.length():
			if not Palette.is_key(line[i]):
				errors.append(where + ": unknown character '%s' at column %d" % [line[i], i + 1])
		rows.append(line)


static func _open_sheet(
	line: String,
	base: String,
	kind: String,
	where: String,
	errors: PackedStringArray,
) -> Sheet:
	if kind.is_empty():
		errors.append(where + ": '! kind' must come before the first sheet")
		return null
	var parts := line.substr(1).strip_edges().split(" ", false)
	if parts.is_empty() or parts.size() > 2:
		errors.append(where + ": expected '@ <anim> [WxH]'")
		return null
	var sheet := Sheet.new()
	sheet.name = base + "_" + parts[0]
	sheet.kind = kind
	sheet.width = DEFAULT_SIZE
	sheet.height = DEFAULT_SIZE
	if parts.size() == 2:
		var size := parts[1].split("x")
		if size.size() != 2 or not size[0].is_valid_int() or not size[1].is_valid_int():
			errors.append(where + ": size must look like 16x32")
			return null
		sheet.width = size[0].to_int()
		sheet.height = size[1].to_int()
	return sheet


static func _close_frame(
	sheet: Sheet,
	rows: PackedStringArray,
	kind: String,
	where: String,
	errors: PackedStringArray,
) -> void:
	if sheet == null:
		return
	if rows.size() != sheet.height:
		errors.append(
			where + ": frame has %d rows, %s needs %d" % [rows.size(), sheet.name, sheet.height]
		)
		return
	for r in rows.size():
		if rows[r].length() != sheet.width:
			errors.append(
				where
				+ ": row %d has %d columns, %s needs %d"
				% [r + 1, rows[r].length(), sheet.name, sheet.width]
			)
			return
	if kind in OUTLINED:
		for r in rows.size():
			for c in sheet.width:
				var edge := r == 0 or c == 0 or r == sheet.height - 1 or c == sheet.width - 1
				if edge and rows[r][c] != Palette.TRANSPARENT:
					errors.append(
						where
						+ ": row %d column %d is on the frame edge; the outline needs a 1px margin"
						% [r + 1, c + 1]
					)
					return
	sheet.frames.append(rows)
