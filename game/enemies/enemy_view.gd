class_name EnemyView
extends Node2D
## Draws an EnemyBrain and frees itself when the enemy dies.

const MOVE_FPS := 6.0
const POSE_FPS := 1.0
const FEET_OFFSET := Vector2(0, -8)
const LABEL_OFFSET := Vector2(-16, -24)
const FLASH := preload("res://game/combat/hit_flash_material.tres")
## A spawning enemy is drawn faded until it can move and hurt.
const SPAWN_ALPHA := 0.5

var brain: EnemyBrain
var _body: AnimatedSprite2D
var _label: Label
var _anim_for_state: Dictionary[StringName, StringName] = { }


func _init(enemy_brain: EnemyBrain) -> void:
	brain = enemy_brain
	position = brain.position
	var d := brain.data
	var anims := { d.anim_move: [MOVE_FPS, true] }
	var windup := d.anim_move
	var attack := d.anim_move
	if d.anim_windup != &"":
		anims[d.anim_windup] = [POSE_FPS, false]
		windup = d.anim_windup
	if d.anim_attack != &"":
		anims[d.anim_attack] = [POSE_FPS, false]
		attack = d.anim_attack
	for s: StringName in [
		EnemyBrain.SPAWN,
		EnemyBrain.CHASE,
		EnemyBrain.RECOVER,
		EnemyBrain.KNOCKBACK,
		EnemyBrain.DEAD,
	]:
		_anim_for_state[s] = d.anim_move
	_anim_for_state[EnemyBrain.WINDUP] = windup
	_anim_for_state[EnemyBrain.ATTACK] = attack
	_body = AnimatedSprite2D.new()
	_body.sprite_frames = Strips.frames(d.sheet, anims)
	_body.offset = FEET_OFFSET
	_body.play(d.anim_move)
	add_child(_body)
	if DebugArgs.current.show_states:
		_label = Label.new()
		_label.position = LABEL_OFFSET
		add_child(_label)


func _process(_delta: float) -> void:
	if not brain.is_alive():
		queue_free()
		return
	position = brain.position
	var anim := _anim_for_state[brain.machine.state]
	if _body.animation != anim:
		_body.play(anim)
	if brain.velocity.x != 0.0:
		_body.flip_h = brain.velocity.x < 0.0
	_body.material = FLASH if brain.flash_left > 0.0 and GameSettings.flashes else null
	_body.modulate.a = SPAWN_ALPHA if brain.machine.state == EnemyBrain.SPAWN else 1.0
	if _label:
		_label.text = brain.machine.state
