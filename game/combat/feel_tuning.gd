class_name FeelTuning
extends Resource
## Game feel values from the Design page (data/tuning/feel.tres).

@export var hitstop_enemy_sec: float = 0.04
@export var hitstop_player_sec: float = 0.08
## Screenshake: trauma added per event (0 to 1), max offset and decay per second.
@export var shake_player_hit: float = 0.5
@export var shake_heavy_kill: float = 0.4
@export var shake_max_px: float = 6.0
@export var shake_decay: float = 2.5
@export var knockback_enemy_tiles: float = 0.5
@export var knockback_player_tiles: float = 1.0
@export var knockback_sec: float = 0.12
## The player's hurt pose, which also carries the knockback.
@export var hurt_sec: float = 0.2
@export var flash_sec: float = 0.034
@export var invulnerable_sec: float = 0.8
@export var blink_hz: float = 8.0
@export var input_buffer_sec: float = 0.12
## Full width of the aim assist cone.
@export var aim_assist_deg: float = 30.0
## How long an enemy shows its spawn before it moves or hurts.
@export var enemy_spawn_sec: float = 0.25
