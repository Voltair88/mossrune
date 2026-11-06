class_name UpgradeData
extends Resource
## One upgrade (data/upgrades/*.tres). A stack changes one PlayerStats value.
## Stats are rebuilt from the base values and the stack counts, so stacks add up
## exactly and the order of picks doesn't matter.

@export var id: StringName
## Upper case: the pixel font has no lower case.
@export var title: String
@export var text: String
@export var icon: Texture2D
## The PlayerStats property a stack changes. Empty for an upgrade that only heals.
@export var stat: StringName
## Added per stack: a share of the base value when percent is true, else a flat amount.
@export var per_stack: float = 0.0
@export var percent: bool = true
@export var cap: int = 1
@export var weight: float = 1.0
## Counts for the pity rule: an offer without one of these raises the pity count.
@export var raises_damage: bool = false
## HP healed when it is picked.
@export var heal: int = 0
## Only offered to fill the slots when fewer than three upgrades are left.
@export var filler: bool = false
