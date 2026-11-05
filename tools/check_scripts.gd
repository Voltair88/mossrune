extends SceneTree
## Loads every .gd outside addons/ in one process. A parse error, including a
## warning raised to an error in project.godot, makes the run exit 1.

const SKIP_DIRS: PackedStringArray = ["res://addons", "res://.godot"]


func _init() -> void:
	var failed: PackedStringArray = []
	var count := 0
	var self_path: String = (get_script() as Script).resource_path
	for path in _scripts("res://"):
		# Reloading the running script with CACHE_MODE_IGNORE corrupts the VM.
		if path == self_path:
			continue
		count += 1
		# Untyped on purpose: assigning a failed load to a typed var crashes the VM.
		var script: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if not (script is Script and (script as Script).can_instantiate()):
			failed.append(path)
	if failed.is_empty():
		print("check_scripts: %d scripts OK" % count)
		quit(0)
	else:
		printerr("check_scripts: %d of %d scripts failed to parse:" % [failed.size(), count])
		for path in failed:
			printerr("  " + path)
		quit(1)


func _scripts(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	if dir_path.trim_suffix("/") in SKIP_DIRS:
		return found
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	for sub in DirAccess.get_directories_at(dir_path):
		found.append_array(_scripts(dir_path.path_join(sub)))
	return found
