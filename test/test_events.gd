extends GutTest
## The event bus skips GDScript warnings, so the unused-signal check lives here:
## every signal declared on Events must be emitted somewhere in game/.

const EVENTS := "res://game/events/events.gd"
const GAME_DIR := "res://game"


func _sources(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for file in DirAccess.get_files_at(dir_path):
		var path := dir_path.path_join(file)
		if file.ends_with(".gd") and path != EVENTS:
			out.append(FileAccess.get_file_as_string(path))
	for sub in DirAccess.get_directories_at(dir_path):
		out.append_array(_sources(dir_path.path_join(sub)))
	return out


func test_every_signal_is_emitted_in_game() -> void:
	var regex := RegEx.create_from_string("(?m)^signal\\s+(\\w+)")
	var declared := regex.search_all(FileAccess.get_file_as_string(EVENTS))
	assert_gt(declared.size(), 0, "Events declares signals")
	var code := "\n".join(_sources(GAME_DIR))
	for m in declared:
		var name := m.get_string(1)
		assert_true(code.contains("Events.%s.emit(" % name), name + " is emitted")


func test_events_holds_no_state_or_functions() -> void:
	var text := FileAccess.get_file_as_string(EVENTS)
	assert_false(text.contains("\nvar "), "no state")
	assert_false(text.contains("\nfunc "), "no functions")
