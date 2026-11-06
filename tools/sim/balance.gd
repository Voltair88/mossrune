extends SceneTree
## Summarises bot runs (JSON lines from bots.gd) and checks the Design page's
## "broken" lines. Exit 1 if one is crossed.
## godot_console --headless --path . -s res://tools/sim/balance.gd -- captures/bots_*.jsonl

const KITE := "kite/random"
const IDLE := "idle/random"
const KITE_MEDIAN_MIN_SEC := 180.0
const KITE_MEDIAN_MAX_SEC := 540.0
const IDLE_MAX_SEC := 120.0
const EARLIEST_DEATH_SEC := 20.0
## An upgrade dominates when kite runs that took it this often in their first
## EARLY_PICKS picks survive this many times longer (median) than the other
## kite runs that made as many picks, with enough runs on each side. Only early
## picks count: a long run stacks everything, so total stacks just measure length.
const EARLY_PICKS := 6
const DOMINANT_STACKS := 2
const DOMINANT_FACTOR := 1.5
const DOMINANT_MIN_RUNS := 5


func _init() -> void:
	var runs: Array[Dictionary] = []
	for path in OS.get_cmdline_user_args():
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			printerr("balance: cannot read %s" % path)
			quit(1)
			return
		while not f.eof_reached():
			var text := f.get_line().strip_edges()
			if text != "":
				runs.append(JSON.parse_string(text))
	if runs.is_empty():
		printerr("balance: no runs")
		quit(1)
		return

	var by_policy := { }
	for r in runs:
		if not by_policy.has(r.policy):
			by_policy[r.policy] = [] as Array[Dictionary]
		by_policy[r.policy].append(r)

	print("policy          runs  median_s  won  median_lv  kills/min  xp/min  causes")
	for policy: String in by_policy:
		var list: Array[Dictionary] = by_policy[policy]
		var causes := { }
		var won := 0
		for r in list:
			if r.won:
				won += 1
			elif r.cause != "":
				causes[r.cause] = causes.get(r.cause, 0) + 1
		print(
			"%-14s  %4d  %8.0f  %3d  %9.0f  %9.1f  %6.1f  %s"
			% [
				policy,
				list.size(),
				_median(list, "survival"),
				won,
				_median(list, "level"),
				_median(list, "kills_per_min"),
				_median(list, "xp_per_min"),
				causes,
			]
		)

	var broken: PackedStringArray = []
	if by_policy.has(KITE):
		var m := _median(by_policy[KITE], "survival")
		if m < KITE_MEDIAN_MIN_SEC or m > KITE_MEDIAN_MAX_SEC:
			broken.append(
				"%s median survival %.0f s is outside %.0f to %.0f s"
				% [KITE, m, KITE_MEDIAN_MIN_SEC, KITE_MEDIAN_MAX_SEC]
			)
		broken.append_array(_dominance(by_policy[KITE]))
	if by_policy.has(IDLE):
		for r: Dictionary in by_policy[IDLE]:
			if r.survival > IDLE_MAX_SEC:
				broken.append("idle survived %.0f s on seed %d" % [r.survival, r.seed])
	for r in runs:
		if not r.won and r.survival < EARLIEST_DEATH_SEC:
			broken.append("%s died at %.0f s on seed %d" % [r.policy, r.survival, r.seed])

	if broken.is_empty():
		print("\nno broken lines crossed")
		quit(0)
	else:
		printerr("\nbroken:\n  " + "\n  ".join(broken))
		quit(1)


func _dominance(list: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = []
	var ids := { }
	var long: Array[Dictionary] = []
	for r in list:
		if r.picks.size() >= EARLY_PICKS:
			long.append(r)
			for id: String in r.picks:
				ids[id] = true
	for id: String in ids:
		var stacked: Array[Dictionary] = []
		var rest: Array[Dictionary] = []
		for r in long:
			var early: Array = r.picks.slice(0, EARLY_PICKS)
			(stacked if early.count(id) >= DOMINANT_STACKS else rest).append(r)
		if stacked.size() < DOMINANT_MIN_RUNS or rest.size() < DOMINANT_MIN_RUNS:
			continue
		var with := _median(stacked, "survival")
		var without := _median(rest, "survival")
		print(
			"  %-10s x%d+ early: %3d runs, median %.0f s; others %.0f s"
			% [id, DOMINANT_STACKS, stacked.size(), with, without]
		)
		if with > without * DOMINANT_FACTOR:
			out.append(
				"%s dominates: %.0f s with %d+ early picks, %.0f s without"
				% [id, with, DOMINANT_STACKS, without]
			)
	return out


func _median(list: Array[Dictionary], key: String) -> float:
	var values: Array[float] = []
	for r in list:
		values.append(float(r[key]))
	values.sort()
	var n := values.size()
	return values[n / 2] if n % 2 == 1 else (values[n / 2 - 1] + values[n / 2]) / 2.0
