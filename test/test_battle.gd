extends GutTest
## The fight without scenes: swing, contact, knockback, separation and the
## adversarial cases from the plan.

const DT := 1.0 / 60

var arena: ArenaData
var feel: FeelTuning
var stats: PlayerStats
var slime: EnemyData
var dummy: EnemyData


func before_all() -> void:
	arena = load("res://data/arenas/gym.tres") as ArenaData
	feel = load("res://data/tuning/feel.tres") as FeelTuning
	stats = load("res://data/tuning/player_stats.tres") as PlayerStats
	slime = load("res://data/enemies/slime.tres") as EnemyData
	dummy = load("res://data/enemies/dummy.tres") as EnemyData


func _battle(run_seed: int = 1) -> Battle:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	return Battle.new(arena, stats, feel, rng)


func _run(b: Battle, seconds: float, move: Vector2 = Vector2.ZERO) -> void:
	for i in roundi(seconds / DT):
		b.step(DT, move)


func test_player_moves_at_its_speed_and_diagonals_are_not_faster() -> void:
	var b := _battle()
	var start := b.player.position
	_run(b, 0.5, Vector2(1, 1))
	var expected := stats.speed_tiles * ArenaData.TILE * 0.5
	assert_almost_eq(b.player.position.distance_to(start), expected, 1.0)


func test_one_swing_hits_an_enemy_once_and_two_swings_kill_a_slime() -> void:
	var b := _battle()
	var e := b.spawn(slime, b.player.position + Vector2(16, 0))
	e.machine.go(EnemyBrain.CHASE)
	b.player.buffer.press()
	_run(b, stats.attack_sec)
	assert_eq(e.health.hp, slime.hp - stats.damage, "one hit per swing")
	_run(b, stats.attack_cooldown_sec)
	b.player.buffer.press()
	_run(b, stats.attack_sec)
	assert_false(e.is_alive(), "two hits kill")
	assert_eq(b.enemies.size(), 0, "removed")


func test_two_kills_on_the_same_frame() -> void:
	var b := _battle()
	var kills := [0]
	var count := func(_id: StringName, _pos: Vector2, _xp: int) -> void:
		kills[0] += 1
	Events.enemy_killed.connect(count)
	for dy: int in [-6, 6]:
		var e := b.spawn(dummy, b.player.position + Vector2(14, dy))
		e.health.hp = 1
	b.player.buffer.press()
	b.step(DT, Vector2.ZERO)
	Events.enemy_killed.disconnect(count)
	assert_eq(kills[0], 2)
	assert_eq(b.enemies.size(), 0)


func test_contact_hurts_once_then_invulnerability() -> void:
	var b := _battle()
	for i in 3:
		var e := b.spawn(slime, b.player.position)
		e.machine.go(EnemyBrain.CHASE)
	b.step(DT, Vector2.ZERO)
	assert_eq(b.player.health.hp, stats.max_hp - slime.contact_damage, "three touching, one hit")
	assert_eq(b.player.machine.state, PlayerBrain.HURT)


func test_spawning_enemies_are_harmless() -> void:
	var b := _battle()
	b.spawn(slime, b.player.position)
	b.step(DT, Vector2.ZERO)
	assert_eq(b.player.health.hp, stats.max_hp)


func test_god_mode_takes_no_damage() -> void:
	var b := _battle()
	b.player.god = true
	var e := b.spawn(slime, b.player.position)
	e.machine.go(EnemyBrain.CHASE)
	_run(b, 2.0)
	assert_eq(b.player.health.hp, stats.max_hp)


func test_hurt_always_ends_over_500_seeds() -> void:
	var stuck := 0
	for s in 500:
		var b := _battle(s)
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		for i in 1 + rng.randi() % 4:
			var e := b.spawn(
				slime,
				b.player.position + Vector2.from_angle(rng.randf() * TAU) * 30.0,
			)
			e.machine.go(EnemyBrain.CHASE)
		var hurt_time := 0.0
		for f in 180:
			if rng.randf() < 0.1:
				b.player.buffer.press()
			b.step(DT, Vector2.from_angle(rng.randf() * TAU))
			hurt_time = hurt_time + DT if b.player.machine.state == PlayerBrain.HURT else 0.0
			if hurt_time > feel.hurt_sec + DT * 2:
				stuck += 1
				break
	assert_eq(stuck, 0, "hurt state that never ended")


