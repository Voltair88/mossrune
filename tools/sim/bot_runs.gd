extends RefCounted
## One bot run, loaded by bots.gd at runtime (see the note there).

const DT := 1.0 / 60
const VIEW_SIZE := Vector2(640, 360)
const ARENA := preload("res://data/arenas/ruin.tres")

var _kills: int = 0


func _init() -> void:
	Events.enemy_killed.connect(
		func(_id: StringName, _p: Vector2, _xp: int) -> void:
			_kills += 1,
	)


func play(run_seed: int, move: StringName, pick: StringName) -> Dictionary:
	var spawner := WaveSpawner.new(WaveSchedule.load_dir("res://data/waves"))
	var waves := spawner.schedule.waves
	var run := Run.new(
		run_seed,
		waves[waves.size() - 1].end_sec(),
		load("res://data/tuning/xp_curve.tres"),
	)
	var battle := Battle.new(
		ARENA,
		load("res://data/tuning/player_stats.tres") as PlayerStats,
		load("res://data/tuning/feel.tres") as FeelTuning,
		run.rng,
		load("res://data/tuning/drops.tres") as DropTable,
	)
	var enemy_data := EnemyData.load_dir("res://data/enemies")
	var spawn := func(id: StringName) -> void:
		var d: EnemyData = enemy_data[id]
		var view := Rect2(battle.player.position - VIEW_SIZE / 2, VIEW_SIZE)
		var pos := SpawnPicker.pick(
			battle.rng,
			ARENA,
			view,
			battle.player.velocity.normalized(),
			d.radius_px,
		)
		battle.spawn(d, pos)
	var session := Session.new(
		run,
		battle,
		spawner,
		UpgradePool.load_dir("res://data/upgrades"),
		spawn,
	)
	var bot := Bot.new(move, pick)
	var pick_rng := RandomNumberGenerator.new()
	pick_rng.seed = run_seed
	_kills = 0
	while battle.player.is_alive() and not run.is_won():
		session.tick(DT)
		while session.pending_levels > 0:
			session.next_offer()
			session.choose(bot.pick(session.offer, pick_rng))
		bot.think(battle, DT)
		if bot.swing:
			battle.player.buffer.press()
		battle.step(DT, bot.move)
	var minutes := maxf(run.elapsed / 60.0, 1.0 / 60.0)
	return {
		"seed": run_seed,
		"policy": "%s/%s" % [move, pick],
		"survival": snappedf(run.elapsed, 0.1),
		"won": run.is_won(),
		"cause": String(battle.last_hit_by) if not run.is_won() else "",
		"level": run.level,
		"picks": session.picks.map(
			func(id: StringName) -> String:
				return String(id),
		),
		"kills_per_min": snappedf(_kills / minutes, 0.1),
		"xp_per_min": snappedf(_xp_gained(run) / minutes, 0.1),
		"death_pos": [roundi(battle.player.position.x), roundi(battle.player.position.y)],
	}


## Total XP the run gathered: every finished level's cost plus the current bar.
func _xp_gained(run: Run) -> int:
	var total := run.xp
	for lv in range(1, run.level):
		total += run.curve.xp_to_next(lv)
	return total
