class_name PlayerStats
extends Resource
## The player's base numbers (data/tuning/player_stats.tres). Upgrades in phase 4
## change a copy of this for the run.

@export var max_hp: int = 100
@export var speed_tiles: float = 5.0
## Movement speed factor while attacking.
@export var attack_move_factor: float = 0.5
@export var damage: int = 10
## From the start of one swing to the next.
@export var attack_cooldown_sec: float = 0.5
## Length of the attack pose.
@export var attack_sec: float = 0.25
## The arc deals damage only at the start of the attack pose.
@export var swing_active_sec: float = 0.1
@export var reach_tiles: float = 1.5
@export var arc_deg: float = 120.0
@export var pickup_radius_tiles: float = 1.5
@export var radius_px: float = 5.0
## HP regained per second (Regrowth). 0 at the start of a run.
@export var regen_per_sec: float = 0.0
