extends Node
## Signals only: gameplay emits, UI and effects listen. No state, no functions.
## This folder skips GDScript warnings (project.godot directory_rules) because the
## unused-signal warning is per class and every signal here is emitted elsewhere.
## test_events.gd checks that each one is emitted somewhere in game/.

signal enemy_hit(position: Vector2)
signal enemy_killed(enemy_id: StringName, position: Vector2, xp: int)
signal player_hit(hp: int, max_hp: int)
signal player_healed(hp: int, max_hp: int)
signal player_died
signal wave_started(index: int)
signal time_changed(seconds: int)
## xp is the XP toward the next level, needed the cost of that level.
signal xp_collected(xp: int, needed: int)
signal level_up(level: int, offer: Array[UpgradeData])
## The only gameplay signal the UI emits: the pick on the level-up screen.
signal upgrade_chosen(upgrade: UpgradeData)
signal run_ended(won: bool, seconds: float, level: int, best_seconds: float, best_level: int)
## UI requests: a setting changed in the pause menu, "again" on the end panel.
signal settings_changed(shake: bool, flashes: bool)
signal restart_requested
