class_name PickupView
extends Node2D
## Draws the gems and hearts lying in a Battle, under the actors.

const GEM := preload("res://assets/sprites/items_gem.png")
const HEART := preload("res://assets/sprites/items_heart.png")

var battle: Battle
var _offset: Vector2


func _init(the_battle: Battle) -> void:
	battle = the_battle
	_offset = -GEM.get_size() / 2


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for p in battle.gems.positions:
		draw_texture(GEM, p + _offset)
	for p in battle.hearts.positions:
		draw_texture(HEART, p + _offset)
