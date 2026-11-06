extends Node2D
## The greybox: the player and three training dummies that come back after they
## die, to judge movement, the swing, aim assist, hit-stop and knockback.
## godot_console --path . res://game/world/gym.tscn

const ARENA := preload("res://data/arenas/gym.tres")
const DUMMY_TILES: Array[Vector2i] = [Vector2i(20, 8), Vector2i(22, 11), Vector2i(20, 14)]
const RESPAWN_SEC := 1.0

var _view: BattleView
var _dummies: Array[EnemyBrain] = []
var _respawn_left: PackedFloat32Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(DebugArgs.current.seed_value, 0)
	_view = BattleView.new()
	if DebugArgs.current.bot != &"":
		_view.bot = Bot.new(DebugArgs.current.bot)
	add_child(_view)
	_view.start(ARENA, rng)
	_view.battle.player.god = DebugArgs.current.god
	for i in DUMMY_TILES.size():
		_dummies.append(_spawn_dummy(i))
		_respawn_left.append(0.0)
	for id in DebugArgs.current.spawns:
		for n in DebugArgs.current.spawns[id]:
			_view.spawn_offscreen(id)


func _physics_process(delta: float) -> void:
	for i in _dummies.size():
		if _dummies[i].is_alive():
			continue
		_respawn_left[i] += delta
		if _respawn_left[i] >= RESPAWN_SEC:
			_respawn_left[i] = 0.0
			_dummies[i] = _spawn_dummy(i)


func _spawn_dummy(i: int) -> EnemyBrain:
	var pos := (Vector2(DUMMY_TILES[i]) + Vector2.ONE / 2) * ArenaData.TILE
	return _view.spawn(&"dummy", pos)
