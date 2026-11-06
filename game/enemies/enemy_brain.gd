class_name EnemyBrain
extends RefCounted
## One enemy's rules without a scene: chase, telegraph, attack, get knocked back.
## Battle ticks every enemy; the enemy node only draws it.

const SPAWN := &"spawn"
const CHASE := &"chase"
const WINDUP := &"windup"
const ATTACK := &"attack"
const RECOVER := &"recover"
const KNOCKBACK := &"knockback"
const DEAD := &"dead"
const MAX_DELTA := 0.1

var data: EnemyData
var feel: FeelTuning
var position: Vector2
var velocity: Vector2 = Vector2.ZERO
var health: Health
var machine: StateMachine
## The last player swing that hit this enemy (see PlayerBrain.swing_id).
var last_swing_hit: int = 0
var flash_left: float = 0.0
## Separation from nearby enemies, refreshed by Battle every other frame.
var push: Vector2 = Vector2.ZERO
## Where the enemy thinks the player is; refreshed after a reaction delay.
var _target: Vector2
var _retarget_left: float = 0.0
var _attack_dir: Vector2 = Vector2.RIGHT
var _knock_velocity: Vector2 = Vector2.ZERO
var _weave_phase: float = 0.0


func _init(
	enemy_data: EnemyData,
	feel_tuning: FeelTuning,
	start: Vector2,
	rng: RandomNumberGenerator,
) -> void:
	data = enemy_data
	feel = feel_tuning
	position = start
	_target = start
	_weave_phase = rng.randf() * TAU
	health = Health.new(data.hp)
	machine = StateMachine.new(
		SPAWN,
		{
			SPAWN: [CHASE, KNOCKBACK, DEAD],
			CHASE: [WINDUP, KNOCKBACK, DEAD],
			WINDUP: [ATTACK, KNOCKBACK, DEAD],
			ATTACK: [RECOVER, KNOCKBACK, DEAD],
			RECOVER: [CHASE, KNOCKBACK, DEAD],
			KNOCKBACK: [CHASE, DEAD],
			DEAD: [],
		},
	)


func is_alive() -> bool:
	return machine.state != DEAD


## True when touching this enemy hurts the player.
func is_harmful() -> bool:
	return machine.state != SPAWN and machine.state != DEAD


func speed_px() -> float:
	return data.speed_tiles * ArenaData.TILE


## separation is the push from nearby enemies, already scaled to px/s.
## Returns true on the frame a slam lands, so Battle can apply its damage.
func tick(
	delta: float,
	player_pos: Vector2,
	separation: Vector2,
	rng: RandomNumberGenerator,
) -> bool:
	var dt := minf(delta, MAX_DELTA)
	machine.tick(dt)
	flash_left = maxf(flash_left - dt, 0.0)
	_retarget_left -= dt
	if _retarget_left <= 0.0:
		_target = player_pos
		_retarget_left = rng.randf_range(data.reaction_min_sec, data.reaction_max_sec)
	var slammed := false
	var t := machine.time_in_state
	match machine.state:
		SPAWN:
			velocity = Vector2.ZERO
			if t >= feel.enemy_spawn_sec:
				machine.go(CHASE)
		CHASE:
			velocity = _chase_velocity() + separation
			var reach := data.attack_range_tiles * ArenaData.TILE
			var in_range := position.distance_to(player_pos) <= reach
			if (data.pattern == "lunge" or data.pattern == "slam") and in_range:
				machine.go(WINDUP)
				_attack_dir = (player_pos - position).normalized()
		WINDUP:
			velocity = separation
			if t >= data.windup_sec:
				machine.go(ATTACK)
				slammed = data.pattern == "slam"
		ATTACK:
			velocity = separation
			if data.pattern == "lunge":
				velocity = _attack_dir * data.lunge_tiles * ArenaData.TILE / data.attack_sec
			if t >= data.attack_sec:
				machine.go(RECOVER)
		RECOVER:
			velocity = separation
			if t >= data.recover_sec:
				machine.go(CHASE)
		KNOCKBACK:
			velocity = _knock_velocity
			if t >= feel.knockback_sec:
				machine.go(CHASE)
		DEAD:
			velocity = Vector2.ZERO
	position += velocity * dt
	return slammed


## Returns true if the hit landed.
func take_hit(damage: int, from: Vector2, swing: int) -> bool:
	if not is_alive() or swing == last_swing_hit:
		return false
	last_swing_hit = swing
	if not health.take(damage):
		return false
	flash_left = feel.flash_sec
	if health.is_dead():
		machine.go(DEAD)
		Events.enemy_killed.emit(data.id, position, data.xp)
		return true
	if data.speed_tiles > 0.0:
		var away := (position - from).normalized()
		_knock_velocity = away * feel.knockback_enemy_tiles * ArenaData.TILE / feel.knockback_sec
		machine.go(KNOCKBACK)
	return true


func _chase_velocity() -> Vector2:
	var to := _target - position
	if to.length_squared() < 1.0:
		return Vector2.ZERO
	var dir := to.normalized()
	var v := dir * speed_px()
	if data.pattern == "weave":
		var w := TAU * data.weave_hz
		var wave := cos(machine.time_in_state * w + _weave_phase)
		var side := wave * data.weave_tiles * ArenaData.TILE * w
		v += dir.orthogonal() * side
	return v
