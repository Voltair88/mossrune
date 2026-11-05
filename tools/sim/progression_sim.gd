extends RefCounted
## Paper simulation of a run: spawns from the wave schedule, an assumed share
## of them killed and collected, XP into the curve. No scene, no physics.
## Used by tools/sim/progression.gd (prints tables) and
## test/test_progression_targets.gd (fails the check when pacing drifts).

## [PLACEHOLDER] XP per kill. Moves into EnemyData in phase 3.
const XP_PER_KILL: Dictionary[StringName, float] = { &"slime": 1.0, &"bat": 1.0, &"mossback": 5.0 }
## [PLACEHOLDER] Share of spawned enemies the player kills. Replaced by bot data in phase 4.
const KILL_RATIO := 0.85
## [PLACEHOLDER] Share of dropped gems the player collects.
const PICKUP_RATIO := 0.9
## [PLACEHOLDER] Seconds from spawn to kill (walk-in time from the spawn ring).
const KILL_DELAY_SEC := 3.0
const RUN_SEC := 600
const MINUTE_SEC := 60

## Pacing targets from the Design page.
const FIRST_LEVEL_MIN_SEC := 30.0
const FIRST_LEVEL_MAX_SEC := 45.0
const LEVEL_AT_5_MIN := 12
const LEVEL_AT_5_MAX := 16
const LEVEL_AT_10_MIN := 22
const LEVEL_AT_10_MAX := 28
const MAX_LEVEL_GAP_SEC := 45.0
const MAX_SPAWNS_PER_MINUTE := 300.0


class Result:
	extends RefCounted
	## level_times[i] is the second level i + 2 was reached.
	var level_times: PackedFloat32Array = []
	## One row per minute: spawns, kills, xp, level at the end of the minute.
	var minutes: Array[Dictionary] = []


	func level_at(sec: float) -> int:
		var level := 1
		for t in level_times:
			if t <= sec:
				level += 1
		return level


static func run(curve: XpCurve, schedule: WaveSchedule) -> Result:
	var result := Result.new()
	var level := 1
	var xp := 0.0
	var row := { "spawns": 0.0, "kills": 0.0, "xp": 0.0 }
	for s in RUN_SEC:
		row.spawns += schedule.spawns_between(s, s + 1)
		var killed := schedule.spawns_by_enemy(s - KILL_DELAY_SEC, s + 1 - KILL_DELAY_SEC)
		for id in killed:
			var kills: float = killed[id] * KILL_RATIO
			var gained: float = kills * XP_PER_KILL[id] * PICKUP_RATIO
			row.kills += kills
			row.xp += gained
			xp += gained
		while xp >= curve.xp_to_next(level):
			xp -= curve.xp_to_next(level)
			level += 1
			result.level_times.append(s + 1)
		if (s + 1) % MINUTE_SEC == 0:
			row.level = level
			result.minutes.append(row)
			row = { "spawns": 0.0, "kills": 0.0, "xp": 0.0 }
	return result


## Every pacing target the result misses, empty when all are met.
static func misses(result: Result) -> PackedStringArray:
	var out: PackedStringArray = []
	var first := result.level_times[0] if not result.level_times.is_empty() else INF
	if first < FIRST_LEVEL_MIN_SEC or first > FIRST_LEVEL_MAX_SEC:
		out.append(
			"first level-up at %.0f s, target %.0f-%.0f"
			% [first, FIRST_LEVEL_MIN_SEC, FIRST_LEVEL_MAX_SEC]
		)
	var at5 := result.level_at(5 * MINUTE_SEC)
	if at5 < LEVEL_AT_5_MIN or at5 > LEVEL_AT_5_MAX:
		out.append("level %d at 5:00, target %d-%d" % [at5, LEVEL_AT_5_MIN, LEVEL_AT_5_MAX])
	var at10 := result.level_at(RUN_SEC)
	if at10 < LEVEL_AT_10_MIN or at10 > LEVEL_AT_10_MAX:
		out.append("level %d at 10:00, target %d-%d" % [at10, LEVEL_AT_10_MIN, LEVEL_AT_10_MAX])
	for i in range(1, result.level_times.size()):
		var gap := result.level_times[i] - result.level_times[i - 1]
		if gap > MAX_LEVEL_GAP_SEC:
			out.append(
				"%.0f s between level %d and %d, max %.0f" % [gap, i + 1, i + 2, MAX_LEVEL_GAP_SEC]
			)
	for m in result.minutes.size():
		if result.minutes[m].spawns > MAX_SPAWNS_PER_MINUTE:
			out.append(
				"%.0f spawns in minute %d, max %.0f"
				% [result.minutes[m].spawns, m + 1, MAX_SPAWNS_PER_MINUTE]
			)
	return out
