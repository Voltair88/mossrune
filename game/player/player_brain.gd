class_name PlayerBrain
extends RefCounted
## The player's rules without a scene: movement, the swing, getting hurt.
## The player node feeds it input and draws what it says.

const IDLE := &"idle"
const MOVE := &"move"
const ATTACK := &"attack"
const HURT := &"hurt"
const DEAD := &"dead"
## A frame longer than this is clamped, so a hitch can't move through a wall.
const MAX_DELTA := 0.1

var stats: PlayerStats
var feel: FeelTuning
var position: Vector2
var facing: Vector2 = Vector2.RIGHT
## Direction of the current swing.
var aim: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO
var health: Health
var machine: StateMachine
var buffer: InputBuffer
## Counts swings. An enemy remembers the last swing that hit it, so a swing hits
## each enemy once even though the arc is live for several frames.
var swing_id: int = 0
var god: bool = false
var flash_left: float = 0.0
var _cooldown_left: float = 0.0
var _knock_velocity: Vector2 = Vector2.ZERO
var _regen: float = 0.0


func _init(player_stats: PlayerStats, feel_tuning: FeelTuning, start: Vector2) -> void:
	stats = player_stats
	feel = feel_tuning
	position = start
	health = Health.new(stats.max_hp, feel.invulnerable_sec)
	buffer = InputBuffer.new(feel.input_buffer_sec)
	machine = StateMachine.new(
		IDLE,
		{
			IDLE: [MOVE, ATTACK, HURT, DEAD],
			MOVE: [IDLE, ATTACK, HURT, DEAD],
			ATTACK: [IDLE, MOVE, HURT, DEAD],
			HURT: [IDLE, MOVE, HURT, DEAD],
			DEAD: [],
		},
	)


func is_alive() -> bool:
	return machine.state != DEAD


func reach_px() -> float:
	return stats.reach_tiles * ArenaData.TILE


## True while the arc of the current swing can still hit.
func swing_live() -> bool:
	return machine.state == ATTACK and machine.time_in_state <= stats.swing_active_sec


## move is the stick or key direction, length up to 1. assist_target is the
## nearest enemy (or null), used to bend a new swing toward it.
func tick(delta: float, move: Vector2, assist_target: Variant = null) -> void:
	var dt := minf(delta, MAX_DELTA)
	health.tick(dt)
	machine.tick(dt)
	buffer.tick(dt)
	_cooldown_left = maxf(_cooldown_left - dt, 0.0)
	flash_left = maxf(flash_left - dt, 0.0)
	move = move.limit_length(1.0)
	if move != Vector2.ZERO:
		facing = move.normalized()
	_tick_regen(dt)

	match machine.state:
		DEAD:
			velocity = Vector2.ZERO
			return
		HURT:
			velocity = _knock_velocity
			if machine.time_in_state >= feel.hurt_sec:
				machine.go(IDLE)
		ATTACK:
			velocity = move * stats.speed_tiles * ArenaData.TILE * stats.attack_move_factor
			# Tempo can bring the cooldown under the pose; the pose then ends with it.
			if machine.time_in_state >= minf(stats.attack_sec, stats.attack_cooldown_sec):
				machine.go(IDLE)

	if machine.state == IDLE or machine.state == MOVE:
		if _cooldown_left <= 0.0 and buffer.consume():
			_start_swing(assist_target)
			velocity = move * stats.speed_tiles * ArenaData.TILE * stats.attack_move_factor
		else:
			var next := MOVE if move != Vector2.ZERO else IDLE
			if machine.state != next:
				machine.go(next)
			velocity = move * stats.speed_tiles * ArenaData.TILE
	position += velocity * dt


## Returns true if the hit landed. from is where the hit came from.
func receive_hit(damage: int, from: Vector2) -> bool:
	if god or not health.take(damage):
		return false
	flash_left = feel.flash_sec
	if health.is_dead():
		machine.go(DEAD)
		Events.player_died.emit()
	else:
		machine.go(HURT)
		var away := (position - from).normalized()
		if away == Vector2.ZERO:
			away = -facing
		_knock_velocity = away * feel.knockback_player_tiles * ArenaData.TILE / feel.hurt_sec
	Events.player_hit.emit(health.hp, health.max_hp)
	return true


func _start_swing(assist_target: Variant) -> void:
	machine.go(ATTACK)
	swing_id += 1
	_cooldown_left = stats.attack_cooldown_sec
	aim = facing
	if assist_target is Vector2:
		aim = Swing.assist(position, facing, assist_target, deg_to_rad(feel.aim_assist_deg) / 2)


func heal(amount: int) -> void:
	if not is_alive() or amount <= 0 or health.hp >= health.max_hp:
		return
	health.heal(amount)
	Events.player_healed.emit(health.hp, health.max_hp)


## Swaps in rebuilt stats (after an upgrade) and heals by heal_amount.
func set_stats(new_stats: PlayerStats, heal_amount: int) -> void:
	stats = new_stats
	health.max_hp = stats.max_hp
	health.hp = mini(health.hp, health.max_hp)
	if is_alive():
		health.heal(heal_amount)
	Events.player_healed.emit(health.hp, health.max_hp)


func pickup_px() -> float:
	return stats.pickup_radius_tiles * ArenaData.TILE


func _tick_regen(dt: float) -> void:
	if stats.regen_per_sec <= 0.0 or health.hp >= health.max_hp:
		_regen = 0.0
		return
	_regen += stats.regen_per_sec * dt
	if _regen >= 1.0:
		var whole := floori(_regen)
		_regen -= whole
		heal(whole)
