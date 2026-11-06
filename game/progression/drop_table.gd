class_name DropTable
extends Resource
## What a dying enemy leaves besides its XP gem (data/tuning/drops.tres).

## Chance that a kill also drops a heart.
@export var heart_chance: float = 0.02
@export var heart_heal: int = 20
## Past this many gems on the ground the oldest merge.
@export var gem_cap: int = 150
