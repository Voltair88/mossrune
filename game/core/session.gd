class_name Session
extends RefCounted
## The rules of a run above the fight: the clock, wave spawns, XP, level-ups and
## upgrade picks. The main scene and the bot simulation both drive it; it never
## touches nodes. Spawning goes through a callable, since only the caller knows
## what the player can see.

var run: Run
var battle: Battle
var spawner: WaveSpawner
var pool: UpgradePool
var base_stats: PlayerStats
## Levels gained and not yet offered.
var pending_levels: int = 0
var offer: Array[UpgradeData] = []
var picks: Array[StringName] = []
var _spawn: Callable
var _wave: int = -1
var _second: int = -1


func _init(
	the_run: Run,
	the_battle: Battle,
	wave_spawner: WaveSpawner,
	upgrade_pool: UpgradePool,
	spawn: Callable,
) -> void:
	run = the_run
	battle = the_battle
	spawner = wave_spawner
	pool = upgrade_pool
	base_stats = battle.player.stats
	_spawn = spawn


## Advances the clock by delta: spawns, wave and clock events, and the XP the
## battle picked up.
func tick(delta: float) -> void:
	var t0 := run.elapsed
	run.elapsed += delta
	for i in spawner.due(t0, run.elapsed):
		_spawn.call(spawner.pick_enemy(run.elapsed, run.rng))
	var wave := spawner.wave_index_at(run.elapsed)
	if wave != _wave:
		_wave = wave
		Events.wave_started.emit(wave + 1)
	if run.seconds() != _second:
		_second = run.seconds()
		Events.time_changed.emit(_second)
	var xp := battle.take_xp()
	if xp > 0:
		pending_levels += run.add_xp(xp)
		Events.xp_collected.emit(run.xp, run.xp_needed())


func is_waiting() -> bool:
	return not offer.is_empty()


## Makes the offer for the next pending level and announces it.
func next_offer() -> void:
	pending_levels -= 1
	offer = pool.offer(run.rng)
	Events.level_up.emit(run.level - pending_levels, offer)


## Applies a pick from the current offer. Returns false for anything else.
func choose(u: UpgradeData) -> bool:
	if not offer.has(u):
		return false
	offer.clear()
	pool.take(u)
	picks.append(u.id)
	battle.player.set_stats(pool.stats_from(base_stats), u.heal)
	return true
