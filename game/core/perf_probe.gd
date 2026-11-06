class_name PerfProbe
extends Node
## Collects frame and battle timings and writes them as JSON when the game quits.
## Added by the main scene for --perf-out=<path>; tools/play-check.ps1 reads it.

## The first frames load and warm caches, so they are left out.
const WARMUP_FRAMES := 60
const USEC_PER_MSEC := 1000.0
const MSEC_PER_SEC := 1000.0

var path: String
var view: BattleView
var run: Run
var _frames: int = 0
var _step_usec: int = 0
var _enemy_usec: int = 0
var _enemy_usec_max: int = 0
var _frame_sec: float = 0.0
var _enemies_max: int = 0
var _enemies_sum: int = 0
var _kills: int = 0
var _seen: int = 0


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)


func _physics_process(_delta: float) -> void:
	_seen += 1
	if _seen <= WARMUP_FRAMES:
		return
	var b := view.battle
	_frames += 1
	_step_usec += b.step_usec
	_enemy_usec += b.enemy_usec
	_enemy_usec_max = maxi(_enemy_usec_max, b.enemy_usec)
	_frame_sec += (
		Performance.get_monitor(Performance.TIME_PROCESS)
		+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	)
	_enemies_max = maxi(_enemies_max, b.enemies.size())
	_enemies_sum += b.enemies.size()


func _exit_tree() -> void:
	var n := maxi(_frames, 1)
	var report := {
		"frames": _frames,
		"run_seconds": run.elapsed,
		"player_hp": view.battle.player.health.hp,
		"player_state": String(view.battle.player.machine.state),
		"kills": _kills,
		"enemies_max": _enemies_max,
		"enemies_mean": float(_enemies_sum) / n,
		"frame_ms_mean": _frame_sec * MSEC_PER_SEC / n,
		"step_ms_mean": _step_usec / USEC_PER_MSEC / n,
		"enemy_ms_mean": _enemy_usec / USEC_PER_MSEC / n,
		"enemy_ms_max": _enemy_usec_max / USEC_PER_MSEC,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("perf: cannot write " + path)
		return
	f.store_string(JSON.stringify(report, "  ") + "\n")


func _on_enemy_killed(_id: StringName, _pos: Vector2, _xp: int) -> void:
	_kills += 1
