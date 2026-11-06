extends GutTest
## Gems, hearts, XP and the session's level-ups.

const DT := 1.0 / 60

var arena: ArenaData
var feel: FeelTuning
var stats: PlayerStats
var slime: EnemyData
var curve: XpCurve


func before_all() -> void:
	arena = load("res://data/arenas/gym.tres") as ArenaData
	feel = load("res://data/tuning/feel.tres") as FeelTuning
	stats = load("res://data/tuning/player_stats.tres") as PlayerStats
	slime = load("res://data/enemies/slime.tres") as EnemyData
	curve = load("res://data/tuning/xp_curve.tres") as XpCurve


func _battle(drops: DropTable = null) -> Battle:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	return Battle.new(arena, stats, feel, rng, drops)


func _session(b: Battle) -> Session:
	var spawner := WaveSpawner.new(WaveSchedule.load_dir("res://data/waves"))
	return Session.new(
		Run.new(1, 600.0, curve),
		b,
		spawner,
		UpgradePool.load_dir("res://data/upgrades"),
		func(_id: StringName) -> void:
			pass,
	)


func test_merging_keeps_the_total_and_the_cap() -> void:
	var f := GemField.new(5)
	for i in 20:
		f.add(Vector2(i * 100, 0), 1)
	assert_eq(f.size(), 5)
	var total := 0
	for v in f.values:
		total += v
	assert_eq(total, 20, "no XP lost to merging")


func test_collect_takes_within_reach_and_pulls_within_range() -> void:
	var f := GemField.new(10)
	f.add(Vector2(3, 0), 2)
	f.add(Vector2(30, 0), 5)
	f.add(Vector2(300, 0), 7)
	assert_eq(f.collect(Vector2.ZERO, 40.0, 4.0, DT), 2)
	assert_lt(f.positions[0].x, 30.0, "the gem in range flies in")
	assert_eq(f.positions[1].x, 300.0, "the far gem stays")


func test_one_big_pickup_gains_several_levels() -> void:
	var run := Run.new(1, 600.0, curve)
	var need := curve.xp_to_next(1) + curve.xp_to_next(2)
	assert_eq(run.add_xp(need + 1), 2)
	assert_eq(run.level, 3)
	assert_eq(run.xp, 1)


func test_a_kill_drops_a_gem_that_comes_back_as_xp() -> void:
	var b := _battle()
	var e := b.spawn(slime, b.player.position + Vector2(80, 0))
	e.machine.go(EnemyBrain.DEAD)
	b.step(DT, Vector2.ZERO)
	assert_eq(b.gems.size(), 1)
	assert_eq(b.take_xp(), 0, "not picked up yet")
	b.player.position = b.gems.positions[0]
	b.step(DT, Vector2.ZERO)
	assert_eq(b.take_xp(), slime.xp)
	assert_eq(b.take_xp(), 0, "taken once")


func test_a_heart_heals_but_not_past_max() -> void:
	var drops := DropTable.new()
	drops.heart_chance = 1.0
	var b := _battle(drops)
	b.player.health.hp = stats.max_hp - 5
	var e := b.spawn(slime, b.player.position + Vector2(80, 0))
	e.machine.go(EnemyBrain.DEAD)
	b.step(DT, Vector2.ZERO)
	b.player.position = b.hearts.positions[0]
	b.step(DT, Vector2.ZERO)
	assert_eq(b.player.health.hp, stats.max_hp)
	assert_eq(b.hearts.size(), 0)


func test_regen_heals_over_time() -> void:
	var s := stats.duplicate() as PlayerStats
	s.regen_per_sec = 2.0
	var b := _battle()
	b.player.set_stats(s, 0)
	b.player.health.hp = 50
	for i in 61:
		b.step(DT, Vector2.ZERO)
	assert_eq(b.player.health.hp, 52)


func test_the_attack_pose_ends_by_the_cooldown() -> void:
	var s := stats.duplicate() as PlayerStats
	s.attack_cooldown_sec = s.attack_sec / 2
	var b := _battle()
	b.player.set_stats(s, 0)
	b.player.buffer.press()
	b.step(DT, Vector2.ZERO)
	for i in roundi(s.attack_cooldown_sec / DT) + 2:
		b.step(DT, Vector2.ZERO)
	assert_ne(b.player.machine.state, PlayerBrain.ATTACK, "fast swings don't lock the pose")


func test_two_levels_give_two_offers_in_turn() -> void:
	var b := _battle()
	var s := _session(b)
	var levels: Array[int] = []
	var on_level := func(level: int, _offer: Array[UpgradeData]) -> void:
		levels.append(level)
	Events.level_up.connect(on_level)
	s.pending_levels = s.run.add_xp(curve.xp_to_next(1) + curve.xp_to_next(2))
	s.next_offer()
	assert_true(s.is_waiting())
	assert_true(s.choose(s.offer[0]))
	assert_false(s.is_waiting())
	s.next_offer()
	assert_true(s.choose(s.offer[0]))
	Events.level_up.disconnect(on_level)
	assert_eq(levels, [2, 3] as Array[int])
	assert_eq(s.pending_levels, 0)
	assert_eq(s.picks.size(), 2)


func test_choose_rejects_an_upgrade_not_offered() -> void:
	var b := _battle()
	var s := _session(b)
	s.pending_levels = 1
	s.next_offer()
	var outside: UpgradeData
	for u in s.pool.upgrades:
		if not s.offer.has(u):
			outside = u
	assert_false(s.choose(outside))
	assert_true(s.is_waiting(), "the offer stays open")
	assert_true(s.picks.is_empty())


func test_level_up_and_death_on_the_same_frame() -> void:
	# The pick still applies to a dead player without bringing it back.
	var b := _battle()
	var s := _session(b)
	b.player.health.hp = 0
	b.player.machine.go(PlayerBrain.DEAD)
	s.pending_levels = 1
	s.next_offer()
	var vigor := load("res://data/upgrades/vigor.tres") as UpgradeData
	s.offer = [vigor] as Array[UpgradeData]
	assert_true(s.choose(vigor))
	assert_false(b.player.is_alive(), "a heal doesn't revive")
