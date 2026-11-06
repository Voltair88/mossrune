class_name PlayerView
extends Node2D
## Draws a PlayerBrain: animation by state, facing, hit flash, blinking while
## invulnerable, and the swing arc. Holds the camera.

const IDLE_FPS := 2.0
const WALK_FPS := 8.0
## Three frames over the 0.25 s attack pose.
const ATTACK_FPS := 12.0
const ANIMS := {
	&"idle": [IDLE_FPS, true],
	&"walk": [WALK_FPS, true],
	&"attack": [ATTACK_FPS, false],
	&"hurt": [1.0, false],
}
const ANIM_FOR_STATE := {
	PlayerBrain.IDLE: &"idle",
	PlayerBrain.MOVE: &"walk",
	PlayerBrain.ATTACK: &"attack",
	PlayerBrain.HURT: &"hurt",
	PlayerBrain.DEAD: &"hurt",
}
const SWING_FPS := ATTACK_FPS
## Sprites stand on their origin: the frame's bottom edge sits at the feet.
const FEET_OFFSET := Vector2(0, -8)
const SWING_OFFSET := Vector2(0, -6)
const LABEL_OFFSET := Vector2(-16, -28)
const FLASH := preload("res://game/combat/hit_flash_material.tres")
const BLINK_DUTY := 0.5

var brain: PlayerBrain
var camera: ShakeCamera
var _body: AnimatedSprite2D
var _swing: AnimatedSprite2D
var _label: Label
var _shown_swing: int = 0


func _init(player_brain: PlayerBrain, feel: FeelTuning) -> void:
	brain = player_brain
	position = brain.position
	_body = AnimatedSprite2D.new()
	_body.sprite_frames = Strips.frames("player", ANIMS)
	_body.offset = FEET_OFFSET
	_body.play(&"idle")
	add_child(_body)
	_swing = AnimatedSprite2D.new()
	_swing.sprite_frames = Strips.frames("fx", { &"swing": [SWING_FPS, false] })
	_swing.position = SWING_OFFSET
	_swing.visible = false
	add_child(_swing)
	camera = ShakeCamera.new()
	camera.feel = feel
	add_child(camera)
	if DebugArgs.current.show_states:
		_label = Label.new()
		_label.position = LABEL_OFFSET
		add_child(_label)


func _process(_delta: float) -> void:
	position = brain.position
	var state := brain.machine.state
	var anim: StringName = ANIM_FOR_STATE[state]
	if _body.animation != anim:
		_body.play(anim)
	var look := brain.aim if state == PlayerBrain.ATTACK else brain.facing
	if look.x != 0.0:
		_body.flip_h = look.x < 0.0
	_body.material = FLASH if brain.flash_left > 0.0 else null
	var invulnerable := brain.health.invulnerable_left()
	_body.visible = (
		state == PlayerBrain.DEAD or invulnerable <= 0.0
		or fmod(invulnerable * brain.feel.blink_hz, 1.0) < BLINK_DUTY
	)
	if brain.swing_id != _shown_swing and state == PlayerBrain.ATTACK:
		_shown_swing = brain.swing_id
		_swing.rotation = brain.aim.angle()
		_swing.visible = true
		_swing.play(&"swing")
		_swing.frame = 0
	elif state != PlayerBrain.ATTACK:
		_swing.visible = false
	if _label:
		_label.text = state
