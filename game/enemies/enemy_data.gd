class_name EnemyData
extends Resource
## One enemy type. Files live in data/enemies/, named after the id.
## Distances are in tiles and times in seconds, as on the Design page.

@export var id: StringName = &""
## Sheet prefix in assets/sprites, e.g. "slime" for slime_move.png.
@export var sheet: String = ""
@export var anim_move: StringName = &"move"
## Empty when the enemy has no windup or attack pose; the move animation plays.
@export var anim_windup: StringName = &""
@export var anim_attack: StringName = &""
@export var speed_tiles: float = 2.5
@export var hp: int = 15
@export var contact_damage: int = 5
@export var xp: int = 1
@export var radius_px: float = 6.0
## lunge: windup, then a hop. slam: windup, then a circle of damage.
## weave: no attack, a sine path toward the player. none: stands still.
@export_enum("lunge", "slam", "weave", "none") var pattern: String = "lunge"
## Distance to the player that starts the windup.
@export var attack_range_tiles: float = 2.0
@export var windup_sec: float = 0.3
@export var attack_sec: float = 0.25
@export var recover_sec: float = 0.5
@export var lunge_tiles: float = 1.5
@export var slam_radius_tiles: float = 1.0
@export var weave_tiles: float = 1.0
@export var weave_hz: float = 1.5
## Delay before the enemy notices where the player went.
@export var reaction_min_sec: float = 0.2
@export var reaction_max_sec: float = 0.4
@export var shake_on_kill: bool = false
