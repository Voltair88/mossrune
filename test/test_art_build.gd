extends GutTest
## The sprite parser must reject bad grids and name the file and line.

const Sheets := preload("res://tools/art/sheets.gd")
const TMP := "user://test_art_build.txt"


func _parse(text: String) -> PackedStringArray:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var sheets: Array[Sheets.Sheet] = []
	var errors: PackedStringArray = []
	Sheets.parse_file(TMP, sheets, errors)
	return errors


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _grid(rows: int, row: String) -> String:
	var lines: PackedStringArray = []
	for i in rows:
		lines.append(row)
	return "\n".join(lines)


func test_a_valid_grid_parses() -> void:
	var errors := _parse("! kind tile\n@ a\n" + _grid(16, "ffffffffffffffff") + "\n")
	assert_eq(errors.size(), 0, "\n".join(errors))


func test_stray_character_names_file_line_and_column() -> void:
	var rows := _grid(16, "ffffffffffffffff").split("\n")
	rows[4] = "fffffffZffffffff"
	var errors := _parse("! kind tile\n@ a\n" + "\n".join(rows) + "\n")
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], TMP + ":7: unknown character 'Z' at column 8")


func test_short_grid_names_where_the_frame_starts() -> void:
	var errors := _parse("! kind tile\n@ a\n" + _grid(15, "ffffffffffffffff") + "\n")
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], TMP + ":3: frame has 15 rows")


func test_outlined_body_on_the_edge_is_rejected() -> void:
	var errors := _parse(
		"! kind actor\n@ a\n4...............\n" + _grid(15, "................") + "\n"
	)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "outline needs a 1px margin")


func test_missing_kind_is_rejected() -> void:
	var errors := _parse("@ a\n" + _grid(16, "ffffffffffffffff") + "\n")
	assert_gt(errors.size(), 0)
