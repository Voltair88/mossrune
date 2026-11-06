class_name UpgradePool
extends RefCounted
## The upgrades of a run: the stack counts, the level-up offer and the stats
## they give. An offer is up to 3 different uncapped upgrades, weighted; after
## PITY_AFTER offers without a damage upgrade, the next one includes one.

const OFFER_SIZE := 3
const PITY_AFTER := 3

var upgrades: Array[UpgradeData] = []
var filler: UpgradeData
var counts: Dictionary[StringName, int] = { }
var offers_without_damage: int = 0


static func load_dir(path: String) -> UpgradePool:
	var pool := UpgradePool.new()
	for f in DirAccess.get_files_at(path):
		if not f.ends_with(".tres"):
			continue
		var u := load(path.path_join(f)) as UpgradeData
		if u.filler:
			pool.filler = u
		else:
			pool.upgrades.append(u)
	return pool


func count(u: UpgradeData) -> int:
	return counts.get(u.id, 0)


func offer(rng: RandomNumberGenerator) -> Array[UpgradeData]:
	var open: Array[UpgradeData] = upgrades.filter(
		func(u: UpgradeData) -> bool:
			return count(u) < u.cap,
	)
	var out: Array[UpgradeData] = []
	if offers_without_damage >= PITY_AFTER:
		var damage: Array[UpgradeData] = open.filter(
			func(u: UpgradeData) -> bool:
				return u.raises_damage,
		)
		if not damage.is_empty():
			var pick := _weighted(damage, rng)
			out.append(pick)
			open.erase(pick)
	while out.size() < OFFER_SIZE and not open.is_empty():
		var pick := _weighted(open, rng)
		out.append(pick)
		open.erase(pick)
	if out.size() < OFFER_SIZE and filler != null:
		out.append(filler)
	if out.any(
		func(u: UpgradeData) -> bool:
			return u.raises_damage,
	):
		offers_without_damage = 0
	else:
		offers_without_damage += 1
	return out


func take(u: UpgradeData) -> void:
	if not u.filler:
		counts[u.id] = count(u) + 1


## A fresh copy of base with every stack applied.
func stats_from(base: PlayerStats) -> PlayerStats:
	var s := base.duplicate() as PlayerStats
	for u in upgrades:
		var n := count(u)
		if n == 0 or u.stat == &"":
			continue
		var start: Variant = base.get(u.stat)
		var v := float(start)
		v = v * (1.0 + u.per_stack * n) if u.percent else v + u.per_stack * n
		s.set(u.stat, roundi(v) if start is int else v)
	return s


static func _weighted(from: Array[UpgradeData], rng: RandomNumberGenerator) -> UpgradeData:
	var total := 0.0
	for u in from:
		total += u.weight
	var roll := rng.randf() * total
	for u in from:
		roll -= u.weight
		if roll < 0.0:
			return u
	return from[from.size() - 1]
