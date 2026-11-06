extends Node
## The run: a Session drives the clock, waves and level-ups, a BattleView runs
## the fight, and the run ends in victory or game over. The UI only talks
## through Events.

const ARENA := preload("res://data/arenas/ruin.tres")
const XP_CURVE := preload("res://data/tuning/xp_curve.tres")
const DROPS := preload("res://data/tuning/drops.tres")
const WAVE_DIR := "res://data/waves"
const UPGRADE_DIR := "res://data/upgrades"
const PLAYING := &"playing"
const LEVEL_UP := &"level_up"
const GAME_OVER := &"game_over"
const VICTORY := &"victory"

var run: Run
var session: Session
var save: SaveStore
var flow := StateMachine.new(
	PLAYING,
	{ PLAYING: [LEVEL_UP, GAME_OVER, VICTORY], LEVEL_UP: [PLAYING], GAME_OVER: [], VICTORY: [] },
)
var _view: BattleView
var _bot: Bot
## Debug switches make a run that shouldn't count for the records.
var _counts: bool = true


func _ready() -> void:
	var args := DebugArgs.current
	for e in args.errors:
		push_warning(e)
	save = SaveStore.read(SaveStore.PATH)
	GameSettings.shake = save.shake
	GameSettings.flashes = save.flashes
	_counts = (
		args.bot == &"" and not args.god and args.wave == 1
		and args.level == 1 and args.spawns.is_empty()
	)

	var spawner := WaveSpawner.new(WaveSchedule.load_dir(WAVE_DIR))
	var waves := spawner.schedule.waves
	var seed_value := args.seed_value if args.seed_value >= 0 else randi()
	run = Run.new(seed_value, waves[waves.size() - 1].end_sec(), XP_CURVE)
	run.level = args.level
	run.elapsed = waves[mini(args.wave, waves.size()) - 1].start_sec

	_view = BattleView.new()
	if args.bot != &"":
		_bot = Bot.new(args.bot)
		_view.bot = _bot
	add_child(_view)
	move_child(_view, 0)
	_view.start(ARENA, run.rng, DROPS)
	_view.battle.player.god = args.god
	session = Session.new(
		run,
		_view.battle,
		spawner,
		UpgradePool.load_dir(UPGRADE_DIR),
		_view.spawn_offscreen,
	)
	for id in args.spawns:
		for n in args.spawns[id]:
			_view.spawn_offscreen(id)
	Events.player_died.connect(_on_player_died)
	Events.upgrade_chosen.connect(_on_upgrade_chosen)
	Events.settings_changed.connect(_on_settings_changed)
	Events.restart_requested.connect(_on_restart_requested)
	if args.perf_out != "":
		var probe := PerfProbe.new()
		probe.path = args.perf_out
		probe.view = _view
		probe.run = run
		add_child(probe)


func _physics_process(delta: float) -> void:
	flow.tick(delta)
	if flow.state != PLAYING or _view.is_frozen():
		return
	session.tick(delta)
	if run.is_won():
		_end(VICTORY)
	elif session.pending_levels > 0 and flow.go(LEVEL_UP):
		_view.process_mode = Node.PROCESS_MODE_DISABLED
		_offer_next()


func _offer_next() -> void:
	session.next_offer()
	if _bot != null:
		Events.upgrade_chosen.emit(_bot.pick(session.offer, run.rng))


func _on_upgrade_chosen(u: UpgradeData) -> void:
	if flow.state != LEVEL_UP or not session.choose(u):
		return
	if session.pending_levels > 0:
		# Deferred, so every listener sees this pick before the next offer.
		_offer_next.call_deferred()
	elif flow.go(PLAYING):
		_view.process_mode = Node.PROCESS_MODE_INHERIT


func _on_player_died() -> void:
	_end(GAME_OVER)


func _end(state: StringName) -> void:
	if not flow.go(state):
		return
	_view.process_mode = Node.PROCESS_MODE_DISABLED
	if _counts and save.record(run.elapsed, run.level):
		_write_save()
	Events.run_ended.emit(
		state == VICTORY,
		run.elapsed,
		run.level,
		save.best_seconds,
		save.best_level,
	)


func _on_settings_changed(shake: bool, flashes: bool) -> void:
	GameSettings.shake = shake
	GameSettings.flashes = flashes
	save.shake = shake
	save.flashes = flashes
	_write_save()


func _on_restart_requested() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _write_save() -> void:
	var err := save.write(SaveStore.PATH)
	if err != OK:
		push_warning("could not save: " + error_string(err))
