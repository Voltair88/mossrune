class_name Bot
extends RefCounted
## Plays without input, for the play checks and the balance simulation.
## Moves: idle stands still; circle runs round the arena centre and swings on a
## timer; kite keeps away from the crowd, picks up gems and swings at what comes
## close; wall_hug sits in a corner and swings at what comes close.
## Picks: random or first, for the level-up offer.

const MOVES: Array[StringName] = [&"idle", &"circle", &"kite", &"wall_hug"]
const CIRCLE_RADIUS := 96.0
const CIRCLE_SWING_SEC := 0.3
## Enemies closer than this push the kiting bot away.
const KITE_SENSE_TILES := 4.0
## Gems closer than this pull the kiting bot.
const GEM_SENSE_TILES := 6.0
const GEM_PULL := 0.6
## Swing when an enemy is within this many reaches.
const SWING_REACH_FACTOR := 1.2
const CORNER_TILES := Vector2(2, 2)

var move_policy: StringName
var pick_policy: StringName
## This frame's decision, set by think().
var move := Vector2.ZERO
var swing: bool = false
var _swing_time: float = 0.0


func _init(move_name: StringName, pick_name: StringName = &"random") -> void:
	move_policy = move_name
	pick_policy = pick_name


func think(b: Battle, delta: float) -> void:
	_swing_time += delta
	move = Vector2.ZERO
	swing = false
	var p := b.player
	match move_policy:
		&"circle":
			var from_center := p.position - b.arena.inner_rect().get_center()
			var tangent := from_center.orthogonal().normalized()
			var correction := (CIRCLE_RADIUS - from_center.length()) / CIRCLE_RADIUS
			move = (tangent + from_center.normalized() * correction).limit_length(1.0)
			swing = _swing_time >= CIRCLE_SWING_SEC
		&"kite":
			move = _kite(b)
			_swing_at_nearest(b)
		&"wall_hug":
			var corner := b.arena.inner_rect().position + CORNER_TILES * ArenaData.TILE
			move = ((corner - p.position) / ArenaData.TILE).limit_length(1.0)
			_swing_at_nearest(b)
	if swing:
		_swing_time = 0.0


func pick(offer: Array[UpgradeData], rng: RandomNumberGenerator) -> UpgradeData:
	if pick_policy == &"first":
		return offer[0]
	return offer[rng.randi_range(0, offer.size() - 1)]


## Away from nearby enemies (closer ones push harder), toward the arena centre
## so it doesn't get cornered, and toward the nearest gem.
func _kite(b: Battle) -> Vector2:
	var p := b.player.position
	var sense := KITE_SENSE_TILES * ArenaData.TILE
	var away := Vector2.ZERO
	for e in b.enemies:
		var d := p - e.position
		var len := d.length()
		if len > 0.0 and len < sense:
			away += d * (sense - len) / (len * sense)
	var inner := b.arena.inner_rect()
	var home := (inner.get_center() - p) / (inner.size.length() / 2)
	var gem := Vector2.ZERO
	var best := GEM_SENSE_TILES * ArenaData.TILE
	for g in b.gems.positions:
		var len := g.distance_to(p)
		if len < best:
			best = len
			gem = (g - p).normalized() * GEM_PULL
	return (away + home + gem).limit_length(1.0)


## On a swing frame the bot turns to the nearest enemy, so the swing faces it.
func _swing_at_nearest(b: Battle) -> void:
	if _swing_time < b.player.stats.attack_cooldown_sec:
		return
	var p := b.player.position
	var reach := b.player.reach_px() * SWING_REACH_FACTOR
	var best := reach
	for e in b.enemies:
		var len := e.position.distance_to(p)
		if len < best:
			best = len
			move = (e.position - p).normalized()
			swing = true
