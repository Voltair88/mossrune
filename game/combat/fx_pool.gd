class_name FxPool
extends Node2D
## A fixed set of hit sparks, reused round-robin, so a hit creates no nodes.

const SIZE := 32
const SPARK_FPS := 24.0
## Lift the spark from the feet to the body.
const BODY_OFFSET := Vector2(0, -6)

var _sprites: Array[AnimatedSprite2D] = []
var _next: int = 0


func _ready() -> void:
	var frames := Strips.frames("fx", { &"spark": [SPARK_FPS, false] })
	for i in SIZE:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = frames
		s.visible = false
		s.animation_finished.connect(s.hide)
		add_child(s)
		_sprites.append(s)
	Events.enemy_hit.connect(_on_enemy_hit)


func _on_enemy_hit(pos: Vector2) -> void:
	var s := _sprites[_next]
	_next = (_next + 1) % SIZE
	s.position = pos + BODY_OFFSET
	s.visible = true
	s.play(&"spark")
	s.frame = 0
