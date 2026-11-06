class_name BattleView
extends Node2D
## Runs a Battle each physics frame and draws it: arena, player, enemies, sparks,
## hit-stop and screenshake. The gym and the main scene both use it.

const FEEL_PATH := "res://data/tuning/feel.tres"
const STATS_PATH := "res://data/tuning/player_stats.tres"
const ENEMY_DIR := "res://data/enemies"
## The circle bot runs around the arena centre at this distance and swings
## this often.
const BOT_CIRCLE_RADIUS := 96.0
const BOT_SWING_SEC := 0.3

var arena: ArenaData
var battle: Battle
var feel: FeelTuning
var enemy_data: Dictionary[StringName, EnemyData] = { }
var player_view: PlayerView
var bot: StringName = &""
var _actors: Node2D
var _freeze_left: float = 0.0
var _bot_time: float = 0.0


func start(arena_data: ArenaData, rng: RandomNumberGenerator) -> void:
	arena = arena_data
	feel = load(FEEL_PATH) as FeelTuning
	for f in DirAccess.get_files_at(ENEMY_DIR):
		if f.ends_with(".tres"):
			var d := load(ENEMY_DIR.path_join(f)) as EnemyData
			enemy_data[d.id] = d
	battle = Battle.new(arena, load(STATS_PATH) as PlayerStats, feel, rng)

	var floor_layer := TileMapLayer.new()
	add_child(floor_layer)
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	add_child(_actors)
	ArenaView.build(arena, floor_layer, _actors)
	add_child(FxPool.new())

	player_view = PlayerView.new(battle.player, feel)
	_actors.add_child(player_view)
	var outer := arena.outer_rect()
	player_view.camera.limit_left = int(outer.position.x)
	player_view.camera.limit_top = int(outer.position.y)
	player_view.camera.limit_right = int(outer.end.x)
	player_view.camera.limit_bottom = int(outer.end.y)
	player_view.camera.make_current()
	# Place the camera now, so spawns made before the first frame see the real view.
	player_view.camera.force_update_scroll()

	Events.player_hit.connect(_on_player_hit)
	Events.enemy_killed.connect(_on_enemy_killed)


func spawn(enemy_id: StringName, pos: Vector2) -> EnemyBrain:
	assert(enemy_data.has(enemy_id), "no enemy " + enemy_id)
	var brain := battle.spawn(enemy_data[enemy_id], pos)
	_actors.add_child(EnemyView.new(brain))
	return brain


## Spawns where the player can't see it.
func spawn_offscreen(enemy_id: StringName) -> EnemyBrain:
	var d := enemy_data[enemy_id]
	var pos := SpawnPicker.pick(
		battle.rng,
		arena,
		view_rect(),
		battle.player.velocity.normalized(),
		d.radius_px,
	)
	return spawn(enemy_id, pos)


func view_rect() -> Rect2:
	var size := get_viewport_rect().size
	return Rect2(player_view.camera.get_screen_center_position() - size / 2, size)


func is_frozen() -> bool:
	return _freeze_left > 0.0


func _physics_process(delta: float) -> void:
	if battle == null:
		return
	if _attack_pressed(delta):
		battle.player.buffer.press()
	if _freeze_left > 0.0:
		_freeze_left -= delta
		if _freeze_left <= 0.0:
			_actors.process_mode = Node.PROCESS_MODE_INHERIT
		return
	var hp := battle.player.health.hp
	if battle.step(delta, _move()):
		var hurt := battle.player.health.hp < hp
		_freeze_left = feel.hitstop_player_sec if hurt else feel.hitstop_enemy_sec
		_actors.process_mode = Node.PROCESS_MODE_DISABLED


func _move() -> Vector2:
	match bot:
		&"":
			return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		&"circle":
			var from_center := battle.player.position - arena.inner_rect().get_center()
			var tangent := from_center.orthogonal().normalized()
			var correction := (BOT_CIRCLE_RADIUS - from_center.length()) / BOT_CIRCLE_RADIUS
			return (tangent + from_center.normalized() * correction).limit_length(1.0)
	return Vector2.ZERO


func _attack_pressed(delta: float) -> bool:
	if bot == &"":
		return Input.is_action_just_pressed(&"attack")
	if bot != &"circle":
		return false
	_bot_time += delta
	if _bot_time < BOT_SWING_SEC:
		return false
	_bot_time = 0.0
	return true


func _on_player_hit(_hp: int, _max_hp: int) -> void:
	player_view.camera.add_trauma(feel.shake_player_hit)


func _on_enemy_killed(enemy_id: StringName, _pos: Vector2, _xp: int) -> void:
	if enemy_data[enemy_id].shake_on_kill:
		player_view.camera.add_trauma(feel.shake_heavy_kill)