func test_crowd_keeps_apart_over_seeds() -> void:
	# Separation: a crowd chasing a still player doesn't collapse into one point.
	var worst := INF
	for s in 20:
		var b := _battle(s)
		b.player.god = true
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		for i in 30:
			var e := b.spawn(
				slime,
				b.player.position + Vector2(rng.randf_range(-120, 120), rng.randf_range(-80, 80)),
			)
			e.machine.go(EnemyBrain.CHASE)
		_run(b, 4.0)
		var total := 0.0
		for e in b.enemies:
			var nearest := INF
			for o in b.enemies:
				if o != e:
					nearest = minf(nearest, e.position.distance_to(o.position))
			total += nearest
		worst = minf(worst, total / b.enemies.size())
	assert_gt(worst, 6.0, "mean nearest-neighbour distance in px")


func test_slime_telegraphs_before_it_lunges() -> void:
	var b := _battle()
	b.player.god = true
	var e := b.spawn(slime, b.player.position + Vector2(48, 0))
	e.machine.go(EnemyBrain.CHASE)
	var seen: Array[StringName] = []
	for i in 60:
		b.step(DT, Vector2.ZERO)
		if seen.is_empty() or seen[-1] != e.machine.state:
			seen.append(e.machine.state)
	assert_eq(
		seen.slice(0, 4),
		[EnemyBrain.CHASE, EnemyBrain.WINDUP, EnemyBrain.ATTACK, EnemyBrain.RECOVER],
	)


func test_zero_and_huge_deltas_keep_everyone_inside() -> void:
	var b := _battle()
	var e := b.spawn(slime, b.player.position + Vector2(40, 0))
	e.machine.go(EnemyBrain.CHASE)
	b.step(0.0, Vector2.RIGHT)
	b.step(10.0, Vector2.RIGHT)
	assert_true(arena.is_free(b.player.position, stats.radius_px - 0.01), "player inside")
	for x in b.enemies:
		assert_true(arena.is_free(x.position, x.data.radius_px - 0.01), "enemy inside")


func test_buffered_attack_fires_when_the_cooldown_ends() -> void:
	var b := _battle()
	b.player.buffer.press()
	b.step(DT, Vector2.ZERO)
	var first := b.player.swing_id
	_run(b, stats.attack_cooldown_sec - 0.1)
	b.player.buffer.press()
	_run(b, 0.12)
	assert_eq(b.player.swing_id, first + 1, "the press 0.1 s early still swung")


func test_hit_flashes_stay_at_three_a_second_with_capped_tempo() -> void:
	var times := _flash_times(feel)
	for k in range(1, times.size()):
		assert_gte(times[k] - times[k - 1], feel.flash_gap_sec - DT, "gap %d" % k)
	assert_between(times.size(), 7, 9, "flashes in 3 s: still about 3 a second")


func test_without_the_gap_capped_tempo_flashes_five_times_a_second() -> void:
	var no_gap := feel.duplicate() as FeelTuning
	no_gap.flash_gap_sec = 0.0
	assert_gt(_flash_times(no_gap).size(), 12, "the probe can see a too-fast flash")


## Swings as fast as capped Tempo allows into a ring of dummies for 3 s. Returns
## when each swing that made a flash first flashed.
func _flash_times(tuning: FeelTuning) -> Array[float]:
	var fast := stats.duplicate() as PlayerStats
	fast.attack_cooldown_sec = 0.2
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var b := Battle.new(arena, fast, tuning, rng)
	for i in 8:
		var e := b.spawn(dummy, b.player.position + Vector2.from_angle(i * TAU / 8) * 14)
		e.health.hp = 10000
	var times: Array[float] = []
	var flashed := { }
	for i in roundi(3.0 / DT):
		b.player.buffer.press()
		b.step(DT, Vector2.ZERO)
		for e in b.enemies:
			if e.flash_left == tuning.flash_sec and not flashed.has(b.player.swing_id):
				flashed[b.player.swing_id] = true
				times.append((i + 1) * DT)
	return times
