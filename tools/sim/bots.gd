extends SceneTree
## Plays whole runs headless with the bots, without nodes or hit-stop, and writes
## one JSON line per run. tools/sim/balance.gd summarises the file.
## godot_console --headless --path . -s res://tools/sim/bots.gd -- --seeds=20
##     --out=captures/bots.jsonl
## The kite bot plays every seed; the other policies play a quarter of them.
## --policy=kite/random plays only that one, so play-check can run them in parallel.

const POLICIES: Array[Array] = [
	[&"kite", &"random"],
	[&"kite", &"first"],
	[&"circle", &"random"],
	[&"wall_hug", &"random"],
	[&"idle", &"random"],
]


func _initialize() -> void:
	# A -s script compiles before the autoloads are registered, so nothing that
	# names Events may load until the main loop runs: bot_runs.gd loads then.
	_main.call_deferred()


func _main() -> void:
	var seeds := 20
	var out := "captures/bots.jsonl"
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = a.get_slice("=", 1).to_int()
		elif a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("--policy="):
			only = a.get_slice("=", 1)
	var runs: Object = load("res://tools/sim/bot_runs.gd").new()
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		printerr("bots: cannot write %s" % out)
		quit(1)
		return
	var started := Time.get_ticks_msec()
	for policy: Array in POLICIES:
		if only != "" and only != "%s/%s" % policy:
			continue
		var n := seeds if policy[0] == &"kite" else maxi(1, seeds / 4)
		for s in n:
			var line: Dictionary = runs.call(&"play", s + 1, policy[0], policy[1])
			file.store_line(JSON.stringify(line))
			print(
				"%s/%s seed %d: %s at %d s, level %d"
				% [
					policy[0],
					policy[1],
					s + 1,
					"won" if line.won else "died",
					line.survival,
					line.level,
				]
			)
	file.close()
	print("bots: wrote %s in %.0f s" % [out, (Time.get_ticks_msec() - started) / 1000.0])
	quit(0)
