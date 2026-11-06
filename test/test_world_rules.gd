extends GutTest
## Arena collision, spawn positions (R8), the wave spawner and the data files.

const SEEDS := 500
const VIEW_SIZE := Vector2(640, 360)
const RADIUS := 7.0

var arena: ArenaData


func before_all() -> void:
	arena = load("res://data/arenas/ruin.tres") as ArenaData


func _view_at(player: Vector2) -> Rect2:
	# The camera is clamped to the arena, like Camera2D limits.
	var outer := arena.outer_rect()
	var pos := (player - VIEW_SIZE / 2).clamp(outer.position, outer.end - VIEW_SIZE)
	return Rect2(pos, VIEW_SIZE)


func test_resolve_keeps_circles_out_of_walls_and_blocks() -> void:
	var p := arena.resolve(Vector2(-50, -50), RADIUS)
	assert_true(arena.is_free(p, RADIUS - 0.01), "pushed inside the walls")
	var pillar := Vector2(12.5, 8.5) * ArenaData.TILE
	assert_true(
		arena.is_free(arena.resolve(pillar, RADIUS), RADIUS - 0.01),
		"pushed out of a pillar",
	)
	var free := Vector2(5, 5) * ArenaData.TILE
	assert_eq(arena.resolve(free, RADIUS), free, "free space untouched")


func test_spawns_are_off_screen_and_never_in_a_wall() -> void:
	# R8, including the arena corners.
	var rng := RandomNumberGenerator.new()
	var inner := arena.inner_rect()
	var spots: Array[Vector2] = [
		inner.position,
		inner.end,
		Vector2(inner.end.x, inner.position.y),
		Vector2(inner.position.x, inner.end.y),
		arena.player_start(),
	]
	var bad := 0
	for s in SEEDS:
		rng.seed = s
		var player: Vector2 = spots[s % spots.size()]
		if s % 3 == 0:
			player = inner.position + Vector2(rng.randf(), rng.randf()) * inner.size
		var view := _view_at(player)
		var heading := Vector2.ZERO if s % 2 == 0 else Vector2.from_angle(rng.randf() * TAU)
		var p := SpawnPicker.pick(rng, arena, view, heading, RADIUS)
		if view.has_point(p) or not arena.is_free(p, RADIUS - 0.01):
			bad += 1
	assert_eq(bad, 0, "spawns on screen or in a wall")


func test_spawns_lean_toward_the_heading() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var view := _view_at(arena.player_start())
	var ahead := 0
	for i in 200:
		var p := SpawnPicker.pick(rng, arena, view, Vector2.RIGHT, RADIUS)
		if p.x > view.get_center().x:
			ahead += 1
	assert_gt(ahead, 140, "most spawns ahead")


func test_wave_spawner_releases_the_expected_count() -> void:
	var spawner := WaveSpawner.new(WaveSchedule.load_dir("res://data/waves"))
	var total := 0
	var t := 0.0
	var dt := 1.0 / 60
	while t < 60.0:
		total += spawner.due(t, t + dt)
		t += dt
	var expected := spawner.schedule.spawns_between(0.0, 60.0)
	assert_almost_eq(float(total), expected, 1.0)


func test_wave_spawner_picks_only_enemies_in_the_wave() -> void:
	var spawner := WaveSpawner.new(WaveSchedule.load_dir("res://data/waves"))
	var rng := RandomNumberGenerator.new()
	for i in 100:
		assert_eq(spawner.pick_enemy(10.0, rng), &"slime", "wave 1 is slimes")
	var seen := { }
	for i in 300:
		seen[spawner.pick_enemy(250.0, rng)] = true
	assert_eq(seen.size(), 3, "wave 5 has all three")
	assert_eq(spawner.wave_index_at(55.0), 0, "lull belongs to the wave before")


func test_every_data_file_loads_with_its_class() -> void:
	var expect := {
		"res://data/enemies": "EnemyData",
		"res://data/waves": "WaveData",
		"res://data/arenas": "ArenaData",
	}
	for dir: String in expect:
		var files := Array(DirAccess.get_files_at(dir)).filter(
			func(f: String) -> bool:
				return f.ends_with(".tres"),
		)
		assert_gt(files.size(), 0, dir)
		for f: String in files:
			var res: Resource = load(dir.path_join(f))
			assert_not_null(res, f)
			if res:
				assert_eq((res.get_script() as Script).get_global_name(), expect[dir], f)
	for f: String in ["feel.tres", "player_stats.tres", "xp_curve.tres"]:
		assert_not_null(load("res://data/tuning/" + f), f)


func test_enemy_files_are_named_after_their_id_and_sane() -> void:
	for f in DirAccess.get_files_at("res://data/enemies"):
		var e := load("res://data/enemies/" + f) as EnemyData
		assert_eq(String(e.id), f.get_basename())
		assert_gt(e.hp, 0, f)
		assert_gt(e.radius_px, 0.0, f)
		assert_true(e.radius_px <= Battle.MAX_ENEMY_RADIUS, f + " fits the query margin")
		assert_true(
			ResourceLoader.exists("res://assets/sprites/%s_%s.png" % [e.sheet, e.anim_move]),
			f,
		)
		for anim: StringName in [e.anim_windup, e.anim_attack]:
			if anim != &"":
				assert_true(
					ResourceLoader.exists("res://assets/sprites/%s_%s.png" % [e.sheet, anim]),
					f,
				)
