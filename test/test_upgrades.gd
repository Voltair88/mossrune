extends GutTest
## Upgrade offers (R5, R6), stacking, the upgrade data, and every pair of
## upgrades together.

const UPGRADE_DIR := "res://data/upgrades"
const SEEDS := 500
const OFFERS_PER_SEED := 30
const DT := 1.0 / 60

var stats: PlayerStats


func before_all() -> void:
	stats = load("res://data/tuning/player_stats.tres") as PlayerStats


func _pool() -> UpgradePool:
	return UpgradePool.load_dir(UPGRADE_DIR)


func _ids(offer: Array[UpgradeData]) -> Array[StringName]:
	var out: Array[StringName] = []
	for u in offer:
		out.append(u.id)
	return out


func test_the_pool_has_eight_upgrades_and_a_filler() -> void:
	var pool := _pool()
	assert_eq(pool.upgrades.size(), 8)
	assert_not_null(pool.filler)


func test_offers_are_distinct_and_uncapped_over_500_seeds() -> void:
	# R5, with random picks so caps are reached along the way.
	for s in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var pool := _pool()
		for n in OFFERS_PER_SEED:
			var open := 0
			for u in pool.upgrades:
				if pool.count(u) < u.cap:
					open += 1
			var offer := pool.offer(rng)
			var ids := _ids(offer)
			assert_eq(
				offer.size(),
				UpgradePool.OFFER_SIZE if open >= UpgradePool.OFFER_SIZE else open + 1,
			)
			for u in offer:
				assert_eq(ids.count(u.id), 1, "seed %d: %s offered twice" % [s, u.id])
				if not u.filler:
					assert_lt(pool.count(u), u.cap, "seed %d: %s offered at its cap" % [s, u.id])
			if open >= UpgradePool.OFFER_SIZE:
				assert_false(offer.has(pool.filler), "seed %d: filler with 3 open" % s)
			pool.take(offer[rng.randi_range(0, offer.size() - 1)])


func test_no_more_than_three_offers_in_a_row_without_damage() -> void:
	# R6: make damage upgrades very unlikely, so only the pity rule brings them.
	for s in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var pool := _pool()
		var weighted: Array[UpgradeData] = []
		for u in pool.upgrades:
			var copy := u.duplicate() as UpgradeData
			copy.weight = 0.001 if copy.raises_damage else 1.0
			weighted.append(copy)
		pool.upgrades = weighted
		var dry := 0
		for n in OFFERS_PER_SEED:
			var offer := pool.offer(rng)
			if offer.any(
				func(u: UpgradeData) -> bool:
					return u.raises_damage,
			):
				dry = 0
			else:
				dry += 1
			assert_lte(dry, UpgradePool.PITY_AFTER, "seed %d offer %d" % [s, n])
			# Picks avoid damage, so the dry spells are as long as they get.
			for u in offer:
				if not u.raises_damage:
					pool.take(u)
					break


func test_with_one_upgrade_left_the_offer_is_it_and_the_filler() -> void:
	var pool := _pool()
	for u: UpgradeData in pool.upgrades.slice(1):
		pool.counts[u.id] = u.cap
	var offer := pool.offer(RandomNumberGenerator.new())
	assert_eq(_ids(offer), [pool.upgrades[0].id, pool.filler.id])


func test_with_everything_capped_only_the_filler_is_offered() -> void:
	var pool := _pool()
	for u in pool.upgrades:
		pool.counts[u.id] = u.cap
	assert_eq(_ids(pool.offer(RandomNumberGenerator.new())), [pool.filler.id])
	pool.take(pool.filler)
	assert_false(pool.counts.has(pool.filler.id), "the filler is not counted")


func test_stacks_change_the_stats() -> void:
	var pool := _pool()
	var by_id := { }
	for u in pool.upgrades:
		by_id[u.id] = u
	pool.take(by_id[&"edge"])
	pool.take(by_id[&"edge"])
	pool.take(by_id[&"sweep"])
	pool.take(by_id[&"vigor"])
	pool.take(by_id[&"tempo"])
	var s := pool.stats_from(stats)
	assert_eq(s.damage, roundi(stats.damage * 1.4))
	assert_almost_eq(s.arc_deg, stats.arc_deg + 30.0, 0.001)
	assert_eq(s.max_hp, stats.max_hp + 20)
	assert_almost_eq(s.attack_cooldown_sec, stats.attack_cooldown_sec * 0.88, 0.0001)
	assert_eq(stats.damage, 10, "the base stats are untouched")


func test_upgrade_data_is_complete_and_uses_font_glyphs() -> void:
	var pool := _pool()
	var all: Array[UpgradeData] = pool.upgrades.duplicate()
	all.append(pool.filler)
	var stat_names := { }
	for p: Dictionary in stats.get_property_list():
		stat_names[StringName(p.name)] = true
	for u: UpgradeData in all:
		assert_ne(u.id, &"", "id")
		assert_not_null(u.icon, String(u.id) + " icon")
		for text: String in [u.title, u.text]:
			assert_ne(text, "", String(u.id) + " text")
			for c: int in text.to_utf8_buffer():
				assert_between(c, 32, 95, "%s: %s outside the font" % [u.id, text])
		if not u.filler:
			assert_true(stat_names.has(u.stat), "%s raises %s" % [u.id, u.stat])
			assert_gt(u.cap, 0, String(u.id) + " cap")
			assert_gt(u.weight, 0.0, String(u.id) + " weight")


func test_every_pair_of_capped_upgrades_gives_a_working_player() -> void:
	# The interaction matrix: each pair at its cap, then everything at its cap.
	var pool := _pool()
	var sets: Array = []
	for i in pool.upgrades.size():
		for j in range(i + 1, pool.upgrades.size()):
			sets.append([pool.upgrades[i], pool.upgrades[j]])
	sets.append(pool.upgrades)
	for combo: Array in sets:
		var p := UpgradePool.load_dir(UPGRADE_DIR)
		for u: UpgradeData in combo:
			p.counts[u.id] = u.cap
		var s := p.stats_from(stats)
		var label := ", ".join(
			combo.map(
				func(u: UpgradeData) -> String:
					return u.id,
			)
		)
		assert_gt(s.attack_cooldown_sec, 0.0, label)
		assert_gt(s.damage, 0, label)
		assert_lte(s.arc_deg, 360.0, label)
		assert_gt(s.max_hp, 0, label)
		assert_true(is_finite(s.speed_tiles) and s.speed_tiles > 0.0, label)
		# A swing still starts, ends and starts again.
		var brain := PlayerBrain.new(
			s,
			load("res://data/tuning/feel.tres") as FeelTuning,
			Vector2.ZERO,
		)
		var swings := 0
		for f in 120:
			brain.buffer.press()
			var before := brain.swing_id
			brain.tick(DT, Vector2.ZERO, null)
			if brain.swing_id != before:
				swings += 1
		assert_gt(swings, 1, label + " swings again")
