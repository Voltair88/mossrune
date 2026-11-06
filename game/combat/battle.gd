class_name Battle
extends RefCounted
## The fight without a scene: the player, every enemy, contact damage, the swing
## and the arena walls. One step() per physics frame. Nodes only draw it.

## Neighbour cells sized near the biggest enemy, so a query looks at few points.
const GRID_CELL := 32.0
## Enemies closer than this push apart.
const SEPARATION_PX := 16.0
const SEPARATION_STRENGTH := 120.0
## Largest enemy radius, so queries around a point don't miss a big enemy.
const MAX_ENEMY_RADIUS := 8.0
## Aim assist looks a little past the reach.
const ASSIST_REACH_FACTOR := 1.5
## A pickup is taken this far outside the player's body.
const PICKUP_REACH_PX := 4.0

var arena: ArenaData
var feel: FeelTuning
var player: PlayerBrain
var enemies: Array[EnemyBrain] = []
var rng: RandomNumberGenerator
var drops: DropTable
var gems: GemField
var hearts: GemField
## The enemy that hurt the player last, for the bot telemetry.
var last_hit_by: StringName = &""
## Microseconds spent on enemy logic in the last step (the AI budget is 2 ms).
var enemy_usec: int = 0
## Microseconds for the whole last step.
var step_usec: int = 0
var _grid: SpatialGrid
## Separation is refreshed for half the enemies each frame, alternating.
var _frame: int = 0
var _xp_banked: int = 0
## Hit flashes are at most 3 a second on the whole screen. Every enemy one swing
## hits flashes together, which counts as one flash.
var _flash_gap_left: float = 0.0
var _flash_swing: int = -1


func _init(
	arena_data: ArenaData,
	player_stats: PlayerStats,
	feel_tuning: FeelTuning,
	random: RandomNumberGenerator,
	drop_table: DropTable = null,
) -> void:
	arena = arena_data
	feel = feel_tuning
	rng = random
	drops = drop_table if drop_table != null else DropTable.new()
	gems = GemField.new(drops.gem_cap)
	hearts = GemField.new(drops.gem_cap)
	player = PlayerBrain.new(player_stats, feel, arena.player_start())
	_grid = SpatialGrid.new(arena.outer_rect(), GRID_CELL)


func spawn(data: EnemyData, pos: Vector2) -> EnemyBrain:
	var e := EnemyBrain.new(data, feel, pos, rng)
	enemies.append(e)
	return e


## move is the player's input direction. Returns true if an enemy was hit or the
## player was hurt this step, for hit-stop.
func step(delta: float, move: Vector2) -> bool:
	var step_start := Time.get_ticks_usec()
	_grid.clear()
	for e in enemies:
		_grid.insert(e.position)

	player.tick(delta, move, _assist_target())
	player.position = arena.resolve(player.position, player.stats.radius_px)

	_flash_gap_left = maxf(_flash_gap_left - delta, 0.0)
	_frame += 1
	var start := Time.get_ticks_usec()
	var hurt := false
	for i in enemies.size():
		var e := enemies[i]
		if (i + _frame) % 2 == 0:
			e.push = _separation(i)
		if e.tick(delta, player.position, e.push, rng):
			var reach := e.data.slam_radius_tiles * ArenaData.TILE + player.stats.radius_px
			if e.position.distance_to(player.position) <= reach:
				hurt = _hurt_player(e) or hurt
		e.position = arena.resolve(e.position, e.data.radius_px)
	enemy_usec = Time.get_ticks_usec() - start

	var hit := _swing_hits()
	hurt = _contact() or hurt
	_remove_dead()
	if player.is_alive():
		var reach := player.stats.radius_px + PICKUP_REACH_PX
		_xp_banked += gems.collect(player.position, player.pickup_px(), reach, delta)
		player.heal(hearts.collect(player.position, player.pickup_px(), reach, delta))
	step_usec = Time.get_ticks_usec() - step_start
	return hit or hurt


func _assist_target() -> Variant:
	var r := player.reach_px() * ASSIST_REACH_FACTOR
	var best := -1
	var best_d2 := INF
	for k in _grid.query(player.position, r):
		var i := _grid.found[k]
		var d2 := enemies[i].position.distance_squared_to(player.position)
		if enemies[i].is_alive() and d2 < best_d2:
			best = i
			best_d2 = d2
	return enemies[best].position if best >= 0 else null


func _separation(index: int) -> Vector2:
	var me := enemies[index].position
	var push := Vector2.ZERO
	for k in _grid.query(me, SEPARATION_PX):
		var i := _grid.found[k]
		if i == index:
			continue
		var away := me - enemies[i].position
		var d := away.length()
		if d > 0.0:
			push += away / d * (1.0 - d / SEPARATION_PX)
		else:
			push += Vector2.from_angle(index)
	return push * SEPARATION_STRENGTH


func _swing_hits() -> bool:
	if not player.swing_live():
		return false
	var hit := false
	var half_arc := deg_to_rad(player.stats.arc_deg) / 2
	for k in _grid.query(player.position, player.reach_px() + MAX_ENEMY_RADIUS):
		var e := enemies[_grid.found[k]]
		if not Swing.hits(
			player.position,
			player.aim,
			player.reach_px(),
			half_arc,
			e.position,
			e.data.radius_px,
		):
			continue
		if e.take_hit(player.stats.damage, player.position, player.swing_id):
			hit = true
			if _may_flash(player.swing_id):
				e.flash_left = feel.flash_sec
			Events.enemy_hit.emit(e.position)
	return hit


## One contact hit per frame at most: the strongest enemy touching the player.
func _contact() -> bool:
	if not player.is_alive() or player.health.invulnerable_left() > 0.0:
		return false
	var strongest := -1
	for k in _grid.query(player.position, player.stats.radius_px + MAX_ENEMY_RADIUS):
		var e := enemies[_grid.found[k]]
		var touch := e.data.radius_px + player.stats.radius_px
		if e.is_harmful() and e.position.distance_to(player.position) <= touch:
			if strongest < 0 or e.data.contact_damage > enemies[strongest].data.contact_damage:
				strongest = _grid.found[k]
	if strongest < 0:
		return false
	return _hurt_player(enemies[strongest])


func _hurt_player(e: EnemyBrain) -> bool:
	if not player.receive_hit(e.data.contact_damage, e.position):
		return false
	last_hit_by = e.data.id
	if _may_flash(-1):
		player.flash_left = feel.flash_sec
	return true


## swing is the swing that hit, or -1 for a hit on the player.
func _may_flash(swing: int) -> bool:
	if swing >= 0 and swing == _flash_swing:
		return true
	if _flash_gap_left > 0.0:
		return false
	_flash_gap_left = feel.flash_gap_sec
	_flash_swing = swing
	return true


## XP picked up since the last call.
func take_xp() -> int:
	var xp := _xp_banked
	_xp_banked = 0
	return xp


## Swap-remove, so removal doesn't shift the array. The dead drop their gem,
## and sometimes a heart.
func _remove_dead() -> void:
	var i := 0
	while i < enemies.size():
		var e := enemies[i]
		if e.is_alive():
			i += 1
		else:
			if e.data.xp > 0:
				gems.add(e.position, e.data.xp)
				if rng.randf() < drops.heart_chance:
					hearts.add(e.position, drops.heart_heal)
			enemies[i] = enemies[enemies.size() - 1]
			enemies.pop_back()
