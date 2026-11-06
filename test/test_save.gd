extends GutTest
## Saves (R11): round trip, bad files, a crash mid-write, and records.

const PATH := "user://test_save.cfg"


func after_each() -> void:
	for p: String in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _assert_defaults(s: SaveStore) -> void:
	assert_eq(s.best_seconds, 0.0)
	assert_eq(s.best_level, 0)
	assert_true(s.shake)
	assert_true(s.flashes)


func test_round_trip() -> void:
	var s := SaveStore.new()
	s.record(123.5, 7)
	s.shake = false
	assert_eq(s.write(PATH), OK)
	var back := SaveStore.read(PATH)
	assert_eq(back.best_seconds, 123.5)
	assert_eq(back.best_level, 7)
	assert_false(back.shake)
	assert_true(back.flashes)


func test_writing_over_an_existing_save_works() -> void:
	var s := SaveStore.new()
	s.record(10.0, 2)
	assert_eq(s.write(PATH), OK)
	s.record(20.0, 3)
	assert_eq(s.write(PATH), OK, "rename over an existing file")
	assert_eq(SaveStore.read(PATH).best_level, 3)
	assert_false(FileAccess.file_exists(PATH + ".tmp"))


func test_missing_file_gives_defaults() -> void:
	_assert_defaults(SaveStore.read(PATH))


func test_garbage_gives_defaults() -> void:
	_write_raw(PATH, "\u0001\u0002 not [a config = file")
	_assert_defaults(SaveStore.read(PATH))
	assert_engine_error("ConfigFile parse error")


func test_unknown_version_gives_defaults() -> void:
	_write_raw(PATH, "[save]\nversion=99\nbest_level=50\n")
	_assert_defaults(SaveStore.read(PATH))


func test_wrong_types_fall_back_per_key() -> void:
	_write_raw(PATH, "[save]\nversion=1\nbest_level=\"lots\"\nbest_seconds=-5.0\nshake=3\n")
	_assert_defaults(SaveStore.read(PATH))


func test_a_half_written_temp_file_leaves_the_save_intact() -> void:
	var s := SaveStore.new()
	s.record(60.0, 4)
	s.write(PATH)
	_write_raw(PATH + ".tmp", "[save]\nversion=1\nbest_le")
	assert_eq(SaveStore.read(PATH).best_level, 4)
	s.record(90.0, 5)
	assert_eq(s.write(PATH), OK, "the next write replaces the stale temp file")
	assert_eq(SaveStore.read(PATH).best_level, 5)


func test_records_only_go_up() -> void:
	var s := SaveStore.new()
	assert_true(s.record(100.0, 5))
	assert_false(s.record(50.0, 3))
	assert_true(s.record(40.0, 6), "a better level alone counts")
	assert_eq(s.best_seconds, 100.0)
	assert_eq(s.best_level, 6)
