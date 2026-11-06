class_name SpawnPicker
extends RefCounted
## Where a new enemy appears: outside the camera view, inside the arena, clear of
## blocks, and biased toward the player's heading so running in a circle doesn't
## leave the crowd behind.

## Distance beyond the view's corner, so a spawn is never half on screen.
const MARGIN := 24.0
## Spawns land in a band this deep beyond the ring.
const RING_DEPTH := 48.0
## Spread of the spawn angle around the heading, in radians.
const HEADING_SPREAD := 0.9
const RING_TRIES := 12
const FALLBACK_TRIES := 64


## view is the camera's visible rect. heading is zero when the player stands still.
static func pick(
	rng: RandomNumberGenerator,
	arena: ArenaData,
	view: Rect2,
	heading: Vector2,
	radius: float,
) -> Vector2:
	var center := view.get_center()
	var ring := view.size.length() / 2 + MARGIN
	for i in RING_TRIES:
		var angle := rng.randf() * TAU
		if heading != Vector2.ZERO:
			angle = heading.angle() + rng.randfn(0.0, HEADING_SPREAD)
		var p := center + Vector2.from_angle(angle) * (ring + rng.randf() * RING_DEPTH)
		if _ok(p, arena, view, radius):
			return p
	# The ring fell outside the arena (the view is near a wall): anywhere off screen.
	var inner := arena.inner_rect().grow(-radius)
	for i in FALLBACK_TRIES:
		var p := inner.position + Vector2(rng.randf(), rng.randf()) * inner.size
		if _ok(p, arena, view, radius):
			return p
	return _farthest_corner(inner, center)


static func _ok(p: Vector2, arena: ArenaData, view: Rect2, radius: float) -> bool:
	return not view.grow(MARGIN).has_point(p) and arena.is_free(p, radius)


## The arena is wider than one view, so its farthest corner is always off screen.
static func _farthest_corner(inner: Rect2, center: Vector2) -> Vector2:
	var best := inner.position
	for c: Vector2 in [
		inner.position,
		inner.end,
		Vector2(inner.end.x, inner.position.y),
		Vector2(inner.position.x, inner.end.y),
	]:
		if c.distance_squared_to(center) > best.distance_squared_to(center):
			best = c
	return best
