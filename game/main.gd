extends Node
## The run: waves spawn into the battle, the clock runs to the end of the last
## wave, and the run ends in victory or game over. The UI only listens to Events.

const ARENA := preload("res://data/arenas/ruin.tres")
const WAVE_DIR := "res://data/waves"
const PLAYING := &"playing"
const GAME_OVER := &"game_over"
const VICTORY := &"victory"
## The end screen ignores input briefly, so a held attack doesn't skip it.
const RESTART_DELAY_SEC := 0.75

var run: Run
var spawner: WaveSpawner
var flow := StateMachine.new(PLAYING, { PLAYING: [GAME_OVER, VICTORY], GAME_OVER: [], VICTORY: [] })
var _view: BattleView
var _wave: int = -1
var _second: int = -1


func _ready() -> void:
	var args := DebugArgs.current
	for e in args.errors:
		push_warning(e)
	spawner = WaveSpawner.new(WaveSchedule.load_dir(WAVE_DIR))
	var waves := spawner.schedule.waves
	var seed_value := args.seed_value if args.seed_value >= 0 else randi()
	run = Run.new(seed_value, waves[waves.size() - 1].end_sec())
	run.level = args.level
	run.elapsed = waves[mini(args.wave, waves.size()) - 1].start_sec

	_view = BattleView.new()
	_view.bot = args.bot
	add_child(_view)
	move_child(_view, 0)
	_view.start(ARENA, run.rng)
	_view.battle.player.god = args.god
	for id in args.spawns:
		for n in args.spawns[id]:
			_view.spawn_offscreen(id)
	Events.player_died.connect(_on_player_died)
	if args.perf_out != "":
		var probe := PerfProbe.new()
		probe.path = args.perf_out
		probe.view = _view
		probe.run = run
		add_child(probe)


func _physics_process(delta: float) -> void:
	flow.tick(delta)
	if flow.state != PLAYING:
		if flow.time_in_state >= RESTART_DELAY_SEC and Input.is_action_just_pressed(&"attack"):
			get_tree().reload_current_scene()
		return
	if _view.is_frozen():
		return
	var t0 := run.elapsed
	run.elapsed += delta
	for i in spawner.due(t0, run.elapsed):
		_view.spawn_offscreen(spawner.pick_enemy(run.elapsed, run.rng))
	var wave := spawner.wave_index_at(run.elapsed)
	if wave != _wave:
		_wave = wave
		Events.wave_started.emit(wave + 1)
	if run.seconds() != _second:
		_second = run.seconds()
		Events.time_changed.emit(_second)
	if run.is_won():
		_end(VICTORY)


func _on_player_died() -> void:
	_end(GAME_OVER)


func _end(state: StringName) -> void:
	if flow.go(state):
		_view.process_mode = Node.PROCESS_MODE_DISABLED
		Events.run_ended.emit(state == VICTORY, run.elapsed, run.level)
